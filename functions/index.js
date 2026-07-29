/**
 * IQ-Market Telegram Bot Webhook (Firebase Cloud Function)
 */

const functions = require('firebase-functions/v1');
const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin     = require('firebase-admin');
const crypto    = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// Import Telegram functions from telegram_bot.js
const telegramBot = require('./telegram_bot');

exports.registerWebhook = telegramBot.registerWebhook;
exports.telegramWebhook = telegramBot.telegramWebhook;
exports.sendTelegramOtp = telegramBot.sendTelegramOtp;
exports.secureSendTelegramMessage = telegramBot.secureSendTelegramMessage;
exports.onVerificationUpdate = telegramBot.onVerificationUpdate;
exports.verifyTelegramOtp = telegramBot.verifyTelegramOtp;


// ─── FIRESTORE TRIGGER: new chat message → FCM push ──────────────────────────
exports.onNewMessage = onDocumentCreated('chats/{chatId}/messages/{msgId}', async (event) => {
    const message  = event.data.data();
    const chatId   = event.params.chatId;
    const senderId = message.senderId;

    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;

    const chatData   = chatSnap.data();
    const users      = chatData.users || [];
    const receiverId = users.find(uid => uid !== senderId);
    if (!receiverId) return;

    const userSnap = await db.collection('users').doc(receiverId).get();
    if (!userSnap.exists) return;

    const receiverData = userSnap.data();
    const blockedUsers = receiverData.blockedUserIds || [];
    if (blockedUsers.includes(senderId)) {
      console.log(`[onNewMessage] FCM skipped: sender ${senderId} is blocked by receiver ${receiverId}`);
      return;
    }

    const receiverToken = receiverData.fcmToken;
    if (!receiverToken) return;

    const senderName = chatData[`name_${senderId}`] || 'Пользователь';
    const adTitle    = chatData.adTitle || 'IQ Market';

    const payload = {
      token       : receiverToken,
      notification: {
        title: `${senderName} (${adTitle})`,
        body : message.text,
      },
      data: {
        type      : 'chat',
        chatId    : chatId,
        senderId  : senderId,
        adId      : chatData.adId    || '',
        adTitle   : chatData.adTitle || '',
        adImage   : chatData.adImage || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority    : 'high',
        notification: { channelId: 'high_importance_channel', sound: 'default' },
      },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    };

    try {
      await admin.messaging().send(payload);
      console.log(`[onNewMessage] FCM sent to ${receiverId}`);
    } catch (error) {
      console.error('[onNewMessage] FCM Error:', error);
      if (error.code === 'messaging/registration-token-not-registered' ||
          error.code === 'messaging/invalid-registration-token') {
        await db.collection('users').doc(receiverId).update({ fcmToken: admin.firestore.FieldValue.delete() });
        console.log(`[onNewMessage] Stale FCM token removed for ${receiverId}`);
      }
    }
  }
);

// ─── HELPER: Expired Ads Lifecycle Processing ────────────────────────────────
async function runExpiredAdsCheckLogic() {
  const now = admin.firestore.Timestamp.now();
  const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const warningTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() + 3 * 24 * 60 * 60 * 1000);

  let expiredCount = 0;
  let notifyCount  = 0;
  let batchOps = [];
  let currentBatch = db.batch();
  let batchCount = 0;

  const expiredDocsMap = new Map();

  // 1. Ищем объявления, у которых expiresAt <= текущего времени
  const expiredByExpirySnap = await db.collection('ads')
    .where('expiresAt', '<=', now)
    .where('status', '==', 'active')
    .get();
  expiredByExpirySnap.forEach((doc) => expiredDocsMap.set(doc.id, doc));

  // 2. Ищем легаси объявления без expiresAt, которые были созданы > 30 дней назад
  const expiredByTimestampSnap = await db.collection('ads')
    .where('timestamp', '<=', thirtyDaysAgo)
    .where('status', '==', 'active')
    .get();
  expiredByTimestampSnap.forEach((doc) => expiredDocsMap.set(doc.id, doc));

  const sendPromises = [];

  // Автоматический перенос просроченных объявлений в архив
  for (const doc of expiredDocsMap.values()) {
    const data = doc.data();
    currentBatch.update(doc.ref, {
      status: 'archived',
      active: false,
      archivedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    batchCount++;
    expiredCount++;

    if (batchCount >= 450) {
      batchOps.push(currentBatch.commit());
      currentBatch = db.batch();
      batchCount = 0;
    }

    // Сохранение уведомления в личный кабинет продавца и отправка Push
    if (data.userId) {
      const userRef = db.collection('users').doc(data.userId);
      const notifPromise = userRef.collection('notifications').add({
        title: 'Объявление перенесено в архив 📁',
        body: `Срок размещения «${data.title || 'Объявление'}» (30 дней) истек. Вы можете в любой момент бесплатно продлить его в профиле!`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: 'ad_archived',
        isRead: false,
        data: { adId: doc.id }
      }).catch(e => console.error('[checkExpiredAds] In-app notif error:', e));

      sendPromises.push(notifPromise);

      const pushPromise = userRef.get().then((userSnap) => {
        if (userSnap.exists && userSnap.data().fcmToken) {
          const payload = {
            token: userSnap.data().fcmToken,
            notification: {
              title: 'Объявление перенесено в архив 📁',
              body: `Срок размещения «${data.title || 'Объявление'}» истек. Продлите его в профиле!`,
            },
            data: { type: 'ad_archived', adId: doc.id, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
          };
          return admin.messaging().send(payload).catch(e => console.error('[checkExpiredAds] FCM Error:', e));
        }
      });
      sendPromises.push(pushPromise);
    }
  }

  // 3. Отправка предупреждающих уведомлений (за 3 дня до истечения)
  const expiringAdsSnap = await db.collection('ads')
    .where('expiresAt', '<=', warningTimestamp)
    .where('expiresAt', '>', now)
    .where('status', '==', 'active')
    .get();

  for (const doc of expiringAdsSnap.docs) {
    const data = doc.data();
    if (data.notifiedExpiry === true) continue;
    currentBatch.update(doc.ref, { notifiedExpiry: true });
    batchCount++;
    if (batchCount >= 450) {
      batchOps.push(currentBatch.commit());
      currentBatch = db.batch();
      batchCount = 0;
    }

    if (data.userId) {
      const userSnap = await db.collection('users').doc(data.userId).get();
      if (userSnap.exists && userSnap.data().fcmToken) {
        const payload = {
          token       : userSnap.data().fcmToken,
          notification: {
            title: 'Объявление скоро истечет ⏳',
            body : `Срок размещения «${data.title}» истекает менее чем через 3 дня. Продлите его в профиле!`,
          },
          data: { type: 'ad_expiring', adId: doc.id, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
        };
        const sendPromise = admin.messaging().send(payload)
          .then(() => notifyCount++)
          .catch(e => console.error('[checkExpiredAds] Warning Push error:', e));
        sendPromises.push(sendPromise);
      }
    }
  }

  if (batchCount > 0) batchOps.push(currentBatch.commit());

  if (batchOps.length > 0 || sendPromises.length > 0) {
    await Promise.all(batchOps);
    await Promise.all(sendPromises);
    console.log(`[checkExpiredAds] Archived ${expiredCount}, notified ${notifyCount}`);
  } else {
    console.log('[checkExpiredAds] No expired or expiring ads today.');
  }

  return { expiredCount, notifyCount };
}

// ─── CRON: Check Expired Ads — каждый день в 03:00 Алматы ────────────────────
exports.checkExpiredAds = functions.pubsub.schedule('0 3 * * *').timeZone('Asia/Almaty').onRun(async () => {
  try {
    await runExpiredAdsCheckLogic();
  } catch (error) {
    console.error('[checkExpiredAds] Cron Error:', error);
  }
});

// ─── HTTPS CALLABLE: Admin manual trigger for ad lifecycle check ─────────────
exports.triggerAdLifecycleCheck = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Авторизуйтесь для выполнения операции');
  }

  const requesterSnap = await db.collection('users').doc(context.auth.uid).get();
  if (!requesterSnap.exists || requesterSnap.data().accountType !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Доступ разрешен только администраторам');
  }

  const result = await runExpiredAdsCheckLogic();
  return { success: true, ...result };
});

