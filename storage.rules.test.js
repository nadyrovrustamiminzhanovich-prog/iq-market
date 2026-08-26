// storage.rules.test.js
// Тесты для Storage Security Rules: avatars, users, chat_media, voice_messages
// Запуск: firebase emulators:start --only firestore,storage
// Затем: npx jest storage.rules.test.js --detectOpenHandles --forceExit

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  ref,
  uploadBytes,
  getDownloadURL,
} = require("firebase/storage");
const {
  doc,
  setDoc,
} = require("firebase/firestore");
const fs = require("fs");

jest.setTimeout(30000);

let testEnv;

// Маленькое изображение для тестов
const SMALL_IMAGE = Buffer.alloc(1024);
const IMAGE_META = { contentType: "image/jpeg" };
// Большое изображение (6 MB — больше лимита 5 MB для avatars)
const LARGE_IMAGE = Buffer.alloc(6 * 1024 * 1024);

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "iq-market-3dc07",
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync("storage.rules", "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
}, 30000);

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

// Хелперы
function userStorage(uid) {
  return testEnv.authenticatedContext(uid).storage();
}

function adminStorage(uid) {
  return testEnv.authenticatedContext(uid, { admin: true }).storage();
}

function anonStorage() {
  return testEnv.unauthenticatedContext().storage();
}

async function createUser(uid, accountType = "user") {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), {
      accountType,
      displayName: "Test User",
    });
  });
}

async function adminUpload(path) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), path), SMALL_IMAGE, IMAGE_META);
  });
}

