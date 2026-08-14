import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'iq_support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  final String lang;
  const HelpCenterScreen({super.key, required this.lang});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _query = '';

  String _t(String key) {
    final ru = {
      'title': 'Центр помощи',
      'search_hint': 'Поиск по вопросам...',
      'no_results': 'Ничего не найдено',
      'no_results_sub': 'Попробуйте изменить запрос или задайте вопрос IQ-Поддержке ниже',
      'ai_chat_title': 'IQ-Поддержка',
      'ai_chat_sub': 'Написать в чат',
    };
    final kz = {
      'title': 'Көмек орталығы',
      'search_hint': 'Сұрақтар бойынша іздеу...',
      'no_results': 'Ештеңе табылмады',
      'no_results_sub': 'Сұрауды өзгертіп көріңіз немесе төмендегі IQ-Қолдаудан сұраңыз',
      'ai_chat_title': 'IQ-Қолдау',
      'ai_chat_sub': 'Чатқа жазу',
    };
    final uyg = {
      'title': 'Йардәм мәркизи',
      'search_hint': 'Соаллар бойичә издәр...',
      'no_results': 'Һеч немә тепилмиди',
      'no_results_sub': 'Издәшни өзгәртип бақаң яки астидики IQ-Йардәмдин сораң',
      'ai_chat_title': 'IQ-Йардәм',
      'ai_chat_sub': 'Чатқа йезиш',
    };
    final dict = widget.lang == 'Қазақша' ? kz : (widget.lang == 'Уйғурчә' ? uyg : ru);
    return dict[key] ?? ru[key] ?? key;
  }

  // 20 самых частых вопросов о маркетплейсе (без такси — раздел закрыт для
  // обычных пользователей, см. iqmarket-taxi-isolation). Ответы сверены с
  // реальным поведением приложения на момент написания (лимиты фото/видео,
  // 30-дневный цикл объявления, правила смены телефона после Telegram и т.д.),
  // а не переписаны из старой support_faq_database.dart — там встречались
  // устаревшие цифры (10 фото вместо 8, 50 объявлений вместо 30) и функция
  // "Поднять объявление", которой в коде нет.
  final List<Map<String, String>> _faqRu = [
    {'q': 'Как подать объявление?', 'a': 'Нажмите «+» внизу экрана, выберите категорию, добавьте фото и видео, укажите цену и описание. После проверки объявление появится в ленте.'},
    {'q': 'Сколько фото и видео можно добавить к объявлению?', 'a': 'До 8 фотографий и одно видео длительностью до 20 секунд.'},
    {'q': 'Сколько времени занимает проверка объявления?', 'a': 'Большинство объявлений проходит автоматическую ИИ-проверку и публикуется сразу. Часть отправляется на ручную модерацию — это может занять немного больше времени.'},
    {'q': 'Что делать, если объявление отклонили?', 'a': 'Причина отклонения показана прямо на объявлении в разделе «Мои объявления». Исправьте указанное и нажмите «Редактировать» — объявление снова уйдёт на проверку.'},
    {'q': 'Как отредактировать или удалить своё объявление?', 'a': 'Профиль → Мои объявления. Откройте нужное объявление и выберите «Редактировать» или «Удалить».'},
    {'q': 'Сколько объявлений можно разместить?', 'a': 'До 30 активных объявлений одновременно и не более 15 новых публикаций в сутки.'},
    {'q': 'Сколько действует объявление и что будет после?', 'a': 'Объявление активно 30 дней. За 3 дня до окончания придёт напоминание, после — оно уйдёт в архив, откуда его можно продлить ещё на 30 дней.'},
    {'q': 'Как связаться с продавцом?', 'a': 'Откройте объявление и нажмите «Написать» (встроенный чат) или «Позвонить».'},
    {'q': 'Как предложить свою цену?', 'a': 'В чате с продавцом нажмите кнопку предложения цены и укажите свою сумму. Продавец сможет принять или отклонить предложение.'},
    {'q': 'Как добавить объявление в избранное?', 'a': 'Нажмите на иконку сердечка на карточке объявления. Все сохранённые товары — в разделе «Избранное».'},
    {'q': 'Что означает синяя галочка у продавца?', 'a': 'Продавец подтвердил номер телефона через Telegram — это дополнительный признак надёжности.'},
    {'q': 'Как войти через Telegram?', 'a': 'На экране входа выберите «Войти через Telegram» и следуйте подсказкам бота. Номер телефона автоматически сохранится и подтвердится в профиле.'},
    {'q': 'Как изменить номер телефона, подтверждённый через Telegram?', 'a': 'Такой номер нельзя изменить самостоятельно — только через модератора. Ссылка на обращение есть в разделе «Личные данные».'},
    {'q': 'Как оставить отзыв о продавце?', 'a': 'После сделки зайдите в профиль продавца, поставьте оценку и напишите комментарий.'},
    {'q': 'Как пожаловаться на объявление или пользователя?', 'a': 'На странице объявления или в профиле пользователя нажмите «⋮» и выберите «Пожаловаться», укажите причину.'},
    {'q': 'Как заблокировать пользователя в чате?', 'a': 'Откройте чат, нажмите «⋮» в шапке и выберите «Заблокировать». Заблокированный пользователь больше не сможет вам написать.'},
    {'q': 'Можно ли удалить отправленное сообщение?', 'a': 'Да — «Удалить у себя» скроет сообщение только у вас, «Удалить у всех» уберёт его из чата обоих собеседников.'},
    {'q': 'Какие товары запрещено продавать?', 'a': 'Оружие, наркотические вещества, алкоголь, лекарства и контрафактные товары — под запретом на платформе.'},
    {'q': 'Как обезопасить себя при сделке?', 'a': 'Не переводите предоплату незнакомым людям, встречайтесь в людных местах и проверяйте товар перед оплатой.'},
    {'q': 'Как изменить город, объявления которого показываются?', 'a': 'Нажмите на название города вверху главного экрана и выберите нужный из списка.'},
  ];

  final List<Map<String, String>> _faqKz = [
    {'q': 'Хабарландыруды қалай беруге болады?', 'a': 'Экранның төменгі жағындағы «+» батырмасын басыңыз, санатты таңдаңыз, фото және видео қосыңыз, бағасы мен сипаттамасын жазыңыз. Тексерістен кейін хабарландыру лентада көрінеді.'},
    {'q': 'Хабарландыруға қанша фото және видео қосуға болады?', 'a': '8-ге дейін фотосурет және ұзақтығы 20 секундтан аспайтын бір видео.'},
    {'q': 'Хабарландыру қанша уақыт тексеріледі?', 'a': 'Көп хабарландырулар жасанды интеллект арқылы автоматты тексеруден өтіп, бірден жарияланады. Кейбіреулері қолмен модерацияға жіберіледі — бұл сәл көбірек уақыт алуы мүмкін.'},
    {'q': 'Хабарландыру қабылданбаса, не істеу керек?', 'a': 'Қабылданбау себебі «Менің хабарландыруларым» бөлімінде хабарландырудың өзінде көрсетіледі. Көрсетілген кемшілікті түзетіп, «Өңдеу» батырмасын басыңыз — хабарландыру қайта тексеріледі.'},
    {'q': 'Хабарландыруды қалай өңдеуге немесе жоюға болады?', 'a': 'Профиль → Менің хабарландыруларым. Қажетті хабарландыруды ашып, «Өңдеу» немесе «Жою» таңдаңыз.'},
    {'q': 'Қанша хабарландыру орналастыруға болады?', 'a': 'Бір уақытта 30-ға дейін белсенді хабарландыру және тәулігіне 15-тен аспайтын жаңа жариялау.'},
    {'q': 'Хабарландыру қанша уақыт күшінде болады және мерзімі өткен соң не болады?', 'a': 'Хабарландыру 30 күн белсенді болады. Мерзімі бітуге 3 күн қалғанда еске салу келеді, одан кейін ол мұрағатқа өтеді — оны тағы 30 күнге ұзартуға болады.'},
    {'q': 'Сатушымен қалай байланысуға болады?', 'a': 'Хабарландыруды ашып, «Жазу» (кірістірілген чат) немесе «Қоңырау шалу» батырмасын басыңыз.'},
    {'q': 'Өз бағаңызды қалай ұсынуға болады?', 'a': 'Сатушымен чатта баға ұсыну батырмасын басып, сомаңызды енгізіңіз. Сатушы ұсынысты қабылдай алады немесе бас тарта алады.'},
    {'q': 'Хабарландыруды Таңдаулыларға қалай қосуға болады?', 'a': 'Хабарландыру картасындағы жүрек белгішесін басыңыз. Сақталған барлық тауарлар «Таңдаулылар» бөлімінде.'},
    {'q': 'Сатушының жанындағы көк белгі нені білдіреді?', 'a': 'Сатушы телефон нөмірін Telegram арқылы растағанын білдіреді — бұл сенімділіктің қосымша белгісі.'},
    {'q': 'Telegram арқылы қалай кіруге болады?', 'a': 'Кіру экранында «Telegram арқылы кіру» таңдаңыз да, боттың нұсқауларын орындаңыз. Телефон нөміріңіз профиліңізде автоматты түрде сақталып, расталады.'},
    {'q': 'Telegram арқылы расталған нөмірді қалай өзгертуге болады?', 'a': 'Мұндай нөмірді өзіңіз өзгерте алмайсыз — тек модератор арқылы. Хабарласу сілтемесі «Жеке деректер» бөлімінде бар.'},
    {'q': 'Сатушыға қалай пікір қалдыруға болады?', 'a': 'Мәміле аяқталған соң сатушының профиліне өтіп, баға қойыңыз және пікір жазыңыз.'},
    {'q': 'Хабарландыруға немесе пайдаланушыға қалай шағымдануға болады?', 'a': 'Хабарландыру бетінде немесе пайдаланушы профилінде «⋮» басып, «Шағымдану» таңдаңыз да, себебін көрсетіңіз.'},
    {'q': 'Чатта пайдаланушыны қалай бұғаттауға болады?', 'a': 'Чатты ашып, жоғарғы жақтағы «⋮» басып, «Бұғаттау» таңдаңыз. Бұғатталған пайдаланушы сізге жаза алмайды.'},
    {'q': 'Жіберілген хабарды жоюға бола ма?', 'a': 'Иә — «Өзімнен жою» хабарды тек сізден жасырады, «Барлығынан жою» оны екі жақтан да алып тастайды.'},
    {'q': 'Қандай тауарларды сатуға тыйым салынған?', 'a': 'Қару-жарақ, есірткі заттар, алкоголь, дәрі-дәрмек және контрафакт тауарлар платформада тыйым салынған.'},
    {'q': 'Мәміле кезінде өзімді қалай сақтандырамын?', 'a': 'Танымайтын адамдарға алдын ала төлем жасамаңыз, адам көп жерлерде кездесіңіз және төлеуден бұрын тауарды тексеріңіз.'},
    {'q': 'Хабарландырулар көрсетілетін қаланы қалай өзгертуге болады?', 'a': 'Басты экранның жоғарғы жағындағы қала атауын басып, тізімнен керектісін таңдаңыз.'},
  ];

  final List<Map<String, String>> _faqUyg = [
    {'q': 'Еланни қандақ чиқиримән?', 'a': 'Экранниң астидики «+» басмисини бесиң, категорийәни таллаң, фото вә видео қошуң, баһаси билән чүшәндүрүшини йезиң. Тәстиқләнгәндин кейин елан лентида көрүниду.'},
    {'q': 'Еланға қанчә фото вә видео қошалаймән?', 'a': '8 гичә фотосүрәт вә узунлуғи 20 секунттин ашмайдиған бир видео.'},
    {'q': 'Елан қанчилик вақит тәкшүрилиду?', 'a': 'Көпинчә еланлар сүнъий әқил арқилиқ автоматик тәкшүрүлүп дәрһал нәшир қилиниду. Бәзилири қолда тәкшүрүшкә йоллиниду — бу сәл көпрәк вақит алиду.'},
    {'q': 'Елан тәстиқләнмисә немә қилимән?', 'a': 'Тәстиқләнмәслик сәвәви «Мениң еланлирим» бөлүмидә еланниң өзидә көрситиду. Көрситилгән кемчиликни түзитип, «Тәһрирләш»ни бесиң — елан қайта тәкшүрилиду.'},
    {'q': 'Еланни қандақ тәһрирләймән йаки өчүрүмән?', 'a': 'Профиль → Мениң еланлирим. Лазимлиқ еланни ечип «Тәһрирләш» йаки «Өчүрүш»ни таллаң.'},
    {'q': 'Қанчә елан орунлаштурсам болиду?', 'a': 'Бир вақитта 30 гичә активлиқ елан вә бир күндә 15 дин ашмайдиған йеңи нәшир.'},
    {'q': 'Елан қанчилик вақит күчидә болиду вә муддити тошса немә болиду?', 'a': 'Елан 30 күн активлиқ болиду. Муддити тошушқа 3 күн қалғанда әскәртиш келиду, андин у архивқа өтиду — уни йәнә 30 күнгә узайтқили болиду.'},
    {'q': 'Сатқучи билән қандақ алақилишимән?', 'a': 'Еланни ечип «Йезиш» (ичидики чат) йаки «Тел қилиш» басмисини бесиң.'},
    {'q': 'Өз баһамни қандақ тәклип қилимән?', 'a': 'Сатқучи билән чатта баһа тәклип қилиш басмисини бесип, соммиңизни киргүзүң. Сатқучи тәклипни қобул қилалайду йаки рәт қилалайду.'},
    {'q': 'Еланни Талланғанларға қандақ қошимән?', 'a': 'Елан картисидики йүрәк бәлгисини бесиң. Сақланған барлиқ түрләр «Талланғанлар» бөлүмидә.'},
    {'q': 'Сатқучи йенидики көк бәлгә немини билдүриду?', 'a': 'Сатқучиниң тел номурини Telegram арқилиқ тәстиқлиғанлиғини билдүриду — бу ишәшлик бәлгиси.'},
    {'q': 'Telegram арқилиқ қандақ киримән?', 'a': 'Кириш экранида «Telegram арқилиқ кириш»ни таллап, ботниң көрсәтмилирини орунлаң. Тел номуруңиз профилиңиздә автоматик сақлиниду вә тәстиқлиниду.'},
    {'q': 'Telegram арқилиқ тәстиқләнгән номурни қандақ өзгәртимән?', 'a': 'Бундақ номурни өзиңиз өзгәртәлмәйсиз — пәқәт модератор арқилиқ. Алақилишиш һаваләси «Шәхсий мәлумат» бөлүмидә бар.'},
    {'q': 'Сатқучиға қандақ пикир қалдуримән?', 'a': 'Соода тамамланғандин кейин сатқучиниң профилиға кирип, баһа қоюң вә пикир йезиң.'},
    {'q': 'Еланға йаки ишләткүчигә қандақ шикайәт қилимән?', 'a': 'Елан бетидә йаки ишләткүчи профилида «⋮»ни бесип «Шикайәт қилиш»ни таллаң, сәвәвини көрситиң.'},
    {'q': 'Чатта ишләткүчини қандақ чәкләймән?', 'a': 'Чатни ечип, үстидики «⋮»ни бесип «Чәкләш»ни таллаң. Чәкләнгән ишләткүчи сизгә йезәлмәйду.'},
    {'q': 'Әвәтилгән хәвәрни өчүрсә боламду?', 'a': 'Шундақ — «Өзүмдин өчүрүш» хәвәрни пәқәт сиздин йошуриду, «Һәммидин өчүрүш» уни икки тәрәптинму елип ташлайду.'},
    {'q': 'Қандақ түрләрни сетиш чәкләнгән?', 'a': 'Қорал-ярақ, гирау моддилар, һарақ-шараб, дора-дәрмәк вә сахта түрләр платформида чәкләнгән.'},
    {'q': 'Соода вақтида өзүмни қандақ сақлаймән?', 'a': 'Тонумиған адәмләргә алдин пул йоллимаң, адәм көп йәрдә учришиң вә төләштин бурун мални тәкшүрүң.'},
    {'q': 'Еланлар көрситилидиған шәһәрни қандақ өзгәртимән?', 'a': 'Баш экранниң үстидики шәһәр намини бесип, тизимликтин керәклигини таллаң.'},
  ];

  List<Map<String, String>> get _filtered {
    List<Map<String, String>> list;
    if (widget.lang == 'Қазақша') {
      list = _faqKz;
    } else if (widget.lang == 'Уйғурчә') {
      list = _faqUyg;
    } else {
      list = _faqRu;
    }

    if (_query.isNotEmpty) {
      list = list.where((e) =>
        e['q']!.toLowerCase().contains(_query.toLowerCase()) ||
        e['a']!.toLowerCase().contains(_query.toLowerCase())
      ).toList();
    }
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
          SliverToBoxAdapter(child: _buildAiChatBanner(context)),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: _filtered.isEmpty
                ? SliverToBoxAdapter(child: _buildNoResults())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _FaqTile(item: _filtered[i]),
                      childCount: _filtered.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── IQ-Поддержка баннер — главный, самый заметный элемент экрана ──
  Widget _buildAiChatBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IqSupportScreen(lang: widget.lang),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('ai_chat_title'),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _t('ai_chat_sub'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: const Color(0xFF1E3A8A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_t('title'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4))],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: _t('search_hint'),
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
            border: InputBorder.none,
            icon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
            suffixIcon: _query.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)), onPressed: () => setState(() => _query = ''))
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.grey.shade300, size: 48),
          const SizedBox(height: 12),
          Text(_t('no_results'), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(_t('no_results_sub'), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
        ],
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
  static const Color _accent = Color(0xFF4A80F0);
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
          border: Border.all(color: _open ? _accent.withValues(alpha: 0.4) : Colors.transparent, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _open ? 0.06 : 0.02), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.help_outline_rounded, color: _accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.item['q']!, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFF1A1D1E))),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: _open ? _accent : Colors.grey.shade400, size: 24),
                ),
              ]),
            ),
            SizeTransition(
              sizeFactor: _anim,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14)),
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