// Rate limiting map for Gemini proxy (in-memory per container instance)
const geminiRateLimitMap = new Map();
const GEMINI_RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const GEMINI_MAX_REQUESTS_PER_WINDOW = 30; // 30 requests / min per user

// Allowlist pattern for valid Gemini API endpoints
const GEMINI_ALLOWED_PATH_REGEX = /^\/v1(beta)?\/models\/gemini-[a-zA-Z0-9.\-]+:(generateContent|streamGenerateContent|countTokens|embedContent)$/;

// ─── SECURE GEMINI CALL PROXY ─────────────────────────────────────────────────
exports.secureGeminiCall = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', 'https://iqmarket.kz');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).send('');

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).send('Unauthorized: Missing token');
  }
  const idToken = authHeader.split('Bearer ')[1];
  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    return res.status(401).send('Unauthorized: Invalid token');
  }

  // 1. Path Allowlist Check
  const reqPath = req.path || '';
  if (!GEMINI_ALLOWED_PATH_REGEX.test(reqPath)) {
    console.warn(`[secureGeminiCall] Blocked unauthorized path: ${reqPath} from user ${decodedToken.uid}`);
    return res.status(403).send('Forbidden: Invalid API endpoint');
  }

  // 2. Rate Limiting Check (per UID)
  const uid = decodedToken.uid;
  const now = Date.now();
  let userRateData = geminiRateLimitMap.get(uid);
  if (!userRateData || (now - userRateData.startTime) > GEMINI_RATE_LIMIT_WINDOW_MS) {
    userRateData = { startTime: now, count: 1 };
    geminiRateLimitMap.set(uid, userRateData);
  } else {
    userRateData.count++;
    if (userRateData.count > GEMINI_MAX_REQUESTS_PER_WINDOW) {
      console.warn(`[secureGeminiCall] Rate limit exceeded for user ${uid}`);
      return res.status(429).send('Too Many Requests: Rate limit exceeded');
    }
  }

  const keySelector = req.query.key || 'moderation';
  const targetApiKey = keySelector === 'assistant'
    ? process.env.GEMINI_ASSISTANT_KEY
    : process.env.GEMINI_MODERATION_KEY;

  if (!targetApiKey) {
    return res.status(500).send('Server configuration error');
  }

  const targetUrl = `https://generativelanguage.googleapis.com${reqPath}?key=${targetApiKey}`;

  try {
    const fetchResponse = await fetch(targetUrl, {
      method : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body   : JSON.stringify(req.body),
    });
    res.status(fetchResponse.status);
    const contentType = fetchResponse.headers.get('content-type');
    if (contentType) res.setHeader('content-type', contentType);
    if (fetchResponse.body) {
      const { Readable } = require('stream');
      Readable.fromWeb(fetchResponse.body).pipe(res);
    } else {
      res.end();
    }
  } catch (error) {
    console.error('[secureGeminiCall] Error:', error);
    res.status(500).send('Internal Server Error');
  }
});


// ─── FIRESTORE TRIGGER: new notification → FCM push ──────────────────────────
exports.onNewNotification = onDocumentCreated('users/{userId}/notifications/{notifId}', async (event) => {
    const notification = event.data.data();
    const userId       = event.params.userId;

    // Исключаем Push-уведомления для чатов из этого триггера,
    // так как они отправляются более подробно через триггер onNewMessage.
    if (notification.type === 'chat') {
        console.log(`[onNewNotification] Skipping FCM push because type is 'chat' (handled by onNewMessage)`);
        return;
    }

    const userSnap = await db.collection('users').doc(userId).get();
    if (!userSnap.exists) return;

    const token = userSnap.data().fcmToken;
    if (!token) return;

    const payload = {
      token,
      notification: {
        title: notification.title,
        body : notification.body,
      },
      data: {
        type        : notification.type || 'system',
        ...(notification.data || {}),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority    : 'high',
        notification: { channelId: 'high_importance_channel', sound: 'default' },
      },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    };

    try {
      await admin.messaging().send(payload);
      console.log(`[onNewNotification] FCM sent to ${userId}`);
    } catch (error) {
      console.error('[onNewNotification] FCM Error:', error);
      if (error.code === 'messaging/registration-token-not-registered' ||
          error.code === 'messaging/invalid-registration-token') {
        await db.collection('users').doc(userId).update({ fcmToken: admin.firestore.FieldValue.delete() });
        console.log(`[onNewNotification] Stale FCM token removed for ${userId}`);
      }
    }
  }
);

