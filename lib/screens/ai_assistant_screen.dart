import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'product_details_screen.dart';
import '../services/azure_tts_service.dart';
import '../services/gemini_service.dart';

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
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  bool _stopRequested = false;
  bool _showScamAlert = false;
  String _scamReason = "";
  int _questionCount = 0;

  String _currentLang = 'RU';
  final GeminiService _geminiService = GeminiService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  final Map<String, String> _responseCache = {};
  final List<File> _selectedFiles = [];
  final ImagePicker _picker = ImagePicker();
  final FlutterTts flutterTts = FlutterTts();
  final AzureTtsService _azureTts = AzureTtsService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initCurrentLang();
    _geminiService.init(_currentLang);
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
          if (val == 'done' || val == 'notListening') setState(() => _isListening = false);
        },
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  void _toggleVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        HapticFeedback.mediumImpact();
        _speech.listen(
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
              if (val.finalResult) {
                _isListening = false;
              }
            });
          },
          localeId: _currentLang == 'KZ' ? 'kk-KZ' : _currentLang == 'UG' ? 'tr-TR' : 'ru-RU',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Голосовой ввод недоступен на этом устройстве')),
        );
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

    setState(() => _isSpeaking = true);

    await _azureTts.speak(azureCleanText, _currentLang);

    if (!_isSpeaking) {
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

    setState(() => _isSpeaking = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _azureTts.stop();
    super.dispose();
  }

  void _addInitialMessage() {
    String welcomeText = _currentLang == 'KZ'
        ? 'Сәлем! Маған фото жіберіп, дауыспен немесе мәтінмен сұрақ қоя аласың! 🧠🎙️'
        : _currentLang == 'UG'
            ? 'Әссаламу әләйкүм! Маңа сүрәт әвәтип, давис йаки текст билән соал қойсиңиз болиду! 🧠🎙️'
            : 'Привет! Я твой IQ GPT. Можешь присылать фотографии, писать текстом или просто говорить голосом! Я оценю цену и помогу с описанием! 🧠🎙️';
    setState(() {
      _messages.add(
          {'isMe': false, 'text': welcomeText, 'time': DateFormat('HH:mm').format(DateTime.now())});
    });
  }

  Future<void> _pickMedia() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (photo != null) setState(() => _selectedFiles.add(File(photo.path)));
  }

  Future<List<Map<String, dynamic>>> _searchAdsInFirebase(String query) async {
    try {
      final q = query.toLowerCase().trim();
      List<Map<String, dynamic>> found = [];

      final snapshot = await FirebaseFirestore.instance
          .collection('ads')
          .where('title_lowercase', isGreaterThanOrEqualTo: q)
          .where('title_lowercase', isLessThanOrEqualTo: q + '\uf8ff')
          .limit(20)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        var adMap = data;
        adMap['id'] = doc.id;
        found.add(adMap);
      }

      if (found.isEmpty) {
        final List<Map<String, dynamic>> mockAds = [
          {
            'id': 'm1',
            'title': 'Nike Air Zoom Кроссовки',
            'price': '45 000',
            'category': 'Одежда',
            'image': 'https://img.icons8.com/color/512/sneakers.png'
          },
          {
            'id': 'm2',
            'title': 'Adidas Yeezy Boost',
            'price': '120 000',
            'category': 'Одежда',
            'image': 'https://img.icons8.com/color/512/sneakers.png'
          },
          {
            'id': 'm3',
            'title': 'iPhone 15 Pro',
            'price': '600 000',
            'category': 'Электроника',
            'image': 'https://img.icons8.com/color/512/iphone.png'
          },
          {
            'id': 'm4',
            'title': 'Toyota Camry 70',
            'price': '15 000 000',
            'category': 'Авто',
            'image': 'https://img.icons8.com/color/512/sedan.png'
          },
        ];
        final words = q.split(' ');
        for (var ad in mockAds) {
          final title = (ad['title'] ?? '').toString().toLowerCase();
          for (var word in words) {
            if (word.length > 2 && title.contains(word)) {
              if (!found.contains(ad)) found.add(ad);
              break;
            }
          }
        }
      }

      return found;
    } catch (e) {
      return [];
    }
  }

  void _sendMessage() async {
    String text = _controller.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) return;

    if (widget.isHomeMode) {
      _questionCount++;
      if (_questionCount > 3) {
        text +=
            "\n[SYSTEM INSTRUCTION: Пользователь превысил лимит на 3 общих вопроса. Начиная с этого момента, ВЕЖЛИВО сообщите ему, что лимит общих вопросов исчерпан, и вы можете отвечать ТОЛЬКО на вопросы, связанные с приложением IQ-Market (покупки, продажи) и IQ-Taxi (межгородское такси). Отвечайте коротко и не давайте ответы на сторонние темы.]";
      }
    }

    if (_selectedFiles.isEmpty && _responseCache.containsKey(text.toLowerCase())) {
      final cached = _responseCache[text.toLowerCase()]!;
      setState(() {
        _messages.add(
            {'isMe': true, 'text': text, 'time': DateFormat('HH:mm').format(DateTime.now())});
        _messages.add(
            {'isMe': false, 'text': cached, 'time': DateFormat('HH:mm').format(DateTime.now())});
        _controller.clear();
      });
      _scrollToBottom();
      return;
    }

    HapticFeedback.mediumImpact();

    final List<File> filesToUpload = List.from(_selectedFiles);
    final displayMsg = text.replaceAll(RegExp(r'\n\[SYSTEM INSTRUCTION:.*?\]'), '');

    setState(() {
      _messages.add({
        'isMe': true,
        'text': text.isEmpty
            ? (_currentLang == 'KZ'
                ? "Медиафайл"
                : _currentLang == 'UG'
                    ? "Медиаһөжҗәт"
                    : "Медиафайл")
            : displayMsg,
        'files': filesToUpload,
        'time': DateFormat('HH:mm').format(DateTime.now())
      });
      _isLoading = true;
      _selectedFiles.clear();
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final DateTime now = DateTime.now();
      final String timeStr = DateFormat('HH:mm').format(now);

      setState(() {
        _messages.add({'isMe': false, 'text': '', 'time': timeStr});
        _isLoading = false;
        _isStreaming = true;
        _stopRequested = false;
      });

      HapticFeedback.mediumImpact();

      String fullResponse = "";
      final responseStream = _geminiService.sendMessageStream(
          text.isEmpty
              ? (_currentLang == 'KZ'
                  ? "Бұл файлдарда не көрінеді?"
                  : _currentLang == 'UG'
                      ? "Бу һөжҗәтләрдә немә бар?"
                      : "Что на этих файлах?")
              : text,
          filesToUpload);

      await for (final chunk in responseStream) {
        if (_stopRequested) break;

        if (chunk.text != null) {
          fullResponse += chunk.text!;
          if (fullResponse.length % 7 == 0) HapticFeedback.selectionClick();

          setState(() {
            _messages.last['text'] = fullResponse;
          });
          _scrollToBottom();
        }
      }

      setState(() => _isStreaming = false);

      if (filesToUpload.isEmpty) {
        _responseCache[text.toLowerCase()] = fullResponse;
      }

      List<Map<String, dynamic>>? foundAds;
      final RegExp searchRegExp = RegExp(r'\[SEARCH:\s*(.*?)\]', caseSensitive: false);
      final match = searchRegExp.firstMatch(fullResponse);

      if (match != null) {
        String searchQuery = (match.group(1) ?? '').trim();
        if (searchQuery.length >= 3) {
          foundAds = await _searchAdsInFirebase(searchQuery);
        }
        String finalVisibleText = fullResponse.replaceAll(searchRegExp, '').trim();
        if (finalVisibleText.isEmpty) {
          finalVisibleText = _currentLang == 'KZ'
              ? 'Міне, мен тапқан тауарлар:'
              : _currentLang == 'UG'
                  ? 'Мән тапқан маллар:'
                  : 'Вот несколько товаров по вашему запросу:';
        }
        setState(() {
          _messages.last['text'] = finalVisibleText;
          if (foundAds != null && foundAds.isNotEmpty) {
            _messages.last['ads'] = foundAds;
          }

          if (fullResponse.toUpperCase().contains('ВНИМАНИЕ!') ||
              fullResponse.toUpperCase().contains('НАЗАР АУДАРЫҢЫЗ!') ||
              fullResponse.toUpperCase().contains('ДИҚҚӘТ!')) {
            _showScamAlert = true;
            _scamReason = finalVisibleText.split('\n').first;
          } else {
            _showScamAlert = false;
          }
        });
      } else {
        if (fullResponse.toUpperCase().contains('ВНИМАНИЕ!') ||
            fullResponse.toUpperCase().contains('НАЗАР АУДАРЫҢЫЗ!') ||
            fullResponse.toUpperCase().contains('ДИҚҚӘТ!')) {
          setState(() {
            _showScamAlert = true;
            _scamReason = fullResponse.split('\n').first;
          });
        }
      }

      _speak(fullResponse);
    } catch (e) {
      String errorStr = e.toString().toLowerCase();
      String errorMsg = _currentLang == 'KZ'
          ? 'Кешіріңіз, желі үзілді немесе серверде қате шықты. Қайтадан байқап көріңізші 🥺'
          : _currentLang == 'UG'
              ? 'Кәчүрүң, алақә үзүлүп қалди, қайта синап көрүң 🥺'
              : 'Извините, связь с нейросетью прервалась. Пожалуйста, попробуйте еще раз! 🥺';

      if (errorStr.contains('429') || errorStr.contains('quota')) {
        errorMsg = _currentLang == 'KZ'
            ? 'Лимит таусылды, бір минуттан соң қайталаңыз ⏳'
            : _currentLang == 'UG'
                ? 'Лимит түгәп қалди, бир минуттин кейин қайта синап көрүң ⏳'
                : 'Лимит запросов исчерпан, пожалуйста, подождите минуту ⏳';
      }

      if (_messages.isNotEmpty && _messages.last['isMe'] == false && _messages.last['text'] == '') {
        setState(() {
          _messages.last['text'] = errorMsg;
        });
      } else {
        setState(() {
          _messages.add({
            'isMe': false,
            'text': errorMsg,
            'time': DateFormat('HH:mm').format(DateTime.now())
          });
        });
      }
    } finally {
      setState(() => _isLoading = false);
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          margin: const EdgeInsets.only(top: 15, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFF00FF85), Color(0xFF00E5FF)]),
                              shape: BoxShape.circle),
                          child: const CircleAvatar(
                              radius: 17,
                              backgroundColor: Colors.black,
                              child: Icon(Icons.psychology_rounded, color: Colors.white, size: 20)),
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
                                    border: Border.all(color: Colors.black, width: 2)))),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0), Color(0xFF94A3B8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text("IQ GPT ✨",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.8)),
                        ),
                        Text(
                          _currentLang == 'KZ'
                              ? "Желіде • Тегін"
                              : _currentLang == 'UG' ? "Онлайн • Төләпсиз" : "В сети • Бесплатно",
                          style: TextStyle(
                              color: const Color(0xFF00FF85).withValues(alpha: 0.9),
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
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF1E40AF),
              Color(0xFF2563EB),
              Color(0xFF3B82F6),
            ],
            stops: [0.1, 0.4, 0.8, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 120, bottom: 20),
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
                  {"icon": "✍️", "title": "Текст йезиш", "desc": "Мал үшін сипатлима"},
                  {"icon": "⚖️", "title": "Баһани содилаш", "desc": "Базар билән тәкшүрүң"},
                  {"icon": "🤝", "title": "Арзанрақ сураш", "desc": "Содилашқини йардәм"},
                ]
              : [
                  {"icon": "✍️", "title": "Напиши текст", "desc": "Описание для товара"},
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
                  {"icon": "✍️", "title": "Текст йезиш", "desc": "Сетиш үшін текст"},
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
            onTap: () {
              _controller.text = suggestions[i]['title']! + " " + (suggestions[i]['desc'] ?? "");
              _sendMessage();
            },
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
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
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, height: 1.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestions[i]['desc']!,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w600),
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
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
          stops: const [0.3, 0.5, 0.7],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    if (_selectedFiles.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, i) => Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.withValues(alpha: 0.1)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isImage(_selectedFiles[i].path)
                    ? Image.file(_selectedFiles[i], fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.description_rounded, color: Color(0xFF4C4DDC))),
              ),
            ),
            Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                    onTap: () => setState(() => _selectedFiles.removeAt(i)),
                    child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 12)))),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isMe ? 24 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 24),
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isMe
                      ? Text(msg['text'],
                          style:
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))
                      : MarkdownBody(
                          data: msg['text'],
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.6),
                            strong: const TextStyle(
                                fontWeight: FontWeight.w900, color: Color(0xFF00E5FF)),
                          ),
                        ),
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
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: msg['text']));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано')));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
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
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
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
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                        Text(ad['title'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))
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
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 28),
                onPressed: _pickMedia),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                            hintText: _currentLang == 'KZ'
                                ? 'Сұрағыңыз...'
                                : _currentLang == 'UG' ? 'Соалиңиз...' : 'Ваш вопрос...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.cyanAccent.withValues(alpha: 0.6 * (1 - value)),
                                            spreadRadius: 20 * value,
                                            blurRadius: 15)
                                      ]),
                                  child: const Icon(Icons.mic, color: Color(0xFF2563EB), size: 24)),
                              onEnd: () => setState(() {}),
                            )
                          : const Icon(Icons.mic_none_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isStreaming ? () => setState(() => _stopRequested = true) : _sendMessage,
              child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 15)]),
                  child: Icon(_isStreaming ? Icons.stop_rounded : Icons.send_rounded,
                      color: const Color(0xFF2563EB), size: 22)),
            ),
          ],
        ),
      ),
    );
  }
}
