import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/screens/iq_support_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TaxiSupportScreen extends StatefulWidget {
  final TaxiTheme t;
  const TaxiSupportScreen({super.key, required this.t});

  @override
  State<TaxiSupportScreen> createState() => _TaxiSupportScreenState();
}

class _TaxiSupportScreenState extends State<TaxiSupportScreen> {
  String _query = '';
  int _selectedCat = 0;

  String _t(TaxiProvider provider, String key) {
    // Custom localized overrides for the support section
    final ru = {
      'title': 'Помощь и поддержка',
      'search_hint': 'Поиск по вопросам...',
      'questions': 'вопросов найдено',
      'all': 'Все',
      'general': 'Общее',
      'taxi': 'IQ Такси',
      'account': 'Аккаунт',
      'operator_title': 'Нужна живая помощь?',
      'operator_hours': 'Операторы онлайн • с 10:00 до 21:00',
      'wa_support': 'WhatsApp',
      'tg_support': 'Telegram',
      'wa_message': 'Здравствуйте! Мне нужна помощь по IQ-Market (Такси и Объявления).',
      'ai_assistant_title': 'IQ ПОМОЩНИК (TAXI GPT) 🤖',
      'ai_assistant_desc': 'Быстрый ИИ-помощник • Ответит на любые вопросы!',
    };

    final kz = {
      'title': 'Қолдау және көмек',
      'search_hint': 'Сұрақтар бойынша іздеу...',
      'questions': 'сұрақ табылды',
      'all': 'Барлығы',
      'general': 'Жалпы',
      'taxi': 'IQ Такси',
      'account': 'Профиль',
      'operator_title': 'Жанды көмек керек пе?',
      'operator_hours': 'Операторлар онлайн • 10:00-ден 21:00-ге дейін',
      'wa_support': 'WhatsApp',
      'tg_support': 'Telegram',
      'wa_message': 'Сәлеметсіз бе! Маған IQ-Market (Такси және Хабарландырулар) бойынша көмек керек.',
      'ai_assistant_title': 'IQ КӨМЕКШІСІ (TAXI GPT) 🤖',
      'ai_assistant_desc': 'Жылдам ЖИ-көмекші • Кез келген сұраққа жауап береді!',
    };

    final uyg = {
      'title': 'Йардәм вә қоллаш',
      'search_hint': 'Соаллар бойичә издәш...',
      'questions': 'соал тепилди',
      'all': 'Һәммиси',
      'general': 'Умумий',
      'taxi': 'IQ Такси',
      'account': 'Һесабат',
      'operator_title': 'Мулазимчи йардими керәкму?',
      'operator_hours': 'Мулазимчилар онлайн • 10:00 дин 21:00 гичә',
      'wa_support': 'WhatsApp',
      'tg_support': 'Telegram',
      'wa_message': 'Әссаламу әлейкум! Маңа IQ-Market (Такси вә Еланлар) бойичә йардәм керәк еди.',
      'ai_assistant_title': 'IQ ЯРДӘМЧИСИ (TAXI GPT) 🤖',
      'ai_assistant_desc': 'Тез Сүнъий әқил йардәмчиси • Һәр қандақ соалға җавап бериду!',
    };

    final String lang = provider.curLang;
    final dict = lang == 'kz' ? kz : (lang == 'uyg' ? uyg : ru);
    return dict[key] ?? ru[key] ?? key;
  }

