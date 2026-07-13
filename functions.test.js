// Mock firebase-admin and firebase-functions before requiring functions code
const mockSettingsSnap = {
  exists: true,
  data: () => ({ adminChatId: '123456789' })
};

const mockAdSnap = {
  exists: true,
  data: () => ({
    title: 'Ad Title Mock',
    price: 15000,
    category: 'Auto',
    userId: 'seller_123'
  })
};

const mockUserSnap = {
  exists: true,
  data: () => ({
    displayName: 'Mock Reported User',
    phone: '+77771112233',
    email: 'mock@violator.com'
  })
};

const mockGet = jest.fn();
const mockCollection = jest.fn();

const mockDb = {
  collection: mockCollection
};

const mockQuery = {
  where: jest.fn(),
  limit: jest.fn(),
  get: jest.fn()
};

mockQuery.where.mockImplementation(() => mockQuery);
mockQuery.limit.mockImplementation(() => mockQuery);
mockQuery.get.mockImplementation(async () => ({
  forEach: (cb) => {}
}));

const mockAdd = jest.fn();
const mockGetUser = jest.fn();
const mockAuth = () => ({
  getUser: mockGetUser
});

const mockDocGet = jest.fn();
const mockDocDelete = jest.fn();

// Setup mock behavior
mockCollection.mockImplementation((name) => {
  return {
    doc: (id) => ({
      get: async () => {
        if (name === 'settings' && id === 'telegram') return mockSettingsSnap;
        if (name === 'ads' && id === 'ad_abc') return mockAdSnap;
        if (name === 'users' && id === 'violator_uid') return mockUserSnap;
        if (name === 'users' && id === 'admin_uid') {
          return { exists: true, data: () => ({ accountType: 'admin' }) };
        }
        if (name === 'users' && id === 'regular_uid') {
          return { exists: true, data: () => ({ accountType: 'user' }) };
        }
        if (name === 'users' && id === 'user_123') {
          return { exists: true, data: () => ({ name: 'Test User', rating: 4.8, reviewsCount: 10 }) };
        }
        return { exists: false };
      },
      collection: (subName) => ({
        doc: (subId) => ({
          get: mockDocGet,
          delete: mockDocDelete
        })
      })
    }),
    where: (...args) => mockQuery.where(...args),
    limit: (...args) => mockQuery.limit(...args),
    get: (...args) => mockQuery.get(...args),
    add: mockAdd
  };
});

const mockFirestoreFunc = () => mockDb;
mockFirestoreFunc.Timestamp = {
  fromDate: (date) => ({
    toDate: () => date
  })
};
mockFirestoreFunc.FieldValue = {
  serverTimestamp: () => 'SERVER_TIMESTAMP'
};

const mockFileDownload = jest.fn();
const mockFileDelete = jest.fn();
const mockFileGetMetadata = jest.fn();
const mockFile = {
  download: mockFileDownload,
  delete: mockFileDelete,
  getMetadata: mockFileGetMetadata
};
const mockBucket = {
  file: jest.fn(() => mockFile)
};
const mockStorageFunc = () => ({
  bucket: () => mockBucket
});

// Mock modules virtually since they are only installed in functions/node_modules
jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  firestore: mockFirestoreFunc,
  auth: mockAuth,
  storage: mockStorageFunc
}), { virtual: true });

class HttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

jest.mock('firebase-functions/v1', () => ({
  firestore: {
    document: (path) => ({
      onCreate: (handler) => handler,
      onUpdate: (handler) => handler
    })
  },
  pubsub: {
    schedule: (cron) => ({
      timeZone: (tz) => ({
        onRun: (handler) => handler
      })
    })
  },
  https: {
    onCall: (handler) => handler,
    onRequest: (handler) => handler,
    HttpsError: HttpsError
  },
  storage: {
    object: () => ({
      onFinalize: (handler) => handler
    })
  }
}), { virtual: true });

// Now require telegram_bot.js to spy on exports
const telegramBot = require('./functions/telegram_bot');
const { onNewReport } = require('./functions/index');

