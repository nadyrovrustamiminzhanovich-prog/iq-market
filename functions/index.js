/**
 * IQ-Market Telegram Bot Webhook (Firebase Cloud Function)
 *
 * SETUP:
 *  1. cd functions && npm install node-fetch@2 firebase-admin firebase-functions
 *  2. firebase functions:config:set telegram.token="YOUR_BOT_TOKEN" telegram.admin_chat="ADMIN_CHAT_ID"
 *  3. firebase deploy --only functions
 *  4. Set webhook: https://api.telegram.org/botTOKEN/setWebhook?url=YOUR_FUNCTION_URL
 */

const functions = require('firebase-functions/v1');
const admin     = require('firebase-admin');
const fetch     = require('node-fetch');

admin.initializeApp();
const db = admin.firestore();

const TOKEN       = functions.config().telegram?.token  || process.env.TG_TOKEN;
const ADMIN_CHAT  = functions.config().telegram?.admin_chat || process.env.ADMIN_CHAT || '';
const API         = `https://api.telegram.org/bot${TOKEN}`;

// ─── send helper ──────────────────────────────────────────────────────────────
async function tgSend(chatId, text, extra = {}) {
  console.log(`Sending to ${chatId}: ${text}`);
  try {
    const response = await fetch(`${API}/sendMessage`, {
      method : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body   : JSON.stringify({ chat_id: chatId, text, parse_mode: 'Markdown', ...extra }),
    });
    if (!response.ok) {
      const errData = await response.json();
      console.error('Telegram API Error:', errData);
    }
    return response;
  } catch (error) {
    console.error('Network Error calling Telegram:', error);
    return null;
  }
}