  // Pre-translated high-quality Taxi & Ads FAQ data
  final List<Map<String, String>> _faqRu = [
    {'cat': 'taxi', 'q': 'Как заказать межгородное такси?', 'a': 'Перейдите в раздел «IQ Такси» → вкладка «Пассажир». Укажите откуда и куда, дату и количество мест. Система покажет доступных водителей.'},
    {'cat': 'taxi', 'q': 'Как работает торг по цене?', 'a': 'Вы можете предложить свою стоимость во время поиска машины, нажав «Торговаться». Водитель моментально получит пуш-уведомление с вашей ставкой.'},
    {'cat': 'taxi', 'q': 'Как стать водителем и брать заказы?', 'a': 'Перейдите на вкладку «Водитель» в IQ Такси и пройдите верификацию: загрузите права, техпаспорт и сделайте селфи. Наш ИИ проверит ваши документы.'},
    {'cat': 'taxi', 'q': 'Как отменить заказ или поездку?', 'a': 'В деталях активной поездки нажмите кнопку «Отменить». Все активные предложения торга будут автоматически отклонены.'},
    {'cat': 'general', 'q': 'Как подать объявление в IQ Market?', 'a': 'Нажмите кнопку «+» на главном экране приложения, выберите категорию, заполните описание, укажите цену и добавьте качественные фотографии.'},
    {'cat': 'general', 'q': 'Почему объявление отклонено?', 'a': 'Объявления отклоняются в случае нарушения правил платформы, указания неверной категории или подозрений в мошенничестве.'},
    {'cat': 'account', 'q': 'Лимит вопросов в день для Taxi GPT?', 'a': 'Для обеспечения высокого качества обслуживания, лимит бесплатных общих вопросов ИИ-помощнику составляет 3 вопроса в день.'},
  ];

  final List<Map<String, String>> _faqKz = [
    {'cat': 'taxi', 'q': 'Қалааралық таксиге қалай тапсырыс беруге болады?', 'a': '«IQ Такси» бөліміне → «Жолаушы» қосымша бетіне өтіңіз. Бағытты, күнді және орын санын көрсетіңіз. Жүйе бос жүргізушілерді көрсетеді.'},
    {'cat': 'taxi', 'q': 'Бағаны саудаласу қалай жұмыс істейді?', 'a': 'Көлік іздеу кезінде «Саудаласу» батырмасын басып, өз бағаңызды ұсына аласыз. Жүргізуші сіздің ұсынысыңызды бірден пуш-хабарлама арқылы алады.'},
    {'cat': 'taxi', 'q': 'Қалай жүргізуші болып тапсырыс алуға болады?', 'a': 'IQ Таксидегі «Жүргізуші» бетіне өтіп, верификациядан өтіңіз: куәлік, техпаспорт жүктеп, селфи жасаңыз. Біздің ЖИ құжаттарды тексеред.'},
    {'cat': 'taxi', 'q': 'Тапсырыстан немесе сапардан қалай бас тартам?', 'a': 'Белсенді сапар мәліметтерінде «Болдырмау» батырмасын басыңыз. Барлық саудаласу ұсыныстары автоматты түрде жойылады.'},
    {'cat': 'general', 'q': 'IQ Market-те хабарландыруды қалай жариялайды?', 'a': 'Қосымшаның басты экранындағы «+» батырмасын басып, санатты таңдаңыз, сипаттамасын жазып, бағасы мен сапалы суреттерін қосыңыз.'},
    {'cat': 'general', 'q': 'Неліктен хабарландыру қабылданбады?', 'a': 'Хабарландырулар платформа ережелерін бұзғанда, қате санат таңдалғанда немесе алаяқтық күдігі туындағанда қабылданбайды.'},
    {'cat': 'account', 'q': 'Taxi GPT үшін күндік сұрақ лимиті қанша?', 'a': 'Қызмет көрсету сапасын арттыру үшін, ИИ көмекшісіне жалпы сұрақтар бойынша тегін лимит күніне 3 сұрақпен шектелген.'},
  ];

