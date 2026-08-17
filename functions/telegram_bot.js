/**
 * IQ-Market Telegram Bot Webhook & Logic Module
 * Separated for clean architecture and maintainability.
 */

const functions = require('firebase-functions/v1');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin     = require('firebase-admin');
const db        = admin.firestore();
const crypto    = require('crypto');
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || '';

const TOKEN      = process.env.TG_TOKEN || '';
const ADMIN_CHAT = process.env.ADMIN_CHAT || '';
const API        = `https://api.telegram.org/bot${TOKEN}`;

// ─── createCustomToken with retry ────────────────────────────────────────────
async function createCustomTokenWithRetry(uid, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const token = await admin.auth().createCustomToken(uid);
      console.log(`[createCustomToken] OK attempt=${attempt} uid=${uid}`);
      return token;
    } catch (err) {
      console.error(`[createCustomToken] Attempt ${attempt}/${maxRetries} failed for uid=${uid}:`, err.message);
      if (attempt < maxRetries) {
        await new Promise(r => setTimeout(r, 1000 * attempt));
      } else {
        console.error('[createCustomToken] FATAL: All attempts failed.');
        return 'error_fallback';
      }
    }
  }
  return 'error_fallback';
}

// ─── Telegram send helper ─────────────────────────────────────────────────────
async function tgSend(chatId, text, extra = {}, parse_mode = 'HTML') {
  console.log(`[tgSend] → chatId=${chatId}`);
  if (!TOKEN) {
    console.error('[tgSend] Error: Telegram token is empty');
    return null;
  }
  try {
    const response = await fetch(`${API}/sendMessage`, {
      method : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body   : JSON.stringify({ chat_id: chatId, text, parse_mode, ...extra }),
    });
    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      console.error('[tgSend] Telegram API Error:', JSON.stringify(errData));
    }
    return response;
  } catch (error) {
    console.error('[tgSend] Network Error:', error);
    return null;
  }
}

// ─── Register Webhook ─────────────────────────────────────────────────────────
exports.registerWebhook = functions.https.onRequest(async (req, res) => {
  // P2: Admin-only endpoint
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).send('Unauthorized: Missing token');
  }
  try {
    const decoded = await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
    const userDoc = await db.collection('users').doc(decoded.uid).get();
    if (!userDoc.exists || userDoc.data().accountType !== 'admin') {
      return res.status(403).send('Forbidden: Admin only');
    }
  } catch (e) {
    return res.status(401).send('Unauthorized: Invalid token');
  }

  if (!TOKEN) return res.status(500).send('TG_TOKEN not set');
  const webhookUrl = `https://us-central1-iq-market-3dc07.cloudfunctions.net/telegramWebhook`;
  try {
    const r = await fetch(`${API}/setWebhook`, {
      method : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body   : JSON.stringify({
        url: webhookUrl,
        allowed_updates: ['message', 'callback_query'],
        secret_token: WEBHOOK_SECRET,
      }),
    });
    const data = await r.json();
    console.log('[registerWebhook] Result:', JSON.stringify(data));
    return res.status(200).json(data);
  } catch (e) {
    return res.status(500).send(e.toString());
  }
});