// ─── HTTPS CALLABLE: sendSystemNotification ──────────────────────────────────
exports.sendSystemNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }

  const targetUid = data.targetUid;
  const title = data.title;
  const body = data.body;
  const type = data.type || 'system';
  const payload = data.payload || null;

  if (!targetUid || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Неполные параметры уведомления');
  }

  await db.collection('users')
    .doc(targetUid)
    .collection('notifications')
    .add({
      title: title,
      body: body,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: type,
      senderId: context.auth.uid,
      isRead: false,
      data: payload
    });

  return { success: true };
});



// ─── HELPER: isAdActive ──────────────────────────────────────────────────────
function isAdActive(adData) {
  if (!adData) return false;
  const status = (adData.status || '').toLowerCase();
  
  if (status === 'rejected' || status === 'sold' || status === 'reserved' || status === 'inactive') {
    return false;
  }
  if (adData.isDeleted === true || adData.deleted === true) {
    return false;
  }
  if (adData.isSold === true || adData.sold === true) {
    return false;
  }
  return true;
}

// ─── HELPER: Parse Storage path from URL ─────────────────────────────────────
function getStoragePathFromUrl(urlOrPath) {
  if (!urlOrPath) return null;
  if (!urlOrPath.startsWith('http')) {
    return urlOrPath; // Already a relative path
  }
  try {
    const u = new URL(urlOrPath);
    const pathname = u.pathname;
    const parts = pathname.split('/o/');
    if (parts.length > 1) {
      return decodeURIComponent(parts[1]);
    }
  } catch (e) {
    console.error('[checkAdFingerprint] Failed to parse URL:', urlOrPath, e);
  }
  return null;
}

// ─── HTTPS CALLABLE: checkAdFingerprint ──────────────────────────────────────
exports.checkAdFingerprint = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }

  const { title, description, imagePaths, adId } = data;
  if (!title || !description || !adId) {
    throw new functions.https.HttpsError('invalid-argument', 'Неполные параметры запроса (title, description, adId)');
  }

  const userId = context.auth.uid;

  // 1. Нормализация текста и генерация SHA-256 (Unicode-безопасно)
  const normalized = (title + ' ' + description)
    .toLowerCase()
    .replace(/[\s\p{P}\p{S}\p{C}]+/gu, '')
    .replace(/[^\p{L}\p{N}]/gu, '');
  const textHash = crypto.createHash('sha256').update(normalized).digest('hex');

  // 2. Скачивание изображений и генерация MD5 на сервере
  const imageHashes = [];
  const bucket = admin.storage().bucket();
  const paths = imagePaths || [];

  for (const pathOrUrl of paths) {
    const storagePath = getStoragePathFromUrl(pathOrUrl);
    if (!storagePath) continue;

    try {
      const file = bucket.file(storagePath);
      const [contents] = await file.download();
      const hash = crypto.createHash('md5').update(contents).digest('hex');
      imageHashes.push(hash);
    } catch (err) {
      console.warn(`[checkAdFingerprint] Skipping image ${storagePath} due to error:`, err.message);
    }
  }

  let verdict = 'CLEAN';
  let reason = '';

  try {
    const result = await db.runTransaction(async (transaction) => {
      // ─── A) READ PHASE ───
      
      // Читаем textFingerprints/{textHash}
      const textFingerprintRef = db.collection('textFingerprints').doc(textHash);
      const textFingerprintSnap = await transaction.get(textFingerprintRef);

      let existingTextAd = null;
      let textDuplicateAdId = null;
      let textDuplicateUserId = null;

      if (textFingerprintSnap.exists) {
        const textFingerprintData = textFingerprintSnap.data();
        textDuplicateAdId = textFingerprintData.adId;
        textDuplicateUserId = textFingerprintData.userId;

        // Делаем проверку только если совпадение НЕ с текущим редактируемым объявлением
        if (textDuplicateAdId !== adId) {
          const adRef = db.collection('ads').doc(textDuplicateAdId);
          const adSnap = await transaction.get(adRef);
          if (adSnap.exists) {
            const adData = adSnap.data();
            if (isAdActive(adData)) {
              existingTextAd = adData;
            }
          }
        }
      }

      // Читаем ВСЕ imageFingerprints/{hash}
      const imageFingerprintSnaps = [];
      for (const hash of imageHashes) {
        const imageFingerprintRef = db.collection('imageFingerprints').doc(hash);
        const imageFingerprintSnap = await transaction.get(imageFingerprintRef);
        imageFingerprintSnaps.push({ hash, snap: imageFingerprintSnap });
      }

      const activeImageDuplicates = [];
      for (const item of imageFingerprintSnaps) {
        if (item.snap.exists) {
          const imageFingerprintData = item.snap.data();
          const imgAdId = imageFingerprintData.adId;
          const imgUserId = imageFingerprintData.userId;

          if (imgAdId !== adId) {
            const adRef = db.collection('ads').doc(imgAdId);
            const adSnap = await transaction.get(adRef);
            if (adSnap.exists) {
              const adData = adSnap.data();
              if (isAdActive(adData)) {
                activeImageDuplicates.push({ adId: imgAdId, userId: imgUserId, hash: item.hash });
              }
            }
          }
        }
      }

      // ─── B) VERDICT CALCULATION ───
      let localVerdict = 'CLEAN';
      let localReason = '';

      if (existingTextAd) {
        if (textDuplicateUserId === userId) {
          // Возвращаем специальный вердикт без throw, чтобы избежать повторных попыток транзакции
          return { verdict: 'DUPLICATE_SELF', reason: 'Вы уже опубликовали объявление с таким текстом' };
        } else {
          localVerdict = 'MANUAL_REVIEW';
          localReason = 'Найден дубликат текста у другого пользователя';
        }
      }

      if (activeImageDuplicates.length > 0) {
        localVerdict = 'MANUAL_REVIEW';
        localReason = `Найдено ${activeImageDuplicates.length} дубликатов изображений`;
      }

      // ─── C) WRITE PHASE ───
      if (localVerdict !== 'DUPLICATE_SELF') {
        const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
        
        // Записываем текстовый отпечаток, если его еще нет
        if (!textFingerprintSnap.exists) {
          transaction.set(textFingerprintRef, {
            adId,
            userId,
            createdAt: serverTimestamp
            // TODO: При удалении/продаже решить: помечать ли неактивным (согласовать позже)
          });
        }

        // Записываем новые отпечатки изображений
        for (const item of imageFingerprintSnaps) {
          if (!item.snap.exists) {
            const ref = db.collection('imageFingerprints').doc(item.hash);
            transaction.set(ref, {
              adId,
              userId,
              createdAt: serverTimestamp
              // TODO: При удалении/продаже решить: помечать ли неактивным (согласовать позже)
            });
          }
        }
      }

      return { verdict: localVerdict, reason: localReason };
    });

    verdict = result.verdict;
    reason = result.reason;
  } catch (error) {
    console.error('[checkAdFingerprint] Transaction failed:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Ошибка транзакции базы данных');
  }

  // Выбрасываем ошибку DUPLICATE_SELF клиенту СНАРУЖИ транзакции
  if (verdict === 'DUPLICATE_SELF') {
    throw new functions.https.HttpsError('already-exists', 'Вы уже опубликовали точно такое же объявление');
  }

  return { verdict, reason };
});


