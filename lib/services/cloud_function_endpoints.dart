class CloudFunctionEndpoints {
  // 🔒 X10 SECURITY: Все секретные ключи перенесены в безопасную серверную среду Cloud Functions.
  // Клиентское приложение больше не хранит никаких токенов или API-ключей.

  static const String geminiProxyUrl = 'https://us-central1-iq-market-3dc07.cloudfunctions.net/secureGeminiCall';
  static const String telegramProxyUrl = 'https://us-central1-iq-market-3dc07.cloudfunctions.net/secureSendTelegramMessage';
  static const String sendOtpUrl = 'https://us-central1-iq-market-3dc07.cloudfunctions.net/sendTelegramOtp';
}
