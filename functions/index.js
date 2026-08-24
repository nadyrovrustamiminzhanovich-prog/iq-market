/**
 * IQ-Market Telegram Bot Webhook (Firebase Cloud Function)
 */

const functions = require('firebase-functions/v1');
const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin     = require('firebase-admin');
const crypto    = require('crypto');
const Jimp      = require('jimp');

admin.initializeApp();
const db = admin.firestore();

// Глобальный тумблер «Push-уведомления» в Личных данных клиента
// (users/{uid}.pushEnabled, profile_settings_screen.dart). У пользователей,
// которые тумблер никогда не трогали, поля в документе вообще нет — тогда
// трактуем как «включено» (обратная совместимость), выключаем отправку
// только при явном pushEnabled === false.
function isPushEnabled(userData) {
  return !userData || userData.pushEnabled !== false;
}

// ─── Ad anti-abuse configuration ─────────────────────────────────────────────
const MAX_ACTIVE_ADS_PER_USER = 30;         // одновременно активных объявлений на обычный аккаунт
const MAX_NEW_ADS_PER_DAY_PER_USER = 15;    // новых публикаций (не редактирований) в сутки на аккаунт
const ALMATY_UTC_OFFSET_HOURS = 5;          // Asia/Almaty, круглый год без перехода на летнее время
const DUPLICATE_STRIKE_THRESHOLD = 3;       // после стольки пойманных дублей — все новые объявления аккаунта уходят на ручную проверку

function getAlmatyDayStartUtc() {
  const now = new Date();
  const almatyNow = new Date(now.getTime() + ALMATY_UTC_OFFSET_HOURS * 60 * 60 * 1000);
  const almatyMidnightAsUtc = Date.UTC(almatyNow.getUTCFullYear(), almatyNow.getUTCMonth(), almatyNow.getUTCDate(), 0, 0, 0);
  return new Date(almatyMidnightAsUtc - ALMATY_UTC_OFFSET_HOURS * 60 * 60 * 1000);
}

// ─── HELPER: perceptual image hash (average hash, 8x8 → 64 bit) ─────────────
// В отличие от точного MD5 файла, устойчив к пересжатию/ресайзу того же фото
// (проверено вручную: distance=0 для того же фото после JPEG q60 и ресайза).
async function computePerceptualHash(buffer) {
  const image = await Jimp.read(buffer);
  image.resize(8, 8).greyscale();
  const values = [];
  image.scan(0, 0, 8, 8, function (x, y, idx) {
    values.push(this.bitmap.data[idx]);
  });
  const avg = values.reduce((a, b) => a + b, 0) / values.length;
  let bits = '';
  for (const v of values) bits += (v >= avg ? '1' : '0');
  let hex = '';
  for (let i = 0; i < 64; i += 4) {
    hex += parseInt(bits.substr(i, 4), 2).toString(16);
  }
  return hex;
}

// Import Telegram functions from telegram_bot.js
const telegramBot = require('./telegram_bot');

exports.registerWebhook = telegramBot.registerWebhook;
exports.telegramWebhook = telegramBot.telegramWebhook;
exports.secureSendTelegramMessage = telegramBot.secureSendTelegramMessage;
exports.onVerificationUpdate = telegramBot.onVerificationUpdate;
exports.verifyTelegramOtp = telegramBot.verifyTelegramOtp;

// Предложения цены: все переходы статуса только через сервер (см. offers.js)
const offersModule = require('./offers');