// ─── FIRESTORE TRIGGER: new report → Telegram notification ──────────────────
exports.onNewReport = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data.data();
  if (!report) return;

  const reportId = event.params.reportId;
  const isAdReport = !!report.adId;

  // 1. Защита от спама (дедупликация) за последние 5 минут
  const N_MINUTES = 5;
  let isSpam = false;

  try {
    const cutoff = new Date(Date.now() - N_MINUTES * 60 * 1000);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoff);

    let duplicateQuery = db.collection('reports')
      .where('timestamp', '>=', cutoffTimestamp);

    if (isAdReport) {
      duplicateQuery = duplicateQuery.where('adId', '==', report.adId);
    } else {
      duplicateQuery = duplicateQuery.where('reportedUserId', '==', report.reportedUserId);
    }

    const snap = await duplicateQuery.limit(5).get();
    
    snap.forEach(doc => {
      if (doc.id === reportId) return; // Пропускаем саму себя
      const data = doc.data();
      
      // Для жалоб на пользователя/профиль: если это жалоба на ОБЪЯВЛЕНИЕ от того же нарушителя,
      // то adId будет заполнен. Нам нужно сравнивать только жалобы на ПРОФИЛЬ (без adId)
      if (!isAdReport && data.adId) return;

      isSpam = true;
    });
  } catch (err) {
    console.error('[onNewReport] Error checking duplicates (fail-open):', err);
  }

  if (isSpam) {
    console.log(`[onNewReport] Suppressing duplicate Telegram notification for target: ${isAdReport ? report.adId : report.reportedUserId}`);
    return;
  }

  // 2. Определение adminChatId из настроек Firestore
  let adminChatId = process.env.ADMIN_CHAT || '';
  try {
    const settingsSnap = await db.collection('settings').doc('telegram').get();
    if (settingsSnap.exists) {
      const settingsData = settingsSnap.data();
      if (settingsData && settingsData.adminChatId) {
        const idStr = String(settingsData.adminChatId).trim();
        if (idStr.length > 0) adminChatId = idStr;
      }
    }
  } catch (err) {
    console.error('[onNewReport] Error fetching settings:', err);
  }

  if (!adminChatId) {
    console.warn('[onNewReport] No adminChatId resolved — skipping Telegram notification');
    return;
  }

  const time = report.timestamp 
    ? report.timestamp.toDate().toLocaleString('ru-RU', { timeZone: 'Asia/Almaty' }) 
    : new Date().toLocaleString('ru-RU', { timeZone: 'Asia/Almaty' });

  // 3. Формирование контекстно-богатого сообщения
  let text = '';
  if (isAdReport) {
    let adTitle = report.adTitle || 'Без названия';
    let adPrice = 'N/A';
    let adCategory = 'N/A';
    let adOwner = report.reportedUserId || 'N/A';

    try {
      const adSnap = await db.collection('ads').doc(report.adId).get();
      if (adSnap.exists) {
        const adData = adSnap.data();
        adTitle = adData.title || adTitle;
        adPrice = adData.price !== undefined ? `${adData.price} ₸` : adPrice;
        adCategory = adData.category || adCategory;
        adOwner = adData.userId || adOwner;
      }
    } catch (err) {
      console.error('[onNewReport] Error fetching ad context (falling back):', err);
    }

    text = `🚨 <b>Жалоба на объявление!</b>\n\n`
         + `🆔 <b>ID Жалобы:</b> <code>${reportId}</code>\n`
         + `🏷️ <b>Название:</b> <b>${adTitle}</b>\n`
         + `💰 <b>Цена:</b> <b>${adPrice}</b>\n`
         + `🗂️ <b>Категория:</b> <code>${adCategory}</code>\n`
         + `🔗 <b>ID Объявления:</b> <code>${report.adId}</code>\n`
         + `👤 <b>Владелец (UID):</b> <code>${adOwner}</code>\n`
         + `⚠️ <b>Тип жалобы:</b> <b>${report.type || 'N/A'}</b>\n`
         + `💬 <b>Комментарий отправителя:</b> <i>${report.comment || 'нет'}</i>\n\n`
         + `👤 <b>Отправитель (UID):</b> <code>${report.reporterUserId || 'anonymous'}</code>\n`
         + `📅 <b>Время (Almaty):</b> <code>${time}</code>`;
  } else {
    let reportedName = report.reportedUserName || 'Без имени';
    let reportedPhone = 'N/A';
    let reportedEmail = 'N/A';

    try {
      const userSnap = await db.collection('users').doc(report.reportedUserId).get();
      if (userSnap.exists) {
        const userData = userSnap.data();
        reportedName = userData.displayName || userData.userName || reportedName;
      }

      const contactSnap = await db.collection('users').doc(report.reportedUserId).collection('private').doc('contact').get();
      if (contactSnap.exists) {
        const contactData = contactSnap.data();
        reportedPhone = contactData.phone || reportedPhone;
        reportedEmail = contactData.email || reportedEmail;
      }
    } catch (err) {
      console.error('[onNewReport] Error fetching user context (falling back):', err);
    }

    text = `🚨 <b>Жалоба на пользователя / чат!</b>\n\n`
         + `🆔 <b>ID Жалобы:</b> <code>${reportId}</code>\n`
         + `👤 <b>Нарушитель (Имя):</b> <b>${reportedName}</b>\n`
         + `📞 <b>Телефон:</b> <code>${reportedPhone}</code>\n`
         + `📧 <b>Email:</b> <code>${reportedEmail}</code>\n`
         + `🔗 <b>UID Нарушителя:</b> <code>${report.reportedUserId || 'N/A'}</code>\n`
         + `⚠️ <b>Тип жалобы:</b> <b>${report.type || 'N/A'}</b>\n`
         + `💬 <b>Комментарий отправителя:</b> <i>${report.comment || 'нет'}</i>\n\n`
         + `👤 <b>Отправитель (UID):</b> <code>${report.reporterUserId || 'anonymous'}</code>\n`
         + `📅 <b>Время (Almaty):</b> <code>${time}</code>`;
  }

  // 4. Безопасная отправка в Telegram
  try {
    await telegramBot.tgSend(adminChatId, text);
    console.log(`[onNewReport] Telegram notification successfully sent for report ${reportId}`);
  } catch (error) {
    console.error('[onNewReport] Failed to send Telegram notification (fail-silent):', error);
  }
});