describe('onNewReport Cloud Function Trigger Tests', () => {
  let tgSendSpy;

  beforeEach(() => {
    jest.clearAllMocks();
    tgSendSpy = jest.spyOn(telegramBot, 'tgSend').mockImplementation(async (chatId, text, extra, parseMode) => {
      return { ok: true };
    });
  });

  afterEach(() => {
    tgSendSpy.mockRestore();
  });

  test('Отправка жалобы на объявление в Telegram с богатым контекстом', async () => {
    const mockReportSnap = {
      data: () => ({
        adId: 'ad_abc',
        adTitle: 'Old Ad Title',
        reportedUserId: 'violator_uid',
        reporterUserId: 'reporter_uid',
        type: 'scam',
        comment: 'This is fraud!',
        timestamp: { toDate: () => new Date('2026-07-13T01:00:00Z') }
      })
    };

    const mockContext = {
      params: { reportId: 'rep_001' }
    };

    await onNewReport(mockReportSnap, mockContext);

    // Проверяем, что tgSend был вызван с нужными аргументами
    expect(tgSendSpy).toHaveBeenCalledTimes(1);
    const [chatId, text] = tgSendSpy.mock.calls[0];
    expect(chatId).toBe('123456789');
    expect(text).toContain('🚨 <b>Жалоба на объявление!</b>');
    expect(text).toContain('rep_001');
    expect(text).toContain('Ad Title Mock'); // Context rich!
    expect(text).toContain('15000 ₸'); // Context rich!
    expect(text).toContain('Auto'); // Context rich!
    expect(text).toContain('scam');
    expect(text).toContain('This is fraud!');
  });

  test('Отправка жалобы на пользователя / профиль в Telegram', async () => {
    const mockReportSnap = {
      data: () => ({
        reportedUserId: 'violator_uid',
        reportedUserName: 'Violator Name',
        reporterUserId: 'reporter_uid',
        type: 'insult',
        comment: 'Rudeness in chat!',
        timestamp: { toDate: () => new Date('2026-07-13T01:00:00Z') }
      })
    };

    const mockContext = {
      params: { reportId: 'rep_002' }
    };

    await onNewReport(mockReportSnap, mockContext);

    expect(tgSendSpy).toHaveBeenCalledTimes(1);
    const [chatId, text] = tgSendSpy.mock.calls[0];
    expect(chatId).toBe('123456789');
    expect(text).toContain('🚨 <b>Жалоба на пользователя / чат!</b>');
    expect(text).toContain('rep_002');
    expect(text).toContain('Mock Reported User'); // Context rich user name!
    expect(text).toContain('+77771112233'); // Context rich phone!
    expect(text).toContain('mock@violator.com'); // Context rich email!
    expect(text).toContain('insult');
    expect(text).toContain('Rudeness in chat!');
  });

  test('Активация дедупликации (защиты от спама): второе уведомление подавляется', async () => {
    const mockReportSnap = {
      data: () => ({
        adId: 'ad_abc',
        adTitle: 'Old Ad Title',
        reportedUserId: 'violator_uid',
        reporterUserId: 'reporter_uid',
        type: 'scam',
        comment: 'Spam report!',
        timestamp: { toDate: () => new Date('2026-07-13T01:20:00.000Z') }
      })
    };

    const mockContext = {
      params: { reportId: 'rep_003' }
    };

    // Настраиваем mock, чтобы имитировать наличие недавней жалобы (например, 2 минуты назад)
    mockQuery.get.mockImplementationOnce(async () => {
      return {
        forEach: (cb) => {
          // Имитируем существующую жалобу
          cb({
            id: 'rep_prev_999',
            data: () => ({
              adId: 'ad_abc',
              timestamp: {
                toDate: () => new Date('2026-07-13T01:18:00.000Z') // 2 минуты назад
              }
            })
          });
        }
      };
    });

    // Мокаем Date.now(), чтобы текущее время в тесте соответствовало T01:20:00Z
    const originalDateNow = Date.now;
    Date.now = jest.fn(() => new Date('2026-07-13T01:20:00.000Z').getTime());

    try {
      await onNewReport(mockReportSnap, mockContext);
    } finally {
      Date.now = originalDateNow;
    }

    // Сообщение должно быть отброшено
    expect(tgSendSpy).not.toHaveBeenCalled();
  });
});

const { getFullUserInfo } = require('./functions/index');

