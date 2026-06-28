import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'iq_support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  final String lang;
  const HelpCenterScreen({super.key, required this.lang});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _query = '';
  int _selectedCat = 0;

  String _t(String key) {
    final ru = {
      'title': 'Центр помощи',
      'questions': 'вопросов и ответов',
      'search_hint': 'Поиск по вопросам...',
      'all': 'Все',
      'general': 'Общее',
      'taxi': 'IQ Такси',
      'account': 'Аккаунт',
      'operator_title': 'Нужна живая помощь?',
      'operator_hours': 'Режим работы: с 10:00 до 21:00',
      'wa_support': 'WhatsApp',
      'tg_support': 'Telegram',
      'inapp_support': 'ЧАТ В ПРИЛОЖЕНИИ',
      'wa_message': 'Здравствуйте! Мне нужна помощь по приложению IQ-Market.',
      'ai_chat_title': 'IQ-Поддержка — ИИ Ассистент',
      'ai_chat_sub': 'Задайте вопрос — ответим за секунды 🚀',
      'ai_chat_btn': 'Открыть чат',
    };

    final kz = {
      'title': 'Көмек орталығы',
      'questions': 'сұрақтар мен жауаптар',
      'search_hint': 'Сұрақтар бойынша іздеу...',
      'all': 'Барлығы',
      'general': 'Жалпы',
      'taxi': 'IQ Такси',
      'account': 'Профиль',
      'operator_title': 'Жанды көмек керек пе?',
      'operator_hours': 'Жұмыс уақыты: 10:00-ден 21:00-ге дейін',
      'wa_support': 'WhatsApp',
      'tg_support': 'Telegram',
      'inapp_support': 'ҚОСЫМШАДАҒЫ ЧАТ',
      'wa_message': 'Сәлеметсіз бе! Маған IQ-Market қосымшасы бойынша көмек керек.',
      'ai_chat_title': 'IQ-Қолдау — ЖИ Ассистенті',
      'ai_chat_sub': 'Сұрақ қойыңыз — секундтар ішінде жауап 🚀',
      'ai_chat_btn': 'Чатты ашу',
    };

    final uyg = {
      'title': 'Йардәм мәркизи',
      'questions': 'соал-җаваплар',
      'search_hint': 'Соаллар бойичә издәр...',
      'all': 'Һәммиси',
      'general': 'Умумий',
      'taxi': 'IQ Такси',
      'account': 'Һесабат',
      'operator_title': 'Мулазимчи йардими керәкму?',
      'operator_hours': 'Иш вақти: 10:00 дин 21:00 гичә',
      'wa_support': 'WhatsApp',
      'tg_support': 'Telegram',
      'inapp_support': 'Программа ичидики чат',
      'wa_message': 'Әссаламу әлейкум! Маңа IQ-Market программиси бойичә йардәм керәк еди.',
      'ai_chat_title': 'IQ-Йардәм — ЯЗ Йардәмчиси',
      'ai_chat_sub': 'Соал қойуң — секундларда җавап 🚀',
      'ai_chat_btn': 'Чатни ечиш',
    };

    final dict = widget.lang == 'Қазақша' ? kz : (widget.lang == 'Уйғурчә' ? uyg : ru);
    return dict[key] ?? ru[key] ?? key;
  }

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

  final List<Map<String, String>> _faqKz = [
    // Жалпы
    {'cat': 'general', 'q': 'Хабарландыруды қалай беруге болады?', 'a': 'Экранның төменгі жағындағы «+» батырмасын басып, санатты таңдаңыз, сипаттаманы толтырыңыз, бағасын көрсетіңіз және сурет қосыңыз. Хабарландыру модерациядан өткен соң бірден шығады.'},
    {'cat': 'general', 'q': 'Хабарландыруды қалай өңдеуге немесе жоюға болады?', 'a': 'Профиль → Менің хабарландыруларым бөліміне өтіңіз. Қажетті хабарландыруды басып, «Өңдеу» немесе «Жою» таңдаңыз.'},
    {'cat': 'general', 'q': 'Сатушымен қалай байланысуға болады?', 'a': 'Хабарландыруды ашып, «Жазу» немесе «Қоңырау шалу» батырмасын басыңыз. Сондай-ақ чатта өз бағаңызды ұсынуға болады.'},
    {'cat': 'general', 'q': 'Таңдаулыға қалай қосуға болады?', 'a': 'Хабарландыру картасындағы немесе хабарландыру ішіндегі жүрекше белгішесін басыңыз. Барлық таңдалған тауарлар «Таңдаулылар» бөлімінде сақталады.'},
    {'cat': 'general', 'q': 'Неліктен менің хабарландыруым көрінбейді?', 'a': 'Ықтимал себептер: хабарландыру модерацияда (24 сағатқа дейін), платформа ережелерін бұзу немесе жариялау мерзімі өткен. Статусты «Менің хабарландыруларым» бөлімінен тексеріңіз.'},
    {'cat': 'general', 'q': 'Іздеу кезінде қаланы қалай таңдауға болады?', 'a': 'Басты экранның жоғарғы жағындағы қала атауын басыңыз. Тізімнен қажетті қаланы таңдаңыз немесе іздеуге атын енгізіңіз.'},
    {'cat': 'general', 'q': 'IQ GPT ассистенті қалай жұмыс істейді?', 'a': 'IQ GPT — бұл тауарлар туралы сұрақтарға жауап беретін, тиімді ұсыныстарды табуға көмектесетін және ықтимал алаяқтық туралы ескертетін кірістірілген жасанды интеллект көмекшісі.'},
    // Такси
    {'cat': 'taxi', 'q': 'Қалааралық таксиге қалай тапсырыс беруге болады?', 'a': '«IQ Такси» бөліміне → «Жолаушы» қосымша бетіне өтіңіз. Қайдан және қайда баратыныңызды, күнін және орын санын көрсетіңіз. Жүйе қолжетімді жүргізушілерді көрсетеді.'},
    {'cat': 'taxi', 'q': 'Өз бағаңызды қалай ұсынуға болады?', 'a': 'Жүргізуші карточкасында «Саудаласу» батырмасын басыңыз. Сомаңызды енгізіңіз — жүргізуші сіздің ұсынысыңызды алады және оны қабылдай алады немесе бас тарта алады.'},
    {'cat': 'taxi', 'q': 'Жүргізуші ретінде қалай тіркелуге болады?', 'a': 'IQ Таксидегі «Жүргізуші» қосымша бетіне өтіңіз. Верификациядан өтіңіз: куәлікті, техпаспортты жүктеңіз және құжатпен селфи жасаңыз. Жасанды интеллект деректерді автоматты түрде тексеред.'},
    {'cat': 'taxi', 'q': 'Жүргізуші верификациясы деген не?', 'a': 'Верификация — бұл ЖИ көмегімен құжаттардың (куәлік + техпаспорт) түпнұсқалығын тексеру. Бұл барлық жолаушылардың қауіпсіздігіне кепілдік береді.'},
    {'cat': 'taxi', 'q': 'Сапарды қалай тоқтатуға болады?', 'a': 'Жүргізушіге чат арқылы жазып, бас тарту туралы хабарлаңыз. Болашақ нұсқаларда тапсырыс картасында тікелей «Бас тарту» батырмасы болады.'},
    {'cat': 'taxi', 'q': 'Сапарға өзіңізбен бірге не алу керек?', 'a': 'Жеке басын куәландыратын құжат. Төлем (келісем бойынша қолма-қол ақша немесе аударым). Жүк — жүргізушімен келісім бойынша (1 орынға 1 стандартты сөмке).'},
    {'cat': 'taxi', 'q': 'Жүргізушіге қалай баға беруге болады?', 'a': 'Сапар аяқталғаннан кейін жүргізушінің профилін ашып, бағаңызды қалдырыңыз. Сіздің пікіріңіз басқа жолаушыларға сенімді жүргізушіні таңдауға көмектеседі.'},
    {'cat': 'taxi', 'q': 'IQ Market таксиі қауіпсіз бе?', 'a': 'Иә. Барлық жүргізушілер құжаттардың көпсатылы верификациясынан өтеді. Деректер шифрланған түрде сақталады. Сұрақтарыңыз болса, әрқашан қолдау қызметіне жаза аласыз.'},
    // Аккаунт
    {'cat': 'account', 'q': 'Құпия сөзді қалай қалпына келтіруге болады?', 'a': 'Кіру экранында «Құпия сөзді ұмыттыңыз ба?» батырмасын басыңыз. Электрондық поштаны енгізіңіз — оған құпия сөзді қалпына келтіруге арналған сілтеме жіберіледі.'},
    {'cat': 'account', 'q': 'Телефон нөмірін қалай өзгертуге болады?', 'a': 'Профиль → Параметрлер → Телефонды өзгерту бөліміне өтіңіз. SMS-код арқылы растау қажет болады.'},
    {'cat': 'account', 'q': 'Аккаунтты қалай жоюға болады?', 'a': 'Профиль → Параметрлер → Аккаунтты жою. Барлық деректеріңіз бен хабарландыруларыңыз 30 күн ішінде біржола жойылады.'},
    {'cat': 'account', 'q': 'Бірнеше аккаунт иеленуге бола ма?', 'a': 'Жоқ. Платформа ережелері бірнеше аккаунт құруға тыйым салады. Дубльдер анықталған жағдайда екі аккаунт та бұғатталады.'},
  ];

  final List<Map<String, String>> _faqUyg = [
    // Умумий
    {'cat': 'general', 'q': 'Еланни қандақ чиқиримән?', 'a': 'Экранниң астидики «+» басмисини бесип, категорийәни таллаң, чүшәндүрүшини толтуруң, баһасини көрситиң вә рәсим қошуң. Елан тәстиқләнгәндин кейин дәрһал чиқиду.'},
    {'cat': 'general', 'q': 'Еланни қандақ тәһрирләймән йаки өчүрүмәни?', 'a': 'Профил → Мениң еланлирим бөлүмигә кириң. Лазимлиқ еланни бесип «Тәһрирләш» йаки «Өчүрүш»ни таллаң.'},
    {'cat': 'general', 'q': 'Сатқучи билән қандақ алақилишимән?', 'a': 'Еланни ечип «Йезиш» йаки «Тел қилиш» басмисини бесип. Чатта биваситә баһа тәклип қилсиңизму болиду.'},
    {'cat': 'general', 'q': 'Талланғанлар бөлүмигә қандақ қошумән?', 'a': 'Елан картисидики йаки елан ичидики йүрәк бәлгисини бесиң. Талланған барлиқ түрләр «Талланғанлар» бөлүмидә сақлиниду.'},
    {'cat': 'general', 'q': 'Немишкә мениң еланим көрүнмәйду?', 'a': 'Мумкин болған сәвәпләр: елан тәстиқлиниватиду (24 саатқичә), каидиләргә хилаплиқ қилинған йаки елан муддити тошқан. Һалитини «Мениң еланлирим»дин тәкшүрүң.'},
    {'cat': 'general', 'q': 'Издәш җәрйанида шәһәрни қандақ таллаймән?', 'a': 'Баш экранниң үстидики шәһәр намини бесиң. Тизимликтин керәклик шәһәрни таллаң йаки издactivityкә намини киргүзүң.'},
    {'cat': 'general', 'q': 'IQ GPT йардәмчиси қандақ ишләйду?', 'a': 'IQ GPT — бу түрләр тоғрисидики соалларға җавап беридиған, пайдилиқ тәклипләрни тепишқа йардәм беридиған вә алдамчилиқтин агаһландуридиған сүнъий әқил йардәмчисидур.'},
    // Такси
    {'cat': 'taxi', 'q': 'Шәһәрләр ара таксиға қандақ заказ беримән?', 'a': '«IQ Такси» бөлүмигә → «Йолучи» бәтчисигә кириң. Қәйәрдин қәйәргә баридиғанлиғиңизни, чесла вә орун санини көрситиң. Систем барлиқ шопурларни көрситиду.'},
    {'cat': 'taxi', 'q': 'Өз баһамни қандақ тәклип қилимән?', 'a': 'Шопур картисида «Содилишиш» басмисини бесиң. Соммини киргүзүң — шопур сизниң тәклипиңизни тапшурувалиду вә кобул қилалайду йаки рәт қилалайду.'},
    {'cat': 'taxi', 'q': 'Шопур болуп қандақ тизимлитимән?', 'a': 'IQ Таксидики «Шопур» бәтчисигә кириң. Гуваһнамә тәкшүрүштин өтүң: кинишкәңизни, техпаспортни йүкләң вә һөҗҗәт билән селфи чүшүң. Сүнъий әқил аптуматик тәкшүриду.'},
    {'cat': 'taxi', 'q': 'Шопурни дәлилләш дегән немә?', 'a': 'Дәлилләш — бу сүнъий әқил арқилиқ һөҗҗәтләрниң (кинишкә + техпаспорт) һәқиқийлигини тәкшүрүш болуп, йолучиларниң бихәтәрлигигә капаләтлик қилиду.'},
    {'cat': 'taxi', 'q': 'Сәпәрни қандақ әмәлдин қалдуримән?', 'a': 'Шопурға чат арқилиқ йезип, ваз кечидиғанлиғиңизни уқтуруң. Кәлгүси нусхиларда заказ картисида биваситә «Ваз кечиш» басмиси болиду.'},
    {'cat': 'taxi', 'q': 'Сәпәргә өзүм билән немиләрни елишим керәк?', 'a': 'Кимлик һөҗҗити. Пул (келишим бойичә нәқ пул йаки йөткеш). Йүк-тақ — шопур билән келишиш бойичә (1 орунға 1 өлчәмлик сомка).'},
    {'cat': 'taxi', 'q': 'Шопурға қандақ баһа беримән?', 'a': 'Сәпәр тамамланғандин кейин шопурниң профилини ечип, баһайиңизни қалдуруң. Сизниң пикириңиз башқа йолучиларниң ишәнчлик шопур таллишиға йардәм бериду.'},
    {'cat': 'taxi', 'q': 'IQ Market таксиси бихәтәрму?', 'a': 'Шундақ. Барлиқ шопурлар көп басқучлуқ дәлилләштин өтиду. Санлиқ мәлуматлар шифирланған һаләттә сақлиниду. Һәр вақит йардәм мулазимитигә йазсиңиз болиду.'},
    // Һесабат
    {'cat': 'account', 'q': 'Парольни қандақ әслигә кәлтуримән?', 'a': 'Кириш экранида «Парольни унтуп қалдиңизму?» ни бесиң. Элхәт киргүзүң — униңға қайта қуруш улиниши әвәтилиду.'},
    {'cat': 'account', 'q': 'Тел номурумни қандақ өзгәртимән?', 'a': 'Профил → Тәңшәкләр → Телефонни өзгәртиш бөлүмигә кириң. SMS коди арқилиқ тәстиқләш тәләп қилиниду.'},
    {'cat': 'account', 'q': 'Һесабатимни қандақ өчүримән?', 'a': 'Профил → Тәңшәкләр → Һесабатни өчүрүш. Барлиқ санлиқ мәлуматлириңиз вә еланлириңиз 30 күн ичидә мәңгүлүк өчүрүлиду.'},
    {'cat': 'account', 'q': 'Бир канчә һесабат ечишқа болидуму?', 'a': 'Йақ. Система каидилири бир канчә һесабат ечишни чәкләйду. Әгәр копейтилгән һесабатлар байқалса, һәр икки һесабат тәң чәклиниду.'},
  ];

  
    final _catKeys = ['all', 'general', 'taxi', 'account'];

  List<String> get _cats => [
    _t('all'),
    _t('general'),
    _t('taxi'),
    _t('account'),
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
    
    if (_selectedCat != 0) list = list.where((e) => e['cat'] == _catKeys[_selectedCat]).toList();
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
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildOperatorCard(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _FaqTile(item: _filtered[i], lang: widget.lang),
                childCount: _filtered.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── IQ-Поддержка баннер ──────────────────────────
  Widget _buildAiChatBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IqSupportScreen(lang: widget.lang),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('ai_chat_title'),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _t('ai_chat_sub'),
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _t('ai_chat_btn'),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF4A80F0),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
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
                  Text(_t('title'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                  const SizedBox(height: 4),
                  Text('${_filtered.length} ${_t('questions')}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: _t('search_hint'),
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
                border: Border.all(color: sel ? Colors.transparent : Colors.black.withValues(alpha: 0.04)),
                boxShadow: sel ? [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Row(children: [
                Icon(icons[i], color: sel ? Colors.white : Colors.grey, size: 15),
                const SizedBox(width: 6),
                Text(_cats[i], style: GoogleFonts.inter(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          );
        },
      ),
    );
  }



  Widget _buildOperatorCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), 
            blurRadius: 24, 
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF4A80F0).withValues(alpha: 0.02),
            blurRadius: 40,
            offset: const Offset(0, 4),
          )
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
                            _t('operator_title'), 
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900, 
                              fontSize: 16, 
                              color: theme.colorScheme.onSurface,
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
                                style: GoogleFonts.plusJakartaSans(
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
                      _t('operator_hours'), 
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5), 
                        fontSize: 12, 
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: _contactItem(
                  _t('wa_support'), 
                  const LinearGradient(
                    colors: [Color(0xFF128C7E), Color(0xFF075E54)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  const Color(0xFF075E54),
                  'whatsapp://send?phone=77089007030&text=${Uri.encodeComponent(_t("wa_message"))}', 
                  'https://wa.me/77089007030?text=${Uri.encodeComponent(_t("wa_message"))}',
                  PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill)
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _contactItem(
                  _t('tg_support'), 
                  const LinearGradient(
                    colors: [Color(0xFF24A1DE), Color(0xFF0088CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  const Color(0xFF0088CC),
                  'tg://resolve?phone=77089007030&text=${Uri.encodeComponent(_t("wa_message"))}', 
                  'https://t.me/+77089007030?text=${Uri.encodeComponent(_t("wa_message"))}',
                  PhosphorIcons.telegramLogo(PhosphorIconsStyle.fill)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactItem(String title, LinearGradient gradient, Color shadowColor, String url, String fallbackUrl, IconData icon) {
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
            }
          }
        } catch (e) {
          debugPrint('Error launching support messenger: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              title, 
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, 
                fontSize: 14, 
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
  final String lang;
  const _FaqTile({required this.item, required this.lang});
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
                    widget.item['cat'] == 'taxi' ? Icons.local_taxi_rounded
                      : widget.item['cat'] == 'account' ? Icons.person_rounded
                      : Icons.help_outline_rounded,
                    color: _catColor, size: 18,
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