// ─── HTTPS CALLABLE: getFullUserInfo ──────────────────────────────────────────
exports.getFullUserInfo = functions.https.onCall(async (data, context) => {
  // 1. Проверка авторизации
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }

  const requesterUid = context.auth.uid;
  const targetUid = data.targetUid;

  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'Не указан targetUid');
  }

  try {
    // 2. Проверка прав администратора (accountType == 'admin') в Firestore
    const requesterSnap = await db.collection('users').doc(requesterUid).get();
    if (!requesterSnap.exists || requesterSnap.data().accountType !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Доступ разрешен только администраторам');
    }

    // 3. Запись в аудит-лог
    await db.collection('audit_logs').add({
      action: 'view_user_card',
      adminUid: requesterUid,
      targetUid: targetUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    // 4. Безопасное получение данных из Firebase Auth
    let authData = null;
    try {
      const userRecord = await admin.auth().getUser(targetUid);
      authData = {
        uid: userRecord.uid,
        email: userRecord.email || null,
        emailVerified: userRecord.emailVerified || false,
        phoneNumber: userRecord.phoneNumber || null,
        displayName: userRecord.displayName || null,
        photoURL: userRecord.photoURL || null,
        disabled: userRecord.disabled || false,
        customClaims: userRecord.customClaims || {},
        creationTime: userRecord.metadata.creationTime || null,
        lastSignInTime: userRecord.metadata.lastSignInTime || null,
        lastRefreshTime: userRecord.metadata.lastRefreshTime || null,
        providerData: (userRecord.providerData || []).map(p => ({
          uid: p.uid,
          providerId: p.providerId,
          displayName: p.displayName || null,
          email: p.email || null,
          phoneNumber: p.phoneNumber || null,
          photoURL: p.photoURL || null
        }))
      };
    } catch (err) {
      console.warn(`[getFullUserInfo] Auth record not found for targetUid: ${targetUid}`, err.message);
    }

    // 5. Параллельное чтение всех связанных коллекций с лимитом 50 записей
    const [
      userSnap,
      adsSnap,
      reportedSnap,
      reporterSnap,
      reviewsToSnap,
      reviewsFromSnap,
      chatsSnap,
      bidsSentSnap,
      bidsReceivedSnap,
      passengerOrdersSnap,
      driverOrdersSnap
    ] = await Promise.all([
      db.collection('users').doc(targetUid).get(),
      db.collection('ads').where('userId', '==', targetUid).limit(50).get(),
      db.collection('reports').where('reportedUserId', '==', targetUid).limit(50).get(),
      db.collection('reports').where('reporterUserId', '==', targetUid).limit(50).get(),
      db.collection('reviews').where('toUserId', '==', targetUid).limit(50).get(),
      db.collection('reviews').where('fromUserId', '==', targetUid).limit(50).get(),
      db.collection('chats').where('users', 'array-contains', targetUid).get(),
      db.collection('taxi_bids').where('senderId', '==', targetUid).limit(50).get(),
      db.collection('taxi_bids').where('receiverId', '==', targetUid).limit(50).get(),
      db.collection('taxi_orders').where('passengerId', '==', targetUid).limit(50).get(),
      db.collection('taxi_orders').where('driverId', '==', targetUid).limit(50).get()
    ]);

    // 6. Формирование структуры ответа
    const profile = userSnap.exists ? userSnap.data() : null;

    const ads = adsSnap.docs.map(doc => {
      const adData = doc.data();
      return {
        id: doc.id,
        title: adData.title || '',
        price: adData.price || 0.0,
        status: adData.status || 'pending',
        createdAt: adData.timestamp ? adData.timestamp.toDate().toISOString() : null
      };
    });

    const reportsAgainst = reportedSnap.docs.map(doc => {
      const repData = doc.data();
      return {
        id: doc.id,
        adId: repData.adId || null,
        adTitle: repData.adTitle || null,
        type: repData.type || '',
        comment: repData.comment || '',
        timestamp: repData.timestamp ? repData.timestamp.toDate().toISOString() : null,
        reporterUserId: repData.reporterUserId || ''
      };
    });

    const reportsSubmitted = reporterSnap.docs.map(doc => {
      const repData = doc.data();
      return {
        id: doc.id,
        adId: repData.adId || null,
        reportedUserId: repData.reportedUserId || '',
        reportedUserName: repData.reportedUserName || null,
        type: repData.type || '',
        comment: repData.comment || '',
        timestamp: repData.timestamp ? repData.timestamp.toDate().toISOString() : null
      };
    });

    // Расчет рейтинга с оптимизацией
    let avgRating = profile ? (profile.rating || 0.0) : 0.0;
    const reviewsCount = profile ? (profile.reviewsCount || 0) : 0;

    // Вычисляем рейтинг на лету, если отзывов < 5, но они есть
    if (reviewsCount > 0 && reviewsCount < 5 && reviewsToSnap.size > 0) {
      let sum = 0;
      reviewsToSnap.docs.forEach(doc => { sum += doc.data().rating || 0; });
      avgRating = sum / reviewsToSnap.size;
    }

    const reviewsTo = reviewsToSnap.docs.map(doc => {
      const revData = doc.data();
      return {
        id: doc.id,
        fromUserId: revData.fromUserId || '',
        fromUserName: revData.fromUserName || '',
        rating: revData.rating || 0,
        comment: revData.comment || '',
        timestamp: revData.timestamp ? revData.timestamp.toDate().toISOString() : null
      };
    });

    const reviewsFrom = reviewsFromSnap.docs.map(doc => {
      const revData = doc.data();
      return {
        id: doc.id,
        toUserId: revData.toUserId || '',
        rating: revData.rating || 0,
        comment: revData.comment || '',
        timestamp: revData.timestamp ? revData.timestamp.toDate().toISOString() : null
      };
    });

    const chats = {
      count: chatsSnap.size,
      chatIds: chatsSnap.docs.map(doc => doc.id)
    };

    const taxiBidsSent = bidsSentSnap.docs.map(doc => {
      const bidData = doc.data();
      return {
        id: doc.id,
        receiverId: bidData.receiverId || '',
        targetId: bidData.targetId || '',
        offeredPrice: bidData.offeredPrice || 0,
        status: bidData.status || ''
      };
    });

    const taxiBidsReceived = bidsReceivedSnap.docs.map(doc => {
      const bidData = doc.data();
      return {
        id: doc.id,
        senderId: bidData.senderId || '',
        targetId: bidData.targetId || '',
        offeredPrice: bidData.offeredPrice || 0,
        status: bidData.status || ''
      };
    });

    const taxiOrdersPassenger = passengerOrdersSnap.docs.map(doc => {
      const ordData = doc.data();
      return {
        id: doc.id,
        driverId: ordData.driverId || '',
        status: ordData.status || '',
        createdAt: ordData.createdAt ? ordData.createdAt.toDate().toISOString() : null
      };
    });

    const taxiOrdersDriver = driverOrdersSnap.docs.map(doc => {
      const ordData = doc.data();
      return {
        id: doc.id,
        passengerId: ordData.passengerId || '',
        status: ordData.status || '',
        createdAt: ordData.createdAt ? ordData.createdAt.toDate().toISOString() : null
      };
    });

    return {
      auth: authData,
      profile: profile,
      ads: ads,
      reportsAgainst: reportsAgainst,
      reportsSubmitted: reportsSubmitted,
      reviewsTo: reviewsTo,
      reviewsFrom: reviewsFrom,
      avgRating: avgRating,
      reviewsCount: reviewsCount,
      chats: chats,
      taxiBidsSent: taxiBidsSent,
      taxiBidsReceived: taxiBidsReceived,
      taxiOrdersPassenger: taxiOrdersPassenger,
      taxiOrdersDriver: taxiOrdersDriver
    };
  } catch (error) {
    console.error('[getFullUserInfo] Error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message || 'Внутренняя ошибка сервера');
  }
});

// ─── HELPER: Parse MP4/M4A duration from buffer (pure JS, no external deps) ───
function parseMp4Duration(buffer) {
  let offset = 0;
  while (offset + 8 <= buffer.length) {
    let size = buffer.readUInt32BE(offset);
    const type = buffer.toString('ascii', offset + 4, offset + 8);
    let headerSize = 8;
    if (size === 1) {
      if (offset + 16 > buffer.length) break;
      const high = buffer.readUInt32BE(offset + 8);
      const low = buffer.readUInt32BE(offset + 12);
      size = high * 0x100000000 + low;
      headerSize = 16;
    }
    
    if (size < headerSize) {
      break;
    }
    
    if (type === 'moov') {
      buffer = buffer.subarray(offset + headerSize, offset + size);
      offset = 0;
      continue;
    }
    
    if (type === 'mvhd') {
      const version = buffer.readUInt8(offset + headerSize);
      let timescale, duration;
      if (version === 0) {
        timescale = buffer.readUInt32BE(offset + headerSize + 12);
        duration = buffer.readUInt32BE(offset + headerSize + 16);
      } else if (version === 1) {
        timescale = buffer.readUInt32BE(offset + headerSize + 20);
        const high = buffer.readUInt32BE(offset + headerSize + 24);
        const low = buffer.readUInt32BE(offset + headerSize + 28);
        duration = high * 0x100000000 + low;
      } else {
        throw new Error('Unsupported mvhd version: ' + version);
      }
      return duration / timescale;
    }
    
    offset += size;
  }
  throw new Error('mvhd box not found');
}

// Helper: Delete Firestore doc with retry to prevent replication/race-condition lags
async function deleteFirestoreDocWithRetry(db, chatId, msgId, retries = 3, delay = 1000) {
  const docRef = db.collection('chats').doc(chatId).collection('messages').doc(msgId);
  for (let i = 0; i < retries; i++) {
    const doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      console.log(`[onVoiceMessageUpload] Successfully deleted message doc ${msgId}`);
      return;
    }
    if (i < retries - 1) {
      console.log(`[onVoiceMessageUpload] Message doc ${msgId} not found, retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  await docRef.delete();
}

// ─── STORAGE TRIGGER: Validate voice message upload duration ─────────────────
exports.onVoiceMessageUpload = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  if (!filePath || !filePath.startsWith('voice_messages/')) {
    return null;
  }

  const parts = filePath.split('/');
  if (parts.length < 3) {
    return null;
  }

  const chatId = parts[1];
  const fileName = parts[2];
  const dotIndex = fileName.lastIndexOf('.');
  const msgId = dotIndex !== -1 ? fileName.substring(0, dotIndex) : fileName;

  const bucket = admin.storage().bucket(object.bucket);
  const file = bucket.file(filePath);
  const db = admin.firestore();

  let duration = null;
  let parseError = null;
  try {
    const [buffer] = await file.download();
    duration = parseMp4Duration(buffer);
  } catch (err) {
    parseError = err;
    console.warn(`[onVoiceMessageUpload] Failed to parse MP4 duration for ${filePath}: ${err.message}. Falling back to file size check.`);
  }

  const maxDuration = 190; // 3 min (180s) + 10s margin
  const maxSizeBytes = 3 * 1024 * 1024; // 3 MB

  if (duration !== null && !isNaN(duration) && duration > 0) {
    if (duration > maxDuration) {
      console.warn(`[onVoiceMessageUpload] Rejecting: duration is too long (${duration}s > ${maxDuration}s) for ${filePath}`);
      try {
        await file.delete();
      } catch (e) {
        console.error(`[onVoiceMessageUpload] Storage deletion failed for ${filePath}:`, e.message);
      }
      await deleteFirestoreDocWithRetry(db, chatId, msgId);
      return null;
    }
    console.log(`[onVoiceMessageUpload] Approved: duration is ${duration}s for ${filePath}`);
  } else {
    // Fallback: check file size if duration parsing fails/zeroes
    let metadata = null;
    let getMetaError = null;
    const delays = [500, 1500];

    for (let attempt = 0; attempt <= delays.length; attempt++) {
      try {
        [metadata] = await file.getMetadata();
        getMetaError = null;
        break;
      } catch (err) {
        getMetaError = err;
        if (attempt < delays.length) {
          const delay = delays[attempt];
          console.warn(`[onVoiceMessageUpload] getMetadata attempt ${attempt + 1} failed: ${err.message}. Retrying in ${delay}ms...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }

    if (metadata) {
      const fileSize = parseInt(metadata.size || '0', 10);
      if (fileSize > maxSizeBytes) {
        console.warn(`[onVoiceMessageUpload] Rejecting: unparseable file is too large (${fileSize} bytes) for ${filePath}`);
        try {
          await file.delete();
        } catch (e) {
          console.error(`[onVoiceMessageUpload] Storage deletion failed for ${filePath}:`, e.message);
        }
        await deleteFirestoreDocWithRetry(db, chatId, msgId);
        return null;
      }
      console.log(`[onVoiceMessageUpload] Approved via size fallback: size is ${fileSize} bytes for ${filePath}`);
    } else {
      functions.logger.error(`[onVoiceMessageUpload] Failed to fetch metadata after retries for ${filePath}. chatId: ${chatId}, msgId: ${msgId}. Parse duration error: ${parseError ? parseError.message : 'none'}, getMetadata error: ${getMetaError ? getMetaError.message : 'unknown'}`);
    }
  }

  return null;
});

