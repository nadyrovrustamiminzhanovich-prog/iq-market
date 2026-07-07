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
});