describe('getFullUserInfo HTTPS Callable Tests', () => {
  const adminContext = {
    auth: { uid: 'admin_uid' }
  };

  const regularContext = {
    auth: { uid: 'regular_uid' }
  };

  beforeEach(() => {
    jest.clearAllMocks();
    mockGetUser.mockReset();
    mockAdd.mockReset();
  });

  test('Доступ запрещен не-авторизованному пользователю', async () => {
    await expect(getFullUserInfo({ targetUid: 'user_123' }, {}))
      .rejects.toThrow('Пользователь должен быть авторизован');
  });

  test('Доступ запрещен обычному пользователю (не-админу)', async () => {
    await expect(getFullUserInfo({ targetUid: 'user_123' }, regularContext))
      .rejects.toThrow('Доступ разрешен только администраторам');
  });

  test('Успешный сбор данных администратором (полный набор полей)', async () => {
    // Настраиваем mock для Auth
    mockGetUser.mockResolvedValueOnce({
      uid: 'user_123',
      email: 'user@test.com',
      emailVerified: true,
      phoneNumber: '+77779998877',
      displayName: 'Test User',
      photoURL: 'http://photo.com/user.jpg',
      disabled: false,
      customClaims: { premium: true },
      metadata: {
        creationTime: '2026-01-01T00:00:00Z',
        lastSignInTime: '2026-07-12T12:00:00Z',
        lastRefreshTime: '2026-07-12T12:00:00Z'
      },
      providerData: [
        { uid: 'user_123', providerId: 'password', email: 'user@test.com' }
      ]
    });

    // Настраиваем mock для Firestore коллекций (ads, reports, etc.)
    mockQuery.get.mockResolvedValue({
      size: 2,
      docs: [
        { id: 'doc_1', data: () => ({ title: 'Test Ad', price: 5000, status: 'active', rating: 5, comment: 'Good!' }) },
        { id: 'doc_2', data: () => ({ title: 'Test Ad 2', price: 9000, status: 'pending', rating: 4, comment: 'Nice!' }) }
      ]
    });

    const result = await getFullUserInfo({ targetUid: 'user_123' }, adminContext);

    // Проверяем запись в аудит-лог
    expect(mockAdd).toHaveBeenCalledTimes(1);
    expect(mockAdd).toHaveBeenCalledWith(expect.objectContaining({
      action: 'view_user_card',
      adminUid: 'admin_uid',
      targetUid: 'user_123'
    }));

    // Проверяем структуру ответа
    expect(result).toHaveProperty('auth');
    expect(result.auth.email).toBe('user@test.com');
    expect(result).toHaveProperty('profile');
    expect(result).toHaveProperty('ads');
    expect(result.ads).toHaveLength(2);
    expect(result.ads[0].title).toBe('Test Ad');
    expect(result).toHaveProperty('reportsAgainst');
    expect(result).toHaveProperty('reportsSubmitted');
    expect(result).toHaveProperty('reviewsTo');
    expect(result).toHaveProperty('reviewsFrom');
    expect(result.avgRating).toBe(4.8); // 4.8 directly from user profile since reviewsCount >= 5
    expect(result.chats.count).toBe(2);
    expect(result.taxiBidsSent).toHaveLength(2);
    expect(result.taxiBidsReceived).toHaveLength(2);
    expect(result.taxiOrdersPassenger).toHaveLength(2);
    expect(result.taxiOrdersDriver).toHaveLength(2);
  });

  test('Обработка несуществующего targetUid в Firebase Auth', async () => {
    // Настраиваем, чтобы getUser возвращал ошибку user-not-found
    mockGetUser.mockRejectedValueOnce(new Error('User not found'));



    const result = await getFullUserInfo({ targetUid: 'non_existent_uid' }, adminContext);

    expect(result.auth).toBeNull();
    expect(result.profile).toBeNull();
  });

  test('Проверка лимита 50 на запросы к связанным коллекциям', async () => {
    mockGetUser.mockResolvedValueOnce({ uid: 'user_123', metadata: {}, providerData: [] });

    // Считаем сколько раз был вызван limit(50)
    const limitSpy = jest.spyOn(mockQuery, 'limit');

    await getFullUserInfo({ targetUid: 'user_123' }, adminContext);

    expect(limitSpy).toHaveBeenCalledWith(50);
    expect(limitSpy.mock.calls.length).toBeGreaterThanOrEqual(9);
    limitSpy.mockRestore();
  });
});