// ─── HTTPS CALLABLE: incrementViewCount ────────────────────────────────────────
exports.incrementViewCount = functions.https.onCall(async (data, context) => {
  // Требование авторизации
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Пользователь должен быть авторизован'
    );
  }

  const listingId = data.listingId;
  if (!listingId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Не указан listingId'
    );
  }

  const userId = context.auth.uid;
  const adRef = db.collection('ads').doc(listingId);
  const logRef = db.collection('viewLogs').doc(`${userId}_${listingId}`);
  const statsRef = db.collection('ads').doc(listingId).collection('stats').doc('counters');

  return db.runTransaction(async (transaction) => {
    // 1. Чтение объявления
    const adSnap = await transaction.get(adRef);
    if (!adSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Объявление не найдено'
      );
    }

    const adData = adSnap.data();
    // Смягчаем проверку: если active или status отсутствуют в документе, считаем их активными по умолчанию
    const isActive = adData.active === undefined ? true : adData.active;
    const status = adData.status === undefined ? 'active' : adData.status;

    if (isActive !== true || status !== 'active') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Объявление не активно (статус: ${status}, активность: ${isActive})`
      );
    }

    // 2. Чтение лога дедупликации
    const logSnap = await transaction.get(logRef);
    const now = Date.now();

    if (logSnap.exists) {
      const lastViewedAt = logSnap.data().lastViewedAt;
      if (lastViewedAt) {
        const lastViewedMs = lastViewedAt.toDate().getTime();
        const diffMs = now - lastViewedMs;
        if (diffMs < 60 * 60 * 1000) { // 1 час
          return { success: false, reason: 'duplicate' };
        }
      }
    }

    // 3. Запись лога с TTL-полем createdAt
    transaction.set(logRef, {
      lastViewedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp() // для TTL политики (удаление через 24 часа)
    });

    // 4. Атомарный инкремент счетчика просмотров прямо в документе объявления ads/{listingId}
    transaction.update(adRef, {
      views: admin.firestore.FieldValue.increment(1)
    });

    // 5. Инкремент счетчика в ads/{listingId}/stats/counters (для аналитики)
    transaction.set(statsRef, {
      viewsCount: admin.firestore.FieldValue.increment(1)
    }, { merge: true });

    return { success: true };
  });
});

// ─── HTTPS CALLABLE: incrementCallCount ────────────────────────────────────────
exports.incrementCallCount = functions.https.onCall(async (data, context) => {
  // Требование авторизации
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Пользователь должен быть авторизован'
    );
  }

  const listingId = data.listingId;
  if (!listingId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Не указан listingId'
    );
  }

  // Проверяем, что объявление существует и активно в коллекции 'ads'
  const adRef = db.collection('ads').doc(listingId);
  const adSnap = await adRef.get();
  if (!adSnap.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Объявление не найдено'
    );
  }

  const adData = adSnap.data();
  // Смягчаем проверку: если active или status отсутствуют в документе, считаем их активными по умолчанию
  const isActive = adData.active === undefined ? true : adData.active;
  const status = adData.status === undefined ? 'active' : adData.status;

  if (isActive !== true || status !== 'active') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Объявление не активно (статус: ${status}, активность: ${isActive})`
    );
  }

  // Инкрементируем callsCount прямо в документе объявления ads/{listingId}
  await adRef.update({
    callsCount: admin.firestore.FieldValue.increment(1)
  });

  // Инкрементируем callsCount в ads/{listingId}/stats/counters
  const statsRef = db.collection('ads').doc(listingId).collection('stats').doc('counters');
  await statsRef.set({
    callsCount: admin.firestore.FieldValue.increment(1)
  }, { merge: true });

  return { success: true };
});

