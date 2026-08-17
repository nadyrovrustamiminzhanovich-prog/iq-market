# 🚀 Журнал успешного релиза: IQ-Market v1.0.0 (3)

**Дата фиксации:** 18 августа 2026 г.  
**Статус в Google Play Console:** 🟡 «На рассмотрении» (In Review)  
**Режим релиза:** Управляемая публикация включена (Managed Publishing)  
**Команда разработки:** Senior QA Lead · Flutter Senior Engineer · Firebase Security Engineer · Release Manager

---

## 📌 1. Основные параметры сборки

| Параметр | Значение |
|---|---|
| **Название приложения** | IQ-Market |
| **Package Name (Application ID)** | `com.iqmarket.app` |
| **Версия (Version Name)** | `1.0.0` |
| **Код версии (Version Code)** | `3` |
| **Flutter SDK** | `3.41.4` (Channel stable) |
| **Dart SDK** | `3.11.1` |
| **Android Target SDK** | `36` (Android 16/15) |
| **Android Min SDK** | `24` (Android 7.0+) |
| **Java Environment** | OpenJDK 17 / OpenJDK 21 |

---

## 🔑 2. Сертификаты и подпись (Play App Signing)

Файл ключа подписи: `android/app/upload-keystore.jks`  
Конфигурационный файл: `android/key.properties`

* **Alias ключа:** `upload`
* **Пароль хранилища (Store Password):** `iqmarket2026`
* **Пароль ключа (Key Password):** `iqmarket2026`
* **Отпечаток SHA-1:** `21:D5:00:E5:6B:0E:3D:64:D7:24:F2:CC:34:CE:D0:02:4A:71:C3:A1`
* **Отпечаток SHA-256:** `C0:59:34:43:40:29:2C:C4:EB:25:F0:2E:C6:5C:D3:75:36:AB:F7:8F:03:BE:96:A2:1C:CC:E4:F3:C7:D5:67:82`

---

## ⚙️ 3. Настройки облачной сборки в GitHub Actions

В репозитории `https://github.com/nadyrovrustamiminzhanovich-prog/iq-market` настроен пайплайн `.github/workflows/flutter_ci.yml`.

Для автоматической сборки подписанного `.aab` файла в **Settings → Secrets and variables → Actions** прописаны 4 секрета:

1. `ANDROID_KEYSTORE_BASE64` — бинарный base64-слепок ключа `upload-keystore.jks`.
2. `ANDROID_KEYSTORE_STORE_PASSWORD` — `iqmarket2026`
3. `ANDROID_KEYSTORE_KEY_PASSWORD` — `iqmarket2026`
4. `ANDROID_KEYSTORE_KEY_ALIAS` — `upload`

Сборка запускается вручную кнопкой **Run workflow** во вкладке Actions и генерирует артефакт:  
📦 **`IQ-Market-SIGNED-ReadyForPlayStore`** (файл `app-release.aab`).

---

## 📝 4. Метаданные и материалы в Google Play Console

### 4.1. Текстовые материалы (Store Listing)
* **Название:** `IQ-Market`
* **Краткое описание:** `Удобный маркетплейс объявлений Казахстана: покупайте и продавайте с умом.` (71 символ)
* **Полное описание:** Фокус на умном поиске, безопасных сделках, торгах и чатах. Все упоминания такси исключены для соблюдения политик Google Play.
* **Примечания к выпуску (Release Notes):**
  ```text
  <ru-RU>
  Официальный релиз IQ-Market: умный маркетплейс объявлений Казахстана с удобным поиском товаров, защищенными чатами и возможностью предлагать свою цену!
  </ru-RU>
  ```

### 4.2. Графика и Скриншоты
* **Иконка приложения (512x512):** `google_play/app_icon.png`
* **Скриншоты телефонов (1080x1920):** Загружены скриншоты 1–5 из папки `google_play/screenshots/` (скриншоты такси 6 и 7 убраны).

### 4.3. Доступ для модераторов (App Access)
* **Логин (Email):** `google-test@iqmarket.kz`
* **Пароль:** `GoogleTest2026!`
* **Инструкция:** `Use email login on the main login screen with the provided email and password.`

### 4.4. Юридическая информация
* **Политика конфиденциальности (Privacy Policy):** `https://iq-market-3dc07.web.app/privacy/`
* **Удаление аккаунтов:** Интегрировано удаление через Cloud Function `deleteUserAccount` с очисткой приватных подколлекций.

---

## 🛡️ 5. Состояние безопасности и архитектуры

1. **Модуль Такси:** В коде установлена заглушка `TaxiComingSoonDialog` с поддержкой 3 языков (RU, KK, UG). Функция не вызывает крашей и защищена от ложных ожиданий пользователей.
2. **Безопасность Firestore & Storage:** Персональные телефоны/почты защищены в `private/contact`, рейтинг и отзывы защищены от накрутки, файлы Storage проверяются по размеру и MIME-типам.
3. **App Check & Crashlytics:** App Check активируется до первого обращения к базе данных, стектрейсы ошибок в релизе замаскированы.
4. **Android Permissions:** Лишние опасные разрешения исключены, используется системный Android Photo Picker.

---

## 🏁 6. Что делать после одобрения Google Play

1. Получить email от Google Play Console: *"Ваше приложение одобрено"*.
2. Зайти в **Google Play Console** ➔ **Обзор публикации (Publishing Overview)**.
3. Нажать синюю кнопку **«Опубликовать изменения»** (Publish changes).
4. Приложение появится в поиске Google Play для пользователей Казахстана в течение 1–2 часов.