// ─── WEBHOOK ──────────────────────────────────────────────────────────────────
exports.telegramWebhook = functions.https.onRequest(async (req, res) => {
  // P1: Verify Telegram webhook secret token
  if (WEBHOOK_SECRET) {
    const receivedSecret = req.headers['x-telegram-bot-api-secret-token'];
    if (receivedSecret !== WEBHOOK_SECRET) {
      console.warn('[telegramWebhook] Invalid secret token — rejecting request');
      return res.sendStatus(403);
    }
  }

  try {
    if (!TOKEN) {
      console.error('[telegramWebhook] TOKEN не задан — игнорируем запрос');
      return res.sendStatus(200);
    }

    const update = req.body;

    // ── Inline button callback (admin approve / reject) ────────────────────────
    if (update.callback_query) {
      const cq     = update.callback_query;
      const fromId = cq.from ? String(cq.from.id) : '';

      // 🔐 X10 SECURITY check: Only the designated ADMIN_CHAT can approve or reject
      if (!ADMIN_CHAT || fromId !== String(ADMIN_CHAT)) {
        console.warn(`[telegramWebhook] Unauthorized callback query from: ${fromId}`);
        await fetch(`${API}/answerCallbackQuery`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            callback_query_id: cq.id,
            text: '❌ Доступ запрещен: Вы не являетесь администратором!',
            show_alert: true,
          }),
        });
        return res.sendStatus(200);
      }

      const data   = cq.data || '';
      const parts  = data.split('|');
      const action = parts[0];
      const docId  = parts[1];
      const driverChatId = parts[2];

      if (action === 'approve') {
        await db.collection('driver_verifications').doc(docId).update({
          status: 'approved',
          reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        await tgSend(driverChatId,
          '🎉 <b>Поздравляем! Верификация пройдена!</b>\n\n'
          + 'Ваши документы проверены и одобрены. Теперь вы можете принимать заказы в <b>IQ-Market Taxi</b>.\n🚀 Удачных поездок!'
        );
        await tgSend(ADMIN_CHAT || cq.from.id, `✅ Водитель (doc: <code>${docId}</code>) — <b>ОДОБРЕН</b>`);
      } else if (action === 'reject') {
        await db.collection('driver_verifications').doc(docId).update({
          status: 'rejected',
          reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        await tgSend(driverChatId,
          '❌ <b>Верификация отклонена</b>\n\n'
          + 'Документы не прошли проверку. Загрузите чёткие фото и повторите попытку.'
        );
        await tgSend(ADMIN_CHAT || cq.from.id, `❌ Водитель (doc: <code>${docId}</code>) — <b>ОТКЛОНЁН</b>`);
      } else if (action === 'approve_ad') {
        await db.collection('ads').doc(docId).update({
          status: 'active',
          active: true,
        });
        
        const adSnap = await db.collection('ads').doc(docId).get();
        if (adSnap.exists) {
          const adData = adSnap.data();
          const adTitle = adData.title || '';
          const userId = adData.userId || '';
          
          if (userId.startsWith('telegram_')) {
            const userChatId = userId.replace('telegram_', '');
            await tgSend(userChatId, `🎉 <b>Ваше объявление «${adTitle}» успешно проверено и опубликовано!</b>`);
          }
        }
        
        await tgSend(ADMIN_CHAT || cq.from.id, `✅ Объявление (doc: <code>${docId}</code>) — <b>ОДОБРЕНО И ОПУБЛИКОВАНО</b>`);
      } else if (action === 'reject_ad') {
        await db.collection('ads').doc(docId).update({
          status: 'rejected',
          active: false,
        });
        
        const adSnap = await db.collection('ads').doc(docId).get();
        if (adSnap.exists) {
          const adData = adSnap.data();
          const adTitle = adData.title || '';
          const userId = adData.userId || '';
          
          if (userId.startsWith('telegram_')) {
            const userChatId = userId.replace('telegram_', '');
            await tgSend(userChatId, `❌ <b>Ваше объявление «${adTitle}» отклонено модератором.</b>\nПожалуйста, проверьте правила публикации.`);
          }
        }
        
        await tgSend(ADMIN_CHAT || cq.from.id, `❌ Объявление (doc: <code>${docId}</code>) — <b>ОТКЛОНЕНО</b>`);
      }

      await fetch(`${API}/answerCallbackQuery`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callback_query_id: cq.id }),
      });
      return res.sendStatus(200);
    }

    // ── Regular messages ───────────────────────────────────────────────────────
    if (!update.message) return res.sendStatus(200);

    const msg    = update.message;
    const chatId = msg.chat.id.toString();
    const text   = msg.text || '';
    const name   = msg.from.first_name || 'друг';

    // ── Contact sharing handler ───────────────────────────────────────────────
    if (msg.contact) {
      const contact = msg.contact;
      console.log(`[contact] Received from chatId=${chatId}`, JSON.stringify(contact));
      const contactUserId = contact.user_id ? contact.user_id.toString() : '';

      if (contactUserId !== chatId) {
        await tgSend(chatId, `❌ Пожалуйста, поделитесь своим собственным контактом для верификации.`);
        return res.sendStatus(200);
      }

      const contactPhone = contact.phone_number.replace(/\D/g, '');
      let stdContactPhone = contactPhone;
      if (contactPhone.length === 11 && contactPhone.startsWith('8')) {
        stdContactPhone = '7' + contactPhone.substring(1);
      } else if (contactPhone.length === 10) {
        stdContactPhone = '7' + contactPhone;
      }

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

      const sessionDoc  = sessionsSnap.docs[0];
      const sessionData = sessionDoc.data();
      const sessionPhoneRaw = sessionData.phone || '';

      // Две ситуации, и различает их наличие phone в сессии:
      //  • сессия С номером — верификация того, что человек уже ввёл в
      //    приложении: номер контакта обязан совпасть с введённым;
      //  • сессия БЕЗ номера — вход через Телеграм: сверять не с чем, номер,
      //    которым поделились, И ЕСТЬ источник истины.
      if (sessionPhoneRaw) {
        const sessionPhone = sessionPhoneRaw.replace(/\D/g, '');
        let stdSessionPhone = sessionPhone;
        if (sessionPhone.length === 11 && sessionPhone.startsWith('8')) {
          stdSessionPhone = '7' + sessionPhone.substring(1);
        } else if (sessionPhone.length === 10) {
          stdSessionPhone = '7' + sessionPhone;
        }

        // X10: Robust 10-digit suffix matching (bypasses prefix differences like 7 vs 8 vs +7)
        const cleanContact = stdContactPhone.slice(-10);
        const cleanSession = stdSessionPhone.slice(-10);

        if (cleanContact !== cleanSession) {
          await tgSend(chatId,
            `❌ <b>Ошибка верификации!</b>\n\n`
            + `Номер вашего Telegram (<code>+${stdContactPhone}</code>) не совпадает с номером в приложении (<code>+${stdSessionPhone}</code>).\n\n`
            + `Вернитесь в приложение, укажите правильный номер и попробуйте снова.`,
            { reply_markup: { remove_keyboard: true } }
          );
          return res.sendStatus(200);
        }
      }

      console.log(`[contact] Phone match OK for chatId=${chatId}. Generating OTP...`);
      const otp = crypto.randomInt(100000, 999999).toString();

      const uid = `telegram_${chatId}`;
      const customToken = await createCustomTokenWithRetry(uid);
      if (customToken === 'error_fallback') {
        console.error(`[contact] FAILED to get customToken for chatId=${chatId}`);
      }

      const tgUsername  = msg.from.username ? `@${msg.from.username}` : '';
      const tgFirstName = msg.from.first_name || '';
      const tgLastName  = msg.from.last_name || '';

      await sessionDoc.ref.update({
        chat_id            : chatId,
        telegram_username  : tgUsername,
        telegram_first_name: tgFirstName,
        telegram_last_name : tgLastName,
        otp                : 'sent',
        verified           : true,
        linked_at          : admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Номер кладём ТОЛЬКО в secure-коллекцию: у tg_auth_sessions правило
      // `allow get: if true`, то есть публичный документ прочитает любой, кто
      // знает токен сессии. Для входа через Телеграм номер — это новая
      // приватная информация, светить её в публичном документе нельзя.
      // У tg_auth_sessions_secure правил нет вовсе → default deny → читает
      // только Admin SDK.
      await db.collection('tg_auth_sessions_secure').doc(sessionDoc.id).set({
        otp,
        customToken,
        verified_phone: stdContactPhone,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`[contact] Session ${sessionDoc.id} secure OTP saved. Public doc updated.`);

      await tgSend(chatId,
        `✅ <b>Номер телефона успешно подтверждён!</b>\n\n`
        + `🔐 Ваш код подтверждения:\n<code>${otp}</code>\n\n`
        + `<i>Введите этот код в приложении. Код действителен 5 минут.</i>`,
        { reply_markup: { remove_keyboard: true } }
      );
      return res.sendStatus(200);
    }

    // /start <sessionToken> — link chat_id to auth session
    if (text.startsWith('/start')) {
      const parts        = text.split(' ');
      const sessionToken = parts[1] || null;

      if (sessionToken && sessionToken.length > 10) {
        const ref  = db.collection('tg_auth_sessions').doc(sessionToken);
        const snap = await ref.get();
        if (snap.exists) {
          const sessionData = snap.data() || {};

          // 🛡️ Bypass duplicate start resets
          const secureSnap = await db.collection('tg_auth_sessions_secure').doc(sessionToken).get();
          const secureData = secureSnap.data() || {};
          if (sessionData.chat_id && secureData.otp) {
            await tgSend(chatId,
              `👋 <b>${name}, ваш код подтверждения (повторный запрос):</b>\n\n`
              + `🔐 Код: <code>${secureData.otp}</code>\n\n`
              + `<i>Введите этот код в приложении. Код действителен 5 минут.</i>`
            );
            return res.sendStatus(200);
          }

          const tgUsername  = msg.from.username ? `@${msg.from.username}` : '';
          const tgFirstName = msg.from.first_name || '';
          const tgLastName  = msg.from.last_name || '';

          if (sessionData.phone) {
            // X10 Secure Contact-Sharing flow (verification after Google/Email login)
            await ref.update({
              chat_id            : chatId,
              telegram_username  : tgUsername,
              telegram_first_name: tgFirstName,
              telegram_last_name : tgLastName,
              linked_at          : admin.firestore.FieldValue.serverTimestamp(),
            });
            await tgSend(chatId,
              `👋 <b>${name}, добро пожаловать в IQ-Market!</b>\n\n`
              + `Для верификации номера <code>+${sessionData.phone}</code> нажмите кнопку ниже.`,
              {
                reply_markup: {
                  keyboard: [[
                    { text: '📱 Поделиться номером телефона', request_contact: true }
                  ]],
                  one_time_keyboard: true,
                  resize_keyboard  : true,
                },
              }
            );
          } else {
            // Вход через Телеграм. Код НЕ выдаём сразу — сначала просим
            // поделиться контактом, иначе номера у аккаунта не будет вовсе:
            // Telegram Bot API не отдаёт телефон, пока пользователь сам не
            // нажмёт request_contact, а custom-token вход не приносит
            // phoneNumber в Firebase Auth.
            //
            // Код выдаётся в обработчике msg.contact — там же, где идёт
            // проверка, что человек поделился СВОИМ контактом
            // (contact.user_id === chatId). Без номера входа нет.
            await ref.update({
              chat_id            : chatId,
              telegram_username  : tgUsername,
              telegram_first_name: tgFirstName,
              telegram_last_name : tgLastName,
              linked_at          : admin.firestore.FieldValue.serverTimestamp(),
            });

            await tgSend(chatId,
              `👋 <b>${name}, добро пожаловать в IQ-Market!</b>\n\n`
              + `Для входа подтвердите свой номер телефона — нажмите кнопку ниже.\n\n`
              + `<i>Номер нужен, чтобы с вами могли связаться по объявлениям. Мы не показываем его никому, кроме тех, кому вы сами позвоните или напишете.</i>`,
              {
                reply_markup: {
                  keyboard: [[
                    { text: '📱 Поделиться номером телефона', request_contact: true }
                  ]],
                  one_time_keyboard: true,
                  resize_keyboard  : true,
                },
              }
            );
          }
        } else {
          await tgSend(chatId,
            `⚠️ <b>Сессия устарела или недействительна.</b>\nПожалуйста, вернитесь в приложение и начните заново.`
          );
        }
      } else {
        await tgSend(chatId,
          `👋 <b>Добро пожаловать в IQ-Market Bot, ${name}!</b>\n\n`
          + `Этот бот используется для:\n`
          + `• 🔐 Безопасной авторизации\n`
          + `• 🚗 Верификации водителей\n`
          + `• 📢 Уведомлений о заказах\n\n`
          + `Ваш Chat ID: <code>${chatId}</code>\n\n`
          + `Используйте приложение IQ-Market для входа.`
        );
      }
    }

    // /approve_ad_<docId> or /reject_ad_<docId> — admin ad commands
    else if (text.startsWith('/approve_ad_') || text.startsWith('/reject_ad_')) {
      if (chatId !== ADMIN_CHAT) {
        return res.sendStatus(200);
      }
      const isApprove = text.startsWith('/approve_ad_');
      const docId = text.replace(isApprove ? '/approve_ad_' : '/reject_ad_', '').trim();
      const snap  = await db.collection('ads').doc(docId).get();
      if (!snap.exists) {
        await tgSend(chatId, `❌ Объявление \`${docId}\` не найдено.`);
      } else {
        const adData = snap.data();
        const adTitle = adData.title || '';
        const userId = adData.userId || '';
        
        await db.collection('ads').doc(docId).update({
          status: isApprove ? 'active' : 'rejected',
          active: isApprove,
        });
        
        if (userId.startsWith('telegram_')) {
          const userChatId = userId.replace('telegram_', '');
          const msgText = isApprove
            ? `🎉 <b>Ваше объявление «${adTitle}» успешно проверено и опубликовано!</b>`
            : `❌ <b>Ваше объявление «${adTitle}» отклонено модератором.</b>\nПожалуйста, проверьте правила публикации.`;
          await tgSend(userChatId, msgText);
        }
        
        await tgSend(chatId, isApprove ? `✅ Объявление «${adTitle}» одобрено.` : `❌ Объявление «${adTitle}» отклонено.`);
      }
    }

    // /approve_<docId> or /reject_<docId> — admin commands
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
          status     : isApprove ? 'approved' : 'rejected',
          reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        const msgText = isApprove
          ? '🎉 <b>Верификация пройдена!</b> Вы можете принимать заказы в IQ-Market Taxi.'
          : '❌ <b>Верификация отклонена.</b> Загрузите чёткие фото и повторите попытку.';
        if (driverChatId) await tgSend(driverChatId, msgText);
        await tgSend(chatId, isApprove ? '✅ Водитель одобрен.' : '❌ Водитель отклонён.');
      }
    }

    return res.sendStatus(200);

  } catch (err) {
    console.error('[telegramWebhook] UNHANDLED ERROR:', err);
    return res.sendStatus(200); // всегда 200, чтобы Telegram не повторял
  }
});