async function updateUserRatingTransaction(userId, ratingChange, countChange) {
  const userRef = db.collection('users').doc(userId);
  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    let currentCount = 0;
    let currentSum = 0;
    if (userSnap.exists) {
      const data = userSnap.data();
      currentCount = data.reviewsCount || 0;
      currentSum = data.ratingSum !== undefined ? (data.ratingSum || 0.0) : ((data.rating || 0.0) * currentCount);
    }
    
    const newSum = Math.max(0, currentSum + ratingChange);
    const newCount = Math.max(0, currentCount + countChange);
    const avgRating = newCount >= 5 ? (newSum / newCount) : 0.0;
    
    transaction.set(userRef, {
      ratingSum: newSum,
      reviewsCount: newCount,
      rating: avgRating
    }, { merge: true });
  });
}

exports.onReviewCreated = onDocumentCreated('reviews/{reviewId}', async (event) => {
  const review = event.data.data();
  const toUserId = review.toUserId;
  const rating = Number(review.rating);
  if (!toUserId || isNaN(rating)) {
    console.error('[onReviewCreated] Invalid review data:', review);
    return;
  }
  try {
    await updateUserRatingTransaction(toUserId, rating, 1);
    console.log(`[onReviewCreated] Successfully updated rating for user ${toUserId}`);
  } catch (err) {
    console.error('[onReviewCreated] Error updating rating transaction:', err);
  }
});