// ──────────────────────────────────────────
// ТЕСТЫ: /avatars/{userId}/
// По правилам: read — if isSignedIn() (любой залогиненный), write — только себе
// ──────────────────────────────────────────
describe("storage: avatars/{userId}/", () => {
  const userId = "user_avatar_001";
  const otherId = "user_avatar_002";
  const adminId = "admin_avatar_001";

  beforeEach(async () => {
    await adminUpload(`avatars/${userId}/avatar.jpg`);
  });

  test("владелец может читать свой аватар", async () => {
    const storageRef = ref(userStorage(userId), `avatars/${userId}/avatar.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("посторонний залогиненный пользователь может читать аватар (публичный профиль)", async () => {
    const storageRef = ref(userStorage(otherId), `avatars/${userId}/avatar.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("анонимный пользователь может читать аватар (публичный профиль маркета)", async () => {
    const storageRef = ref(anonStorage(), `avatars/${userId}/avatar.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("владелец может загрузить свой аватар", async () => {
    const storageRef = ref(userStorage(userId), `avatars/${userId}/new_avatar.jpg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("посторонний НЕ может загрузить аватар другому пользователю", async () => {
    const storageRef = ref(userStorage(otherId), `avatars/${userId}/hacked.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("анонимный НЕ может загрузить аватар", async () => {
    const storageRef = ref(anonStorage(), `avatars/${userId}/anon.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("владелец НЕ может загрузить файл больше 5 MB", async () => {
    const storageRef = ref(userStorage(userId), `avatars/${userId}/big.jpg`);
    await assertFails(uploadBytes(storageRef, LARGE_IMAGE, IMAGE_META));
  });

  test("владелец НЕ может загрузить не-изображение (только image/*)", async () => {
    const storageRef = ref(userStorage(userId), `avatars/${userId}/script.js`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "application/javascript" }));
  });

  test("admin (Custom Claim) может читать чужой аватар", async () => {
    const storageRef = ref(adminStorage(adminId), `avatars/${userId}/avatar.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: /users/{userId}/
// По правилам: read — if true (публично), write — только себе
// ──────────────────────────────────────────
describe("storage: users/{userId}/", () => {
  const userId = "user_files_001";
  const otherId = "user_files_002";

  beforeEach(async () => {
    await adminUpload(`users/${userId}/avatar.jpg`);
  });

  test("владелец может читать свой файл", async () => {
    const storageRef = ref(userStorage(userId), `users/${userId}/avatar.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("посторонний может читать файл (публично)", async () => {
    const storageRef = ref(userStorage(otherId), `users/${userId}/avatar.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("анонимный может читать файл (публично)", async () => {
    const storageRef = ref(anonStorage(), `users/${userId}/avatar.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("владелец может загрузить свой файл", async () => {
    const storageRef = ref(userStorage(userId), `users/${userId}/photo.jpg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("посторонний НЕ может загрузить файл другому", async () => {
    const storageRef = ref(userStorage(otherId), `users/${userId}/hacked.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("анонимный НЕ может загрузить файл", async () => {
    const storageRef = ref(anonStorage(), `users/${userId}/anon.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: /chat_media/{chatId}/
// По правилам: доступ только пользователям, чей uid содержится в chatId
// (формат chatId: uid1_uid2, детерминированный, sorted)
// ВАЖНО: правила проверяют паттерн по chatId, НЕ через firestore.get()
// ──────────────────────────────────────────
describe("storage: chat_media/{chatId}/", () => {
  const uid1 = "aaaa";
  const uid2 = "bbbb";
  const outsider = "cccc";
  // chatId должен содержать uid пользователя (sorted: aaaa_bbbb)
  const chatId = "aaaa_bbbb";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `chats/${chatId}`), {
        users: [uid1, uid2],
      });
      await uploadBytes(
        ref(ctx.storage(), `chat_media/${chatId}/image.jpg`),
        SMALL_IMAGE,
        IMAGE_META
      );
    });
  });

  test("первый участник (uid в начале chatId) может читать медиа", async () => {
    const storageRef = ref(userStorage(uid1), `chat_media/${chatId}/image.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("второй участник (uid в конце chatId) может читать медиа", async () => {
    const storageRef = ref(userStorage(uid2), `chat_media/${chatId}/image.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("посторонний НЕ может читать медиа чата", async () => {
    // outsider 'cccc' не входит в chatId 'aaaa_bbbb'
    const storageRef = ref(userStorage(outsider), `chat_media/${chatId}/image.jpg`);
    await assertFails(getDownloadURL(storageRef));
  });

  test("анонимный НЕ может читать медиа чата", async () => {
    const storageRef = ref(anonStorage(), `chat_media/${chatId}/image.jpg`);
    await assertFails(getDownloadURL(storageRef));
  });

  test("первый участник может загрузить медиа в свой чат", async () => {
    const storageRef = ref(userStorage(uid1), `chat_media/${chatId}/new.jpg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("второй участник может загрузить медиа в свой чат", async () => {
    const storageRef = ref(userStorage(uid2), `chat_media/${chatId}/new2.jpg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("посторонний НЕ может загрузить медиа в чужой чат", async () => {
    const storageRef = ref(userStorage(outsider), `chat_media/${chatId}/hacked.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("анонимный НЕ может загрузить медиа в чат", async () => {
    const storageRef = ref(anonStorage(), `chat_media/${chatId}/anon.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("участник НЕ может загрузить файл больше 20 MB", async () => {
    const BIG = Buffer.alloc(21 * 1024 * 1024);
    const storageRef = ref(userStorage(uid1), `chat_media/${chatId}/big.jpg`);
    await assertFails(uploadBytes(storageRef, BIG, IMAGE_META));
  });

  // 🔒 Регрессия на находку аудита: contentType раньше вообще не проверялся —
  // под видом фото в чат можно было залить файл любого типа.
  test("участник НЕ может загрузить файл не-image/* под видом фото в чат", async () => {
    const storageRef = ref(userStorage(uid1), `chat_media/${chatId}/fake.jpg`);
    await assertFails(
      uploadBytes(storageRef, SMALL_IMAGE, { contentType: "application/octet-stream" })
    );
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: /voice_messages/{chatId}/
// По правилам: аналогично chat_media — проверка по uid в chatId
// ──────────────────────────────────────────
describe("storage: voice_messages/{chatId}/", () => {
  const uid1 = "aaaa";
  const uid2 = "bbbb";
  const outsider = "cccc";
  const chatId = "aaaa_bbbb";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `chats/${chatId}`), {
        users: [uid1, uid2],
      });
      await uploadBytes(
        ref(ctx.storage(), `voice_messages/${chatId}/voice.ogg`),
        SMALL_IMAGE,
        { contentType: "audio/ogg" }
      );
    });
  });

  test("первый участник может читать голосовое сообщение", async () => {
    const storageRef = ref(userStorage(uid1), `voice_messages/${chatId}/voice.ogg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("второй участник может читать голосовое сообщение", async () => {
    const storageRef = ref(userStorage(uid2), `voice_messages/${chatId}/voice.ogg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("посторонний НЕ может читать голосовое сообщение", async () => {
    const storageRef = ref(userStorage(outsider), `voice_messages/${chatId}/voice.ogg`);
    await assertFails(getDownloadURL(storageRef));
  });

  test("анонимный НЕ может читать голосовое сообщение", async () => {
    const storageRef = ref(anonStorage(), `voice_messages/${chatId}/voice.ogg`);
    await assertFails(getDownloadURL(storageRef));
  });

  test("первый участник может загрузить голосовое сообщение", async () => {
    const storageRef = ref(userStorage(uid1), `voice_messages/${chatId}/new_voice.ogg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "audio/ogg" }));
  });

  test("участник может загрузить голосовое сообщение <= 5MB", async () => {
    const storageRef = ref(userStorage(uid1), `voice_messages/${chatId}/under_5mb.ogg`);
    const size4mb = Buffer.alloc(4 * 1024 * 1024);
    await assertSucceeds(uploadBytes(storageRef, size4mb, { contentType: "audio/ogg" }));
  });

  test("участник НЕ может загрузить голосовое сообщение > 5MB", async () => {
    const storageRef = ref(userStorage(uid1), `voice_messages/${chatId}/over_5mb.ogg`);
    await assertFails(uploadBytes(storageRef, LARGE_IMAGE, { contentType: "audio/ogg" }));
  });

  // 🔒 Регрессия на находку аудита: contentType раньше вообще не проверялся —
  // под видом голосового сообщения можно было залить файл любого типа.
  test("участник НЕ может загрузить файл не-audio/* под видом голосового", async () => {
    const storageRef = ref(userStorage(uid1), `voice_messages/${chatId}/fake.jpg`);
    await assertFails(
      uploadBytes(storageRef, SMALL_IMAGE, { contentType: "image/jpeg" })
    );
  });

  test("посторонний НЕ может загрузить голосовое сообщение в чужой чат", async () => {
    const storageRef = ref(userStorage(outsider), `voice_messages/${chatId}/hacked.ogg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "audio/ogg" }));
  });

  test("участник свежесозданного чата с ретраем в итоге может загрузить файл (симуляция лага репликации)", async () => {
    const freshChatId = "laggy_chat_id";
    const userUid = "user_laggy";
    
    // 1. Попытка загрузки ДО создания чата в Firestore должна провалиться (permission-denied)
    const storageRef = ref(userStorage(userUid), `voice_messages/${freshChatId}/voice.m4a`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "audio/x-m4a" }));

    // 2. Симулируем прохождение лага репликации: создаем чат в Firestore
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `chats/${freshChatId}`), {
        users: [userUid, "another_user"],
      });
    });

    // 3. Повторная попытка загрузки (retry) теперь должна завершиться успешно
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "audio/x-m4a" }));
  });

  test("не-участник чата НЕ может загрузить файл в любом случае, даже зная правильный формат chatId", async () => {
    const maliciousChatId = "hacked_chat_id";
    const victimUid = "victim_user";
    const hackerUid = "hacker_user";
    
    // 1. Создаем чат в Firestore, где Хакер НЕ является участником
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `chats/${maliciousChatId}`), {
        users: [victimUid, "legit_user"],
      });
    });

    // 2. Хакер пытается загрузить файл в чужой чат — это должно провалиться
    const storageRef = ref(userStorage(hackerUid), `voice_messages/${maliciousChatId}/hacked.m4a`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "audio/x-m4a" }));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: /ads/{uid}/ (медиафайлы объявлений)
// По правилам: read — публично, write — только владелец папки (или admin), медиа < 50MB
// ──────────────────────────────────────────
describe("storage: ads/{uid}/ (public read, owner-only write)", () => {
  const userId = "user_ads_001";
  const otherUserId = "user_ads_002";

  beforeEach(async () => {
    await adminUpload(`ads/${userId}/images/photo.jpg`);
  });

  test("анонимный может читать медиа объявления (публично)", async () => {
    const storageRef = ref(anonStorage(), `ads/${userId}/images/photo.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("владелец может загрузить изображение в свою папку объявлений", async () => {
    const storageRef = ref(userStorage(userId), `ads/${userId}/images/new_photo.jpg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("другой авторизованный пользователь НЕ может загрузить файл в чужую папку объявлений", async () => {
    const storageRef = ref(userStorage(otherUserId), `ads/${userId}/images/hacked.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("анонимный НЕ может загрузить медиа объявления", async () => {
    const storageRef = ref(anonStorage(), `ads/${userId}/images/anon.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("владелец НЕ может загрузить не-медиафайл в ads (только image/* или video/*)", async () => {
    const storageRef = ref(userStorage(userId), `ads/${userId}/docs/report.pdf`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "application/pdf" }));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: Резервное правило (произвольные пути)
// По правилам: все остальные пути — read: false, write: false
// ──────────────────────────────────────────
describe("storage: fallback deny rule", () => {
  const userId = "user_fallback_001";

  test("нельзя читать файлы из произвольного пути", async () => {
    const storageRef = ref(userStorage(userId), "random_folder/file.jpg");
    await assertFails(getDownloadURL(storageRef));
  });

  test("нельзя записать файлы в произвольный путь", async () => {
    const storageRef = ref(userStorage(userId), "random_folder/file.jpg");
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: /chats/{chatId}/ (вложения чатов)
// По правилам: доступ только участникам чата (проверка по Firestore)
// ──────────────────────────────────────────
describe("storage: chats/{chatId}/", () => {
  const chatId = "chat_storage_001";
  const user1 = "user_chat_alpha";
  const user2 = "user_chat_beta";
  const outsider = "user_chat_outsider";
  const adminId = "admin_chat_001";

  beforeEach(async () => {
    // Создаем документ чата в Firestore
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `chats/${chatId}`), {
        users: [user1, user2],
      });
      // Загружаем тестовое вложение
      await uploadBytes(
        ref(ctx.storage(), `chats/${chatId}/attachment.jpg`),
        SMALL_IMAGE,
        IMAGE_META
      );
    });
  });

  test("участник чата (первый) может читать вложения", async () => {
    const storageRef = ref(userStorage(user1), `chats/${chatId}/attachment.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("участник чата (второй) может читать вложения", async () => {
    const storageRef = ref(userStorage(user2), `chats/${chatId}/attachment.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("посторонний НЕ может читать вложения чата", async () => {
    const storageRef = ref(userStorage(outsider), `chats/${chatId}/attachment.jpg`);
    await assertFails(getDownloadURL(storageRef));
  });

  test("анонимный НЕ может читать вложения чата", async () => {
    const storageRef = ref(anonStorage(), `chats/${chatId}/attachment.jpg`);
    await assertFails(getDownloadURL(storageRef));
  });

  test("участник чата может загружать вложения", async () => {
    const storageRef = ref(userStorage(user1), `chats/${chatId}/new_attach.jpg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("посторонний НЕ может загружать вложения в чужой чат", async () => {
    const storageRef = ref(userStorage(outsider), `chats/${chatId}/hacked.jpg`);
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });

  test("участник НЕ может загрузить файл больше 20 MB в чат", async () => {
    const BIG = Buffer.alloc(21 * 1024 * 1024);
    const storageRef = ref(userStorage(user1), `chats/${chatId}/big.jpg`);
    await assertFails(uploadBytes(storageRef, BIG, IMAGE_META));
  });

  test("admin (Custom Claim) может читать вложения любого чата", async () => {
    const storageRef = ref(adminStorage(adminId), `chats/${chatId}/attachment.jpg`);
    await assertSucceeds(getDownloadURL(storageRef));
  });

  // 🔒 Регрессия на находку аудита: contentType раньше вообще не проверялся —
  // в отличие от соседних chat_media/voice_messages, сюда можно было залить
  // файл любого типа до 20MB.
  test("участник НЕ может загрузить файл не-image/не-audio в чат", async () => {
    const storageRef = ref(userStorage(user1), `chats/${chatId}/fake.jpg`);
    await assertFails(
      uploadBytes(storageRef, SMALL_IMAGE, { contentType: "application/octet-stream" })
    );
  });

  test("участник по-прежнему может загрузить audio/* вложение в чат", async () => {
    const storageRef = ref(userStorage(user1), `chats/${chatId}/voice.ogg`);
    await assertSucceeds(uploadBytes(storageRef, SMALL_IMAGE, { contentType: "audio/ogg" }));
  });
});
