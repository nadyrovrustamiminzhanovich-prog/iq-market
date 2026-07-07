// admin.storage.rules.test.js
// ВАЖНО: требует одновременного запуска Firestore (8080) и Storage (9199) эмуляторов
// Запуск: firebase emulators:start --only firestore,storage
// Затем: npx jest admin.storage.rules.test.js --detectOpenHandles

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

const SMALL_IMAGE = Buffer.alloc(1024);
const IMAGE_META = { contentType: "image/jpeg" };

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

// Хелпер: создать пользователя в Firestore через admin (обходя правила)
async function createUser(uid, accountType = "user") {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), {
      accountType,
      displayName: "Test User",
    });
  });
}

function userStorage(uid) {
  return testEnv.authenticatedContext(uid).storage();
}

function adminStorage(uid) {
  // Admin через Custom Claim
  return testEnv.authenticatedContext(uid, { admin: true }).storage();
}

// ──────────────────────────────────────────
// ТЕСТЫ: isAdmin() через Custom Claim
// ──────────────────────────────────────────
describe("storage: admin via Custom Claim", () => {
  const adminId = "admin_claim_001";
  const driverId = "driver_claim_001";

  beforeEach(async () => {
    // Загружаем файл водителя через admin обход
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const storageRef = ref(
        ctx.storage(),
        `driver_documents/${driverId}/passport.jpg`
      );
      await uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META);
    });
  });

  test("admin (Custom Claim) может читать документ водителя", async () => {
    const storageRef = ref(
      adminStorage(adminId),
      `driver_documents/${driverId}/passport.jpg`
    );
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("обычный пользователь (Custom Claim) НЕ может читать чужой документ", async () => {
    const storageRef = ref(
      userStorage("random_user"),
      `driver_documents/${driverId}/passport.jpg`
    );
    await assertFails(getDownloadURL(storageRef));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: isAdmin() через Firestore accountType
// ──────────────────────────────────────────
describe("storage: admin via Firestore accountType", () => {
  const adminId = "admin_firestore_001";
  const regularId = "user_regular_001";
  const driverId = "driver_firestore_001";

  beforeEach(async () => {
    // Создаём admin-пользователя в Firestore
    await createUser(adminId, "admin");
    // Создаём обычного пользователя
    await createUser(regularId, "user");

    // Загружаем файл водителя через обход правил
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const storageRef = ref(
        ctx.storage(),
        `driver_documents/${driverId}/passport.jpg`
      );
      await uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META);
    });
  });

  test("admin (Firestore accountType) может читать документ водителя", async () => {
    const storageRef = ref(
      userStorage(adminId),
      `driver_documents/${driverId}/passport.jpg`
    );
    await assertSucceeds(getDownloadURL(storageRef));
  });

  test("обычный пользователь (Firestore accountType=user) НЕ может читать чужой документ", async () => {
    const storageRef = ref(
      userStorage(regularId),
      `driver_documents/${driverId}/passport.jpg`
    );
    await assertFails(getDownloadURL(storageRef));
  });

  test("admin (Firestore) может загрузить файл в driver_documents", async () => {
    // По текущим storage.rules write в driver_documents разрешён только самому userId
    // Этот тест намеренно проверяет: admin НЕ имеет права записи туда
    // Если это нужно изменить — скажи, добавим isAdmin() в write-правило
    const storageRef = ref(
      userStorage(adminId),
      `driver_documents/${driverId}/new_doc.jpg`
    );
    await assertFails(uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META));
  });
});

// ──────────────────────────────────────────
// ТЕСТЫ: кросс-сервисный вызов не ломается
// при отсутствии документа пользователя
// ──────────────────────────────────────────
describe("storage: isAdmin() graceful fallback", () => {
  const ghostId = "user_no_firestore_doc";
  const driverId = "driver_ghost_001";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const storageRef = ref(
        ctx.storage(),
        `driver_documents/${driverId}/passport.jpg`
      );
      await uploadBytes(storageRef, SMALL_IMAGE, IMAGE_META);
    });
    // НЕ создаём документ в Firestore для ghostId намеренно
  });

  test("пользователь без документа в Firestore НЕ получает доступ к чужим документам", async () => {
    // firestore.get() вернёт null → isAdmin() = false → правило отклонит
    const storageRef = ref(
      userStorage(ghostId),
      `driver_documents/${driverId}/passport.jpg`
    );
    await assertFails(getDownloadURL(storageRef));
  });
});
