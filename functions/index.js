/**
 * IQ-Market Telegram Bot Webhook (Firebase Cloud Function)
 */

const functions = require('firebase-functions/v1');
const admin     = require('firebase-admin');

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

    const receiverToken = userSnap.data().fcmToken;
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
            admin.messaging().send(payload)
              .then(() => notifyCount++)
              .catch(e => console.error('Push error:', e));
          }
        }
      }

      if (batchCount > 0) batchOps.push(currentBatch.commit());
      if (batchOps.length > 0) {
        await Promise.all(batchOps);
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
    fetchResponse.body.pipe(res);
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
