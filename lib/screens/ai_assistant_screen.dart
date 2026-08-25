import 'dart:io';
import 'package:iqmarket/services/translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'product_details_screen.dart';
import '../services/azure_tts_service.dart';

import '../services/support_bot_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialLanguage;
  final Map<String, dynamic>? initialAd;
  final bool bargainMode;
  final bool isHomeMode;

  const AiAssistantScreen({
    Key? key,
    this.initialLanguage,
    this.initialAd,
    this.bargainMode = false,
    this.isHomeMode = false,
  }) : super(key: key);

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  String _getTranslationLang() {
    if (_currentLang == 'KZ') return 'Қазақша';
    if (_currentLang == 'UG') return 'Уйғурчә';
    return 'Русский';
  }
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _showScamAlert = false;
  String _scamReason = "";

  String _currentLang = 'RU';
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  final List<File> _selectedFiles = [];
  final ImagePicker _picker = ImagePicker();
  final FlutterTts flutterTts = FlutterTts();
  final AzureTtsService _azureTts = AzureTtsService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initCurrentLang();
    _initSpeech();
    _setupHighQualityVoice();
    
    if (widget.bargainMode && widget.initialAd != null) {
      _startBargaining();
    } else {
      _addInitialMessage();
    }
  }

  void _initCurrentLang() {
    if (widget.initialLanguage != null) {
      if (widget.initialLanguage == 'Қазақша')
        _currentLang = 'KZ';
      else if (widget.initialLanguage == 'Уйғурчә')
        _currentLang = 'UG';
      else
        _currentLang = 'RU';
    }
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onError: (val) => debugPrint('Speech Error: $val'),
        onStatus: (val) {
          if ((val == 'done' || val == 'notListening') && mounted) setState(() => _isListening = false);
        },
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  void _toggleVoice() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onError: (val) => debugPrint('Speech Error: $val'),
          onStatus: (val) {
            if ((val == 'done' || val == 'notListening') && mounted) {
              setState(() => _isListening = false);
            }
          },
        );
        if (available) {
          if (mounted) setState(() => _isListening = true);
          HapticFeedback.mediumImpact();
          _speech.listen(
            onResult: (val) {
              if (!mounted) return;
              setState(() {
                _controller.text = val.recognizedWords;
              });
              // Автоматически отправить сообщение после финального результата
              if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
                setState(() => _isListening = false);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted && _controller.text.trim().isNotEmpty) {
                    _sendMessage();
                  }
                });
              }
            },
            localeId: _currentLang == 'KZ' ? 'kk-KZ' : _currentLang == 'UG' ? 'tr-TR' : 'ru-RU',
            listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.confirmation),
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(TranslationService.t('voiceInputUnavailable', _getTranslationLang()))),
            );
          }
        }
      } catch (e) {
        debugPrint('Voice toggle error: $e');
        if (mounted) setState(() => _isListening = false);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _startBargaining() async {
    final ad = widget.initialAd!;
    final welcome = _currentLang == 'KZ'
        ? "Керемет таңдау! Қазір мен '${ad['title']}' тауарын зерттеп, саудаласуға көмектесемін... 🤝"
        : _currentLang == 'UG'
            ? "Апперин! Мән һазир '${ad['title']}' мални көрүп, содилашқини йардәм беримән... 🤝"
            : "Отличный выбор! Сейчас я изучу товар '${ad['title']}' и помогу тебе выгодно поторговаться... 🤝";

    setState(() {
      _messages.add(
          {'isMe': false, 'text': welcome, 'time': DateFormat('HH:mm').format(DateTime.now())});
      _isLoading = true;
    });

    final prompt =
        "Я хочу купить этот товар: '${ad['title']}'. Цена: ${ad['price']}. Описание: '${ad['desc'] ?? 'нет'}'. Проанализируй описание и состояние. Дай мне совет, как выгодно поторговаться, на что обратить внимание и какую цену предложить в качестве честной и справедливой. Ответь на языке: $_currentLang.";
    _controller.text = prompt;
    _sendMessage();
  }

  Future<void> _setupHighQualityVoice() async {
    String langCode = _currentLang == 'KZ' ? 'kk-KZ' : _currentLang == 'UG' ? 'ug-CN' : 'ru-RU';
    await flutterTts.setLanguage(langCode);

    if (_currentLang == 'KZ') {
      await flutterTts.setPitch(0.9);
      await flutterTts.setSpeechRate(0.45);
    } else if (_currentLang == 'UG') {
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.42);
    } else {
      await flutterTts.setPitch(1.05);
      await flutterTts.setSpeechRate(0.48);
    }

    try {
      if (Platform.isAndroid) {
        await flutterTts.setEngine("com.google.android.tts");
      }

      List<dynamic> voices = await flutterTts.getVoices;
      var bestVoice = voices.firstWhere(
        (v) =>
            v.toString().toLowerCase().contains('neural') && v.toString().contains(langCode),
        orElse: () => voices.firstWhere(
          (v) =>
              v.toString().toLowerCase().contains('google') && v.toString().contains(langCode),
          orElse: () => voices.firstWhere(
            (v) => v.toString().contains(langCode),
            orElse: () => null,
          ),
        ),
      );

      if (bestVoice != null) {
        await flutterTts.setVoice({"name": bestVoice["name"], "locale": bestVoice["locale"]});
      }
    } catch (e) {
      debugPrint("Error setting high quality voice: $e");
    }

    await flutterTts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    String azureCleanText = text.replaceAll(RegExp(r'\[SEARCH:.*?\]'), '').replaceAll(
        RegExp(
            r'[\u{1f300}-\u{1f5ff}\u{1f600}-\u{1f64f}\u{1f680}-\u{1f6ff}\u{1f900}-\u{1f9ff}\u{2600}-\u{26ff}\u{2700}-\u{27bf}]',
            unicode: true),
        '');

    if (mounted) setState(() => _isSpeaking = true);

    await _azureTts.speak(azureCleanText, _currentLang);

    if (mounted && !_isSpeaking) {
      String cleanText = azureCleanText;
      if (_currentLang == 'KZ' || _currentLang == 'UG') {
        cleanText = cleanText
            .replaceAll('ә', 'а')
            .replaceAll('Ә', 'А')
            .replaceAll('і', 'и')
            .replaceAll('І', 'И')
            .replaceAll('ң', 'н')
            .replaceAll('Ң', 'Н')
            .replaceAll('ғ', 'г')
            .replaceAll('Ғ', 'Г')
            .replaceAll('ү', 'у')
            .replaceAll('Ү', 'У')
            .replaceAll('ұ', 'у')
            .replaceAll('Ұ', 'У')
            .replaceAll('қ', 'к')
            .replaceAll('Қ', 'К')
            .replaceAll('ө', 'о')
            .replaceAll('Ө', 'О')
            .replaceAll('һ', 'х')
            .replaceAll('Һ', 'Х')
            .replaceAll('җ', 'ж')
            .replaceAll('Җ', 'Ж')
            .replaceAll('ق', 'к')
            .replaceAll('غ', 'г')
            .replaceAll('ڭ', 'н')
            .replaceAll('ژ', 'ж')
            .replaceAll('ئ', '')
            .replaceAll('ی', 'и');
      }
      cleanText = cleanText
          .replaceAll('!', '!... ')
          .replaceAll('?', '?... ')
          .replaceAll(':', ':... ')
          .replaceAll('.', '... ');

      await flutterTts.speak(cleanText);
    }

    if (mounted) setState(() => _isSpeaking = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _azureTts.stop();
    _azureTts.dispose();
    flutterTts.stop();
    _speech.cancel();
    super.dispose();
  }

  void _addInitialMessage() {
    String welcomeText = _currentLang == 'KZ'
        ? 'Сәлем! Мен сенің ЖИ-көмекшіңмін. 🚕✨\n\nIQ Market қосымшасы мен такси туралы кез келген сұрағыңызды қойыңыз. Көмектесуге әрқашан дайынмын!'
        : _currentLang == 'UG'
            ? 'Әссаламу әләйкум! Мән сизниң Сүнъий әқил йардәмчиңиз. 🚕✨\n\nIQ Market программиси вә такси соаллири бойичә кез кәлгән соал қойсиңиз болиду. Йардәм беришкә тәйярмән!'
            : 'Привет! Я твой ИИ-помощник. 🚕✨\n\nЗадавай любые вопросы по работе с приложением IQ Market и Такси межгород. Я всегда готов помочь!';
    setState(() {
      _messages.add(
          {'isMe': false, 'text': welcomeText, 'time': DateFormat('HH:mm').format(DateTime.now())});
    });
  }

  Future<void> _pickMedia() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo != null && mounted) {
        setState(() => _selectedFiles.add(File(photo.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.t('errChoosePhoto', _getTranslationLang()).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent),
        );
      }
    }
  }





  void _sendMessage() async {
    if (_isLoading) return;
    String text = _controller.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) return;

    HapticFeedback.mediumImpact();

    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    if (mounted) {
      setState(() {
        _messages.add({
          'isMe': true,
          'text': text.isEmpty ? "Медиафайл" : text,
          'time': timeStr,
        });
        _messages.add({
          'isMe': false,
          'text': '',
          'time': timeStr,
          'loading': true,
        });
        _isLoading = true;
        _controller.clear();
        _selectedFiles.clear();
      });
    }
    _scrollToBottom();

    try {
      final reply = await SupportBotService.processMessage(
        userMessage: text,
        mode: 'market',
        lang: _currentLang,
        chatHistory: [],
      );

      if (mounted) {
        setState(() {
          _messages.last = {
            'isMe': false,
            'text': reply.text,
            'time': timeStr,
            'loading': false,
            'showContact': reply.showContact,
            'isOffline': reply.isOffline,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = {
            'isMe': false,
            'text': 'Ошибка: $e',
            'time': timeStr,
            'loading': false,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final double current = _scrollController.position.pixels;
        final double max = _scrollController.position.maxScrollExtent;
        if (max - current < 150) {
          _scrollController.animateTo(max,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          margin: const EdgeInsets.only(top: 15, left: 16, right: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95), // Lite mode instead of BackdropFilter
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF4A80F0), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF6366F1)]),
                              shape: BoxShape.circle),
                          child: const CircleAvatar(
                              radius: 17,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.psychology_rounded, color: Color(0xFF4A80F0), size: 20)),
                        ),
                        Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: const Color(0xFF00FF85),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2)))),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("IQ GPT ✨",
                            style: GoogleFonts.inter(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: 0.5)),
                        Text(
                          _currentLang == 'KZ'
                              ? "Желіде • Көмекші"
                              : _currentLang == 'UG' ? "Онлайн • Йардәмчи" : "В сети • Ассистент",
                          style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEDF2F7),
              Color(0xFFF7FAFC),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 105), // Space for header
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessage(_messages[index]),
                  ),
                ),
                if (_isLoading) _buildSkeletonLoader(),
                _buildAttachmentPreview(),
                if (!isKeyboardOpen) _buildSuggestionChips(),
                _inputArea(),
              ],
            ),
            if (_showScamAlert) _buildScamBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildScamBanner() {
    return Positioned(
      top: 110,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -50 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              _currentLang == 'KZ'
                                  ? "САҚ БОЛЫҢЫЗ!"
                                  : _currentLang == 'UG' ? "САҚ БОЛУҢ!" : "ВНИМАНИЕ!",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5)),
                          Text(_scamReason,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: () => setState(() => _showScamAlert = false),
                        icon: const Icon(Icons.close, color: Colors.white, size: 18)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionChips() {
    if (_messages.isEmpty) return const SizedBox.shrink();

    final lastMsg = _messages.last;
    final bool isAi = lastMsg['isMe'] == false;
    final bool hasAds = isAi && lastMsg['ads'] != null;

    List<Map<String, String>> suggestions;

    if (hasAds) {
      suggestions = _currentLang == 'KZ'
          ? [
              {"icon": "✍️", "title": "Сипаттама жаз", "desc": "Таңдалған тауарға"},
              {"icon": "⚖️", "title": "Бағаны салыстыру", "desc": "Нарықпен тексер"},
              {"icon": "🤝", "title": "Саудаласу", "desc": "Арзандатуды сұра"},
            ]
          : _currentLang == 'UG'
              ? [
                  {"icon": "✍️", "title": "Текст йезиш", "desc": "Мал үчүн сипатлима"},
                  {"icon": "⚖️", "title": "Баһани содилаш", "desc": "Базар билән тәкшүрүң"},
                  {"icon": "🤝", "title": "Арзанрақ сураш", "desc": "Содилашқини йардәм"},
                ]
              : [
                  {"icon": "✍️", "title": "Напиши text", "desc": "Описание для товара"},
                  {"icon": "⚖️", "title": "Сравни цены", "desc": "Анализ рынка"},
                  {"icon": "🤝", "title": "Как торговаться?", "desc": "Советы профи"},
                ];
    } else if (_messages.length == 1) {
      suggestions = _currentLang == 'KZ'
          ? [
              {"icon": "💰", "title": "Бағалау", "desc": "Тауар бағасын біл"},
              {"icon": "✍️", "title": "Сипаттама", "desc": "Сату үшін текст"},
              {"icon": "🔍", "title": "Тауар табу", "desc": "Ұқсас зат іздеу"},
            ]
          : _currentLang == 'UG'
              ? [
                  {"icon": "💰", "title": "Баһалаш", "desc": "Төвән баһани билиң"},
                  {"icon": "✍️", "title": "Текст йезиш", "desc": "Сетиш үчүн текст"},
                  {"icon": "🔍", "title": "Мал тепиш", "desc": "Охшаш мал издәш"},
                ]
              : [
                  {"icon": "💰", "title": "Оценка", "desc": "Узнай рыночную цену"},
                  {"icon": "✍️", "title": "Описание", "desc": "Текст для рекламы"},
                  {"icon": "🔍", "title": "Найти товар", "desc": "Поиск по базе"},
                ];
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      height: 110,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _isLoading ? null : () {
              _controller.text = suggestions[i]['title']! + " " + (suggestions[i]['desc'] ?? "");
              _sendMessage();
            },
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(suggestions[i]['icon']!, style: const TextStyle(fontSize: 22)),
                      const Icon(Icons.bolt_rounded, color: Color(0xFF3B82F6), size: 16),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    suggestions[i]['title']!,
                    style: GoogleFonts.inter(
                        color: const Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 13, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestions[i]['desc']!,
                    style: GoogleFonts.inter(
                        color: const Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -2.0, end: 2.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.linear,
      builder: (context, value, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBox(180, 20, value, 10),
              const SizedBox(height: 10),
              _skeletonBox(260, 60, value, 18),
              const SizedBox(height: 10),
              _skeletonBox(140, 20, value, 10),
            ],
          ),
        );
      },
    );
  }

  Widget _skeletonBox(double w, double h, double offset, double radius) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(offset - 0.5, -0.3),
          end: Alignment(offset + 0.5, 0.3),
          colors: [
            const Color(0xFFE2E8F0),
            const Color(0xFFF1F5F9),
            const Color(0xFFE2E8F0),
          ],
          stops: const [0.3, 0.5, 0.7],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, i) => Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  color: const Color(0xFFF8FAFC)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _isImage(_selectedFiles[i].path)
                    ? Image.file(_selectedFiles[i], fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.description_rounded, color: Color(0xFF4A80F0))),
              ),
            ),
            Positioned(
                right: 4,
                top: 0,
                child: GestureDetector(
                    onTap: () => setState(() => _selectedFiles.removeAt(i)),
                    child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 10)))),
          ],
        ),
      ),
    );
  }

  bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    bool isMe = msg['isMe'] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (msg['image_path'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(File(msg['image_path']), width: 220, fit: BoxFit.cover),
              ),
            ),
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: msg['text']));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('textCopiedMsg', _getTranslationLang()))));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
              decoration: BoxDecoration(
                gradient: isMe 
                    ? const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isMe ? 24 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 24),
                ),
                border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: isMe ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isMe
                      ? Text(msg['text'],
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5, height: 1.45))
                      : MarkdownBody(
                          data: msg['text'],
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 14.5, height: 1.55, fontWeight: FontWeight.w500),
                            strong: GoogleFonts.inter(
                                fontWeight: FontWeight.w800, color: const Color(0xFF3B82F6)),
                          ),
                        ),
                  if (msg['showContact'] == true) _buildInlineContactWidget(),
                  if (!isMe) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => _speak(msg['text']),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.volume_up_rounded, color: Color(0xFF64748B), size: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: msg['text']));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('copiedMsg', _getTranslationLang()))));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (msg['ads'] != null) _buildAdCarousel(msg['ads']),
        ],
      ),
    );
  }

  Widget _buildInlineContactWidget() {
    final String waMsg = _currentLang == 'KZ'
        ? 'Сәлеметсіз бе! Маған IQ-Market қосымшасы бойынша көмек керек.'
        : _currentLang == 'UG'
            ? 'Әссаламу әлейкум! Маңа IQ-Market программиси бойичә йардәм керәк.'
            : 'Здравствуйте! Мне нужна помощь по приложению IQ-Market.';

    Future<void> openWhatsApp() async {
      final msg = Uri.encodeComponent(waMsg);
      final wa = Uri.parse('whatsapp://send?phone=77089007030&text=$msg');
      final waWeb = Uri.parse('https://wa.me/77089007030?text=$msg');
      if (await canLaunchUrl(wa)) {
        await launchUrl(wa, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waWeb, mode: LaunchMode.externalApplication);
      }
    }

    Future<void> openTelegram() async {
      final msg = Uri.encodeComponent(waMsg);
      final tg = Uri.parse('https://t.me/+77089007030?text=$msg');
      await launchUrl(tg, mode: LaunchMode.externalApplication);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: openWhatsApp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text('WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: openTelegram,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF24A1DE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.telegramLogo(PhosphorIconsStyle.fill), color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text('Telegram', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdCarousel(List ads) {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ads.length,
        itemBuilder: (context, i) {
          final ad = ads[i];
          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(
                        ad: ad,
                        onReport: (id) {},
                        lang: widget.initialLanguage ?? 'Русский',
                        heroPrefix: 'ai_'))),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Hero(
                        tag: 'ai_ad-image-${ad['id']}',
                        child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: ad['image'] != null && ad['image'].toString().startsWith('http')
                                ? Image.network(ad['image'], fit: BoxFit.cover, width: double.infinity)
                                : Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.image_outlined, color: Colors.grey))),
                      )),
                  Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${ad['price']} ₸',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF2563EB))),
                        Text(ad['title'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))
                      ])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF4F46E5), size: 28),
                onPressed: _pickMedia),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14.5),
                        decoration: InputDecoration(
                            hintText: _currentLang == 'KZ'
                                ? 'Сұрағыңыз...'
                                : _currentLang == 'UG' ? 'Соалиңиз...' : 'Ваш вопрос...',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 14),
                            border: InputBorder.none),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleVoice,
                      child: _isListening
                          ? TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              builder: (context, value, child) => Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.6 * (1 - value)),
                                            spreadRadius: 20 * value,
                                            blurRadius: 15)
                                      ]),
                                  child: const Icon(Icons.mic, color: Colors.white, size: 20)),
                              onEnd: () => setState(() {}),
                            )
                          : const Icon(Icons.mic_none_rounded, color: Color(0xFF64748B), size: 26),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