  final List<Map<String, String>> _faqUyg = [
    {'cat': 'taxi', 'q': 'Шәһәрләрара таксиға қандақ буйруқ беримән?', 'a': '«IQ Такси» бөлүмигә → «Йолучи» бетчисигә кириң. Қәйәрдин қәйәргә барадиғанлиғиңизни, числа вә орун санини көрситиң.'},
    {'cat': 'taxi', 'q': 'Баһани содилишиш қандақ ишләйду?', 'a': 'Машина издөш вақтида «Содилаш» тугмисини бесип, өз баһаңизни сунсаңиз болиду. Шопур сизнің сунушиңизни пуш арқилиқ дәрһал алиду.'},
    {'cat': 'taxi', 'q': 'Қандақ шопур болуп буйруқ алсам болиду?', 'a': 'IQ Таксидики «Шопур» бетигә өтүп тәкшүрүштин өтүң: гуваһнамә, техпаспорт жүкләп, селфи чүшүң. Сүнъий әқил һөҗҗәтләрни тәкшүриду.'},
    {'cat': 'taxi', 'q': 'Сапәрдин қандақ ваз кечимән?', 'a': 'Бесенди сапәр учурлирида «Бикар қилиш» тугмисини бесиң. Барлиқ содилаш сунушлири автоматлиқ йоқотилиду.'},
    {'cat': 'general', 'q': 'IQ Market-та еланни қандақ чиқиримән?', 'a': 'Программа баштыдики «+» басмисини бесип, елан санитини таллаң, чүшәндүрүши вә баһасини йезип, сүрәт қошуң.'},
    {'cat': 'general', 'q': 'Елан немшқа рәт қилинди?', 'a': 'Еланлар қаидиләр бузулғанда, хата санат талланғанда яки алаяқлиқ гумани туғулғанда рәт қилиниду.'},
    {'cat': 'account', 'q': 'Taxi GPT үчүн күнлүк лимит қанчә?', 'a': 'Мулазимәт сүпитини сақлаш үчүн, Сүнъий әқил йардәмчисигә күнлүк соал лимити 3 соал қилип бәлгүләнгән.'},
  ];

  final _catKeys = ['all', 'general', 'taxi', 'account'];

  List<String> _cats(TaxiProvider provider) => [
    _t(provider, 'all'),
    _t(provider, 'general'),
    _t(provider, 'taxi'),
    _t(provider, 'account'),
  ];