const { onVoiceMessageUpload } = require('./functions/index');

describe('onVoiceMessageUpload Cloud Function Storage Trigger Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // Helper to create synthetic M4A buffer
  function createMockM4a(timescale, duration) {
    const mvhd = Buffer.alloc(36);
    mvhd.writeUInt32BE(36, 0); // size
    mvhd.write('mvhd', 4);     // type
    mvhd.writeUInt8(0, 8);     // version 0
    mvhd.writeUInt32BE(timescale, 20); // timescale
    mvhd.writeUInt32BE(duration, 24);  // duration
    
    const moov = Buffer.alloc(8 + 36);
    moov.writeUInt32BE(8 + 36, 0); // size
    moov.write('moov', 4);         // type
    mvhd.copy(moov, 8);
    
    const ftyp = Buffer.alloc(8);
    ftyp.writeUInt32BE(8, 0);
    ftyp.write('ftyp', 4);
    
    return Buffer.concat([ftyp, moov]);
  }

  test('Игнорирует загрузку файлов вне папки voice_messages/', async () => {
    const mockObject = {
      name: 'avatars/user_123/avatar.png',
      bucket: 'my-bucket'
    };
    await onVoiceMessageUpload(mockObject);
    expect(mockFileDownload).not.toHaveBeenCalled();
  });

  test('Успешно пропускает валидный файл голосового сообщения (< 190s)', async () => {
    const mockObject = {
      name: 'voice_messages/chat_abc/msg_123.m4a',
      bucket: 'my-bucket'
    };
    const buffer = createMockM4a(1000, 60000);
    mockFileDownload.mockResolvedValueOnce([buffer]);

    await onVoiceMessageUpload(mockObject);

    expect(mockFileDownload).toHaveBeenCalledTimes(1);
    expect(mockFileDelete).not.toHaveBeenCalled();
    expect(mockDocDelete).not.toHaveBeenCalled();
  });

  test('Удаляет голосовое сообщение и Firestore-документ, если длительность превышает 190s', async () => {
    const mockObject = {
      name: 'voice_messages/chat_abc/msg_123.m4a',
      bucket: 'my-bucket'
    };
    const buffer = createMockM4a(1000, 200000);
    mockFileDownload.mockResolvedValueOnce([buffer]);
    mockDocGet.mockResolvedValueOnce({ exists: true });

    await onVoiceMessageUpload(mockObject);

    expect(mockFileDownload).toHaveBeenCalledTimes(1);
    expect(mockFileDelete).toHaveBeenCalledTimes(1);
    expect(mockDocDelete).toHaveBeenCalledTimes(1);
  });

  test('Фоллбэк по размеру: одобряет поврежденный/непарсируемый файл, если размер < 3MB', async () => {
    const mockObject = {
      name: 'voice_messages/chat_abc/msg_123.m4a',
      bucket: 'my-bucket'
    };
    const buffer = Buffer.from('corrupted data');
    mockFileDownload.mockResolvedValueOnce([buffer]);
    mockFileGetMetadata.mockResolvedValueOnce([{ size: '2000000' }]);

    await onVoiceMessageUpload(mockObject);

    expect(mockFileDownload).toHaveBeenCalledTimes(1);
    expect(mockFileGetMetadata).toHaveBeenCalledTimes(1);
    expect(mockFileDelete).not.toHaveBeenCalled();
    expect(mockDocDelete).not.toHaveBeenCalled();
  });

  test('Фоллбэк по размеру: удаляет поврежденный/непарсируемый файл, если размер >= 3MB', async () => {
    const mockObject = {
      name: 'voice_messages/chat_abc/msg_123.m4a',
      bucket: 'my-bucket'
    };
    const buffer = Buffer.from('corrupted data');
    mockFileDownload.mockResolvedValueOnce([buffer]);
    mockFileGetMetadata.mockResolvedValueOnce([{ size: '3500000' }]);
    mockDocGet.mockResolvedValueOnce({ exists: true });

    await onVoiceMessageUpload(mockObject);

    expect(mockFileDownload).toHaveBeenCalledTimes(1);
    expect(mockFileGetMetadata).toHaveBeenCalledTimes(1);
    expect(mockFileDelete).toHaveBeenCalledTimes(1);
    expect(mockDocDelete).toHaveBeenCalledTimes(1);
  });
});
