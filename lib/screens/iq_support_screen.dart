import 'package:flutter/material.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/support_bot_service.dart';

// ─────────────────────────────────────────────────────────────────
//  IQ-Поддержка v2 — Offline-first ИИ-ассистент поддержки
//  Tier 1: Мгновенные ответы из базы FAQ (без интернета)
//  Tier 2: Умный keyword-матчинг тем
//  Tier 3: Gemini API — тематические вопросы (безлимитно)
//  Tier 4: Gemini API — офтопик (3 вопроса / 24 часа)
// ─────────────────────────────────────────────────────────────────

class IqSupportScreen extends StatefulWidget {
  final String lang;
  final String initialMode;
  const IqSupportScreen({
    super.key,
    required this.lang,
    this.initialMode = 'market',
  });
  @override
  State<IqSupportScreen> createState() => _IqSupportScreenState();
}

class _IqSupportScreenState extends State<IqSupportScreen>
    with SingleTickerProviderStateMixin {
  late String _mode;
  late String _lang;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  bool _isLoading = false;



  // ── Локализация ──────────────────────────────────────────────────
  String _t(String key) {
    const t = <String, Map<String, String>>{
      'title': {'RU': 'IQ-Поддержка', 'KZ': 'IQ-Қолдау', 'UG': 'IQ-Йардәм'},
      'market': {'RU': 'Маркет', 'KZ': 'Маркет', 'UG': 'Маркет'},
      'taxi': {'RU': 'Такси', 'KZ': 'Такси', 'UG': 'Такси'},
      'hint': {
        'RU': 'Напишите ваш вопрос...',
        'KZ': 'Сұрағыңызды жазыңыз...',
        'UG': 'Соалиңизни йезиң...',
      },
      'send': {'RU': 'Отправить', 'KZ': 'Жіберу', 'UG': 'Жибериш'},
      'copy': {'RU': 'Скопировано', 'KZ': 'Көшірілді', 'UG': 'Көчүрүлди'},
      'templates_title': {
        'RU': 'Частые вопросы',
        'KZ': 'Жиі сұрақтар',
        'UG': 'Дайим соаллар',
      },
      'welcome_market': {
        'RU': 'Привет! 👋 Я IQ-Поддержка — ваш персональный ИИ-помощник по IQ-Market.\n\nЗадавайте любые вопросы по работе с приложением, и я постараюсь мгновенно помочь вам! 🚀',
        'KZ': 'Сәлем! 👋 Мен IQ-Қолдау — IQ-Market бойынша жеке көмекшіңізбін.\n\nҚосымшаның жұмысына қатысты кез келген сұрақтарды қойыңыз, мен сізге дереу көмектесуге тырысамын! 🚀',
        'UG': 'Мәрһәба! 👋 Мән IQ-Йардәм — IQ-Market бойичә шәхсий йардәмчиңизмән.\n\nПрограмма бойичә һәр қандақ соалларни йезиң, мән сиргә дәрһал йардәм беришкә тиришимән! 🚀',
      },
      'welcome_taxi': {
        'RU': 'Привет! 🚕 Я IQ-Поддержка Такси — помогу с любым вопросом по IQ-Taxi.\n\nСпрашивайте о заказах, правилах, тарифах или условиях работы водителей! 💫',
        'KZ': 'Сәлем! 🚕 Мен IQ-Қолдау Такси — IQ-Taxi бойынша кез келген сұраққа жауап беремін.\n\nТапсырыстар, ережелер, тарифтер немесе жүргізушілердің жұмыс шарттары туралы сұраңыз! 💫',
        'UG': 'Мәрһәба! 🚕 Мән IQ-Йардәм Такси — IQ-Taxi бойичә йардәм беримән.\n\nЗаказлар, қаидиләр, тарифлар яки айдавчиларниң иш шараитлири тоғрилиқ соалларни йезиң! 💫',
      },
      'wa_msg': {
        'RU': 'Здравствуйте! Мне нужна помощь по приложению IQ-Market.',
        'KZ': 'Сәлеметсіз бе! Маған IQ-Market қосымшасы бойынша көмек керек.',
        'UG': 'Әссаламу әлейкум! Маңа IQ-Market программиси бойичә йардәм керәк.',
      },
      'limit_banner': {
        'RU': '⏳ Общие вопросы (лимит 3/день): осталось {n}',
        'KZ': '⏳ Жалпы сұрақтар (лимит 3/күн): қалды {n}',
        'UG': '⏳ Умумий соаллар (лимит 3/күн): қалди {n}',
      },
    };
    return t[key]?[_lang] ?? t[key]?['RU'] ?? key;
  }

  // ── Шаблонные вопросы ────────────────────────────────────────────
  List<Map<String, String>> get _templates {
    if (_mode == 'taxi') {
      return (<String, List<Map<String, String>>>{
        'RU': [
          {'icon': '🚗', 'text': 'Как заказать такси?'},
          {'icon': '🧑‍✈️', 'text': 'Как стать водителем?'},
          {'icon': '💰', 'text': 'Как торговаться по цене?'},
          {'icon': '❌', 'text': 'Как отменить поездку?'},
          {'icon': '🧳', 'text': 'Сколько багажа можно взять?'},
          {'icon': '⭐', 'text': 'Как оценить водителя?'},
          {'icon': '🛡️', 'text': 'Безопасно ли такси?'},
          {'icon': '📍', 'text': 'Какие города есть в IQ-Taxi?'},
        ],
        'KZ': [
          {'icon': '🚗', 'text': 'Такси қалай тапсырыс беруге болады?'},
          {'icon': '🧑‍✈️', 'text': 'Жүргізуші болу үшін не істеу керек?'},
          {'icon': '💰', 'text': 'Баға бойынша қалай сауда жасауға болады?'},
          {'icon': '❌', 'text': 'Сапардан қалай бас тартуға болады?'},
          {'icon': '🧳', 'text': 'Қанша жүк ала аламын?'},
          {'icon': '⭐', 'text': 'Жүргізушіні қалай бағалауға болады?'},
          {'icon': '🛡️', 'text': 'Такси қауіпсіз бе?'},
          {'icon': '📍', 'text': 'IQ-Taxi-де қандай қалалар бар?'},
        ],
        'UG': [
          {'icon': '🚗', 'text': 'Такси қандақ заказ қилиш керәк?'},
          {'icon': '🧑‍✈️', 'text': 'Айдавчи болуш үчүн немә қилиш керәк?'},
          {'icon': '💰', 'text': 'Баһа бойичә қандақ сөдигирлиш керәк?'},
          {'icon': '❌', 'text': 'Сәпәрдин қандақ вас кечиш керәк?'},
          {'icon': '🧳', 'text': 'Қанчә юк ала аламән?'},
          {'icon': '⭐', 'text': 'Айдавчини қандақ баһалаш керәк?'},
          {'icon': '🛡️', 'text': 'Такси хәвипсизму?'},
          {'icon': '📍', 'text': 'IQ-Taxi-дә қайси шәһәрләр бар?'},
        ],
      })[_lang] ?? [];
    } else {
      return (<String, List<Map<String, String>>>{
        'RU': [
          {'icon': '📢', 'text': 'Как разместить объявление?'},
          {'icon': '✏️', 'text': 'Как редактировать объявление?'},
          {'icon': '🔍', 'text': 'Как найти товар?'},
          {'icon': '❤️', 'text': 'Как добавить в избранное?'},
          {'icon': '🔑', 'text': 'Как восстановить пароль?'},
          {'icon': '🚫', 'text': 'Почему моё объявление не отображается?'},
          {'icon': '🛡️', 'text': 'Как пожаловаться на мошенника?'},
          {'icon': '🗑️', 'text': 'Как удалить аккаунт?'},
        ],
        'KZ': [
          {'icon': '📢', 'text': 'Хабарландыруды қалай беруге болады?'},
          {'icon': '✏️', 'text': 'Хабарландыруды қалай өңдеуге болады?'},
          {'icon': '🔍', 'text': 'Тауарды қалай табуға болады?'},
          {'icon': '❤️', 'text': 'Таңдаулыға қалай қосуға болады?'},
          {'icon': '🔑', 'text': 'Құпия сөзді қалай қалпына келтіруге болады?'},
          {'icon': '🚫', 'text': 'Неліктен менің хабарландырум көрінбейді?'},
          {'icon': '🛡️', 'text': 'Алаяқтыққа қалай шағым беруге болады?'},
          {'icon': '🗑️', 'text': 'Аккаунтты қалай жоюға болады?'},
        ],
        'UG': [
          {'icon': '📢', 'text': 'Елан қандақ чиқириш керәк?'},
          {'icon': '✏️', 'text': 'Еланни қандақ өзгәртиш керәк?'},
          {'icon': '🔍', 'text': 'Мални қандақ тепиш керәк?'},
          {'icon': '❤️', 'text': 'Таллиғанларға қандақ қошиш керәк?'},
          {'icon': '🔑', 'text': 'Шифирни қандақ яңилаш керәк?'},
          {'icon': '🚫', 'text': 'Немишкә еланим көрүнмәйду?'},
          {'icon': '🛡️', 'text': 'Алдамчиға қандақ шикайәт қилиш керәк?'},
          {'icon': '🗑️', 'text': 'Аккаунтни қандақ өчүриш керәк?'},
        ],
      })[_lang] ?? [];
    }
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _lang = widget.lang == 'Қазақша'
        ? 'KZ'
        : widget.lang == 'Уйғурчә'
            ? 'UG'
            : 'RU';
    _addWelcome();
  }

  void _addWelcome() {
    final key = _mode == 'taxi' ? 'welcome_taxi' : 'welcome_market';
    _messages.add({
      'isMe': false,
      'text': _t(key),
      'time': DateFormat('HH:mm').format(DateTime.now()),
      'type': 'welcome',
    });
  }

  void _switchMode(String newMode) {
    if (_mode == newMode) return;
    setState(() {
      _mode = newMode;
      _messages.clear();
    });
    _addWelcome();
  }

  // ── Отправка сообщения ────────────────────────────────────────────
  Future<void> _sendMessage({String? override}) async {
    final text = (override ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    HapticFeedback.mediumImpact();
    final now = DateFormat('HH:mm').format(DateTime.now());

    // Add user message
    setState(() {
      _messages.add({'isMe': true, 'text': text, 'time': now});
      // Placeholder for bot reply
      _messages.add({
        'isMe': false,
        'text': '',
        'time': now,
        'loading': true,
      });
      _isLoading = true;
    });
    _scrollToBottom();

    // Build chat history for AI context (last 10 messages, skip placeholder)
    final history = _messages
        .where((m) => m['loading'] != true && (m['text'] as String).isNotEmpty)
        .take(10)
        .toList();

    try {
      final reply = await SupportBotService.processMessage(
        userMessage: text,
        mode: _mode,
        lang: _lang,
        chatHistory: history,
      );

      if (!mounted) return;
      setState(() {
        // Replace placeholder
        _messages.last = {
          'isMe': false,
          'text': reply.text,
          'time': now,
          'loading': false,
          'type': reply.type.name,
          'isOffline': reply.isOffline,
          'showContact': reply.showContact,
        };
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = {
            'isMe': false,
            'text': 'Ошибка: $e',
            'time': now,
            'loading': false,
            'type': 'text',
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
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openWhatsApp() async {
    final msg = Uri.encodeComponent(_t('wa_msg'));
    final wa = Uri.parse('whatsapp://send?phone=77089007030&text=$msg');
    final waWeb = Uri.parse('https://wa.me/77089007030?text=$msg');
    try {
      if (await canLaunchUrl(wa)) {
        await launchUrl(wa, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waWeb, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.t('errWhatsappUnavailable', widget.lang)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _openTelegram() async {
    final msg = Uri.encodeComponent(_t('wa_msg'));
    final tg = Uri.parse('https://t.me/+77089007030?text=$msg');
    try {
      if (await canLaunchUrl(tg)) {
        await launchUrl(tg, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(TranslationService.t('errTelegramUnavailable', widget.lang)), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.t('errTelegramUnavailable', widget.lang)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessages()),
          if (_messages.length <= 2) _buildTemplates(),
          _buildLiveSupportHeaderPill(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: const Icon(Icons.smart_toy_rounded,
                            color: Colors.white, size: 26),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('title'),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'IQ GPT • Online',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildModeSwitch(),
          ],
        ),
      ),
    );
  }

  // ── MODE SWITCH ───────────────────────────────────────────────────
  Widget _buildModeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _modeTab('market', Icons.storefront_rounded, _t('market')),
            _modeTab('taxi', Icons.local_taxi_rounded, _t('taxi')),
          ],
        ),
      ),
    );
  }

  Widget _modeTab(String mode, IconData icon, String label) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? const Color(0xFF1E3A8A)
                      : Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: selected
                      ? const Color(0xFF1E3A8A)
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ── MESSAGES ──────────────────────────────────────────────────────
  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final isMe = msg['isMe'] as bool;
        final text = msg['text'] as String;
        final time = msg['time'] as String;
        final loading = msg['loading'] as bool? ?? false;
        final showContact = msg['showContact'] as bool? ?? false;
        final isOffline = msg['isOffline'] as bool? ?? false;
        final msgType = msg['type'] as String? ?? '';

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () {
                  if (text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('copy')),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                    );
                  }
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.84,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                    border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: (isMe
                                ? const Color(0xFF2563EB)
                                : Colors.black)
                            .withValues(alpha: isMe ? 0.25 : 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Source badge for bot messages
                      if (!isMe && !loading && text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildSourceBadge(msgType, isOffline),
                        ),
                      // Content
                      if (loading)
                        _buildTypingIndicator()
                      else
                        Text(
                          text,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isMe
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      if (showContact && !loading) ...[
                        const SizedBox(height: 12),
                        _buildInlineContact(),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                child: Text(
                  time,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceBadge(String type, bool isOffline) {
    String label;
    Color color;
    IconData icon;

    if (type == BotReplyType.faqMatch.name) {
      label = _lang == 'KZ' ? 'Жауап базасы' : _lang == 'UG' ? 'Базидин' : 'База ответов';
      color = const Color(0xFF10B981);
      icon = Icons.bolt_rounded;
    } else if (isOffline) {
      label = _lang == 'KZ' ? 'Офлайн' : _lang == 'UG' ? 'Оффлайн' : 'Офлайн';
      color = const Color(0xFF8B5CF6);
      icon = Icons.offline_bolt_rounded;
    } else {
      label = 'IQ GPT';
      color = const Color(0xFF2563EB);
      icon = Icons.auto_awesome_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.2, end: 1.0),
          duration: Duration(milliseconds: 450 + i * 150),
          builder: (_, val, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: val),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInlineContact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniContactBtn(
          icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
          color: const Color(0xFF10B981),
          label: 'WhatsApp',
          onTap: _openWhatsApp,
        ),
        const SizedBox(width: 8),
        _miniContactBtn(
          icon: PhosphorIcons.telegramLogo(PhosphorIconsStyle.fill),
          color: const Color(0xFF0284C7),
          label: 'Telegram',
          onTap: _openTelegram,
        ),
      ],
    );
  }

  Widget _miniContactBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TEMPLATES ─────────────────────────────────────────────────────
  Widget _buildTemplates() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(14, 6, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 12),
            child: Text(
              _t('templates_title').toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length,
              itemBuilder: (ctx, i) {
                final t = _templates[i];
                return GestureDetector(
                  onTap: _isLoading ? null : () => _sendMessage(override: t['text']),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t['icon']!,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          t['text']!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── LIVE SUPPORT COMPACT BAR ──────────────────────────────────────
  Widget _buildLiveSupportHeaderPill() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.headset_mic_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Живой оператор:',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _openWhatsApp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), color: const Color(0xFF10B981), size: 13),
                      const SizedBox(width: 4),
                      Text('WhatsApp', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF047857))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openTelegram,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.telegramLogo(PhosphorIconsStyle.fill), color: const Color(0xFF0284C7), size: 13),
                      const SizedBox(width: 4),
                      Text('Telegram', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0369A1))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── INPUT BAR ─────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: _t('hint'),
                    hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _isLoading
                      ? const LinearGradient(
                          colors: [Color(0xFFCBD5E1), Color(0xFFCBD5E1)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isLoading
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