  List<Map<String, String>> _filtered(TaxiProvider provider) {
    List<Map<String, String>> list;
    final String lang = provider.curLang;
    if (lang == 'kz') {
      list = _faqKz;
    } else if (lang == 'uyg') {
      list = _faqUyg;
    } else {
      list = _faqRu;
    }

    if (_selectedCat != 0) {
      list = list.where((e) => e['cat'] == _catKeys[_selectedCat]).toList();
    }
    if (_query.isNotEmpty) {
      list = list.where((e) =>
          e['q']!.toLowerCase().contains(_query.toLowerCase()) ||
          e['a']!.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    final list = _filtered(provider);

    return Scaffold(
      backgroundColor: widget.t.bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context, provider, list.length),
          SliverToBoxAdapter(child: _buildAiAssistantCard(context, provider)),
          SliverToBoxAdapter(child: _buildSearchBar(provider)),
          SliverToBoxAdapter(child: _buildCategories(provider)),
          SliverToBoxAdapter(child: _buildOperatorCard(context, provider)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _FaqTile(item: list[i], t: widget.t),
                childCount: list.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context, TaxiProvider provider, int count) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF4A80F0),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_t(provider, 'title'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 3),
                  Text('$count ${_t(provider, 'questions')}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiAssistantCard(BuildContext context, TaxiProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            // Convert app locale code into corresponding string for IqSupportScreen state initialization
            final String aiLang = provider.curLang == 'kz' 
                ? 'Қазақша' 
                : (provider.curLang == 'uyg' ? 'Уйғурчә' : 'Русский');
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IqSupportScreen(
                  lang: aiLang,
                  initialMode: 'taxi',
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4A80F0).withValues(alpha: 0.15),
                        const Color(0xFF6366F1).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Color(0xFF4A80F0), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(provider, 'ai_assistant_title'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: const Color(0xFF1E293B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(provider, 'ai_assistant_desc'),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF4A80F0),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF4A80F0), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(TaxiProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: _t(provider, 'search_hint'),
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600),
            border: InputBorder.none,
            icon: const Icon(Icons.search_rounded, color: Color(0xFF4A80F0)),
            suffixIcon: _query.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => setState(() => _query = ''))
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(TaxiProvider provider) {
    final icons = [Icons.apps_rounded, Icons.info_outline_rounded, Icons.local_taxi_rounded, Icons.person_rounded];
    final categories = _cats(provider);
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final sel = i == _selectedCat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCat = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF4A80F0) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: sel ? Colors.transparent : Colors.black.withValues(alpha: 0.04)),
                boxShadow: sel ? [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Row(children: [
                Icon(icons[i], color: sel ? Colors.white : Colors.grey, size: 15),
                const SizedBox(width: 6),
                Text(categories[i], style: GoogleFonts.inter(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOperatorCard(BuildContext context, TaxiProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4A80F0).withValues(alpha: 0.15),
                      const Color(0xFF6366F1).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF4A80F0), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _t(provider, 'operator_title'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF25D366),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ONLINE',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF25D366),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(provider, 'operator_hours'),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _contactItem(
                  _t(provider, 'wa_support'),
                  const LinearGradient(
                    colors: [Color(0xFF128C7E), Color(0xFF075E54)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  const Color(0xFF075E54),
                  'whatsapp://send?phone=77089007030&text=${Uri.encodeComponent(_t(provider, "wa_message"))}',
                  'https://wa.me/77089007030?text=${Uri.encodeComponent(_t(provider, "wa_message"))}',
                  PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _contactItem(
                  _t(provider, 'tg_support'),
                  const LinearGradient(
                    colors: [Color(0xFF24A1DE), Color(0xFF0088CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  const Color(0xFF0088CC),
                  'tg://resolve?phone=77089007030&text=${Uri.encodeComponent(_t(provider, "wa_message"))}',
                  'https://t.me/+77089007030?text=${Uri.encodeComponent(_t(provider, "wa_message"))}',
                  PhosphorIcons.telegramLogo(PhosphorIconsStyle.fill),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactItem(String title, LinearGradient gradient, Color shadowColor, String url, String fallbackUrl, IconData icon) {
    final provider = Provider.of<TaxiProvider>(context, listen: false);
    return GestureDetector(
      onTap: () async {
        try {
          final primaryUri = Uri.parse(url);
          if (await canLaunchUrl(primaryUri)) {
            await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
          } else {
            final fallbackUri = Uri.parse(fallbackUrl);
            if (await canLaunchUrl(fallbackUri)) {
              await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.translate('appNotInstalled')), backgroundColor: Colors.redAccent),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Error launching support messenger: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(provider.translate('appNotInstalled')), backgroundColor: Colors.redAccent),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final Map<String, String> item;
  final TaxiTheme t;
  const _FaqTile({required this.item, required this.t});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _catColor {
    switch (widget.item['cat']) {
      case 'taxi':
        return const Color(0xFF6366F1);
      case 'account':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF4A80F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _open = !_open);
        _open ? _ctrl.forward() : _ctrl.reverse();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _open ? _catColor.withValues(alpha: 0.4) : Colors.transparent, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _open ? 0.06 : 0.02), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                    widget.item['cat'] == 'taxi'
                        ? Icons.local_taxi_rounded
                        : widget.item['cat'] == 'account'
                            ? Icons.person_rounded
                            : Icons.help_outline_rounded,
                    color: _catColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.item['q']!, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFF1A1D1E))),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: _open ? _catColor : Colors.grey.shade400, size: 24),
                ),
              ]),
            ),
            SizeTransition(
              sizeFactor: _anim,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _catColor.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14)),
                  child: Text(widget.item['a']!, style: GoogleFonts.inter(fontSize: 13, color: Colors.black87, height: 1.6, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
