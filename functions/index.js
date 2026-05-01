/**
 * IQ-Market Telegram Bot Webhook (Firebase Cloud Function)
 *
 * SETUP:
 *  1. cd functions && npm install node-fetch@2 firebase-admin firebase-functions
 *  2. firebase functions:config:set telegram.token="YOUR_BOT_TOKEN" telegram.admin_chat="ADMIN_CHAT_ID"
 *  3. firebase deploy --only functions
 *  4. Set webhook: https://api.telegram.org/botTOKEN/setWebhook?url=YOUR_FUNCTION_URL
 */

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
const fetch     = require('node-fetch');

admin.initializeApp();
const db = admin.firestore();

const TOKEN       = functions.config().telegram?.token  || process.env.TG_TOKEN;
const ADMIN_CHAT  = functions.config().telegram?.admin_chat || '';
const API         = `https://api.telegram.org/bot${TOKEN}`;

// ─── send helper ──────────────────────────────────────────────────────────────
async function tgSend(chatId, text, extra = {}) {
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

  // /start <sessionToken>  — link chat_id to auth session
  if (text.startsWith('/start')) {
    const parts        = text.split(' ');
    const sessionToken = parts[1] || null;

    if (sessionToken && sessionToken.length > 10) {
      // Auth flow: link chat_id to Firestore session
      const ref = db.collection('tg_auth_sessions').doc(sessionToken);
      const snap = await ref.get();
      if (snap.exists) {
        const otp = String(Math.floor(100000 + Math.random() * 900000));
        await ref.update({
          chat_id : chatId,
          verified: false,
          otp,
          linked_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        await tgSend(chatId,
          `👋 *${name}, добро пожаловать в IQ\\-Market!*\n\n`
          + `🔐 Ваш код подтверждения:\n\`${otp}\`\n\n`
          + `_Введите этот код в приложении. Код действителен 5 минут._`
        );
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
