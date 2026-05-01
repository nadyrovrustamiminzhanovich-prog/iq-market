import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/screens/ai_assistant_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  final String lang;
  const HelpCenterScreen({super.key, required this.lang});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _query = '';
  int _selectedCat = 0;

  final List<Map<String, String>> _faqRu = [
    // Общие
    {'cat': 'general', 'q': 'Как подать объявление?', 'a': 'Нажмите кнопку «+» внизу экрана, выберите категорию, заполните описание, укажите цену и добавьте фото. Объявление появится сразу после модерации.'},
    {'cat': 'general', 'q': 'Как редактировать или удалить объявление?', 'a': 'Перейдите в Профиль → Мои объявления. Нажмите на нужное объявление и выберите «Редактировать» или «Удалить».'},
    {'cat': 'general', 'q': 'Как связаться с продавцом?', 'a': 'Откройте объявление и нажмите кнопку «Написать» или «Позвонить». Можно также сделать предложение о цене прямо в чате.'},
    {'cat': 'general', 'q': 'Как добавить в избранное?', 'a': 'Нажмите на иконку сердечка на карточке объявления или внутри объявления. Все избранные товары хранятся в разделе «Избранное».'},
    {'cat': 'general', 'q': 'Почему моё объявление не отображается?', 'a': 'Возможные причины: объявление на модерации (до 24 ч), нарушение правил платформы, или истёк срок публикации. Проверьте статус в «Мои объявления».'},
    {'cat': 'general', 'q': 'Как выбрать город при поиске?', 'a': 'Нажмите на название города вверху главного экрана. Выберите нужный город из списка или введите название в поиск.'},
    {'cat': 'general', 'q': 'Как работает IQ GPT ассистент?', 'a': 'IQ GPT — это встроенный ИИ помощник, который отвечает на вопросы о товарах, помогает найти выгодные предложения и предупреждает о возможном мошенничестве.'},
    // Такси
    {'cat': 'taxi', 'q': 'Как заказать межгородное такси?', 'a': 'Перейдите в раздел «IQ Такси» → вкладка «Пассажир». Укажите откуда и куда, дату и количество мест. Система покажет доступных водителей.'},
    {'cat': 'taxi', 'q': 'Как предложить свою цену?', 'a': 'В карточке водителя нажмите кнопку «Торговаться». Введите свою сумму — водитель получит ваше предложение и может принять или отклонить.'},
    {'cat': 'taxi', 'q': 'Как зарегистрироваться водителем?', 'a': 'Перейдите на вкладку «Водитель» в IQ Такси. Пройдите верификацию: загрузите права, техпаспорт и сделайте селфи с документом. ИИ проверит данные автоматически.'},
    {'cat': 'taxi', 'q': 'Что значит верификация водителя?', 'a': 'Верификация — это проверка подлинности документов (права + техпаспорт) с помощью ИИ. Это гарантирует безопасность для всех пассажиров.'},
    {'cat': 'taxi', 'q': 'Как отменить поездку?', 'a': 'Напишите водителю в чат и сообщите об отмене. В будущих версиях будет кнопка «Отменить» прямо в карточке заказа.'},
    {'cat': 'taxi', 'q': 'Что брать с собой в поездку?', 'a': 'Документ, удостоверяющий личность. Оплату (наличными или переводом по договорённости). Багаж — по договорённости с водителем (1 стандартная сумка на 1 место).'},
    {'cat': 'taxi', 'q': 'Как оценить водителя?', 'a': 'После завершения поездки откройте профиль водителя и оставьте оценку. Ваш отзыв помогает другим пассажирам выбрать надёжного водителя.'},
    {'cat': 'taxi', 'q': 'Безопасно ли такси IQ Market?', 'a': 'Да. Все водители проходят многоступенчатую верификацию документов. Данные хранятся зашифрованными. Вы всегда можете написать в поддержку.'},
    // Аккаунт
    {'cat': 'account', 'q': 'Как восстановить пароль?', 'a': 'На экране входа нажмите «Забыли пароль?». Введите email — на него придёт ссылка для сброса пароля.'},
    {'cat': 'account', 'q': 'Как изменить номер телефона?', 'a': 'Перейдите в Профиль → Настройки → Изменить телефон. Потребуется подтверждение через SMS-код.'},
    {'cat': 'account', 'q': 'Как удалить аккаунт?', 'a': 'Профиль → Настройки → Удалить аккаунт. Все ваши данные и объявления будут безвозвратно удалены в течение 30 дней.'},
    {'cat': 'account', 'q': 'Можно ли иметь несколько аккаунтов?', 'a': 'Нет. Правила платформы запрещают создание нескольких аккаунтов. При обнаружении дубликатов оба аккаунта будут заблокированы.'},
  ];

  final _cats = ['Все', 'Общее', 'IQ Такси', 'Аккаунт'];
  final _catKeys = ['all', 'general', 'taxi', 'account'];

  List<Map<String, String>> get _filtered {
    var list = _faqRu;
    if (_selectedCat != 0) list = list.where((e) => e['cat'] == _catKeys[_selectedCat]).toList();
    if (_query.isNotEmpty) list = list.where((e) => e['q']!.toLowerCase().contains(_query.toLowerCase()) || e['a']!.toLowerCase().contains(_query.toLowerCase())).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildAiBanner(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _FaqTile(item: _filtered[i]),
                childCount: _filtered.length,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildOperatorCard(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 130,
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
              padding: const EdgeInsets.fromLTRB(60, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Центр помощи', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
                  const SizedBox(height: 4),
                  Text('${_faqRu.length} вопросов и ответов', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Поиск по вопросам...',
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
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

  Widget _buildCategories() {
    final icons = [Icons.apps_rounded, Icons.store_rounded, Icons.local_taxi_rounded, Icons.person_rounded];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: _cats.length,
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
                boxShadow: sel ? [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Row(children: [
                Icon(icons[i], color: sel ? Colors.white : Colors.grey, size: 15),
                const SizedBox(width: 6),
                Text(_cats[i], style: GoogleFonts.inter(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAiBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiAssistantScreen(initialLanguage: widget.lang))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: const Color(0xFF9333EA).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('IQ GPT — ИИ Помощник', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 3),
            Text('Мгновенные ответы на любые вопросы ✨', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
        ]),
      ),
    );
  }

  Widget _buildOperatorCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF4A80F0).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_rounded, color: Color(0xFF4A80F0), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Нужна живая помощь?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: theme.colorScheme.onSurface)),
                Text('Режим работы: с 10:00 до 21:00', style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
              ])),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(child: _contactItem('WhatsApp поддержка', const Color(0xFF25D366), 'https://wa.me/77089007030?text=${Uri.encodeComponent("Здравствуйте! Мне нужна помощь по приложению IQ-Market.")}', theme)),
              const SizedBox(width: 12),
              Expanded(child: _contactItem('Telegram бот', const Color(0xFF0088CC), 'https://t.me/iqmarket_support_bot', theme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactItem(String title, Color color, String url, ThemeData theme) {
    return GestureDetector(
      onTap: () async => await canLaunchUrl(Uri.parse(url)) ? await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.1))),
        child: Column(children: [
          Icon(title.contains('WhatsApp') ? Icons.message : Icons.telegram, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: theme.colorScheme.onSurface)),
        ]),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final Map<String, String> item;
  const _FaqTile({required this.item});
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _catColor {
    switch (widget.item['cat']) {
      case 'taxi': return const Color(0xFF6366F1);
      case 'account': return const Color(0xFF10B981);
      default: return const Color(0xFF4A80F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _open ? 0.07 : 0.03), blurRadius: 16, offset: const Offset(0, 4))],
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
                    widget.item['cat'] == 'taxi' ? Icons.local_taxi_rounded
                      : widget.item['cat'] == 'account' ? Icons.person_rounded
                      : Icons.help_outline_rounded,
                    color: _catColor, size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.item['q']!, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF1A1D1E))),
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
                  decoration: BoxDecoration(color: _catColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                  child: Text(widget.item['a']!, style: GoogleFonts.inter(fontSize: 13, color: Colors.black87, height: 1.6, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