exports.onReviewDeleted = onDocumentDeleted('reviews/{reviewId}', async (event) => {
  const review = event.data.data();
  const toUserId = review.toUserId;
  const rating = Number(review.rating);
  if (!toUserId || isNaN(rating)) {
    console.error('[onReviewDeleted] Invalid review data:', review);
    return;
  }
  try {
    await updateUserRatingTransaction(toUserId, -rating, -1);
    console.log(`[onReviewDeleted] Successfully updated rating for user ${toUserId}`);
  } catch (err) {
    console.error('[onReviewDeleted] Error updating rating transaction:', err);
  }
});

exports.onReviewUpdated = onDocumentUpdated('reviews/{reviewId}', async (event) => {
  const oldReview = event.data.before.data();
  const newReview = event.data.after.data();
  const toUserId = newReview.toUserId;
  const oldRating = Number(oldReview.rating);
  const newRating = Number(newReview.rating);
  
  if (!toUserId || isNaN(oldRating) || isNaN(newRating)) {
    console.error('[onReviewUpdated] Invalid review data:', oldReview, newReview);
    return;
  }
  
  const ratingChange = newRating - oldRating;
  if (ratingChange === 0) {
    console.log('[onReviewUpdated] Rating did not change, skipping update');
    return;
  }
  
  try {
    await updateUserRatingTransaction(toUserId, ratingChange, 0);
    console.log(`[onReviewUpdated] Successfully updated rating for user ${toUserId}`);
  } catch (err) {
    console.error('[onReviewUpdated] Error updating rating transaction:', err);
  }
});

// ─── CRON: Cleanup Expired Sessions — каждые 10 минут ───────────────────────
exports.cleanupExpiredSessions = functions.pubsub.schedule('every 10 minutes').onRun(async (context) => {
  const tenMinutesAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 10 * 60 * 1000);
  
  try {
    const sessionsSnap = await db.collection('tg_auth_sessions')
      .where('created_at', '<', tenMinutesAgo)
      .get();
      
    if (!sessionsSnap.empty) {
      const batch = db.batch();
      sessionsSnap.docs.forEach((doc) => {
        batch.delete(doc.ref);
        // Также удаляем соответствующий документ из защищенной коллекции
        const secureRef = db.collection('tg_auth_sessions_secure').doc(doc.id);
        batch.delete(secureRef);
      });
      await batch.commit();
      console.log(`[cleanupExpiredSessions] Cleaned up ${sessionsSnap.size} expired sessions.`);
    }
  } catch (err) {
    console.error('[cleanupExpiredSessions] Error:', err);
  }
});

// ─── CRON: Auto-expire Taxi Orders and Rides older than 24 hours ─────────────
exports.expireOldTaxiEntries = functions.region('europe-west1').pubsub.schedule('every 24 hours').timeZone('Asia/Almaty').onRun(async (context) => {
  const cutOffDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));
  const collections = ['taxi_orders', 'taxi_rides'];

  for (const collName of collections) {
    try {
      const snapshot = await db.collection(collName)
        .where('status', '==', 'active')
        .where('createdAt', '<=', cutOffDate)
        .get();

      if (snapshot.empty) {
        console.log(`[expireOldTaxiEntries] No expired active entries in ${collName}.`);
        continue;
      }

      console.log(`[expireOldTaxiEntries] Found ${snapshot.size} expired active entries in ${collName}. Processing batch update...`);

      const docs = snapshot.docs;
      for (let i = 0; i < docs.length; i += 500) {
        const batch = db.batch();
        const chunk = docs.slice(i, i + 500);

        chunk.forEach((doc) => {
          batch.update(doc.ref, {
            status: 'expired',
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        await batch.commit();
      }

      console.log(`[expireOldTaxiEntries] Successfully updated ${docs.length} entries to 'expired' status in ${collName}.`);
    } catch (err) {
      console.error(`[expireOldTaxiEntries] Error updating ${collName}:`, err);
    }
  }
});