// ─── FIRESTORE TRIGGER: verification status → notify driver ──────────────────
exports.onVerificationUpdate = onDocumentUpdated('driver_verifications/{docId}', async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (before.status === after.status) return;
    const chatId = after.driver_chat_id;
    if (!chatId) return;

    if (after.status === 'approved') {
      await tgSend(chatId,
        '🎉 <b>Поздравляем! Верификация пройдена!</b>\n\n'
        + 'Ваши документы одобрены. Добро пожаловать в команду IQ-Market Taxi!'
      );
    } else if (after.status === 'rejected') {
      await tgSend(chatId,
        '❌ <b>Верификация отклонена</b>\n\n'
        + `Причина: ${after.reject_reason || 'Документы не соответствуют требованиям'}\n\n`
        + 'Откройте приложение и загрузите чёткие фотографии.'
      );
    }
  }
);

// ─── SECURE SEND TELEGRAM MESSAGE ────────────────────────────────────────────
exports.secureSendTelegramMessage = functions.https.onRequest(async (req, res) => {
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

  const { chatId, text, reply_markup, parse_mode } = req.body;
  if (!chatId || !text) return res.status(400).send('Missing chatId or text');

  const targetChatStr = String(chatId);
  const adminChatStr = String(ADMIN_CHAT);
  const isTargetAdmin = (targetChatStr === adminChatStr || targetChatStr === '1910159480');

  // 🔒 X10 SECURITY: Validate that the client is not sending arbitrary messages to random chats.
  // The destination must be either the Admin Chat (for driver review / ad moderation)
  // or the sender's own Telegram chat_id registered in their profile.
  let isAllowedRecipient = false;
  if (isTargetAdmin) {
    isAllowedRecipient = true;
  } else {
    try {
      const contactSnap = await db.collection('users').doc(decodedToken.uid).collection('private').doc('contact').get();
      if (contactSnap.exists) {
        const contactData = contactSnap.data();
        const userChatId = contactData.telegram_chat_id || contactData.telegramChatId || contactData.chatId || contactData.chat_id;
        if (userChatId && String(userChatId) === targetChatStr) {
          isAllowedRecipient = true;
        }
      }
    } catch (dbError) {
      console.error('[secureSendTelegramMessage] Firestore error:', dbError);
    }
  }

  if (!isAllowedRecipient) {
    console.error(`[secureSendTelegramMessage] Security breach: User ${decodedToken.uid} tried sending to unauthorized chatId=${targetChatStr}`);
    return res.status(403).send('Forbidden: Message destination is not allowed.');
  }

  // 🔒 Check message content templates
  const isMessageAllowed = (messageText) => {
    if (isTargetAdmin) {
      return messageText.includes('Требуется ручная проверка водителя') ||
             messageText.includes('Новое объявление на модерацию') ||
             messageText.includes('Объявление АВТО-ОДОБРЕНО ИИ');
    }
    
    return messageText.includes('Ваш код подтверждения') ||
           messageText.includes('Ваш код для входа') ||
           messageText.includes('Поздравляем! Верификация пройдена') ||
           messageText.includes('Верификация отклонена') ||
           messageText.includes('успешно проверено и опубликовано') ||
           messageText.includes('отклонено модератором');
  };

  if (!isMessageAllowed(text)) {
    console.error(`[secureSendTelegramMessage] Security breach: Content is not allowed. Tried: "${text}"`);
    return res.status(403).send('Forbidden: Message content is not allowed.');
  }

  try {
    const extra    = reply_markup ? { reply_markup } : {};
    const response = await tgSend(chatId, text, extra, parse_mode || 'HTML');
    if (response && response.ok) {
      return res.status(200).json({ success: true });
    } else {
      const errText = response ? await response.text() : 'Unknown error';
      return res.status(500).json({ success: false, error: errText });
    }
  } catch (error) {
    return res.status(500).send(error.toString());
  }
});

