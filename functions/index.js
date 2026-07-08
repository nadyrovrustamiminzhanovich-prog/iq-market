/**
 * IQ-Market Telegram Bot Webhook (Firebase Cloud Function)
 */

const functions = require('firebase-functions/v1');
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


// ─── FIRESTORE TRIGGER: new chat message → FCM push ──────────────────────────
exports.onNewMessage = functions.firestore.document('chats/{chatId}/messages/{msgId}').onCreate(async (snapshot, context) => {
    const message  = snapshot.data();
    const chatId   = context.params.chatId;
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

// ─── CRON: Check Expired Ads — каждый день в 03:00 Алматы ────────────────────
exports.checkExpiredAds = functions.pubsub.schedule('0 3 * * *').timeZone('Asia/Almaty').onRun(async () => {
    const now              = admin.firestore.Timestamp.now();
    const warningTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() + 3 * 24 * 60 * 60 * 1000);
    let expiredCount = 0;
    let notifyCount  = 0;
    let batchOps = [];
    let currentBatch = db.batch();
    let batchCount = 0;

    try {
      const expiredAdsSnap = await db.collection('ads')
        .where('expiresAt', '<=', now)
        .where('status', '==', 'active')
        .get();
      expiredAdsSnap.forEach((doc) => {
        currentBatch.update(doc.ref, { status: 'archived', active: false });
        batchCount++;
        if (batchCount >= 499) {
          batchOps.push(currentBatch.commit());
          currentBatch = db.batch();
          batchCount = 0;
        }
        expiredCount++;
      });

      const expiringAdsSnap = await db.collection('ads')
        .where('expiresAt', '<=', warningTimestamp)
        .where('expiresAt', '>', now)
        .where('status', '==', 'active')
        .get();

      const sendPromises = [];

      for (const doc of expiringAdsSnap.docs) {
        const data = doc.data();
        if (data.notifiedExpiry === true) continue;
        currentBatch.update(doc.ref, { notifiedExpiry: true });
        batchCount++;
        if (batchCount >= 499) {
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
                body : `Срок размещения "${data.title}" истекает менее чем через 3 дня. Продлите его в профиле!`,
              },
              data: { type: 'ad_expiring', adId: doc.id, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
            };
            const sendPromise = admin.messaging().send(payload)
              .then(() => notifyCount++)
              .catch(e => console.error('Push error:', e));
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
    } catch (error) {
      console.error('[checkExpiredAds] Error:', error);
    }
  }
);

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
  try {
    await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    return res.status(401).send('Unauthorized: Invalid token');
  }

  const keySelector = req.query.key || 'moderation';
  const targetApiKey = keySelector === 'assistant'
    ? process.env.GEMINI_ASSISTANT_KEY
    : process.env.GEMINI_MODERATION_KEY;

  if (!targetApiKey) {
    return res.status(500).send('Server configuration error');
  }

  const reqPath   = req.path || '';
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
exports.onNewNotification = functions.firestore.document('users/{userId}/notifications/{notifId}').onCreate(async (snapshot, context) => {
    const notification = snapshot.data();
    const userId       = context.params.userId;

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

// ─── HTTPS CALLABLE: verifyTelegramOtp ────────────────────────────────────────
exports.verifyTelegramOtp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }

  const otp = data.otp;
  const phone = data.phone;
  const sessionToken = data.sessionToken;

  if (!otp || !phone || !sessionToken) {
    throw new functions.https.HttpsError('invalid-argument', 'Неполные параметры запроса (otp, phone, sessionToken)');
  }

  try {
    const sessionRef = db.collection('tg_auth_sessions').doc(sessionToken);
    const sessionSnap = await sessionRef.get();

    if (!sessionSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Сессия верификации не найдена или устарела');
    }

    const sessionData = sessionSnap.data();
    
    // Проверка на уязвимость подмены токена (initiatorUid должен совпадать с текущим UID)
    if (sessionData.initiatorUid && sessionData.initiatorUid !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Попытка верификации чужой сессии');
    }
    
    // Проверяем статус верификации сессии и OTP-код
    if (sessionData.otp !== otp || sessionData.verified !== true) {
      throw new functions.https.HttpsError('failed-precondition', 'Неверный код подтверждения');
    }

    // Дополнительная валидация номера телефона (сравнение последних 10 цифр)
    const sessionPhoneRaw = sessionData.phone || '';
    const cleanSession = sessionPhoneRaw.replace(/\D/g, '').slice(-10);
    const cleanInput = phone.replace(/\D/g, '').slice(-10);

    if (cleanSession !== cleanInput) {
      throw new functions.https.HttpsError('failed-precondition', 'Номер телефона не совпадает с подтвержденным в Telegram');
    }

    const userUid = context.auth.uid;
    const userRef = db.collection('users').doc(userUid);
    
    await userRef.update({
      isVerified: true,
      phone: phone,
      telegramChatId: sessionData.chat_id || ''
    });

    console.log(`[verifyTelegramOtp] User ${userUid} successfully verified via Telegram.`);
    
    return { success: true };
  } catch (error) {
    console.error('[verifyTelegramOtp] Error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message || 'Внутренняя ошибка сервера');
  }
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