exports.respondToOffer = offersModule.respondToOffer;


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
    if (!isPushEnabled(receiverData)) {
      console.log(`[onNewMessage] FCM skipped: push disabled by receiver ${receiverId}`);
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
        // Кому предназначен пуш. Клиент сверяет с текущим uid и молча
        // выбрасывает чужие уведомления: FCM-токен мог остаться привязан к
        // аккаунту, который раньше логинился на этом устройстве, и тогда
        // обработчик пуша проставлял статусы «доставлено»/«прочитано» на
        // сообщения того, кто вошёл позже (2 синие галочки самому себе).
        receiverId: receiverId,
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
        if (userSnap.exists && userSnap.data().fcmToken && isPushEnabled(userSnap.data())) {
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
      if (userSnap.exists && userSnap.data().fcmToken && isPushEnabled(userSnap.data())) {
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

    const userData = userSnap.data();
    const token = userData.fcmToken;
    if (!token) return;
    if (!isPushEnabled(userData)) {
      console.log(`[onNewNotification] FCM skipped: push disabled by user ${userId}`);
      return;
    }

    const payload = {
      token,
      notification: {
        title: notification.title,
        body : notification.body,
      },
      data: {
        type        : notification.type || 'system',
        ...(notification.data || {}),
        // Адресат пуша — см. комментарий в onNewMessage. Ставится после
        // спреда data, чтобы содержимое уведомления не могло его переопределить.
        receiverId  : userId,
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
// Раньше единственной проверкой было "пользователь авторизован" — любой
// залогиненный мог отправить уведомление ЛЮБОМУ targetUid с произвольными
// title/body/type (например поддельное "Объявление одобрено ✅" от чужого
// имени). Теперь каждый тип либо admin-only, либо проверяется по реальным
// данным в Firestore: caller обязан быть тем, за кого себя выдаёт.
//
// Себе — можно всегда, без проверок (ad_expiring шлётся самому себе из
// AdService.checkMyAdsLifecycle): испортить можно только собственную ленту
// уведомлений, это не дыра.
const ADMIN_ONLY_NOTIFICATION_TYPES = new Set([
  'ad_approved',
  'ad_rejected',
  'driver_verified',
  'review_deleted',
  // Такси сейчас открыто только админу — home_screen.dart._navToTaxi блокирует
  // экран всем остальным через TaxiComingSoonDialog. Когда такси откроют для
  // обычных пользователей, эту проверку тоже придётся ослабить и добавить
  // контекстную валидацию по taxi_bids/taxi_orders/taxi_rides (по образцу
  // review/price_drop ниже), а не просто убрать из списка.
  'taxi_bid',
  'taxi_bid_accepted',
  'taxi_bid_rejected',
  'taxi_trip_confirmed',
]);

async function isAdminUid(uid) {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists && snap.data().accountType === 'admin';
}

exports.sendSystemNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }

  const callerUid = context.auth.uid;
  const targetUid = data.targetUid;
  const title = data.title;
  const body = data.body;
  const type = data.type || 'system';
  const payload = data.payload || null;

  if (!targetUid || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Неполные параметры уведомления');
  }

  if (targetUid !== callerUid) {
    if (ADMIN_ONLY_NOTIFICATION_TYPES.has(type)) {
      if (!(await isAdminUid(callerUid))) {
        throw new functions.https.HttpsError('permission-denied', 'Этот тип уведомления доступен только администратору');
      }
    } else if (type === 'review') {
      // ReviewService.addReview: уведомление продавцу о новом отзыве.
      // Легитимно, только если такой отзыв правда существует — иначе можно
      // было бы подделать "у вас новый отзыв" кому угодно.
      const adId = payload && payload.adId;
      if (!adId) {
        throw new functions.https.HttpsError('invalid-argument', 'Не хватает adId для типа review');
      }
      // Одно равенство (fromUserId) — уже есть автоматический индекс,
      // остальное фильтруем в памяти: у одного автора отзывов немного,
      // отдельный composite-индекс под это разворачивать не нужно.
      const reviewsSnap = await db.collection('reviews').where('fromUserId', '==', callerUid).get();
      const matches = reviewsSnap.docs.some((d) => d.data().adId === adId && d.data().toUserId === targetUid);
      if (!matches) {
        throw new functions.https.HttpsError('permission-denied', 'Отзыв не найден — уведомление отклонено');
      }
    } else if (type === 'price_drop') {
      // AdService._notifyPriceDrop: рассылка тем, у кого объявление в
      // избранном. Легитимно, только если caller реально владелец этого
      // объявления, а targetUid реально добавил его в избранное.
      const adId = payload && payload.adId;
      if (!adId) {
        throw new functions.https.HttpsError('invalid-argument', 'Не хватает adId для типа price_drop');
      }
      const adSnap = await db.collection('ads').doc(adId).get();
      if (!adSnap.exists || adSnap.data().userId !== callerUid) {
        throw new functions.https.HttpsError('permission-denied', 'Вы не владелец этого объявления');
      }
      const targetSnap = await db.collection('users').doc(targetUid).get();
      const favoriteIds = (targetSnap.exists && targetSnap.data().favoriteIds) || [];
      if (!favoriteIds.includes(adId)) {
        throw new functions.https.HttpsError('permission-denied', 'Получатель не добавлял это объявление в избранное');
      }
    } else {
      // Неизвестный/непредусмотренный тип для чужого targetUid — запрещаем
      // по умолчанию, чтобы новый тип, добавленный без этой проверки, не
      // превращался в готовую дыру для спуфинга.
      throw new functions.https.HttpsError('permission-denied', 'Недопустимый тип уведомления для этого получателя');
    }
  }

  await db.collection('users')
    .doc(targetUid)
    .collection('notifications')
    .add({
      title: title,
      body: body,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: type,
      senderId: callerUid,
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

// ─── HTTPS CALLABLE: checkAdRateLimit ────────────────────────────────────────
// Защита от спам-заливки объявлений. Вызывается клиентом ДО сжатия/загрузки фото
// (при создании НОВОГО объявления, не при редактировании), чтобы не тратить
// впустую сжатие/аплоад, если лимит уже исчерпан.
exports.checkAdRateLimit = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }
  const userId = context.auth.uid;

  const userSnap = await db.collection('users').doc(userId).get();
  const userData = userSnap.exists ? userSnap.data() : {};
  if (userData.accountType === 'admin') {
    return { allowed: true };
  }

  const dayStart = getAlmatyDayStartUtc();

  const [activeCountSnap, dailyCountSnap] = await Promise.all([
    db.collection('ads').where('userId', '==', userId).where('status', '==', 'active').count().get(),
    db.collection('ads').where('userId', '==', userId).where('timestamp', '>=', admin.firestore.Timestamp.fromDate(dayStart)).count().get(),
  ]);

  const activeCount = activeCountSnap.data().count;
  const dailyCount = dailyCountSnap.data().count;

  if (activeCount >= MAX_ACTIVE_ADS_PER_USER) {
    throw new functions.https.HttpsError('resource-exhausted', `Достигнут лимит активных объявлений (${MAX_ACTIVE_ADS_PER_USER}). Заархивируйте старые, чтобы опубликовать новое.`);
  }
  if (dailyCount >= MAX_NEW_ADS_PER_DAY_PER_USER) {
    throw new functions.https.HttpsError('resource-exhausted', `Достигнут лимит новых объявлений в сутки (${MAX_NEW_ADS_PER_DAY_PER_USER}). Попробуйте завтра.`);
  }

  return { allowed: true, activeCount, dailyCount };
});

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
  // installId — анонимный ID установки приложения с клиента (UUID v4), используется
  // только для эвристики "объявления с одного устройства под разными аккаунтами".
  // Строгий формат, иначе игнорируем (fail-open, не блокируем публикацию из-за этого).
  const installId = (typeof data.installId === 'string' && /^[a-zA-Z0-9-]{8,64}$/.test(data.installId))
    ? data.installId
    : null;

  // 1. Нормализация текста и генерация SHA-256 (Unicode-безопасно)
  const normalized = (title + ' ' + description)
    .toLowerCase()
    .replace(/[\s\p{P}\p{S}\p{C}]+/gu, '')
    .replace(/[^\p{L}\p{N}]/gu, '');
  const textHash = crypto.createHash('sha256').update(normalized).digest('hex');

  // 2. Скачивание изображений и генерация perceptual hash (aHash) на сервере.
  //    В отличие от точного MD5 файла, устойчив к пересжатию/ресайзу того же фото.
  const imageHashes = [];
  const bucket = admin.storage().bucket();
  const paths = imagePaths || [];

  for (const pathOrUrl of paths) {
    const storagePath = getStoragePathFromUrl(pathOrUrl);
    if (!storagePath) continue;

    try {
      const file = bucket.file(storagePath);
      const [contents] = await file.download();
      const hash = await computePerceptualHash(contents);
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

      // Читаем users/{userId} — историю дублей и флаг ограничения аккаунта
      const userRef = db.collection('users').doc(userId);
      const userSnap = await transaction.get(userRef);
      const userData = userSnap.exists ? userSnap.data() : {};
      const alreadyRestricted = userData.postingRestricted === true;

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
      let isGenuineDuplicateHit = false;

      if (existingTextAd) {
        if (textDuplicateUserId === userId) {
          // Тоже считается как страйк за дубли, только потом возвращаем спец-вердикт без throw
          transaction.set(userRef, {
            duplicateStrikeCount: admin.firestore.FieldValue.increment(1),
          }, { merge: true });
          return { verdict: 'DUPLICATE_SELF', reason: 'Вы уже опубликовали объявление с таким текстом' };
        } else {
          localVerdict = 'MANUAL_REVIEW';
          localReason = 'Найден дубликат текста у другого пользователя';
          isGenuineDuplicateHit = true;
        }
      }

      if (activeImageDuplicates.length > 0) {
        localVerdict = 'MANUAL_REVIEW';
        localReason = `Найдено ${activeImageDuplicates.length} дубликатов изображений`;
        isGenuineDuplicateHit = true;
      }

      // ─── B2) STRIKES & AUTO-RESTRICTION ───
      // После N пойманных дублей — все новые объявления аккаунта уходят на ручную
      // проверку, пока админ вручную не снимет флаг postingRestricted.
      if (isGenuineDuplicateHit) {
        const newStrikeCount = (userData.duplicateStrikeCount || 0) + 1;
        const userUpdates = { duplicateStrikeCount: admin.firestore.FieldValue.increment(1) };
        if (newStrikeCount >= DUPLICATE_STRIKE_THRESHOLD && !alreadyRestricted) {
          userUpdates.postingRestricted = true;
          userUpdates.postingRestrictedAt = admin.firestore.FieldValue.serverTimestamp();
        }
        transaction.set(userRef, userUpdates, { merge: true });
      }

      if (alreadyRestricted && localVerdict === 'CLEAN') {
        localVerdict = 'MANUAL_REVIEW';
        localReason = 'Аккаунт ограничен из-за повторных дублей — объявления проверяются вручную';
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

  // 3. Мульти-аккаунт эвристика: то же installId (устройство) уже публиковало объявления
  //    с ДРУГИХ аккаунтов. Не блокирует — только флаг для админки (fail-open при ошибке).
  let multiAccountSuspected = false;
  let linkedAccountsCount = 0;
  if (installId) {
    try {
      const linkRef = db.collection('userInstallLinks').doc(`${userId}_${installId}`);
      await linkRef.set({
        userId,
        installId,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        adCount: admin.firestore.FieldValue.increment(1),
      }, { merge: true });

      const sameDeviceSnap = await db.collection('userInstallLinks').where('installId', '==', installId).get();
      const distinctUserIds = new Set(sameDeviceSnap.docs.map((d) => d.data().userId));
      distinctUserIds.delete(userId);
      linkedAccountsCount = distinctUserIds.size;
      multiAccountSuspected = linkedAccountsCount > 0;
    } catch (err) {
      console.warn('[checkAdFingerprint] Multi-account check failed (fail-open):', err.message);
    }
  }

  return { verdict, reason, multiAccountSuspected, linkedAccountsCount };
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
      driverOrdersSnap,
      contactSnap
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
      db.collection('taxi_orders').where('driverId', '==', targetUid).limit(50).get(),
      // Контакты лежат в приватном поддокументе, а не в профиле: правила
      // запрещают phone/email в users/{uid}. Без этого чтения админ не видел
      // телефон вообще — в authData.phoneNumber у входа через Телеграм и Google
      // всегда null, а в профиле поля phone нет и быть не может.
      db.collection('users').doc(targetUid).collection('private').doc('contact').get()
    ]);

    // 6. Формирование структуры ответа
    const profile = userSnap.exists ? userSnap.data() : null;
    const contact = contactSnap.exists ? contactSnap.data() : {};

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

    // updateUserRatingTransaction уже держит profile.rating в актуальном состоянии
    // (5.0 по умолчанию без отзывов, иначе реальное среднее) — пересчёт на лету не нужен.
    const avgRating = profile ? (profile.rating ?? 5.0) : 5.0;
    const reviewsCount = profile ? (profile.reviewsCount || 0) : 0;

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
      // Контакты отдельным блоком — админу нужен телефон, чтобы связаться с
      // пользователем. telegramUsername позволяет написать напрямую в Телеграм.
      contact: {
        phone: contact.phone || profile?.verified_phone || null,
        verifiedPhone: profile?.verified_phone || null,
        email: contact.email || null,
        telegramChatId: contact.telegramChatId || contact.telegram_chat_id || profile?.telegramChatId || null,
        telegramUsername: contact.telegram_username || profile?.telegram_username || null,
        isTelegramVerified: profile?.isTelegramVerified === true,
      },
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

// ─── HTTPS CALLABLE: deleteUserAccount ────────────────────────────────────────
// UserService.deleteUserData() (клиент) удаляет объявления и вызывает эту
// функцию для всего остального — раньше private/contact (телефон+email),
// notifications и отзывы оставались в базе навсегда после удаления аккаунта,
// хотя политика конфиденциальности обещает удаление данных. Firestore не
// удаляет подколлекции вместе с родительским документом сам по себе.
//
// Чаты (chats/*) сознательно НЕ трогаем: это общие данные с другим
// участником, а не только этого пользователя — аккуратная чистка (скрыть
// вместо удаления) требует того же подхода, что уже есть у отдельных
// сообщений (deletedFor), а не поспешного решения здесь.
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }
  const uid = context.auth.uid;

  try {
    // Отзывы, которые пользователь написал и которые написали о нём —
    // после удаления профиля они всё равно становятся "про несуществующего
    // пользователя", смысла оставлять не больше, чем в самом профиле.
    const [reviewsFrom, reviewsTo] = await Promise.all([
      db.collection('reviews').where('fromUserId', '==', uid).get(),
      db.collection('reviews').where('toUserId', '==', uid).get(),
    ]);
    const reviewRefs = new Map();
    reviewsFrom.docs.forEach((d) => reviewRefs.set(d.id, d.ref));
    reviewsTo.docs.forEach((d) => reviewRefs.set(d.id, d.ref));
    if (reviewRefs.size > 0) {
      const batch = db.batch();
      reviewRefs.forEach((ref) => batch.delete(ref));
      await batch.commit();
    }

    // users/{uid} и ВСЕ его подколлекции разом (private/contact,
    // notifications и любые будущие) — recursiveDelete не требует заранее
    // знать их список, в отличие от ручного перебора.
    await db.recursiveDelete(db.collection('users').doc(uid));

    // Auth-аккаунт последним, после того как данные реально удалены —
    // если этот шаг упадёт, клиент увидит ошибку и не решит, что всё готово.
    await admin.auth().deleteUser(uid);

    console.log(`[deleteUserAccount] Deleted account and personal data for ${uid}`);
    return { success: true };
  } catch (error) {
    console.error('[deleteUserAccount] Error:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message || 'Не удалось удалить аккаунт');
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

    // 2. Чтение лога уникального просмотра
    const logSnap = await transaction.get(logRef);

    if (logSnap.exists) {
      // Пользователь уже просматривал это объявление ранее
      return { success: true, reason: 'duplicate', views: adData.views || 0 };
    }

    // 3. Запись лога уникального просмотра
    transaction.set(logRef, {
      firstViewedAt: admin.firestore.FieldValue.serverTimestamp(),
      userId: userId,
      listingId: listingId
    });

    const currentViews = (adData.views || 0);
    const newViews = currentViews + 1;

    // 4. Атомарный инкремент счетчика просмотров прямо в документе объявления ads/{listingId}
    transaction.set(adRef, {
      views: admin.firestore.FieldValue.increment(1)
    }, { merge: true });

    // 5. Инкремент счетчика в ads/{listingId}/stats/counters (для аналитики)
    transaction.set(statsRef, {
      viewsCount: admin.firestore.FieldValue.increment(1)
    }, { merge: true });

    return { success: true, views: newViews };
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
    // БИЗНЕС-ПРАВИЛО IQ-MARKET:
    // Стартовый рейтинг у всех пользователей равен 5.0 (пока отзывов меньше 5).
    // Начиная с 5 отзывов (newCount >= 5) рейтинг рассчитывается как честное среднее (newSum / newCount).
    const avgRating = newCount >= 5 ? Number((newSum / newCount).toFixed(1)) : 5.0;
    
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