// sendTelegramOtp удалена (2026-08-17, x10-аудит): открытый неаутентифицированный
// HTTP-эндпоинт — chat_id/code приходили от вызывающего без проверки сессии и без
// экранирования, вставлялись в HTML-текст сообщения официального бота. Единственный
// клиентский вызывающий (TelegramAuthService.sendOtp, telegram_service.dart) нигде
// не вызывался в UI — реальный вход идёт через verifyTelegramOtp ниже (сервер сам
// генерирует и проверяет код в рамках настоящей сессии). Удалён вместе с мёртвым
// клиентским классом и sendOtpUrl (cloud_function_endpoints.dart).

// ─── VERIFY TELEGRAM OTP CALLABLE ───────────────────────────────────────────
const OTP_MAX_ATTEMPTS = 5;
const OTP_TTL_MS = 5 * 60 * 1000; // совпадает с текстом "Код действителен 5 минут" в сообщении бота

exports.verifyTelegramOtp = functions.https.onCall(async (data, context) => {
  const sessionId = data.sessionId || data.sessionToken;
  const otp = data.otp;

  if (!sessionId || !otp) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing sessionId or otp');
  }

  try {
    const secureDocRef = db.collection('tg_auth_sessions_secure').doc(sessionId);

    // Транзакция: чтение + инкремент счётчика попыток (или удаление сессии)
    // атомарны, иначе параллельные запросы могли бы обойти лимит попыток
    // (check-then-act race). Бросать HttpsError ВНУТРИ transaction нельзя —
    // это отменяет уже поставленные в очередь tx.update/tx.delete, поэтому
    // здесь только возвращаем статус и решаем, что бросить, уже снаружи.
    const result = await db.runTransaction(async (tx) => {
      const secureSnap = await tx.get(secureDocRef);
      if (!secureSnap.exists) {
        return { status: 'not_found' };
      }

      const sData = secureSnap.data();
      const createdAtMs = sData.created_at ? sData.created_at.toMillis() : 0;
      if (!createdAtMs || Date.now() - createdAtMs > OTP_TTL_MS) {
        tx.delete(secureDocRef);
        return { status: 'expired' };
      }

      const attempts = sData.attempts || 0;
      if (attempts >= OTP_MAX_ATTEMPTS) {
        tx.delete(secureDocRef);
        return { status: 'locked' };
      }

      if (otp !== sData.otp) {
        tx.update(secureDocRef, { attempts: admin.firestore.FieldValue.increment(1) });
        return { status: 'wrong' };
      }

      // Single-use cleanup — атомарно с самой проверкой.
      tx.delete(secureDocRef);
      return { status: 'ok', data: sData };
    });

    if (result.status === 'not_found') {
      throw new functions.https.HttpsError('not-found', 'Сессия не найдена или срок ее действия истек.');
    }
    if (result.status === 'expired') {
      throw new functions.https.HttpsError('deadline-exceeded', 'Код истёк. Запросите новый.');
    }
    if (result.status === 'locked') {
      throw new functions.https.HttpsError('resource-exhausted', 'Слишком много неверных попыток. Запросите новый код.');
    }
    if (result.status === 'wrong') {
      throw new functions.https.HttpsError('permission-denied', 'Неверный код подтверждения.');
    }

    const secureData = result.data;
    const customToken = secureData.customToken;

    // Get public session info for chat_id or phone if needed
    const sessionRef = db.collection('tg_auth_sessions').doc(sessionId);
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Сессия верификации не найдена или устарела');
    }
    const sessionData = sessionSnap.data();

    // Check initiatorUid matching if exists
    if (sessionData.initiatorUid && context.auth && sessionData.initiatorUid !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Попытка верификации чужой сессии');
    }

    // Single-use clean up уже сделан внутри транзакции выше (атомарно с
    // проверкой otp/attempts) — здесь второй delete был бы избыточен.

    // Case 1: Authenticated user (Linking Telegram/Phone)
    if (context.auth) {
      const userUid = context.auth.uid;
      const userRef = db.collection('users').doc(userUid);

      // Защита от угона номера. Раньше эту проверку делал КЛИЕНТ
      // (`.where('verified_phone', ...)`) уже ПОСЛЕ того, как этот же вызов
      // успешно записывал verified_phone текущему пользователю — то есть
      // даже сработай она, было поздно (запись уже ушла), а сработать она
      // и не могла: allow list в 02_users.rules требует isAdmin(), обычный
      // пользователь получал permission-denied и видел невнятную ошибку
      // вместо реальной причины. Здесь, через Admin SDK, правила не мешают
      // и проверка идёт ДО записи, а не после.
      if (secureData.verified_phone) {
        const collision = await db.collection('users')
          .where('verified_phone', '==', secureData.verified_phone)
          .limit(2)
          .get();
        const takenByOther = collision.docs.some(d => d.id !== userUid);
        if (takenByOther) {
          throw new functions.https.HttpsError('already-exists', 'Этот номер уже привязан к другому аккаунту.');
        }
      }

      // verified_phone из secure-документа — номер, которым пользователь
      // поделился контактом в боте, проверенный сервером. Он приоритетнее
      // data.phone: то, что прислал клиент, клиент мог и подменить.
      const phoneToUse = (secureData.verified_phone ? '+' + secureData.verified_phone : '')
        || data.phone
        || sessionData.phone
        || '';
      const tgUsername = sessionData.telegram_username || '';
      const tgFirstName = sessionData.telegram_first_name || '';
      const tgLastName = sessionData.telegram_last_name || '';
      
      await userRef.set({
        isVerified: true,
        isTelegramVerified: true,
        // Номер, подтверждённый через контакт в Телеграме. Держится в основном
        // документе намеренно: на нём стоит защита от угона номера (запрос
        // users where verified_phone == ...) и его видит админ в карточке
        // пользователя. Правила разрешают это поле как исключение.
        ...(secureData.verified_phone ? { verified_phone: secureData.verified_phone } : {}),
        // telegramChatId НЕ пишем сюда — users/{uid} читается через
        // "allow get: if isSignedIn()" (02_users.rules), т.е. ЛЮБОЙ
        // авторизованный аккаунт может прочитать чужой telegramChatId по
        // известному uid и использовать его для фишинга. Значение уже
        // сохраняется в users/{uid}/private/contact ниже (owner+admin only) —
        // единственное защищённое место для этого поля.
        telegram_username: tgUsername,
        telegram_first_name: tgFirstName,
        telegram_last_name: tgLastName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      await userRef.collection('private').doc('contact').set({
        phone: phoneToUse,
        telegram_chat_id: sessionData.chat_id || '',
        telegramChatId: sessionData.chat_id || '',
        telegram_username: tgUsername,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      console.log(`[verifyTelegramOtp] User ${userUid} successfully verified via Telegram. TgUser=${tgUsername}`);
      return {
        success: true,
        chatId: sessionData.chat_id || '',
        telegramUsername: tgUsername,
        telegramFirstName: tgFirstName,
        telegramLastName: tgLastName,
      };
    }

    // Case 2: Guest user (Logging in via Telegram)
    //
    // Профиля ещё нет — его создаст клиент после входа по customToken, поэтому
    // номер возвращаем ему, чтобы он положил его в users/{uid}/private/contact
    // и в verified_phone. Иначе аккаунт остался бы вообще без телефона:
    // custom-token вход не приносит phoneNumber в Firebase Auth.
    return {
      success: true,
      customToken: customToken,
      verifiedPhone: secureData.verified_phone ? '+' + secureData.verified_phone : '',
      telegramUsername: sessionData.telegram_username || '',
      telegramChatId: sessionData.chat_id || '',
    };
  } catch (error) {
    console.error('[verifyTelegramOtp] Error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message || 'Ошибка верификации');
  }
});

exports.tgSend = tgSend;