// ─── WEBHOOK ──────────────────────────────────────────────────────────────────
exports.telegramWebhook = functions.https.onRequest(async (req, res) => {
  const update = req.body;

  // ── Inline button callback (admin approve / reject) ────────────────────────
  if (update.callback_query) {
    const cq     = update.callback_query;
    const data   = cq.data || '';
    const parts  = data.split('|');          // approve|docId|driverChatId
    const action = parts[0];
    const docId  = parts[1];
    const driverChatId = parts[2];

    if (action === 'approve') {
      await db.collection('driver_verifications').doc(docId).update({
        status: 'approved',
        reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      await tgSend(driverChatId,
        '🎉 *Поздравляем! Верификация пройдена!*\n\n'
        + 'Ваши документы проверены и одобрены. Теперь вы можете принимать заказы в *IQ\\-Market Taxi*.\n🚀 Удачных поездок!'
      );
      await tgSend(ADMIN_CHAT || cq.from.id, `✅ Водитель (doc: ${docId}) — *ОДОБРЕН*`);
    } else if (action === 'reject') {
      await db.collection('driver_verifications').doc(docId).update({
        status: 'rejected',
        reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      await tgSend(driverChatId,
        '❌ *Верификация отклонена*\n\n'
        + 'Документы не прошли проверку. Загрузите чёткие фото и повторите попытку.'
      );
      await tgSend(ADMIN_CHAT || cq.from.id, `❌ Водитель (doc: ${docId}) — *ОТКЛОНЁН*`);
    }

    // Answer callback to remove "loading" on button
    await fetch(`${API}/answerCallbackQuery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ callback_query_id: cq.id }),
    });
    return res.sendStatus(200);
  }

  // ── Regular messages ───────────────────────────────────────────────────────
  if (!update.message) return res.sendStatus(200);

  const msg     = update.message;
  const chatId  = msg.chat.id.toString();
  const text    = msg.text || '';
  const name    = msg.from.first_name || 'друг';

  // ── Contact sharing handler ───────────────────────────────────────────────
  if (msg.contact) {
    const contact = msg.contact;
    const contactUserId = contact.user_id ? contact.user_id.toString() : '';

    // Safety check: ensure they shared THEIR OWN contact
    if (contactUserId !== chatId) {
      await tgSend(chatId, `❌ Пожалуйста, поделитесь своим собственным контактом для верификации.`);
      return res.sendStatus(200);
    }

    // Standardize phone number from Telegram contact
    const contactPhone = contact.phone_number.replace(/\D/g, ''); // Clean non-digits
    let stdContactPhone = contactPhone;
    if (contactPhone.length === 11 && contactPhone.startsWith('8')) {
      stdContactPhone = '7' + contactPhone.substring(1);
    } else if (contactPhone.length === 10) {
      stdContactPhone = '7' + contactPhone;
    }

    // Find the active session for this chat_id that is NOT verified yet
    const sessionsSnap = await db.collection('tg_auth_sessions')
      .where('chat_id', '==', chatId)
      .where('verified', '==', false)
      .orderBy('created_at', 'desc')
      .limit(1)
      .get();

    if (sessionsSnap.empty) {
      await tgSend(chatId, `⚠️ Активная сессия не найдена. Пожалуйста, вернитесь в приложение и начните заново.`);
      return res.sendStatus(200);
    }

    const sessionDoc = sessionsSnap.docs[0];
    const sessionData = sessionDoc.data();
    const sessionPhoneRaw = sessionData.phone || '';

    // Standardize phone from session doc
    const sessionPhone = sessionPhoneRaw.replace(/\D/g, '');
    let stdSessionPhone = sessionPhone;
    if (sessionPhone.length === 11 && sessionPhone.startsWith('8')) {
      stdSessionPhone = '7' + sessionPhone.substring(1);
    } else if (sessionPhone.length === 10) {
      stdSessionPhone = '7' + sessionPhone;
    }

    // Check if the numbers match!
    if (stdContactPhone !== stdSessionPhone) {
      await tgSend(chatId, 
        `❌ *Ошибка верификации!*\n\n`
        + `Номер телефона вашего Telegram-аккаунта (\`+${stdContactPhone}\`) не совпадает с номером, введенным вами в приложении (\`+${stdSessionPhone}\`).\n\n`
        + `Пожалуйста, вернитесь в приложение, укажите правильный номер и попробуйте снова.`,
        {
          reply_markup: { remove_keyboard: true }
        }
      );
      return res.sendStatus(200);
    }

    // Verification successful! Generate and send OTP!
    const otp = String(Math.floor(100000 + Math.random() * 900000));

    // 🔒 X10 SECURITY: Generating a Firebase Custom Token
    let customToken = 'error_fallback';
    try {
      const uid = `telegram_${chatId}`;
      customToken = await admin.auth().createCustomToken(uid);
    } catch (tokenError) {
      console.error("WARNING: Failed to generate custom token:", tokenError);
    }

    await sessionDoc.ref.update({
      otp,
      customToken: customToken,
      linked_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    await tgSend(chatId,
      `✅ *Номер телефона успешно подтвержден!*\n\n`
      + `🔐 Ваш код подтверждения:\n\`${otp}\`\n\n`
      + `_Введите этот код в приложении. Код действителен 5 минут._`,
      {
        reply_markup: { remove_keyboard: true }
      }
    );
    return res.sendStatus(200);
  }

  // /start <sessionToken>  — link chat_id to auth session
  if (text.startsWith('/start')) {
    const parts        = text.split(' ');
    const sessionToken = parts[1] || null;

    if (sessionToken && sessionToken.length > 10) {
      // Auth flow: link chat_id to Firestore session
      const ref = db.collection('tg_auth_sessions').doc(sessionToken);
      const snap = await ref.get();
      if (snap.exists) {
        const sessionData = snap.data() || {};
        
        if (sessionData.phone) {
          // X10 Secure Contact-Sharing flow!
          await ref.update({
            chat_id : chatId,
            linked_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          await tgSend(chatId,
            `👋 *${name}, добро пожаловать в IQ-Market!*\n\n`
            + `Для верификации вашего номера телефона \`+${sessionData.phone}\` нажмите кнопку ниже и поделитесь своим контактом.`,
            {
              reply_markup: {
                keyboard: [[
                  { text: '📱 Поделиться номером телефона', request_contact: true }
                ]],
                one_time_keyboard: true,
                resize_keyboard: true
              }
            }
          );
        } else {
          // Direct OTP login flow!
          const otp = String(Math.floor(100000 + Math.random() * 900000));
          
          // 🔒 X10 SECURITY: Generating a Firebase Custom Token
          let customToken = 'error_fallback';
          try {
            const uid = `telegram_${chatId}`;
            customToken = await admin.auth().createCustomToken(uid);
          } catch (tokenError) {
            console.error("WARNING: Failed to generate custom token:", tokenError);
          }
          
          await ref.update({
            chat_id : chatId,
            verified: false,
            otp,
            customToken: customToken,
            linked_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          await tgSend(chatId,
            `👋 *${name}, добро пожаловать в IQ\\-Market!*\n\n`
            + `🔐 Ваш код подтверждения:\n\`${otp}\`\n\n`
            + `_Введите этот код в приложении. Код действителен 5 минут._`
          );
        }
      } else {
        await tgSend(chatId,
          `⚠️ Сессия устарела или недействительна.\nПожалуйста, вернитесь в приложение и начните заново.`
        );
      }
    } else {
      // No token — just show info
      await tgSend(chatId,
        `👋 *Добро пожаловать в IQ\\-Market Bot, ${name}!*\n\n`
        + `Этот бот используется для:\n`
        + `• 🔐 Безопасной авторизации\n`
        + `• 🚗 Верификации водителей\n`
        + `• 📢 Уведомлений о заказах\n\n`
        + `Ваш Chat ID: \`${chatId}\`\n\n`
        + `Используйте приложение IQ\\-Market для входа.`
      );
    }
  }

  // /approve_<docId> or /reject_<docId>  — admin commands in chat
  else if (text.startsWith('/approve_') || text.startsWith('/reject_')) {
    if (chatId !== ADMIN_CHAT) {
      return res.sendStatus(200);
    }
    const isApprove = text.startsWith('/approve_');
    const docId = text.replace(isApprove ? '/approve_' : '/reject_', '').trim();
    const snap  = await db.collection('driver_verifications').doc(docId).get();
    if (!snap.exists) {
      await tgSend(chatId, `❌ Документ \`${docId}\` не найден.`);
    } else {
      const driverChatId = snap.data().driver_chat_id;
      await db.collection('driver_verifications').doc(docId).update({
        status: isApprove ? 'approved' : 'rejected',
        reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      const msg = isApprove
        ? '🎉 *Верификация пройдена!* Вы можете принимать заказы в IQ\\-Market Taxi.'
        : '❌ *Верификация отклонена.* Загрузите чёткие фото и повторите попытку.';
      if (driverChatId) await tgSend(driverChatId, msg);
      await tgSend(chatId, isApprove ? '✅ Водитель одобрен.' : '❌ Водитель отклонён.');
    }
  }

  return res.sendStatus(200);
});

// ─── FIRESTORE TRIGGER: when verification status changes, notify driver ────────
exports.onVerificationUpdate = functions.firestore
  .document('driver_verifications/{docId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.status === after.status) return; // no change
    const chatId = after.driver_chat_id;
    if (!chatId) return;

    if (after.status === 'approved') {
      await tgSend(chatId,
        '🎉 *Поздравляем! Верификация пройдена!*\n\n'
        + 'Ваши документы одобрены. Добро пожаловать в команду IQ\\-Market Taxi!'
      );
    } else if (after.status === 'rejected') {
      await tgSend(chatId,
        '❌ *Верификация отклонена*\n\n'
        + `Причина: ${after.reject_reason || 'Документы не соответствуют требованиям'}\n\n`
        + 'Откройте приложение и загрузите чёткие фотографии.'
      );
    }
  });

// ─── FIRESTORE TRIGGER: Send FCM when a new message is created ────────────────
exports.onNewMessage = functions.firestore
  .document('chats/{chatId}/messages/{msgId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const chatId = context.params.chatId;
    const senderId = message.senderId;

    // 1. Get the chat document to find the receiver
    const chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) return;

    const chatData = chatSnap.data();
    const users = chatData.users || [];
    const receiverId = users.find(uid => uid !== senderId);

    if (!receiverId) return;

    // 2. Get receiver's FCM token
    const userSnap = await db.collection('users').doc(receiverId).get();
    if (!userSnap.exists) return;

    const receiverToken = userSnap.data().fcmToken;
    if (!receiverToken) return;

    // 3. Construct and send the message
    const senderName = chatData[`name_${senderId}`] || 'Пользователь';
    const adTitle = chatData.adTitle || 'IQ Market';

    const payload = {
      token: receiverToken,
      notification: {
        title: `${senderName} (${adTitle})`,
        body: message.text,
      },
      data: {
        type: 'chat',
        chatId: chatId,
        senderId: senderId,
        adId: chatData.adId || '',
        adTitle: chatData.adTitle || '',
        adImage: chatData.adImage || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          }
        }
      }
    };

    try {
      await admin.messaging().send(payload);
      console.log(`Successfully sent message to ${receiverId}`);
    } catch (error) {
      console.error('Error sending FCM:', error);
    }
  });

// ─── CRON JOB: Check Expired Ads (runs every 24 hours at 3 AM) ────────────────
exports.checkExpiredAds = functions.pubsub.schedule('0 3 * * *').timeZone('Asia/Almaty').onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();
  const warningTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() + (3 * 24 * 60 * 60 * 1000));
  
  const batch = db.batch();
  let expiredCount = 0;
  let notifyCount = 0;

  try {
    // 1. Archive expired ads
    const expiredAdsSnap = await db.collection('ads')
      .where('expiresAt', '<=', now)
      .where('status', '==', 'active')
      .get();

    expiredAdsSnap.forEach((doc) => {
      batch.update(doc.ref, { status: 'archived', active: false });
      expiredCount++;
    });

    // 2. Notify users about ads expiring in <= 3 days
    const expiringAdsSnap = await db.collection('ads')
      .where('expiresAt', '<=', warningTimestamp)
      .where('expiresAt', '>', now)
      .where('status', '==', 'active')
      .get();

    for (const doc of expiringAdsSnap.docs) {
      const data = doc.data();
      if (data.notifiedExpiry === true) continue; // Already notified

      // Mark as notified in the batch
      batch.update(doc.ref, { notifiedExpiry: true });
      
      // Send push notification
      if (data.userId) {
        const userSnap = await db.collection('users').doc(data.userId).get();
        if (userSnap.exists && userSnap.data().fcmToken) {
          const payload = {
            token: userSnap.data().fcmToken,
            notification: {
              title: 'Объявление скоро истечет ⏳',
              body: `Срок размещения "${data.title}" истекает менее чем через 3 дня. Продлите его в профиле!`,
            },
            data: {
              type: 'ad_expiring',
              adId: doc.id,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            }
          };
          admin.messaging().send(payload).then(() => notifyCount++).catch(e => console.error('Push error:', e));
        }
      }
    }

    if (expiredCount > 0 || notifyCount > 0) {
      await batch.commit();
      console.log(`Archived ${expiredCount} ads. Sent ${notifyCount} expiry warnings.`);
    } else {
      console.log('No expired or expiring ads found today.');
    }
  } catch (error) {
    console.error('Error in checkExpiredAds:', error);
  }

  return null;
});

// ─── SECURE GEMINI CALL PROXY ────────────────────────────────────────────────
exports.secureGeminiCall = functions.https.onRequest(async (req, res) => {
  // CORS setup
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  // 1. Verify Firebase Auth ID Token
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.error('Gemini call rejected: Missing authorization header');
    return res.status(401).send('Unauthorized: Missing token');
  }
  const idToken = authHeader.split('Bearer ')[1];
  try {
    await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    console.error('Gemini call rejected: Invalid authorization token:', error);
    return res.status(401).send('Unauthorized: Invalid token');
  }

  // 2. Determine target key based on "key" query parameter
  const keySelector = req.query.key || 'moderation';
  let targetApiKey = keySelector === 'assistant' 
    ? process.env.GEMINI_ASSISTANT_KEY 
    : process.env.GEMINI_MODERATION_KEY;

  // Fallback to direct env variables if needed
  if (!targetApiKey) {
    targetApiKey = keySelector === 'assistant'
      ? 'AIzaSyBmEtwHY3pMJRFBy4FrwqkJPuar0doS76Q'
      : 'AIzaSyDtAj-fwr89rDc7arxu3ONplnJOW0Vk_IU';
  }

  // 3. Reconstruct target path and URL
  const reqPath = req.path || '';
  const targetUrl = `https://generativelanguage.googleapis.com${reqPath}?key=${targetApiKey}`;

  console.log(`Proxying Gemini Request to ${reqPath} using key selector: ${keySelector}`);

  try {
    const fetchResponse = await fetch(targetUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(req.body),
    });

    res.status(fetchResponse.status);

    // Copy headers from response
    const contentType = fetchResponse.headers.get('content-type');
    if (contentType) {
      res.setHeader('content-type', contentType);
    }
    const transferEncoding = fetchResponse.headers.get('transfer-encoding');
    if (transferEncoding) {
      res.setHeader('transfer-encoding', transferEncoding);
    }

    // Pipe the response body stream directly back to the client
    fetchResponse.body.pipe(res);
  } catch (error) {
    console.error('secureGeminiCall proxy error:', error);
    res.status(500).send('Internal Server Error in Gemini Proxy');
  }
});

// ─── SECURE SEND TELEGRAM MESSAGE ───────────────────────────────────────────
exports.secureSendTelegramMessage = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  // 1. Verify Firebase Auth ID Token
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.error('Telegram call rejected: Missing authorization header');
    return res.status(401).send('Unauthorized: Missing token');
  }
  const idToken = authHeader.split('Bearer ')[1];
  try {
    await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    console.error('Telegram call rejected: Invalid authorization token:', error);
    return res.status(401).send('Unauthorized: Invalid token');
  }

  const { chatId, text, reply_markup } = req.body;
  if (!chatId || !text) {
    return res.status(400).send('Missing chatId or text');
  }

  try {
    const extra = reply_markup ? { reply_markup } : {};
    const response = await tgSend(chatId, text, extra);
    if (response && response.ok) {
      return res.status(200).json({ success: true });
    } else {
      const errText = response ? await response.text() : 'Unknown network error';
      console.error('Telegram API error response:', errText);
      return res.status(500).json({ success: false, error: 'Telegram API error', details: errText });
    }
  } catch (error) {
    console.error('secureSendTelegramMessage error:', error);
    return res.status(500).send(error.toString());
  }
});

// ─── SEND TELEGRAM OTP ───────────────────────────────────────────────────────
exports.sendTelegramOtp = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  const { chat_id, phone, code } = req.body;
  if (!chat_id || !code) {
    return res.status(400).send('Missing chat_id or code');
  }

  const text = `🔐 *Ваш код для входа в IQ-Market:*\n\n\`${code}\`\n\n_Код действителен 5 минут. Никому не сообщайте!_`;

  try {
    const response = await tgSend(chat_id, text);
    if (response && response.ok) {
      return res.status(200).json({ success: true });
    } else {
      const errText = response ? await response.text() : 'Unknown network error';
      console.error('Telegram OTP error response:', errText);
      return res.status(500).json({ success: false, error: 'Telegram API error', details: errText });
    }
  } catch (error) {
    console.error('sendTelegramOtp error:', error);
    return res.status(500).send(error.toString());
  }
});
