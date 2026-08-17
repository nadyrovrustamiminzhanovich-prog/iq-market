/**
 * IQ-Market — предложения цены (офферы).
 *
 * Источник истины по офферу — документ offers/{offerId}, а не поле внутри
 * сообщения чата. Причина: chatId строится по паре пользователей и никак не
 * привязан к объявлению (chats.adId хранит лишь ПОСЛЕДНИЙ обсуждавшийся товар),
 * поэтому найти конкурирующие офферы на один adId через чаты невозможно.
 *
 * offerId детерминированный: adId_buyerId. Два активных предложения одного
 * покупателя на один товар физически не могут существовать.
 *
 * Все переходы статуса выполняет сервер. Клиенту запись в offers.status
 * запрещена правилами: иначе статус подделывается с рутованного устройства,
 * а гонка двух одновременных accept решается только серверной транзакцией.
 */

const functions = require('firebase-functions/v1');
const admin     = require('firebase-admin');
const db        = admin.firestore();

const OFFER_PENDING  = 'pending';
const OFFER_ACCEPTED = 'accepted';
const OFFER_REJECTED = 'rejected';

function offerIdFor(adId, buyerId) {
  return `${adId}_${buyerId}`;
}

/**
 * Русский текст — фолбэк для пуш-уведомления и старых клиентов.
 * В ленте чата сообщение рендерится по systemKey на языке читающего,
 * поэтому текст здесь не является единственным носителем смысла.
 */
const SYSTEM_TEXT = {
  offer_accepted: 'Предложение принято! ✅',
  offer_rejected: 'Предложение отклонено ❌',
};

/**
 * Побочные эффекты одного разрешённого оффера: зеркалим статус в сообщение,
 * пишем системное сообщение, обновляем сводку чата и уведомление покупателю.
 *
 * Вызывается ТОЛЬКО после того, как транзакция реально сменила статус.
 * Ровно на этом раньше горел прод: ранний return внутри транзакции не
 * прерывал внешний код, и покупателю уходило "отклонено" по офферу,
 * который на самом деле только что был принят.
 */
