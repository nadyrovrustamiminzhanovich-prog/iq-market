const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, arrayUnion, increment } = require("firebase/firestore");
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
// ТЕСТЫ: taxi_rides / taxi_orders — модуль закрыт для всех кроме админа.
// Раньше read:true отдавал настоящие телефон/имя/фото/маршрут пассажира и
// водителя без входа в аккаунт вообще, а create:isSignedIn() (без isAdmin())
// пускал любого обычного юзера маркетплейса писать заказы в обход заглушки
// "Скоро запуск" напрямую через SDK.
// ──────────────────────────────────────────
describe("taxi_rides / taxi_orders — только админ", () => {
  const rideId = "ride_001";
  const orderId = "order_001";
  const adminId = "taxi_admin_001";
  const driverId = "taxi_driver_001";
  const passengerId = "taxi_passenger_001";
  const strangerId = "taxi_stranger_001";

  beforeEach(async () => {
    await adminSet(`users/${adminId}`, { accountType: "admin" });
    await adminSet(`taxi_rides/${rideId}`, {
      driverId,
      from: "A",
      to: "B",
      status: "active",
      price: 1000,
      createdAt: new Date(),
      driverPhone: "+77001234567",
      driverName: "Тестовый водитель",
    });
    await adminSet(`taxi_orders/${orderId}`, {
      passengerId,
      from: "A",
      to: "B",
      status: "active",
      price: 1000,
      createdAt: new Date(),
      passengerPhone: "+77007654321",
      passengerName: "Тестовый пассажир",
    });
  });

  test("анонимный НЕ может прочитать ride/order (была публичная утечка телефона/маршрута)", async () => {
    await assertFails(getDoc(doc(anonDb(), "taxi_rides", rideId)));
    await assertFails(getDoc(doc(anonDb(), "taxi_orders", orderId)));
  });

  test("обычный залогиненный (не админ) НЕ может прочитать ride/order", async () => {
    await assertFails(getDoc(doc(userDb(strangerId), "taxi_rides", rideId)));
    await assertFails(getDoc(doc(userDb(strangerId), "taxi_orders", orderId)));
  });

  test("админ может прочитать ride/order", async () => {
    await assertSucceeds(getDoc(doc(userDb(adminId), "taxi_rides", rideId)));
    await assertSucceeds(getDoc(doc(userDb(adminId), "taxi_orders", orderId)));
  });

  test("обычный залогиненный (не админ) НЕ может создать ride/order в обход заглушки", async () => {
    await assertFails(
      setDoc(doc(userDb(driverId), "taxi_rides", "ride_bypass"), {
        driverId,
        from: "A",
        to: "B",
        status: "active",
        price: 500,
        createdAt: new Date(),
      })
    );
    await assertFails(
      setDoc(doc(userDb(passengerId), "taxi_orders", "order_bypass"), {
        passengerId,
        from: "A",
        to: "B",
        status: "active",
        price: 500,
        createdAt: new Date(),
      })
    );
  });

  test("админ может создать ride/order сам за себя", async () => {
    await assertSucceeds(
      setDoc(doc(userDb(adminId), "taxi_rides", "ride_admin_new"), {
        driverId: adminId,
        from: "A",
        to: "B",
        status: "active",
        price: 500,
        createdAt: new Date(),
      })
    );
    await assertSucceeds(
      setDoc(doc(userDb(adminId), "taxi_orders", "order_admin_new"), {
        passengerId: adminId,
        from: "A",
        to: "B",
        status: "active",
        price: 500,
        createdAt: new Date(),
      })
    );
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

  // Без этих проверок модифицированный клиент мог родить новый аккаунт сразу
  // с накрученной репутацией (rating/reviewsCount на create не проверялись).
  test("создание аккаунта со стартовым рейтингом 5.0/0 отзывов — разрешено", async () => {
    await assertSucceeds(
      setDoc(doc(userDb("user_new_signup"), "users", "user_new_signup"), {
        uid: "user_new_signup",
        name: "New User",
        accountType: "user",
        status: "active",
        reviewsCount: 0,
        rating: 5.0,
      })
    );
  });

  test("создание аккаунта с накрученным рейтингом — запрещено", async () => {
    await assertFails(
      setDoc(doc(userDb("user_faker"), "users", "user_faker"), {
        uid: "user_faker",
        name: "Faker",
        accountType: "user",
        status: "active",
        reviewsCount: 500,
        rating: 4.9,
      })
    );
  });

  test("создание аккаунта вообще без rating/reviewsCount — разрешено", async () => {
    await assertSucceeds(
      setDoc(doc(userDb("user_minimal"), "users", "user_minimal"), {
        uid: "user_minimal",
        name: "Minimal User",
        status: "active",
      })
    );
  });

  // ── Где физически живёт телефон ──────────────────────────────────────────
  // Контактные поля закрыты для основного документа и лежат в
  // users/{uid}/private/contact. Пока этого теста не было, экран «Личные
  // данные» писал телефон в private/contact, а читал из основного документа —
  // и номер после перезахода всегда оказывался пустым.
  describe("контактные поля (phone/email)", () => {
    test("владелец НЕ может записать phone в основной документ", async () => {
      await assertFails(
        updateDoc(doc(userDb(userId), "users", userId), {
          phone: "+77001234567",
        })
      );
    });

    test("владелец НЕ может записать email в основной документ", async () => {
      await assertFails(
        updateDoc(doc(userDb(userId), "users", userId), {
          email: "a@b.c",
        })
      );
    });

    test("документ с уже существующим phone нельзя обновить даже не трогая phone", async () => {
      // request.resource.data для update — это ВЕСЬ итоговый документ, поэтому
      // hasAny(['phone']) срабатывает на unchanged-поле. Если phone когда-то
      // просочился в основной документ, профиль становится нередактируемым.
      await adminSet(`users/${userId}`, {
        displayName: "Test User",
        accountType: "user",
        rating: 4.5,
        reviewsCount: 10,
        status: "active",
        phone: "+77001234567",
      });
      await assertFails(
        updateDoc(doc(userDb(userId), "users", userId), {
          displayName: "New Name",
        })
      );
    });

    test("владелец МОЖЕТ писать телефон в private/contact", async () => {
      await assertSucceeds(
        setDoc(doc(userDb(userId), `users/${userId}/private`, "contact"), {
          phone: "+77001234567",
          email: "a@b.c",
        })
      );
    });

    test("владелец может читать свой private/contact", async () => {
      await adminSet(`users/${userId}/private/contact`, { phone: "+77001234567" });
      await assertSucceeds(
        getDoc(doc(userDb(userId), `users/${userId}/private`, "contact"))
      );
    });

    test("посторонний НЕ может читать чужой private/contact", async () => {
      await adminSet(`users/${userId}/private/contact`, { phone: "+77001234567" });
      await assertFails(
        getDoc(doc(userDb(otherId), `users/${userId}/private`, "contact"))
      );
    });

    test("владелец-НЕ-telegram_* НЕ может сам записать verified_phone", async () => {
      // ДО фикса 2026-08-15 это ПРОХОДИЛО — verified_phone вообще не был в
      // списке защищённых полей 02_users.rules. Ровно уязвимость из аудита:
      // любой авторизованный (в т.ч. обычный email/Google) аккаунт мог
      // подставить себе чужой реальный номер телефона, который потом виден
      // в контактах объявления — вектор докса.
      await assertFails(
        updateDoc(doc(userDb(userId), "users", userId), {
          verified_phone: "77001234567",
        })
      );
    });

    test("владелец-НЕ-telegram_* НЕ может сам выставить isTelegramVerified", async () => {
      // Та же уязвимость с другой стороны: обход OTP-верификации водителя
      // такси без единого реального сообщения боту.
      await assertFails(
        updateDoc(doc(userDb(userId), "users", userId), {
          isTelegramVerified: true,
        })
      );
    });

    test("telegram_*-аккаунт МОЖЕТ обновить себе verified_phone/isTelegramVerified", async () => {
      // Единственный легитимный путь на этот код: UserService.
      // markPhoneVerifiedViaTelegram сразу после входа через Телеграм
      // (login_screen.dart _finalizeLogin) — единственный случай, когда
      // сервер сам НЕ пишет эти поля (аккаунта ещё не было в момент вызова
      // verifyTelegramOtp, писать было некуда). uid вида telegram_* подделать
      // нельзя — его минтит только доверенная Cloud Function verifyTelegramOtp
      // после реальной проверки OTP в боте.
      const telegramUid = "telegram_789";
      await adminSet(`users/${telegramUid}`, {
        displayName: "Telegram User",
        accountType: "user",
        rating: 5.0,
        reviewsCount: 0,
        status: "active",
      });
      await assertSucceeds(
        updateDoc(doc(userDb(telegramUid), "users", telegramUid), {
          verified_phone: "77001234567",
          isTelegramVerified: true,
        })
      );
    });

    test("владелец НЕ может сам выставить себе isVerified", async () => {
      await assertFails(
        updateDoc(doc(userDb(userId), "users", userId), {
          isVerified: true,
        })
      );
    });

    // Ровно та полезная нагрузка, которую telegram_verification_dialog писал
    // ДО фикса 2026-08-15. Правила её отклоняют целиком — из-за 'phone' и
    // 'isVerified' (как и раньше), а теперь дополнительно ещё и из-за
    // verified_phone/isTelegramVerified для не-telegram_*-аккаунта. После
    // фикса клиент эти 2 поля в этой связке больше не отправляет вообще (см.
    // telegram_verification_dialog.dart) — сервер (verifyTelegramOtp) уже
    // проставил их сам через Admin SDK для уже авторизованного пользователя.
    test("полная нагрузка телеграм-верификации с клиента отклоняется", async () => {
      await assertFails(
        setDoc(
          doc(userDb(userId), "users", userId),
          {
            verified_phone: "77001234567",
            phone: "+7 (700) 123-45-67",
            isVerified: true,
            isTelegramVerified: true,
            telegramChatId: "12345",
          },
          { merge: true }
        )
      );
    });

    test("telegramChatId в основном документе тоже запрещён", async () => {
      // Его пишет только сервер через Admin SDK (verifyTelegramOtp), правила
      // Admin SDK не проверяют. С клиента — отказ.
      await assertFails(
        updateDoc(doc(userDb(userId), "users", userId), {
          telegramChatId: "12345",
        })
      );
    });

    test("та же нагрузка для НЕ-telegram_* аккаунта отклоняется", async () => {
      // ДО фикса 2026-08-15 это было ровно то состояние уязвимости: ни
      // verified_phone, ни isTelegramVerified не входили в защищённый список,
      // поэтому запись без 'phone'/'isVerified'/'telegramChatId' проходила
      // целиком. Теперь оба поля защищены отдельно (см. тесты выше) — запись
      // отклоняется целиком, как и остальные защищённые поля.
      await assertFails(
        setDoc(
          doc(userDb(userId), "users", userId),
          {
            verified_phone: "77001234567",
            isTelegramVerified: true,
          },
          { merge: true }
        )
      );
    });

    test("владелец-НЕ-telegram_* НЕ может создать документ с isTelegramVerified/verified_phone", async () => {
      // Симметрично isVerified-тестам ниже: новый аккаунт не должен уметь
      // родиться сразу "телеграм-подтверждённым" с произвольным номером.
      await assertFails(
        setDoc(doc(userDb("user_003"), "users", "user_003"), {
          uid: "user_003",
          displayName: "New User",
          isTelegramVerified: true,
          verified_phone: "77009998877",
        })
      );
    });
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

  // ── Галочки доставки/прочтения ставит ТОЛЬКО получатель ──────────────────
  // Прод-баг: отправитель видел 2 синие галочки сразу после отправки, хотя
  // собеседник не открывал приложение. Клиент помечал сообщение прочитанным
  // сам себе (обработчик чужого FCM-пуша, прилетевшего на это устройство),
  // а правила это разрешали через ветку «автор правит своё сообщение».
  test("отправитель НЕ может пометить своё сообщение прочитанным", async () => {
    await assertFails(
      updateDoc(
        doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"),
        { isRead: true }
      )
    );
  });

  test("отправитель НЕ может пометить своё сообщение доставленным", async () => {
    await assertFails(
      updateDoc(
        doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"),
        { isDelivered: true }
      )
    );
  });

  test("отправитель НЕ может протащить isRead вместе с легальной правкой mediaUrl", async () => {
    await assertFails(
      updateDoc(
        doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"),
        { mediaUrl: "https://example.com/photo.jpg", isRead: true }
      )
    );
  });

  test("отправитель по-прежнему МОЖЕТ дописать mediaUrl после загрузки", async () => {
    await assertSucceeds(
      updateDoc(
        doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"),
        { mediaUrl: "https://example.com/photo.jpg", uploadFailed: false }
      )
    );
  });

  test("получатель МОЖЕТ пометить сообщение доставленным и прочитанным разом", async () => {
    await assertSucceeds(
      updateDoc(
        doc(userDb(user2), `chats/${chatId}/messages`, "msg_001"),
        { isRead: true, isDelivered: true, readAt: new Date() }
      )
    );
  });

  test("отправитель может удалить своё сообщение", async () => {
    await assertSucceeds(
      deleteDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"))
    );
  });

  test("получатель НЕ может удалить сообщение отправителя", async () => {
    await assertFails(
      deleteDoc(doc(userDb(user2), `chats/${chatId}/messages`, "msg_001"))
    );
  });

  test("посторонний НЕ может удалить сообщение", async () => {
    await assertFails(
      deleteDoc(doc(userDb(outsider), `chats/${chatId}/messages`, "msg_001"))
    );
  });

  // ── «Удалить у меня» (deletedFor) ────────────────────────────────────────
  // Инвариант: итоговый deletedFor == старый ∪ {свой uid}. Ни добавить чужой
  // uid, ни убрать чужую пометку нельзя — иначе одна сторона решала бы, что
  // видит другая.
  describe("deletedFor (удалить у меня)", () => {
    test("получатель может скрыть у себя чужое сообщение", async () => {
      await assertSucceeds(
        updateDoc(doc(userDb(user2), `chats/${chatId}/messages`, "msg_001"), {
          deletedFor: arrayUnion(user2),
        })
      );
    });

    test("отправитель может скрыть у себя своё сообщение", async () => {
      await assertSucceeds(
        updateDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"), {
          deletedFor: arrayUnion(user1),
        })
      );
    });

    test("повторное скрытие уже скрытого проходит (идемпотентность)", async () => {
      await adminSet(`chats/${chatId}/messages/msg_hidden`, {
        senderId: user1,
        text: "Скрыто",
        isRead: false,
        type: "text",
        deletedFor: [user2],
      });
      await assertSucceeds(
        updateDoc(doc(userDb(user2), `chats/${chatId}/messages`, "msg_hidden"), {
          deletedFor: arrayUnion(user2),
        })
      );
    });

    test("НЕЛЬЗЯ скрыть сообщение у собеседника (чужой uid в deletedFor)", async () => {
      await assertFails(
        updateDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"), {
          deletedFor: arrayUnion(user2),
        })
      );
    });

    test("НЕЛЬЗЯ добавить себя и собеседника разом", async () => {
      await assertFails(
        updateDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"), {
          deletedFor: [user1, user2],
        })
      );
    });

    test("НЕЛЬЗЯ убрать чужую пометку из deletedFor", async () => {
      await adminSet(`chats/${chatId}/messages/msg_hidden`, {
        senderId: user1,
        text: "Скрыто у user2",
        isRead: false,
        type: "text",
        deletedFor: [user2],
      });
      await assertFails(
        updateDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_hidden"), {
          deletedFor: [user1],
        })
      );
    });

    test("НЕЛЬЗЯ протащить правку текста вместе с deletedFor", async () => {
      await assertFails(
        updateDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_001"), {
          deletedFor: arrayUnion(user1),
          text: "Подменено",
        })
      );
    });

    test("посторонний НЕ может скрыть сообщение", async () => {
      await assertFails(
        updateDoc(doc(userDb(outsider), `chats/${chatId}/messages`, "msg_001"), {
          deletedFor: arrayUnion(outsider),
        })
      );
    });

    test("НЕЛЬЗЯ скрыть у себя оффер чужой правкой статуса под видом deletedFor", async () => {
      await adminSet(`chats/${chatId}/messages/msg_offer`, {
        senderId: user2,
        text: "Предложение цены: 1000 ₸",
        isRead: false,
        type: "offer",
        offerStatus: "pending",
        offerPrice: 1000,
      });
      await assertFails(
        updateDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_offer"), {
          deletedFor: arrayUnion(user1),
          offerStatus: "accepted",
        })
      );
    });

    test("оффер можно скрыть у себя, не меняя статус", async () => {
      await adminSet(`chats/${chatId}/messages/msg_offer`, {
        senderId: user2,
        text: "Предложение цены: 1000 ₸",
        isRead: false,
        type: "offer",
        offerStatus: "pending",
        offerPrice: 1000,
      });
      await assertSucceeds(
        updateDoc(doc(userDb(user1), `chats/${chatId}/messages`, "msg_offer"), {
          deletedFor: arrayUnion(user1),
        })
      );
    });
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

  // Пометка «прочитано» — операция владельца. Раньше в правиле стояла ветка
  // «любой авторизованный может менять только isRead», и посторонний мог
  // гасить чужой счётчик уведомлений, зная uid и id документа.
  describe("пометка прочитанным", () => {
    beforeEach(async () => {
      await adminSet(`users/${sellerId}/notifications/${notifId}`, {
        title: "Новое сообщение",
        body: "Привет",
        type: "chat",
        timestamp: new Date(),
        senderId: buyerId,
        isRead: false,
      });
    });

    test("владелец помечает своё уведомление прочитанным", async () => {
      await assertSucceeds(
        updateDoc(doc(userDb(sellerId), `users/${sellerId}/notifications`, notifId), {
          isRead: true,
        })
      );
    });

    test("посторонний НЕ может пометить чужое уведомление прочитанным", async () => {
      await assertFails(
        updateDoc(doc(userDb("stranger_999"), `users/${sellerId}/notifications`, notifId), {
          isRead: true,
        })
      );
    });

    test("отправитель сообщения тоже НЕ гасит уведомление получателя", async () => {
      await assertFails(
        updateDoc(doc(userDb(buyerId), `users/${sellerId}/notifications`, notifId), {
          isRead: true,
        })
      );
    });

    // Обратная сторона того же запрета: новое сообщение обязано поднимать
    // уведомление обратно в непрочитанные, иначе прочитанный однажды чат
    // больше никогда не зажжёт колокольчик.
    test("новое сообщение возвращает уведомление в непрочитанные", async () => {
      await adminSet(`users/${sellerId}/notifications/${notifId}`, {
        title: "Новое сообщение",
        body: "Привет",
        type: "chat",
        timestamp: new Date(),
        senderId: buyerId,
        isRead: true,
      });
      await assertSucceeds(
        setDoc(
          doc(userDb(buyerId), `users/${sellerId}/notifications`, notifId),
          {
            title: "Новое сообщение",
            body: "Ещё сообщение",
            type: "chat",
            timestamp: new Date(),
            senderId: buyerId,
            isRead: false,
          },
          { merge: true }
        )
      );
    });

    test("отправитель по-прежнему может обновить сам текст chat-уведомления", async () => {
      await assertSucceeds(
        setDoc(
          doc(userDb(buyerId), `users/${sellerId}/notifications`, notifId),
          {
            title: "Новое сообщение",
            body: "Сообщение удалено",
            type: "chat",
            senderId: buyerId,
          },
          { merge: true }
        )
      );
    });
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

  test("продавец может отклонить предложение напрямую, но НЕ может принять — Accept закрыт клиенту до деплоя respondToOffer", async () => {
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

    // 4. Продавец не может выставить статус оффера с клиента НИ В КАКУЮ
    //    сторону. Ответ на предложение целиком исполняет respondToOffer через
    //    Admin SDK. Именно клиентский переход статуса был источником прод-бага
    //    (гонка двух Accept + ложное "отклонено" по факту принятого).
    await assertFails(
      updateDoc(doc(userDb(sellerId), `chats/${chatId}/messages`, "offer_001"), {
        offerStatus: "accepted",
      })
    );

    await assertFails(
      updateDoc(doc(userDb(sellerId), `chats/${chatId}/messages`, "offer_001"), {
        offerStatus: "rejected",
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

  // Прод-баг: КАЖДОЕ первое предложение цены по товару падало с
  // permission-denied. ChatService.sendOffer сначала читает свой слот оффера
  // (чтобы погасить прошлую карточку), а у несуществующего документа
  // resource == null — обращение к resource.data.buyerId в правиле даёт не
  // false, а ошибку вычисления, то есть отказ.
  test("покупатель может прочитать свой ЕЩЁ НЕ созданный слот оффера", async () => {
    await assertSucceeds(
      getDoc(doc(userDb(buyerId), "offers", offerId))
    );
  });

  test("посторонний НЕ может прощупывать чужой пустой слот оффера", async () => {
    await assertFails(
      getDoc(doc(userDb(strangerId), "offers", offerId))
    );
  });

  test("участники читают существующее предложение, посторонний — нет", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertSucceeds(getDoc(doc(userDb(buyerId), "offers", offerId)));
    await assertSucceeds(getDoc(doc(userDb(sellerId), "offers", offerId)));
    await assertFails(getDoc(doc(userDb(strangerId), "offers", offerId)));
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

  // Ответ на оффер — исключительно серверный путь (respondToOffer через Admin
  // SDK). У продавца нет права записи в offers ни в какую сторону: только
  // сервер умеет атомарно разрешить гонку двух Accept и отклонить конкурентов
  // на тот же товар.
  test("продавец НЕ может выставить rejected с клиента", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertFails(
      updateDoc(doc(userDb(sellerId), "offers", offerId), { status: "rejected" })
    );
  });

  test("продавец НЕ может выставить accepted с клиента", async () => {
    await adminSet(`offers/${offerId}`, validOffer);
    await assertFails(
      updateDoc(doc(userDb(sellerId), "offers", offerId), { status: "accepted" })
    );
  });

  test("продавец не может тронуть чужое предложение (не sellerId)", async () => {
    await adminSet(`offers/${offerId}`, { ...validOffer, sellerId: strangerId });
    await assertFails(
      updateDoc(doc(userDb(sellerId), "offers", offerId), { status: "rejected" })
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
// ТЕСТЫ: sendOffer целиком, как её выполняет приложение
//
// Остальные тесты офферов проверяют операции ПООТДЕЛЬНОСТИ, и прод-баг с
// permission-denied на каждом первом предложении проскочил мимо них именно
// поэтому: падал не сам оффер, а чтение пустого слота ПЕРЕД ним. Здесь
// воспроизводится вся цепочка ChatService.sendOffer в том же порядке и с теми
// же полями: сводка чата → чтение своего слота → документ оффера → карточка в
// ленте сообщений. Менять поля здесь только вместе с chat_service.dart.
// ──────────────────────────────────────────
describe("sendOffer — полная цепочка как в приложении", () => {
  const buyerId = "flow_buyer";
  const sellerId = "flow_seller";
  const adId = "flow_ad_001";
  const adPrice = 100000;
  const offerPrice = 90000;
  const offerId = `${adId}_${buyerId}`;
  const chatId = [buyerId, sellerId].sort().join("_");
  const msgId = "flow_msg_new";

  beforeEach(async () => {
    await adminSet(`ads/${adId}`, {
      userId: sellerId,
      price: adPrice,
      status: "active",
      title: "Тестовый товар",
      timestamp: new Date(),
    });
  });

  // Шаг 1 — сводка чата. В приложении идёт ПЕРВОЙ: документ чата обязан
  // существовать до любых запросов к messages, правила читают его users.
  function writeChatSummary(db) {
    return setDoc(
      doc(db, "chats", chatId),
      {
        lastMessage: `Предложение цены: ${offerPrice} ₸`,
        lastMessageType: "offer",
        lastOfferPrice: offerPrice,
        lastTimestamp: new Date(),
        lastSenderId: buyerId,
        isRead: false,
        users: [buyerId, sellerId].sort(),
        [`unreadCount_${sellerId}`]: increment(1),
        [`name_${buyerId}`]: "Покупатель",
        [`name_${sellerId}`]: "Продавец",
        adId,
        adTitle: "Тестовый товар",
        adImage: "",
      },
      { merge: true }
    );
  }

  // Шаг 3 — документ оффера, источник истины по предложению
  function writeOffer(db, messageId) {
    return setDoc(doc(db, "offers", offerId), {
      adId,
      adTitle: "Тестовый товар",
      price: offerPrice,
      sellerId,
      buyerId,
      chatId,
      messageId,
      status: "pending",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  }

  // Шаг 4 — карточка предложения в ленте сообщений
  function writeOfferMessage(db, messageId) {
    return setDoc(doc(db, "chats", chatId, "messages", messageId), {
      senderId: buyerId,
      text: `Предложение цены: ${offerPrice} ₸`,
      type: "offer",
      offerPrice,
      offerStatus: "pending",
      offerId,
      timestamp: new Date(),
      isRead: false,
      adId,
      adTitle: "Тестовый товар",
    });
  }

  // Тот самый прод-баг: чата нет, слота оффера нет — падало здесь.
  test("ПЕРВОЕ предложение по товару: ни чата, ни слота оффера ещё нет", async () => {
    const db = userDb(buyerId);
    await assertSucceeds(writeChatSummary(db));
    await assertSucceeds(getDoc(doc(db, "offers", offerId)));
    await assertSucceeds(writeOffer(db, msgId));
    await assertSucceeds(writeOfferMessage(db, msgId));
  });

  test("ПОВТОРНОЕ предложение: гасим прошлую карточку и перебиваем цену", async () => {
    const db = userDb(buyerId);
    await assertSucceeds(writeChatSummary(db));
    await assertSucceeds(writeOffer(db, "flow_msg_old"));
    await assertSucceeds(writeOfferMessage(db, "flow_msg_old"));

    await assertSucceeds(getDoc(doc(db, "offers", offerId)));
    await assertSucceeds(
      updateDoc(doc(db, "chats", chatId, "messages", "flow_msg_old"), {
        offerStatus: "cancelled",
      })
    );
    await assertSucceeds(writeOffer(db, msgId));
    await assertSucceeds(writeOfferMessage(db, msgId));
  });

  test("предложение в УЖЕ СУЩЕСТВУЮЩИЙ чат (переписка была раньше)", async () => {
    await adminSet(`chats/${chatId}`, {
      users: [buyerId, sellerId].sort(),
      lastMessage: "Здравствуйте",
      lastSenderId: sellerId,
      adId: "flow_ad_other",
    });
    const db = userDb(buyerId);
    await assertSucceeds(writeChatSummary(db));
    await assertSucceeds(getDoc(doc(db, "offers", offerId)));
    await assertSucceeds(writeOffer(db, msgId));
    await assertSucceeds(writeOfferMessage(db, msgId));
  });

  test("продавец видит и оффер, и карточку в чате", async () => {
    const buyer = userDb(buyerId);
    await assertSucceeds(writeChatSummary(buyer));
    await assertSucceeds(writeOffer(buyer, msgId));
    await assertSucceeds(writeOfferMessage(buyer, msgId));

    const seller = userDb(sellerId);
    await assertSucceeds(getDoc(doc(seller, "offers", offerId)));
    await assertSucceeds(getDoc(doc(seller, "chats", chatId, "messages", msgId)));
  });

  // Профили обоих участников заведены: isBanned/isBlockedByUsersList начинают
  // реально читать users/{uid}, а не выходить по exists() == false.
  test("оба участника с заведёнными профилями — цепочка не ломается", async () => {
    await adminSet(`users/${sellerId}`, { name: "Продавец", status: "active" });
    await adminSet(`users/${buyerId}`, { name: "Покупатель", status: "active" });
    const db = userDb(buyerId);
    await assertSucceeds(writeChatSummary(db));
    await assertSucceeds(getDoc(doc(db, "offers", offerId)));
    await assertSucceeds(writeOffer(db, msgId));
    await assertSucceeds(writeOfferMessage(db, msgId));
  });

  // 🔒 Продавец заблокировал покупателя ПОСЛЕ того, как чат уже существовал
  // (переписка была раньше): шаги 3 (оффер) и 4 (карточка в чате) теперь
  // корректно падают. ⚠️ ИЗВЕСТНЫЙ ОСТАТОЧНЫЙ ПРОБЕЛ, не в скоупе сегодняшнего
  // фикса: шаг 1 (сводка чата, writeChatSummary) всё ещё УСПЕШЕН, потому что
  // allow UPDATE для chats/{chatId} в 04_chats.rules не проверяет
  // isBlockedByUsersList (проверяет только allow CREATE — если бы чата ещё не
  // было, шаг 1 тоже упал бы, см. тест ниже). Значит превью
  // "Предложение цены: X ₸" технически долетает до lastMessage чата
  // продавца, но только когда переписка началась ДО блокировки. Общий баг,
  // шире офферов (та же дыра у sendMessage для обычного текста) — не трогал.
  test("продавец заблокировал покупателя ПОСЛЕ прошлой переписки — оффер и карточка падают, сводка чата ещё нет", async () => {
    await adminSet(`users/${sellerId}`, { name: "Продавец", status: "active", blockedUserIds: [buyerId] });
    await adminSet(`users/${buyerId}`, { name: "Покупатель", status: "active" });
    await adminSet(`chats/${chatId}`, {
      users: [buyerId, sellerId].sort(),
      lastMessage: "Здравствуйте",
      lastSenderId: sellerId,
      adId,
    });
    const db = userDb(buyerId);
    await assertSucceeds(writeChatSummary(db)); // см. комментарий выше — известный пробел
    await assertFails(writeOffer(db, msgId));
    await assertFails(writeOfferMessage(db, msgId));
  });

  // Контрольный случай: если переписки ДО блокировки не было, allow CREATE
  // для chats/{chatId} уже проверяет isBlockedByUsersList — гэп из теста выше
  // здесь не проявляется, падает уже первый шаг.
  test("продавец заблокировал покупателя ДО первого контакта — падает уже сводка чата", async () => {
    await adminSet(`users/${sellerId}`, { name: "Продавец", status: "active", blockedUserIds: [buyerId] });
    await adminSet(`users/${buyerId}`, { name: "Покупатель", status: "active" });
    const db = userDb(buyerId);
    await assertFails(writeChatSummary(db));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: ads — переходы статуса при update()
//
// Прод-баг (2026-08-09): владелец переоткрывал отклонённое админом
// объявление в «Редактировать», ничего не менял, нажимал «Опубликовать» —
// оно мгновенно возвращалось в активные в обход решения администратора,
// потому что ad_service.dart решал статус только по вердикту ИИ, а ИИ его
// изначально и не отклонял (это сделал человек). Фикс в двух местах:
// AdService.uploadAndPublishAd теперь переводит такое объявление в
// 'pending', а не 'active' — но правило update() для владельца разрешало
// только ['active', 'reserved', 'sold', 'archived'], 'pending' там не было
// (create() эту проверку не делает — им пишутся только НОВЫЕ объявления,
// редактирование существующего всегда идёт через update()). Без этого теста
// повторная публикация ловила бы permission-denied вместо ухода на
// повторную ручную проверку.
// ──────────────────────────────────────────
describe("ads — переходы статуса владельцем", () => {
  const adId = "ad_status_001";
  const ownerId = "ad_owner_001";
  const adminId = "ad_admin_001";
  const strangerId = "ad_stranger_001";

  beforeEach(async () => {
    await adminSet(`users/${adminId}`, { accountType: "admin" });
  });

  async function setAd(status) {
    await adminSet(`ads/${adId}`, {
      title: "Тестовый товар",
      price: 10000,
      userId: ownerId,
      timestamp: new Date(),
      status,
      active: status === "active",
    });
  }

  test("владелец может перевести своё объявление в pending (повторная модерация после ручного отклонения)", async () => {
    await setAd("rejected");
    await assertSucceeds(
      updateDoc(doc(userDb(ownerId), "ads", adId), {
        status: "pending",
        active: false,
      })
    );
  });

  test("владелец по-прежнему может архивировать/продать/восстановить своё объявление", async () => {
    await setAd("active");
    await assertSucceeds(updateDoc(doc(userDb(ownerId), "ads", adId), { status: "archived", active: false }));
    await assertSucceeds(updateDoc(doc(userDb(ownerId), "ads", adId), { status: "sold", active: false }));
    await assertSucceeds(updateDoc(doc(userDb(ownerId), "ads", adId), { status: "reserved" }));
    await assertSucceeds(updateDoc(doc(userDb(ownerId), "ads", adId), { status: "active", active: true }));
  });

  test("владелец НЕ может сам себя отклонить (status: rejected остаётся только за админом)", async () => {
    await setAd("active");
    await assertFails(
      updateDoc(doc(userDb(ownerId), "ads", adId), {
        status: "rejected",
      })
    );
  });

  test("посторонний НЕ может менять статус чужого объявления", async () => {
    await setAd("active");
    await assertFails(
      updateDoc(doc(userDb(strangerId), "ads", adId), {
        status: "pending",
      })
    );
  });

  test("админ по-прежнему может поставить любой статус, включая rejected", async () => {
    await setAd("pending");
    await assertSucceeds(
      updateDoc(doc(userDb(adminId), "ads", adId), {
        status: "rejected",
        active: false,
        rejectionReason: "Тестовая причина",
      })
    );
  });
});

describe("ads — редактирование не бесплатно продлевает объявление", () => {
  const adId = "ad_edit_bump_001";
  const ownerId = "ad_edit_owner_001";
  const strangerId = "ad_edit_stranger_001";
  const oldExpiresAt = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000); // истекает через 5 дней

  beforeEach(async () => {
    await adminSet(`ads/${adId}`, {
      title: "Тестовый товар",
      price: 10000,
      userId: ownerId,
      timestamp: new Date(2026, 0, 1),
      status: "active",
      active: true,
      expiresAt: oldExpiresAt,
      notifiedExpiry: true,
    });
  });

  test("владелец НЕ может сам себе бесплатно продлить объявление, редактируя контент", async () => {
    await assertFails(
      updateDoc(doc(userDb(ownerId), "ads", adId), {
        price: 12000,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        notifiedExpiry: false,
      })
    );
  });

  test("владелец НЕ может поднять объявление в ленте через timestamp при обычной правке", async () => {
    await assertFails(
      updateDoc(doc(userDb(ownerId), "ads", adId), {
        price: 12000,
        timestamp: new Date(),
      })
    );
  });

  test("владелец МОЖЕТ редактировать контент, если не трогает timestamp/expiresAt/notifiedExpiry", async () => {
    await assertSucceeds(
      updateDoc(doc(userDb(ownerId), "ads", adId), {
        price: 12000,
        title: "Тестовый товар (обновлено)",
      })
    );
  });

  test("владелец МОЖЕТ продлить объявление отдельным вызовом (как настоящая кнопка «Продлить»)", async () => {
    await assertSucceeds(
      updateDoc(doc(userDb(ownerId), "ads", adId), {
        active: true,
        status: "active",
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        notifiedExpiry: false,
      })
    );
  });

  test("посторонний не может редактировать чужое объявление ни в каком виде", async () => {
    await assertFails(updateDoc(doc(userDb(strangerId), "ads", adId), { price: 1 }));
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
// ──────────────────────────────────────────
// ТЕСТЫ: tg_auth_sessions — read доступ
// ──────────────────────────────────────────
describe("tg_auth_sessions", () => {
  test("сессия С initiatorUid — читает только сам инициатор", async () => {
    await adminSet("tg_auth_sessions/session_linked", {
      created_at: new Date(),
      verified: false,
      chat_id: null,
      otp: null,
      initiatorUid: "user_linker",
    });
    await assertSucceeds(getDoc(doc(userDb("user_linker"), "tg_auth_sessions", "session_linked")));
    await assertFails(getDoc(doc(userDb("user_stranger"), "tg_auth_sessions", "session_linked")));
    await assertFails(getDoc(doc(anonDb(), "tg_auth_sessions", "session_linked")));
  });

  test("сессия БЕЗ initiatorUid (свежий вход, пользователь ещё не залогинен) — читает кто угодно по id, как раньше", async () => {
    await adminSet("tg_auth_sessions/session_fresh_login", {
      created_at: new Date(),
      verified: false,
      chat_id: null,
      otp: null,
    });
    await assertSucceeds(getDoc(doc(anonDb(), "tg_auth_sessions", "session_fresh_login")));
  });

  test("список сессий по-прежнему запрещён", async () => {
    await assertFails(getDocs(collection(userDb("user_linker"), "tg_auth_sessions")));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: reports — анонимные жалобы больше не проходят
// ──────────────────────────────────────────
describe("reports", () => {
  test("анонимная жалоба (reporterUserId: 'anonymous') — запрещена", async () => {
    await assertFails(
      setDoc(doc(anonDb(), "reports", "report_anon"), {
        reporterUserId: "anonymous",
        userId: "some_seller",
        reason: "spam",
      })
    );
  });

  test("жалоба от вошедшего пользователя — разрешена", async () => {
    await assertSucceeds(
      setDoc(doc(userDb("user_reporter"), "reports", "report_real"), {
        reporterUserId: "user_reporter",
        userId: "some_seller",
        reason: "spam",
      })
    );
  });
});

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
    await adminSet(`ads/ad_owned_by_banned`, {
      title: "Owned by banned",
      price: 500,
      userId: bannedUid,
      status: "active",
      timestamp: new Date(),
    });
    await adminSet(`reviews/review_by_banned_existing`, {
      fromUserId: bannedUid,
      toUserId: sellerUid,
      rating: 4,
    });
    await adminSet(`chats/${chatId}/messages/msg_existing_by_banned`, {
      senderId: bannedUid,
      text: "old message",
      type: "text",
      isRead: false,
    });
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

  // Бан раньше блокировал только create — update этих же коллекций
  // isBanned() не проверял, нарушитель продолжал редактировать старое.
  test("забаненный пользователь НЕ может отредактировать своё старое объявление", async () => {
    await assertFails(
      updateDoc(doc(userDb(bannedUid), "ads", "ad_owned_by_banned"), {
        title: "Edited by banned",
      })
    );
  });

  test("забаненный пользователь НЕ может отредактировать свой старый отзыв", async () => {
    await assertFails(
      updateDoc(doc(userDb(bannedUid), "reviews", "review_by_banned_existing"), {
        rating: 1,
      })
    );
  });

  test("забаненный пользователь НЕ может отредактировать своё старое сообщение", async () => {
    await assertFails(
      updateDoc(doc(userDb(bannedUid), `chats/${chatId}/messages`, "msg_existing_by_banned"), {
        text: "edited",
      })
    );
  });

  test("собеседник забаненного всё ещё МОЖЕТ пометить его сообщение прочитанным (ветка read-receipt не задета)", async () => {
    await assertSucceeds(
      updateDoc(doc(userDb(otherUid), `chats/${chatId}/messages`, "msg_existing_by_banned"), {
        isRead: true,
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

  // 🔒 Регрессия на находку аудита: офферы были единственным каналом,
  // где личная блокировка вообще не проверялась — заблокированный покупатель
  // мог слать предложения цены в обход блока (10b_offers.rules).
  test("заблокированный НЕ может отправить оффер тому, кто его заблокировал", async () => {
    const adId = "ad_blocked_offer_001";
    await adminSet(`ads/${adId}`, {
      userId: blockerUid,
      price: 100000,
      status: "active",
      title: "Товар блокировщика",
    });
    await assertFails(
      setDoc(doc(userDb(blockedUid), "offers", `${adId}_${blockedUid}`), {
        adId,
        adTitle: "Товар блокировщика",
        price: 90000,
        sellerId: blockerUid,
        buyerId: blockedUid,
        chatId: existingChatId,
        messageId: "msg_offer_blocked",
        status: "pending",
      })
    );
  });

  test("заблокированный НЕ может перебить цену своего оффера, пока блокировка активна", async () => {
    const adId = "ad_blocked_offer_002";
    const offerId = `${adId}_${blockedUid}`;
    await adminSet(`ads/${adId}`, {
      userId: blockerUid,
      price: 100000,
      status: "active",
      title: "Товар блокировщика 2",
    });
    await adminSet(`offers/${offerId}`, {
      adId,
      adTitle: "Товар блокировщика 2",
      price: 90000,
      sellerId: blockerUid,
      buyerId: blockedUid,
      chatId: existingChatId,
      messageId: "msg_offer_blocked_2",
      status: "pending",
    });
    await assertFails(
      setDoc(doc(userDb(blockedUid), "offers", offerId), {
        adId,
        adTitle: "Товар блокировщика 2",
        price: 95000,
        sellerId: blockerUid,
        buyerId: blockedUid,
        chatId: existingChatId,
        messageId: "msg_offer_blocked_2",
        status: "pending",
      })
    );
  });

  // Отзыв — не новая попытка связаться, а её противоположность. Блокировка
  // не должна навечно замораживать чужой pending-оффер без возможности снять.
  test("заблокированный всё ещё МОЖЕТ отозвать оффер, отправленный ДО блокировки", async () => {
    const adId = "ad_blocked_offer_003";
    const offerId = `${adId}_${blockedUid}`;
    await adminSet(`ads/${adId}`, {
      userId: blockerUid,
      price: 100000,
      status: "active",
      title: "Товар блокировщика 3",
    });
    await adminSet(`offers/${offerId}`, {
      adId,
      adTitle: "Товар блокировщика 3",
      price: 90000,
      sellerId: blockerUid,
      buyerId: blockedUid,
      chatId: existingChatId,
      messageId: "msg_offer_blocked_3",
      status: "pending",
    });
    await assertSucceeds(
      updateDoc(doc(userDb(blockedUid), "offers", offerId), { status: "cancelled" })
    );
  });
});


