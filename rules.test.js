const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs } = require("firebase/firestore");
const fs = require("fs");

jest.setTimeout(30000);

let testEnv;

// ──────────────────────────────────────────
// SETUP
// ──────────────────────────────────────────
beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "iq-market-3dc07",
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
}, 30000);

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// Хелпер: получить db от имени конкретного пользователя
function userDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

// Хелпер: анонимный пользователь
function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

// Хелпер: создать документ через admin (обходя правила)
async function adminSet(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

// ──────────────────────────────────────────
// ТЕСТЫ: taxi_bids
// ──────────────────────────────────────────
describe("taxi_bids", () => {
  const bidId = "bid_001";
  const senderId = "user_sender";
  const receiverId = "user_receiver";
  const strangerId = "user_stranger";

  beforeEach(async () => {
    await adminSet(`taxi_bids/${bidId}`, {
      senderId,
      receiverId,
      targetId: "ride_001",
      offeredPrice: 500,
      status: "pending",
    });
  });

  // ── READ ──
  test("sender может прочитать свою ставку", async () => {
    await assertSucceeds(getDoc(doc(userDb(senderId), "taxi_bids", bidId)));
  });

  test("receiver может прочитать ставку", async () => {
    await assertSucceeds(getDoc(doc(userDb(receiverId), "taxi_bids", bidId)));
  });

  test("посторонний НЕ может прочитать ставку", async () => {
    await assertFails(getDoc(doc(userDb(strangerId), "taxi_bids", bidId)));
  });

  test("анонимный НЕ может прочитать ставку", async () => {
    await assertFails(getDoc(doc(anonDb(), "taxi_bids", bidId)));
  });

  // ── CREATE ──
  test("sender может создать ставку с корректными полями", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(senderId), "taxi_bids", "bid_new"), {
        senderId,
        receiverId,
        targetId: "ride_002",
        offeredPrice: 300,
        status: "pending",
      })
    );
  });

  test("нельзя создать ставку от чужого имени", async () => {
    await assertFails(
      setDoc(doc(userDb(strangerId), "taxi_bids", "bid_fake"), {
        senderId, // не совпадает с auth.uid
        receiverId,
        targetId: "ride_003",
        offeredPrice: 100,
        status: "pending",
      })
    );
  });

  test("нельзя создать ставку без обязательных полей", async () => {
    await assertFails(
      setDoc(doc(userDb(senderId), "taxi_bids", "bid_incomplete"), {
        senderId,
        offeredPrice: 100,
        // нет receiverId, targetId, status
      })
    );
  });

  test("нельзя создать ставку с отрицательной ценой", async () => {
    await assertFails(
      setDoc(doc(userDb(senderId), "taxi_bids", "bid_negative"), {
        senderId,
        receiverId,
        targetId: "ride_004",
        offeredPrice: -50,
        status: "pending",
      })
    );
  });

  test("нельзя создать ставку с невалидным статусом", async () => {
    await assertFails(
      setDoc(doc(userDb(senderId), "taxi_bids", "bid_badstatus"), {
        senderId,
        receiverId,
        targetId: "ride_005",
        offeredPrice: 200,
        status: "unknown",
      })
    );
  });

  // ── UPDATE ──
  test("sender НЕ может обновить offeredPrice (защита от изменения цен)", async () => {
    await assertFails(
      updateDoc(doc(userDb(senderId), "taxi_bids", bidId), {
        offeredPrice: 600,
      })
    );
  });

  test("receiver может обновить статус", async () => {
    await assertSucceeds(
      updateDoc(doc(userDb(receiverId), "taxi_bids", bidId), {
        status: "accepted",
      })
    );
  });

  test("нельзя изменить senderId при update", async () => {
    await assertFails(
      updateDoc(doc(userDb(senderId), "taxi_bids", bidId), {
        senderId: "hacker",
      })
    );
  });

  test("нельзя изменить receiverId при update", async () => {
    await assertFails(
      updateDoc(doc(userDb(senderId), "taxi_bids", bidId), {
        receiverId: "hacker",
      })
    );
  });

  test("нельзя изменить targetId при update", async () => {
    await assertFails(
      updateDoc(doc(userDb(senderId), "taxi_bids", bidId), {
        targetId: "fake_ride",
      })
    );
  });

  test("посторонний НЕ может обновить ставку", async () => {
    await assertFails(
      updateDoc(doc(userDb(strangerId), "taxi_bids", bidId), {
        status: "accepted",
      })
    );
  });

  // ── DELETE ──
  test("никто не может удалить ставку", async () => {
    await assertFails(deleteDoc(doc(userDb(senderId), "taxi_bids", bidId)));
    await assertFails(deleteDoc(doc(userDb(receiverId), "taxi_bids", bidId)));
    await assertFails(deleteDoc(doc(userDb(strangerId), "taxi_bids", bidId)));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: users
// ──────────────────────────────────────────
describe("users", () => {
  const userId = "user_001";
  const otherId = "user_002";

  beforeEach(async () => {
    await adminSet(`users/${userId}`, {
      displayName: "Test User",
      accountType: "user",
      rating: 4.5,
      reviewsCount: 10,
      status: "active",
    });
  });

  test("любой вошедший пользователь может читать профиль пользователя", async () => {
    await assertSucceeds(getDoc(doc(userDb("any_user"), "users", userId)));
  });

  test("анонимный пользователь НЕ может читать профиль пользователя", async () => {
    await assertFails(getDoc(doc(anonDb(), "users", userId)));
  });

  test("пользователь может обновить своё имя", async () => {
    await assertSucceeds(
      updateDoc(doc(userDb(userId), "users", userId), {
        displayName: "New Name",
      })
    );
  });

  test("пользователь НЕ может изменить свой accountType", async () => {
    await assertFails(
      updateDoc(doc(userDb(userId), "users", userId), {
        accountType: "admin",
      })
    );
  });

  test("пользователь НЕ может изменить свой рейтинг", async () => {
    await assertFails(
      updateDoc(doc(userDb(userId), "users", userId), {
        rating: 5.0,
      })
    );
  });

  test("пользователь НЕ может обновить чужой профиль", async () => {
    await assertFails(
      updateDoc(doc(userDb(otherId), "users", userId), {
        displayName: "Hacked",
      })
    );
  });

  test("пользователь НЕ может сам снять себе postingRestricted", async () => {
    await assertFails(
      updateDoc(doc(userDb(userId), "users", userId), {
        postingRestricted: false,
      })
    );
  });

  test("пользователь НЕ может изменить свой duplicateStrikeCount", async () => {
    await assertFails(
      updateDoc(doc(userDb(userId), "users", userId), {
        duplicateStrikeCount: 0,
      })
    );
  });

  test("пользователь НЕ может изменить свой isVerified на true", async () => {
    await assertFails(
      updateDoc(doc(userDb(userId), "users", userId), {
        isVerified: true,
      })
    );
  });

  test("пользователь НЕ может создать документ с isVerified: true если UID не начинается с telegram_", async () => {
    await assertFails(
      setDoc(doc(userDb(userId), "users", userId), {
        uid: userId,
        displayName: "Test User",
        isVerified: true,
      })
    );
  });

  test("пользователь может создать документ с isVerified: true если UID начинается с telegram_", async () => {
    const telegramUid = "telegram_123456";
    await assertSucceeds(
      setDoc(doc(userDb(telegramUid), "users", telegramUid), {
        uid: telegramUid,
        displayName: "Telegram User",
        isVerified: true,
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: chats / messages
// ──────────────────────────────────────────
describe("chats/messages", () => {
  const chatId = "chat_001";
  const user1 = "user_alpha";
  const user2 = "user_beta";
  const outsider = "user_outsider";

  beforeEach(async () => {
    await adminSet(`chats/${chatId}`, { users: [user1, user2] });
    await adminSet(`chats/${chatId}/messages/msg_001`, {
      senderId: user1,
      text: "Привет",
      isRead: false,
    });
  });

  test("участник чата может читать сообщения", async () => {
    await assertSucceeds(
      getDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"))
    );
  });

  test("посторонний НЕ может читать сообщения", async () => {
    await assertFails(
      getDoc(doc(userDb(outsider), `chats/${chatId}/messages`, "msg_001"))
    );
  });

  test("участник может отправить сообщение от своего имени", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_new"), {
        senderId: user1,
        text: "Новое сообщение",
        isRead: false,
        type: "text",
      })
    );
  });

  test("нельзя отправить сообщение от чужого имени", async () => {
    await assertFails(
      setDoc(doc(userDb(user2), `chats/${chatId}/messages`, "msg_fake"), {
        senderId: user1, // не совпадает с auth.uid
        text: "Подделка",
        isRead: false,
        type: "text",
      })
    );
  });

  test("нельзя отправить сообщение длиннее 2000 символов", async () => {
    await assertFails(
      setDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_too_long"), {
        senderId: user1,
        text: "a".repeat(2001),
        isRead: false,
        type: "text",
      })
    );
  });

  test("сообщение ровно 2000 символов проходит", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_exactly_2000"), {
        senderId: user1,
        text: "a".repeat(2000),
        isRead: false,
        type: "text",
      })
    );
  });

  test("получатель может пометить сообщение как прочитанное", async () => {
    await assertSucceeds(
      updateDoc(
        doc(userDb(user2), `chats/${chatId}/messages`, "msg_001"),
        { isRead: true }
      )
    );
  });

  test("получатель НЕ может изменить текст сообщения", async () => {
    await assertFails(
      updateDoc(
        doc(userDb(user2), `chats/${chatId}/messages`, "msg_001"),
        { text: "Изменено" }
      )
    );
  });

  test("отправитель может удалить своё сообщение", async () => {
    await assertSucceeds(
      deleteDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"))
    );
  });

  test("посторонний НЕ может удалить сообщение", async () => {
    await assertFails(
      deleteDoc(doc(userDb(outsider), `chats/${chatId}/messages`, "msg_001"))
    );
  });

  test("Сценарий А: посторонний НЕ может прочитать сам документ чата", async () => {
    await assertFails(getDoc(doc(userDb(outsider), "chats", chatId)));
  });

  test("Сценарий Б: участник может прочитать документ чата", async () => {
    await assertSucceeds(getDoc(doc(userDb(user1), "chats", chatId)));
  });

  test("Сценарий В: попытка чтения несуществующего chatId завершается Permission Denied", async () => {
    await assertFails(getDoc(doc(userDb(user1), "chats", "non_existent_chat")));
  });

  test("Сценарий В: попытка чтения сообщений несуществующего chatId завершается Permission Denied", async () => {
    await assertFails(getDoc(doc(userDb(user1), `chats/non_existent_chat/messages`, "msg_any")));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: driver_verifications
// ──────────────────────────────────────────
describe("driver_verifications", () => {
  const driverId = "driver_001";
  const otherId = "user_other";
  const docId = "verif_001";

  beforeEach(async () => {
    await adminSet(`driver_verifications/${docId}`, {
      userId: driverId,
      status: "pending",
    });
  });

  test("владелец может читать свою верификацию", async () => {
    await assertSucceeds(
      getDoc(doc(userDb(driverId), "driver_verifications", docId))
    );
  });

  test("посторонний НЕ может читать верификацию", async () => {
    await assertFails(
      getDoc(doc(userDb(otherId), "driver_verifications", docId))
    );
  });

  test("водитель может создать верификацию", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(driverId), "driver_verifications", "verif_new"), {
        userId: driverId,
        status: "pending",
      })
    );
  });

  test("никто не может обновить верификацию", async () => {
    await assertFails(
      updateDoc(doc(userDb(driverId), "driver_verifications", docId), {
        status: "approved",
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: app_config
// ──────────────────────────────────────────
describe("app_config", () => {
  const docId = "version_info";
  const userId = "user_001";
  const adminId = "admin_001";

  beforeEach(async () => {
    // Создаем пользователя admin с accountType: admin
    await adminSet("users/admin_001", {
      accountType: "admin"
    });
    // И обычного пользователя
    await adminSet("users/user_001", {
      accountType: "user"
    });
    // Создаем тестовый конфиг
    await adminSet(`app_config/${docId}`, {
      min_version_code: "2",
      store_url: "https://play.google.com/store/apps/details?id=com.iqmarket.app"
    });
  });

  test("анонимный пользователь может читать конфиг версий", async () => {
    await assertSucceeds(
      getDoc(doc(anonDb(), "app_config", docId))
    );
  });

  test("обычный пользователь может читать конфиг версий", async () => {
    await assertSucceeds(
      getDoc(doc(userDb(userId), "app_config", docId))
    );
  });

  test("обычный пользователь НЕ может изменять конфиг версий", async () => {
    await assertFails(
      setDoc(doc(userDb(userId), "app_config", docId), {
        min_version_code: "3"
      })
    );
  });

  test("администратор может изменять конфиг версий", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(adminId), "app_config", docId), {
        min_version_code: "3",
        store_url: "https://play.google.com/store/apps/details?id=com.iqmarket.app"
      })
    );
  });

  test("пользователь без документа в /users/ НЕ приводит к падению isAdmin() и возвращает false (доступ запрещен)", async () => {
    await assertFails(
      setDoc(doc(userDb("non_existent_user_doc"), "app_config", docId), {
        min_version_code: "3"
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: fingerprints (text and image)
// ──────────────────────────────────────────
describe("fingerprints (text and image)", () => {
  const textHash = "test_text_hash_123";
  const imageHash = "test_image_hash_456";
  const userId = "user_test";

  test("обычный пользователь НЕ может прочитать textFingerprints", async () => {
    await assertFails(getDoc(doc(userDb(userId), "textFingerprints", textHash)));
  });

  test("обычный пользователь НЕ может записать в textFingerprints", async () => {
    await assertFails(
      setDoc(doc(userDb(userId), "textFingerprints", textHash), {
        adId: "ad_123",
        userId: userId,
        createdAt: new Date(),
      })
    );
  });

  test("обычный пользователь НЕ может прочитать imageFingerprints", async () => {
    await assertFails(getDoc(doc(userDb(userId), "imageFingerprints", imageHash)));
  });

  test("обычный пользователь НЕ может записать в imageFingerprints", async () => {
    await assertFails(
      setDoc(doc(userDb(userId), "imageFingerprints", imageHash), {
        adId: "ad_123",
        userId: userId,
        createdAt: new Date(),
      })
    );
  });

  test("анонимный пользователь НЕ может прочитать textFingerprints", async () => {
    await assertFails(getDoc(doc(anonDb(), "textFingerprints", textHash)));
  });

  test("анонимный пользователь НЕ может записать в textFingerprints", async () => {
    await assertFails(
      setDoc(doc(anonDb(), "textFingerprints", textHash), {
        adId: "ad_123",
        userId: "some_user",
        createdAt: new Date(),
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: userInstallLinks (мульти-аккаунт эвристика)
// ──────────────────────────────────────────
describe("userInstallLinks", () => {
  const userId = "user_test";
  const linkId = "user_test_install-abc-123";

  test("обычный пользователь НЕ может прочитать userInstallLinks", async () => {
    await assertFails(getDoc(doc(userDb(userId), "userInstallLinks", linkId)));
  });

  test("обычный пользователь НЕ может записать в userInstallLinks", async () => {
    await assertFails(
      setDoc(doc(userDb(userId), "userInstallLinks", linkId), {
        userId: userId,
        installId: "install-abc-123",
        lastSeenAt: new Date(),
        adCount: 1,
      })
    );
  });

  test("анонимный пользователь НЕ может прочитать userInstallLinks", async () => {
    await assertFails(getDoc(doc(anonDb(), "userInstallLinks", linkId)));
  });
});

// ──────────────────────────────────────────
// НОВЫЕ ТЕСТЫ ДЛЯ ЗАДАЧ 2 И 3
// ──────────────────────────────────────────
describe("notifications schema", () => {
  const buyerId = "buyer_001";
  const sellerId = "seller_001";
  const notifId = "chat_chat_001";

  beforeEach(async () => {
    await adminSet("chats/chat_001", {
      users: [buyerId, sellerId]
    });
  });

  test("создание уведомления по старому формату (без senderId на верхнем уровне) отклоняется", async () => {
    await assertFails(
      setDoc(doc(userDb(buyerId), `users/${sellerId}/notifications`, notifId), {
        title: "Тест",
        body: "Тест тела",
        type: "chat",
        timestamp: new Date(),
        data: {
          chatId: "chat_001",
          senderId: buyerId
        }
      })
    );
  });

  test("создание уведомления по новому формату (с senderId на верхнем уровне) разрешается", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), `users/${sellerId}/notifications`, notifId), {
        title: "Тест",
        body: "Тест тела",
        type: "chat",
        timestamp: new Date(),
        senderId: buyerId,
        data: {
          chatId: "chat_001",
          senderId: buyerId
        }
      })
    );
  });
});

describe("chats users order comparison", () => {
  const buyerId = "buyer_123";
  const sellerId = "seller_456";
  const chatId = "buyer_123_seller_456";

  test("покупатель создает чат с порядком [buyer, seller], затем продавец отвечает/обновляет с порядком [seller, buyer], затем покупатель предлагает цену с порядком [buyer, seller] - все должно пройти", async () => {
    // 1. Покупатель создает чат с users: [buyer, seller]
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), "chats", chatId), {
        users: [buyerId, sellerId],
        lastMessage: "Привет",
        lastTimestamp: new Date(),
        lastSenderId: buyerId
      })
    );

    // 2. Продавец отвечает (обновляет чат с users в другом порядке [seller, buyer])
    await assertSucceeds(
      setDoc(doc(userDb(sellerId), "chats", chatId), {
        users: [sellerId, buyerId],
        lastMessage: "Привет покупатель",
        lastTimestamp: new Date(),
        lastSenderId: sellerId
      }, { merge: true })
    );

    // 3. Покупатель предлагает цену (обновляет чат с users в порядке [buyer, seller])
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), "chats", chatId), {
        users: [buyerId, sellerId],
        lastMessage: "Предложение цены: 1000",
        lastTimestamp: new Date(),
        lastSenderId: buyerId
      }, { merge: true })
    );
  });

  test("продавец НЕ может выставить offerStatus напрямую — accept/reject только через Cloud Function respondToOffer", async () => {
    // 1. Покупатель создает чат с users: [buyer, seller]
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), "chats", chatId), {
        users: [buyerId, sellerId],
        lastMessage: "Предложение",
        lastTimestamp: new Date(),
        lastSenderId: buyerId
      })
    );

    // 2. Создаем сообщение-предложение от покупателя
    await adminSet(`chats/${chatId}/messages/offer_001`, {
      senderId: buyerId,
      text: "Предложение цены: 500",
      type: "offer",
      offerPrice: 500,
      offerStatus: "pending",
      timestamp: new Date(),
      isRead: false,
    });

    // 3. Продавец обновляет чат, меняя порядок users на [seller, buyer]
    await assertSucceeds(
      setDoc(doc(userDb(sellerId), "chats", chatId), {
        users: [sellerId, buyerId],
      }, { merge: true })
    );

    // 4. Продавец пытается принять предложение записью с клиента.
    //    Раньше это разрешалось правилом — статус можно было подделать в обход
    //    сервера, а гонка двух одновременных accept оставалась без арбитра.
    //    Теперь единственный легальный путь — callable respondToOffer.
    await assertFails(
      updateDoc(doc(userDb(sellerId), `chats/${chatId}/messages`, "offer_001"), {
        offerStatus: "accepted",
      })
    );
  });

  test("покупатель может отменить свое предложение цены, даже если порядок участников users в чате изменился", async () => {
    // 1. Покупатель создает чат с users: [buyer, seller]
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), "chats", chatId), {
        users: [buyerId, sellerId],
        lastMessage: "Предложение",
        lastTimestamp: new Date(),
        lastSenderId: buyerId
      })
    );

    // 2. Создаем сообщение-предложение от покупателя (pending)
    await adminSet(`chats/${chatId}/messages/offer_002`, {
      senderId: buyerId,
      text: "Предложение цены: 700",
      type: "offer",
      offerPrice: 700,
      offerStatus: "pending",
      timestamp: new Date(),
      isRead: false,
    });

    // 3. Продавец обновляет чат, меняя порядок users на [seller, buyer]
    await assertSucceeds(
      setDoc(doc(userDb(sellerId), "chats", chatId), {
        users: [sellerId, buyerId],
      }, { merge: true })
    );

    // 4. Покупатель (отправитель оффера) отменяет предложение — должно пройти успешно
    await assertSucceeds(
      updateDoc(doc(userDb(buyerId), `chats/${chatId}/messages`, "offer_002"), {
        offerStatus: "cancelled",
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: offers (предложения цены)
// Статус оффера меняет ТОЛЬКО Cloud Function respondToOffer — правила
// обязаны запрещать клиенту любые переходы в accepted/rejected.
// ──────────────────────────────────────────
describe("offers", () => {
  const buyerId = "offer_buyer_1";
  const sellerId = "offer_seller_1";
  const strangerId = "offer_stranger_1";
  const adId = "ad_offer_1";
  const chatId = "offer_buyer_1_offer_seller_1";
  const offerId = `${adId}_${buyerId}`;

  const validOffer = {
    adId,
    adTitle: "Диван",
    price: 80000,
    sellerId,
    buyerId,
    chatId,
    messageId: "msg_1",
    status: "pending",
  };

  beforeEach(async () => {
    await adminSet(`ads/${adId}`, {
      userId: sellerId,
      title: "Диван",
      price: 100000,
      status: "active",
      active: true,
    });
  });

  test("покупатель создаёт предложение с детерминированным id", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), "offers", offerId), validOffer)
    );
  });

  test("id обязан быть adId_buyerId — произвольный id отклоняется", async () => {
    await assertFails(
      setDoc(doc(userDb(buyerId), "offers", "random_id"), validOffer)
    );
  });

  test("нельзя создать предложение от чужого имени", async () => {
    await assertFails(
      setDoc(doc(userDb(strangerId), "offers", `${adId}_${strangerId}`), validOffer)
    );
  });

  test("цена ниже 70% от цены объявления отклоняется", async () => {
    await assertFails(
      setDoc(doc(userDb(buyerId), "offers", offerId), { ...validOffer, price: 50000 })
    );
  });

  test("продавец не может торговаться сам с собой", async () => {
    await assertFails(
      setDoc(doc(userDb(sellerId), "offers", `${adId}_${sellerId}`), {
        ...validOffer,
        buyerId: sellerId,
      })
    );
  });

  test("ПРОДАВЕЦ НЕ МОЖЕТ выставить status accepted — только respondToOffer", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertFails(
      updateDoc(doc(userDb(sellerId), "offers", offerId), { status: "accepted" })
    );
  });

  test("ПОКУПАТЕЛЬ НЕ МОЖЕТ принять предложение сам себе", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertFails(
      updateDoc(doc(userDb(buyerId), "offers", offerId), { status: "accepted" })
    );
  });

  test("покупатель может отозвать своё активное предложение", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertSucceeds(
      updateDoc(doc(userDb(buyerId), "offers", offerId), { status: "cancelled" })
    );
  });

  test("покупатель может перебить свою цену новым предложением", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), "offers", offerId), { ...validOffer, price: 95000 })
    );
  });

  test("после отказа покупатель может предложить снова", async () => {
    await adminSet(`offers/${offerId}`, { ...validOffer, status: "rejected" });
    await assertSucceeds(
      setDoc(doc(userDb(buyerId), "offers", offerId), { ...validOffer, price: 90000 })
    );
  });

  test("посторонний не видит чужое предложение", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertFails(getDoc(doc(userDb(strangerId), "offers", offerId)));
  });

  test("участники сделки видят предложение", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertSucceeds(getDoc(doc(userDb(buyerId), "offers", offerId)));
    await assertSucceeds(getDoc(doc(userDb(sellerId), "offers", offerId)));
  });

  test("клиент не может подделать системное сообщение об исходе оффера", async () => {
    await adminSet(`chats/${chatId}`, { users: [buyerId, sellerId] });
    await assertFails(
      setDoc(doc(userDb(buyerId), `chats/${chatId}/messages`, "fake_system"), {
        senderId: buyerId,
        text: "Предложение принято! ✅",
        type: "system",
        systemKey: "offer_accepted",
        timestamp: new Date(),
        isRead: false,
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: ads stats and viewLogs
// ──────────────────────────────────────────
describe("ads stats and viewLogs", () => {
  const adId = "ad_test_001";
  const userId = "user_001";
  const adminId = "admin_001";

  beforeEach(async () => {
    // 1. Создаем объявление через admin
    await adminSet(`ads/${adId}`, {
      title: "Test Ad",
      price: 100,
      userId: "seller_123",
      timestamp: new Date()
    });

    // 2. Создаем пользователя admin с accountType: admin
    await adminSet("users/admin_001", {
      accountType: "admin"
    });

    // 3. Создаем обычного пользователя
    await adminSet("users/user_001", {
      accountType: "user"
    });
  });

  test("обычный авторизованный пользователь НЕ может прочитать ads/adId/stats/counters", async () => {
    await assertFails(getDoc(doc(userDb(userId), `ads/${adId}/stats/counters`)));
  });

  test("пользователь с ролью admin МОЖЕТ прочитать ads/adId/stats/counters", async () => {
    await assertSucceeds(getDoc(doc(userDb(adminId), `ads/${adId}/stats/counters`)));
  });

  test("никто кроме серверного admin SDK не может писать в counters напрямую с клиента", async () => {
    await assertFails(
      setDoc(doc(userDb(adminId), `ads/${adId}/stats/counters`), {
        viewsCount: 10
      })
    );
    await assertFails(
      setDoc(doc(userDb(userId), `ads/${adId}/stats/counters`), {
        viewsCount: 10
      })
    );
  });

  test("никто не может читать или писать в viewLogs с клиента", async () => {
    await assertFails(getDoc(doc(userDb(userId), "viewLogs", `${userId}_${adId}`)));
    await assertFails(
      setDoc(doc(userDb(userId), "viewLogs", `${userId}_${adId}`), {
        lastViewedAt: new Date()
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: забаненный пользователь (users/{uid}.status == 'banned')
// не может создавать новый контент — объявления/чаты/сообщения/отзывы
// ──────────────────────────────────────────
describe("banned users are blocked from creating new content", () => {
  const bannedUid = "user_banned";
  const activeUid = "user_active";
  const otherUid = "user_other";
  const sellerUid = "user_seller_for_review";
  const adId = "ad_for_banned_test";
  const chatId = [bannedUid, otherUid].sort().join("_");
  const activeChatId = [activeUid, otherUid].sort().join("_");

  beforeEach(async () => {
    await adminSet(`users/${bannedUid}`, { status: "banned" });
    await adminSet(`users/${activeUid}`, { status: "active" });
    await adminSet(`users/${otherUid}`, { status: "active" });
    await adminSet(`ads/${adId}`, {
      title: "Test Ad",
      price: 1000,
      userId: sellerUid,
      status: "active",
      timestamp: new Date(),
    });
    await adminSet(`chats/${chatId}`, { users: [bannedUid, otherUid].sort() });
    await adminSet(`chats/${activeChatId}`, { users: [activeUid, otherUid].sort() });
  });

  test("забаненный пользователь НЕ может создать объявление", async () => {
    await assertFails(
      setDoc(doc(userDb(bannedUid), "ads", "ad_new_by_banned"), {
        title: "Spam",
        userId: bannedUid,
        price: 100,
        timestamp: new Date(),
      })
    );
  });

  test("обычный пользователь МОЖЕТ создать объявление (не сломали основной путь)", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(activeUid), "ads", "ad_new_by_active"), {
        title: "Normal ad",
        userId: activeUid,
        price: 100,
        timestamp: new Date(),
      })
    );
  });

  test("забаненный пользователь НЕ может оставить отзыв", async () => {
    await assertFails(
      setDoc(doc(userDb(bannedUid), "reviews", "review_by_banned"), {
        fromUserId: bannedUid,
        toUserId: sellerUid,
        rating: 5,
      })
    );
  });

  test("обычный пользователь МОЖЕТ оставить отзыв (не сломали основной путь)", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(activeUid), "reviews", "review_by_active"), {
        fromUserId: activeUid,
        toUserId: sellerUid,
        rating: 5,
      })
    );
  });

  test("забаненный пользователь НЕ может создать новый чат", async () => {
    await assertFails(
      setDoc(doc(userDb(bannedUid), "chats", [bannedUid, "user_fresh"].sort().join("_")), {
        users: [bannedUid, "user_fresh"].sort(),
      })
    );
  });

  test("обычный пользователь МОЖЕТ создать новый чат (не сломали основной путь)", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(activeUid), "chats", [activeUid, "user_fresh2"].sort().join("_")), {
        users: [activeUid, "user_fresh2"].sort(),
      })
    );
  });

  test("забаненный пользователь НЕ может отправить сообщение в уже существующий чат", async () => {
    await assertFails(
      setDoc(doc(userDb(bannedUid), `chats/${chatId}/messages`, "msg_by_banned"), {
        senderId: bannedUid,
        text: "Привет",
        type: "text",
        isRead: false,
      })
    );
  });

  test("обычный пользователь МОЖЕТ отправить сообщение (не сломали основной путь offer/chat)", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(activeUid), `chats/${activeChatId}/messages`, "msg_by_active"), {
        senderId: activeUid,
        text: "Привет",
        type: "text",
        isRead: false,
      })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: личная блокировка (users/{uid}.blockedUserIds) —
// заблокированный не может писать тому, кто его заблокировал
// ──────────────────────────────────────────
describe("personal block (blockedUserIds) prevents contact from the blocked side", () => {
  const blockerUid = "user_blocker";
  const blockedUid = "user_blocked_by_other";
  const strangerUid = "user_stranger";
  const existingChatId = [blockerUid, blockedUid].sort().join("_");

  beforeEach(async () => {
    // blockerUid заблокировал blockedUid
    await adminSet(`users/${blockerUid}`, { status: "active", blockedUserIds: [blockedUid] });
    await adminSet(`users/${blockedUid}`, { status: "active" });
    await adminSet(`users/${strangerUid}`, { status: "active" });
    await adminSet(`chats/${existingChatId}`, { users: [blockerUid, blockedUid].sort() });
  });

  test("заблокированный НЕ может начать новый чат с тем, кто его заблокировал", async () => {
    await assertFails(
      setDoc(doc(userDb(blockedUid), "chats", existingChatId + "_new_attempt"), {
        users: [blockerUid, blockedUid].sort(),
      })
    );
  });

  test("заблокированный НЕ может отправить сообщение в уже существующий чат с блокировщиком", async () => {
    await assertFails(
      setDoc(doc(userDb(blockedUid), `chats/${existingChatId}/messages`, "msg_from_blocked"), {
        senderId: blockedUid,
        text: "Разблокируй меня",
        type: "text",
        isRead: false,
      })
    );
  });

  test("блокировщик по-прежнему МОЖЕТ писать в чат (блок не бьёт по нему самому)", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(blockerUid), `chats/${existingChatId}/messages`, "msg_from_blocker"), {
        senderId: blockerUid,
        text: "Сообщение от блокировщика",
        type: "text",
        isRead: false,
      })
    );
  });

  test("посторонний (никого не блокировавший) может нормально писать в свой чат", async () => {
    const strangerChatId = [strangerUid, blockerUid].sort().join("_");
    await adminSet(`chats/${strangerChatId}`, { users: [strangerUid, blockerUid].sort() });
    await assertSucceeds(
      setDoc(doc(userDb(strangerUid), `chats/${strangerChatId}/messages`, "msg_from_stranger"), {
        senderId: strangerUid,
        text: "Привет",
        type: "text",
        isRead: false,
      })
    );
  });
});