async function applyOutcome({ offerId, offer, accepted }) {
  const systemKey = accepted ? 'offer_accepted' : 'offer_rejected';
  const text      = SYSTEM_TEXT[systemKey];
  const chatId    = offer.chatId;
  const now       = admin.firestore.FieldValue.serverTimestamp();

  const batch = db.batch();

  if (chatId) {
    // Зеркало статуса в исходном сообщении — карточка оффера в ленте
    // читает msg.offerStatus. Пропускаем, если сообщение удалили.
    if (offer.messageId) {
      const msgRef  = db.collection('chats').doc(chatId).collection('messages').doc(offer.messageId);
      const msgSnap = await msgRef.get();
      if (msgSnap.exists) {
        batch.update(msgRef, { offerStatus: accepted ? OFFER_ACCEPTED : OFFER_REJECTED });
      }
    }

    // Системное сообщение вместо хардкода на русском в пузыре.
    const systemRef = db.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(systemRef, {
      senderId  : offer.sellerId,
      text      : text,
      type      : 'system',
      systemKey : systemKey,
      offerPrice: offer.price || 0,
      adId      : offer.adId || '',
      adTitle   : offer.adTitle || '',
      timestamp : now,
      isRead    : false,
    });

    // Сводка чата: без lastMessageType превью в списке чатов останется
    // сырым русским текстом навсегда (см. i18n-инвариант чата).
    batch.set(db.collection('chats').doc(chatId), {
      lastMessage    : text,
      lastMessageType: 'system',
      lastSystemKey  : systemKey,
      lastOfferPrice : offer.price || 0,
      lastTimestamp  : now,
      lastSenderId   : offer.sellerId,
      isRead         : false,
      [`unreadCount_${offer.buyerId}`]: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  }

  // Уведомление покупателю — СВОЙ документ offer_<offerId>.
  // Чат-уведомления клиент upsert-ит в общий chat_<chatId>, из-за чего
  // "Предложение принято" затиралось следующим сообщением переписки.
  batch.set(db.collection('users').doc(offer.buyerId).collection('notifications').doc(`offer_${offerId}`), {
    title    : text,
    body     : `Ваше предложение по товару "${offer.adTitle || 'объявление'}"`,
    timestamp: now,
    type     : 'chat',
    isRead   : false,
    senderId : offer.sellerId,
    data     : {
      chatId  : chatId || '',
      adId    : offer.adId || '',
      adTitle : offer.adTitle || '',
      senderId: offer.sellerId,
      offerId : offerId,
    },
  });

  await batch.commit();
}

/**
 * Отклоняет остальные pending-офферы на тот же товар.
 * Запрос идёт по коллекции offers (там adId настоящий), а не по чатам.
 */
async function rejectCompetingOffers({ adId, keepOfferId, sellerId }) {
  const snap = await db.collection('offers')
    .where('adId', '==', adId)
    .where('status', '==', OFFER_PENDING)
    .get();

  let rejected = 0;

  for (const docSnap of snap.docs) {
    if (docSnap.id === keepOfferId) continue;
    const offer = docSnap.data();
    if (offer.sellerId !== sellerId) continue;

    const didReject = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(docSnap.ref);
      if (!fresh.exists || fresh.data().status !== OFFER_PENDING) return false;
      tx.update(docSnap.ref, {
        status      : OFFER_REJECTED,
        autoRejected: true,
        updatedAt   : admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (!didReject) continue;

    await applyOutcome({ offerId: docSnap.id, offer, accepted: false });
    rejected++;
  }

  return rejected;
}

/**
 * Офферы, созданные до перехода на коллекцию offers, живут только как
 * сообщение в чате. Поднимаем из сообщения полноценный документ, чтобы
 * дальше был один путь исполнения, а не два.
 */
async function migrateLegacyOffer({ chatId, messageId, uid }) {
  if (!chatId || !messageId) {
    throw new functions.https.HttpsError('invalid-argument', 'Нужен offerId либо chatId и messageId');
  }

  const msgRef  = db.collection('chats').doc(chatId).collection('messages').doc(messageId);
  const msgSnap = await msgRef.get();
  if (!msgSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Сообщение с предложением не найдено');
  }

  const msg = msgSnap.data();
  if (msg.type !== 'offer') {
    throw new functions.https.HttpsError('invalid-argument', 'Сообщение не является предложением цены');
  }

  const adId = msg.adId || '';
  if (!adId) {
    throw new functions.https.HttpsError('failed-precondition', 'У предложения нет adId — ответить нельзя');
  }

  // Продавцом можно стать только по факту владения объявлением, а не
  // потому что вызвавший так представился.
  const adSnap = await db.collection('ads').doc(adId).get();
  if (!adSnap.exists || adSnap.data().userId !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Отвечать на предложение может только владелец объявления');
  }

  const buyerId = msg.senderId;
  if (buyerId === uid) {
    throw new functions.https.HttpsError('failed-precondition', 'Нельзя отвечать на собственное предложение');
  }

  const offerId  = offerIdFor(adId, buyerId);
  const offerRef = db.collection('offers').doc(offerId);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(offerRef);
    if (existing.exists) return;
    tx.set(offerRef, {
      adId                : adId,
      adTitle             : msg.adTitle || adSnap.data().title || '',
      price               : Number(msg.offerPrice) || 0,
      sellerId            : uid,
      buyerId             : buyerId,
      chatId              : chatId,
      messageId           : messageId,
      status              : msg.offerStatus || OFFER_PENDING,
      createdAt           : msg.timestamp || admin.firestore.FieldValue.serverTimestamp(),
      updatedAt           : admin.firestore.FieldValue.serverTimestamp(),
      migratedFromMessage : true,
    });
  });

  return offerId;
}

// ─── HTTPS CALLABLE: продавец принимает или отклоняет предложение ────────────
exports.respondToOffer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Пользователь должен быть авторизован');
  }

  const uid    = context.auth.uid;
  const action = data && data.action;
  if (action !== 'accept' && action !== 'reject') {
    throw new functions.https.HttpsError('invalid-argument', 'action должен быть accept или reject');
  }
  const accepted = action === 'accept';

  const offerId = data.offerId
    ? String(data.offerId)
    : await migrateLegacyOffer({ chatId: data.chatId, messageId: data.messageId, uid });

  const offerRef = db.collection('offers').doc(offerId);

  const offer = await db.runTransaction(async (tx) => {
    const snap = await tx.get(offerRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Предложение не найдено');
    }

    const current = snap.data();
    if (current.sellerId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Отвечать на предложение может только продавец');
    }
    if (current.status !== OFFER_PENDING) {
      throw new functions.https.HttpsError('failed-precondition', 'Предложение уже обработано');
    }

    // Принять оффер на удалённое/снятое объявление раньше проходило молча —
    // покупатель получал уведомление "оффер принят" на несуществующий товар.
    // Отклонить оффер на мёртвом объявлении по-прежнему можно (это просто
    // уборка, без вводящего в заблуждение уведомления покупателю).
    if (accepted) {
      const adSnap = await tx.get(db.collection('ads').doc(current.adId));
      if (!adSnap.exists) {
        throw new functions.https.HttpsError('failed-precondition', 'Объявление удалено, оффер больше нельзя принять');
      }
      const adData = adSnap.data();
      const isActive = adData.active === undefined ? true : adData.active;
      const status = adData.status === undefined ? 'active' : adData.status;
      if (isActive !== true || status !== 'active') {
        throw new functions.https.HttpsError('failed-precondition', `Объявление не активно (статус: ${status}), оффер больше нельзя принять`);
      }
    }

    tx.update(offerRef, {
      status    : accepted ? OFFER_ACCEPTED : OFFER_REJECTED,
      updatedAt : admin.firestore.FieldValue.serverTimestamp(),
      resolvedBy: uid,
    });

    return current;
  });

  await applyOutcome({ offerId, offer, accepted });

  const rejectedCount = accepted
    ? await rejectCompetingOffers({ adId: offer.adId, keepOfferId: offerId, sellerId: uid })
    : 0;

  console.log(`[respondToOffer] ${offerId} → ${accepted ? OFFER_ACCEPTED : OFFER_REJECTED} by ${uid}, competitors rejected: ${rejectedCount}`);

  return {
    status       : accepted ? OFFER_ACCEPTED : OFFER_REJECTED,
    offerId      : offerId,
    rejectedCount: rejectedCount,
  };
});

module.exports.offerIdFor = offerIdFor;
module.exports.OFFER_PENDING = OFFER_PENDING;
module.exports.OFFER_ACCEPTED = OFFER_ACCEPTED;
module.exports.OFFER_REJECTED = OFFER_REJECTED;
