// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get activityBath => 'Купание';

  @override
  String get activityMassage => 'Массаж';

  @override
  String get activityMusic => 'Музыка';

  @override
  String get activityNailTrim => 'Стрижка ногтей';

  @override
  String get activityOutdoor => 'Прогулка';

  @override
  String get activityPlay => 'Игра';

  @override
  String get activityRead => 'Чтение';

  @override
  String get activitySkinToSkin => 'Кожа к коже';

  @override
  String get activitySwim => 'Плавание';

  @override
  String get activityTummyTime => 'Время на животике';

  @override
  String get activityVitamin => 'Витамин';

  @override
  String get add => 'Добавить';

  @override
  String ageDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String ageDueIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Роды через $count дня',
      many: 'Роды через $count дней',
      few: 'Роды через $count дня',
      one: 'Роды через $count день',
    );
    return '$_temp0';
  }

  @override
  String ageMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String agePair(Object big, Object small) {
    return '$big $small';
  }

  @override
  String ageWeeks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count недели',
      many: '$count недель',
      few: '$count недели',
      one: '$count неделя',
    );
    return '$_temp0';
  }

  @override
  String ageYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года',
      many: '$count лет',
      few: '$count года',
      one: '$count год',
    );
    return '$_temp0';
  }

  @override
  String agoDuration(Object duration) {
    return '$duration назад';
  }

  @override
  String get blowout => 'протёк';

  @override
  String get bookAddMemory => 'Добавить момент';

  @override
  String get bookAddPhoto => 'Добавить фото';

  @override
  String bookAgeOld(Object age) {
    return 'в $age';
  }

  @override
  String bookAsYouLookAt(Object name) {
    return 'если смотреть на малыша';
  }

  @override
  String bookBananaIntro(Object name) {
    return 'Один и тот же банан рядом с малышом каждый месяц: лучший способ увидеть, как быстро летит время.';
  }

  @override
  String get bookBananaName => 'Банан для масштаба';

  @override
  String get bookBeforeBirth => 'До рождения';

  @override
  String bookBorn(Object date) {
    return 'Дата рождения: $date';
  }

  @override
  String get bookChangePhoto => 'Сменить';

  @override
  String get bookChapter => 'Глава';

  @override
  String get bookChapterCelebrations => 'Праздники';

  @override
  String get bookChapterFamily => 'О твоей семье';

  @override
  String get bookChapterFirsts => 'Впервые';

  @override
  String get bookChapterGrowing => 'Растём';

  @override
  String get bookChapterHello => 'Привет, мир';

  @override
  String bookChapterNumber(Object number) {
    return 'ГЛАВА $number';
  }

  @override
  String get bookChapterSubCelebrations => 'Праздники и особые дни';

  @override
  String get bookChapterSubFamily => 'До тебя были мы';

  @override
  String get bookChapterSubFirsts => 'Всё новое, месяц за месяцем';

  @override
  String get bookChapterSubGrowing => 'Зубы, рост и как быстро летит время';

  @override
  String get bookChapterSubHello => 'Самое начало';

  @override
  String get bookChapterSubWaiting => 'Пока тебя ждали';

  @override
  String get bookChapterWaiting => 'В ожидании тебя';

  @override
  String get bookDaysBeforeBirth => 'дн. до рождения';

  @override
  String get bookDeleteBody =>
      'Момент и его фото будут удалены для всей семьи.';

  @override
  String get bookDeleteTitle => 'Удалить этот момент?';

  @override
  String get bookDiaryFirst => 'Написать первую страницу';

  @override
  String bookDiaryIntro(Object name) {
    return 'Время от времени — страница о том, как проходят дни. Распорядок заполняется по последним 7 дням.';
  }

  @override
  String get bookDiaryNew => 'Новая страница';

  @override
  String get bookDueDate => 'Предполагаемая дата родов';

  @override
  String bookDueOn(Object date) {
    return 'ПДР: $date';
  }

  @override
  String get bookEditMemory => 'Изменить момент';

  @override
  String get bookEmptyBody =>
      'Выберите идею ниже или добавьте свою: фото, день и пару слов о нём.';

  @override
  String get bookEmptyReadOnly =>
      'Моменты появятся здесь, когда семья их добавит.';

  @override
  String get bookEmptyTitle => 'Первая страница ждёт';

  @override
  String bookHereFor(Object time) {
    return 'С нами уже $time';
  }

  @override
  String get bookIdeaBabyShower => 'Беби-шауэр';

  @override
  String get bookIdeaBaptism => 'Крестины или имянаречение';

  @override
  String get bookIdeaBassinet => 'Вырос из люльки';

  @override
  String get bookIdeaBelly => 'Животик';

  @override
  String get bookIdeaBirthday => 'Первый день рождения';

  @override
  String get bookIdeaBoyOrGirl => 'Мальчик или девочка?';

  @override
  String get bookIdeaCameHome => 'Дома!';

  @override
  String get bookIdeaCar => 'Наша машина';

  @override
  String get bookIdeaCarSeat => 'Автокресло по ходу движения';

  @override
  String get bookIdeaChristmas => 'Первое Рождество';

  @override
  String get bookIdeaClapped => 'Хлопает в ладоши';

  @override
  String get bookIdeaClothesSize => 'Следующий размер одежды';

  @override
  String get bookIdeaCold => 'Первая простуда';

  @override
  String get bookIdeaCooed => 'Гулит';

  @override
  String get bookIdeaCrawled => 'Ползает';

  @override
  String get bookIdeaCup => 'Первый глоток из чашки';

  @override
  String get bookIdeaDada => 'Сказал(а) «папа»';

  @override
  String get bookIdeaDaycare => 'Первый день в садике';

  @override
  String get bookIdeaDiaperSize => 'Следующий размер подгузников';

  @override
  String get bookIdeaDiary => 'Дневник';

  @override
  String get bookIdeaEaster => 'Первая Пасха';

  @override
  String get bookIdeaFathersDay => 'Первый День отца';

  @override
  String get bookIdeaFirstBath => 'Первое купание';

  @override
  String get bookIdeaFirstBottle => 'Первая бутылочка';

  @override
  String get bookIdeaFirstDance => 'Первый танец';

  @override
  String get bookIdeaFirstLaugh => 'Первый смех';

  @override
  String get bookIdeaFirstShoes => 'Первая обувь';

  @override
  String get bookIdeaFirstSmile => 'Первая улыбка';

  @override
  String get bookIdeaFirstSolid => 'Первый прикорм';

  @override
  String get bookIdeaFirstSteps => 'Первые шаги';

  @override
  String get bookIdeaFirstTooth => 'Первый зуб';

  @override
  String get bookIdeaFirstWalk => 'Первая прогулка';

  @override
  String get bookIdeaFirstWord => 'Первое слово';

  @override
  String get bookIdeaFoundHands => 'Нашёл(ла) ручки';

  @override
  String get bookIdeaFoundOut => 'Мы узнали';

  @override
  String get bookIdeaFoundToes => 'Нашёл(ла) пальчики на ногах';

  @override
  String get bookIdeaGrandparents => 'Знакомство с бабушкой и дедушкой';

  @override
  String get bookIdeaHaircut => 'Первая стрижка';

  @override
  String get bookIdeaHalloween => 'Первый Хеллоуин';

  @override
  String get bookIdeaHeartbeat => 'Услышали сердцебиение';

  @override
  String get bookIdeaHeldHead => 'Держит головку';

  @override
  String get bookIdeaHome => 'Наш дом';

  @override
  String get bookIdeaHowWeMet => 'Как мы познакомились';

  @override
  String get bookIdeaKiss => 'Первый поцелуй';

  @override
  String get bookIdeaMama => 'Сказал(а) «мама»';

  @override
  String get bookIdeaMothersDay => 'Первый День матери';

  @override
  String get bookIdeaNursery => 'Детская комната';

  @override
  String get bookIdeaOwnBottle => 'Сам(а) держит бутылочку';

  @override
  String get bookIdeaOwnName => 'Узнаёт своё имя';

  @override
  String get bookIdeaOwnRoom => 'Своя комната';

  @override
  String get bookIdeaPets => 'Наши питомцы';

  @override
  String get bookIdeaPrints => 'Отпечатки ручек и ножек';

  @override
  String get bookIdeaPulledStand => 'Встаёт с опорой';

  @override
  String get bookIdeaReachedToy => 'Тянется к игрушке';

  @override
  String get bookIdeaRolledOver => 'Переворачивается';

  @override
  String get bookIdeaSatUp => 'Сидит без поддержки';

  @override
  String get bookIdeaSentence => 'Первая фраза';

  @override
  String get bookIdeaSiblings => 'Знакомство с братом или сестрой';

  @override
  String get bookIdeaSleptNight => 'Спит всю ночь';

  @override
  String get bookIdeaSnow => 'Первый снег';

  @override
  String get bookIdeaSounds => 'Поворачивается на звуки';

  @override
  String get bookIdeaSpoon => 'Ест ложкой сам(а)';

  @override
  String get bookIdeaStoodAlone => 'Стоит без опоры';

  @override
  String get bookIdeaSwim => 'Первое плавание';

  @override
  String get bookIdeaTrip => 'Первое путешествие';

  @override
  String get bookIdeaUltrasound => 'Первое УЗИ';

  @override
  String get bookIdeaWaved => 'Машет «пока-пока»';

  @override
  String get bookIdeaWedding => 'Наша свадьба';

  @override
  String get bookIdeasForChapter => 'Идеи для этой главы';

  @override
  String bookIdeasProgress(Object done, Object total) {
    return 'В книге $done из $total. Нажмите, чтобы добавить.';
  }

  @override
  String get bookIdeasToRemember => 'Что стоит запомнить';

  @override
  String bookLivedHere(Object time) {
    return 'Жили здесь $time';
  }

  @override
  String bookMemoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count момента',
      many: '$count моментов',
      few: '$count момента',
      one: '$count момент',
    );
    return '$_temp0';
  }

  @override
  String get bookNameHint => 'Первая улыбка, переворачивается…';

  @override
  String get bookNameNeeded => 'Что случилось? Дайте моменту название.';

  @override
  String get bookNewMemory => 'Новый момент';

  @override
  String get bookNewborn => 'Новорождённый';

  @override
  String bookNoBabyYet(Object family) {
    return 'Книга малыша появится здесь, когда в семью «$family» добавят малыша.';
  }

  @override
  String get bookNoMemories => 'Пока нет моментов';

  @override
  String get bookPhotoAMonth => 'фото каждый месяц';

  @override
  String bookPhotoCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String bookPhotoNotSaved(Object error) {
    return 'Момент сохранён, а фото нет: $error';
  }

  @override
  String bookPrintPhotoNotSaved(Object error) {
    return 'Момент и фото сохранены, а копия в полном размере для печати — нет: $error';
  }

  @override
  String bookPhotoOf(Object name) {
    return 'Фото: $name';
  }

  @override
  String get bookPreparingPhoto => 'Готовим фото…';

  @override
  String get bookSaveToBook => 'Сохранить в книгу';

  @override
  String get bookSaving => 'Сохранение…';

  @override
  String get bookSeeAll => 'Все';

  @override
  String get bookSetDueDate => 'Указать ПДР';

  @override
  String get bookStory => 'История';

  @override
  String get bookStoryHint => 'Где вы были, кто был рядом, что вы чувствовали…';

  @override
  String get bookTabCelebrations => 'Праздники';

  @override
  String get bookTabFamily => 'Семья';

  @override
  String get bookTabFirsts => 'Впервые';

  @override
  String get bookTabGrowing => 'Растём';

  @override
  String get bookTabHello => 'Привет';

  @override
  String get bookTabWaiting => 'Ожидание';

  @override
  String get bookTakeFirst => 'Сделать первое';

  @override
  String get bookTeeth => 'Зубы';

  @override
  String get bookTheBookOf => 'Книга малыша';

  @override
  String get bookTheFamily => 'семья';

  @override
  String get bookThisMonth => 'В этом месяце';

  @override
  String bookTitle(Object name) {
    return 'Книга · $name';
  }

  @override
  String bookWeeksAlong(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-я неделя',
      many: '$count-я неделя',
      few: '$count-я неделя',
      one: '$count-я неделя',
    );
    return '$_temp0';
  }

  @override
  String bookWeeksBeforeBirth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'за $count недели до рождения',
      many: 'за $count недель до рождения',
      few: 'за $count недели до рождения',
      one: 'за $count неделю до рождения',
    );
    return '$_temp0';
  }

  @override
  String get bookWhatHappened => 'Что случилось?';

  @override
  String bookWhenAfterYears(Object count) {
    return 'после $count лет';
  }

  @override
  String get bookWhenAnyTime => 'в любое время';

  @override
  String get bookWhenAnythingSpecial => 'любой особый день';

  @override
  String bookWhenAroundMonths(Object count) {
    return 'около $count мес.';
  }

  @override
  String bookWhenAroundWeeks(Object count) {
    return 'около $count нед.';
  }

  @override
  String bookWhenAroundWeeksRange(Object from, Object to) {
    return 'около $from–$to нед.';
  }

  @override
  String get bookWhenBeforeYou => 'до тебя';

  @override
  String get bookWhenEachOne => 'для каждого';

  @override
  String get bookWhenFirstDays => 'первые дни';

  @override
  String get bookWhenFirstWeeks => 'первые недели';

  @override
  String get bookWhenLastWeeks => 'последние недели';

  @override
  String bookWhenMonthsRange(Object from, Object to) {
    return '$from–$to мес.';
  }

  @override
  String get bookWhenNowAndThen => 'время от времени';

  @override
  String get bookWhenSpring => 'весна';

  @override
  String get bookWhenTest => 'тест';

  @override
  String bookWhenWeeksRange(Object from, Object to) {
    return '$from–$to нед.';
  }

  @override
  String get bookWhenWithFirstSteps => 'первые шаги';

  @override
  String get bookWhichTooth => 'Какой зуб?';

  @override
  String get bookYourOwn => 'Своё';

  @override
  String get both => 'Обе';

  @override
  String get breastfeedPlusBottle => 'Грудь + бутылочка';

  @override
  String get calendarDiapers => 'Подгузники';

  @override
  String get calendarFeeds => 'Кормления';

  @override
  String get calendarNextWeek => 'Следующая неделя';

  @override
  String get calendarOther => 'Другое';

  @override
  String get calendarPrevWeek => 'Предыдущая неделя';

  @override
  String get calendarTitle => 'Календарь';

  @override
  String get cancel => 'Отмена';

  @override
  String get childAddPhoto => 'Добавить фото';

  @override
  String get childBirthDate => 'Дата рождения (или ПДР)';

  @override
  String get childBirthDateMissing => 'Выберите дату рождения (или ПДР)';

  @override
  String get childBirthDateRequired => 'Дата рождения (или ПДР) *';

  @override
  String get childBoy => 'Мальчик';

  @override
  String get childChangePhoto => 'Сменить фото';

  @override
  String get childChoosePhoto => 'Выбрать фото';

  @override
  String get childDelete => 'Удалить малыша';

  @override
  String childDeleteBody(Object name) {
    return 'Профиль «$name» и всё, что для него записано, будут удалены навсегда для всех, кто ухаживает за малышом. Это нельзя отменить.';
  }

  @override
  String childDeleteTitle(Object name) {
    return 'Удалить профиль «$name»?';
  }

  @override
  String childEditTitle(Object name) {
    return 'Изменить: $name';
  }

  @override
  String get childEnterName => 'Введите имя';

  @override
  String get childGirl => 'Девочка';

  @override
  String get childName => 'Имя';

  @override
  String get childSexUnknown => 'Не указан';

  @override
  String get childTapToChoose => 'Нажмите, чтобы выбрать';

  @override
  String get close => 'Закрыть';

  @override
  String get colorBlack => 'Чёрный';

  @override
  String get colorBrown => 'Коричневый';

  @override
  String get colorGray => 'Серый';

  @override
  String get colorGreen => 'Зелёный';

  @override
  String get colorRed => 'Красный';

  @override
  String get colorYellow => 'Жёлтый';

  @override
  String commonChangeDay(Object day) {
    return 'Изменить день, $day';
  }

  @override
  String commonChangeTime(Object time) {
    return 'Изменить время, $time';
  }

  @override
  String commonSomethingWrong(Object error) {
    return 'Что-то пошло не так: $error';
  }

  @override
  String commonTypeToConfirm(Object text) {
    return 'Введите $text для подтверждения.';
  }

  @override
  String get consistencyMucousy => 'Со слизью';

  @override
  String get consistencyMushy => 'Кашицеобразный';

  @override
  String get consistencyPebbles => 'Комочками';

  @override
  String get consistencyRunny => 'Жидкий';

  @override
  String get consistencySolid => 'Твёрдый';

  @override
  String get dayHoursDayStarts => 'Начало дня';

  @override
  String get dayHoursDaytime => 'Дневное время';

  @override
  String get dayHoursIntro =>
      'Эти часы определяют, считается ли кормление, подгузник или сон дневным или ночным в «Статистике». Сон, начавшийся днём, — это дневной сон. Настройка действует для всей семьи.';

  @override
  String get dayHoursNightStarts => 'Начало ночи';

  @override
  String get dayHoursStartBeforeEnd =>
      'День должен начинаться раньше, чем заканчиваться.';

  @override
  String daysAgo(Object count) {
    return '$count дн. назад';
  }

  @override
  String get defaultBabyName => 'Малыш';

  @override
  String get delete => 'Удалить';

  @override
  String diaryBedtime(Object time) {
    return 'Отбой около $time';
  }

  @override
  String diaryFeeds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кормления в день',
      many: '$count кормлений в день',
      few: '$count кормления в день',
      one: '$count кормление в день',
    );
    return '$_temp0';
  }

  @override
  String diaryNaps(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дневного сна ($time всего)',
      many: '$count дневных снов ($time всего)',
      few: '$count дневных сна ($time всего)',
      one: '$count дневной сон ($time всего)',
    );
    return '$_temp0';
  }

  @override
  String diaryNightSleep(Object time) {
    return '$time ночного сна';
  }

  @override
  String get diarySchedule => 'Наши дни сейчас:';

  @override
  String diaryWakesUp(Object time) {
    return 'Подъём около $time';
  }

  @override
  String get dirty => 'Грязный';

  @override
  String get done => 'Готово';

  @override
  String get dry => 'Сухой';

  @override
  String durDaysHours(Object days, Object hours) {
    return '$days д $hours ч';
  }

  @override
  String durHoursMinutes(Object hours, Object minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String durMinutes(Object minutes) {
    return '$minutes мин';
  }

  @override
  String durMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes мин $seconds с';
  }

  @override
  String durSeconds(Object seconds) {
    return '$seconds с';
  }

  @override
  String get durUnderMinute => '<1 мин';

  @override
  String get edit => 'Изменить';

  @override
  String endedSide(Object side) {
    return 'закончили: $side';
  }

  @override
  String get familyAccount => 'Аккаунт';

  @override
  String get familyAddBaby => 'Добавить малыша';

  @override
  String get familyAndroidOnly => 'Доступно в приложении для Android';

  @override
  String get familyApiToken => 'API-токен';

  @override
  String get familyApiTokenHint => 'Для ваших скриптов';

  @override
  String get familyAppearance => 'Оформление';

  @override
  String get familyAtLeast8 => 'Не менее 8 символов';

  @override
  String get familyBabies => 'Малыши';

  @override
  String get familyBackedUp => 'Копия на Google Диске';

  @override
  String get familyBackupDrive => 'Резервная копия на Google Диск';

  @override
  String get familyBackupHint =>
      'Хранит копию в вашем аккаунте Google, раз в день';

  @override
  String get familyBackupServerHint =>
      'Копия данных сервера в вашем аккаунте Google, раз в день, на случай потери сервера';

  @override
  String get familyBookOnlyHint =>
      'Вам доступна книга малыша. Чтобы получить больше, обратитесь к владельцу семьи.';

  @override
  String familyBorn(Object date) {
    return 'дата рождения: $date';
  }

  @override
  String familyCaregiverCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека',
      many: '$count человек',
      few: '$count человека',
      one: '$count человек',
    );
    return '$_temp0';
  }

  @override
  String get familyCaregivers => 'Кто ухаживает';

  @override
  String get familyChangePassword => 'Сменить пароль';

  @override
  String get familyChooseAnotherFile => 'Выбрать другой файл';

  @override
  String get familyChooseCsv => 'Выбрать CSV-файл';

  @override
  String get familyCodeCopied => 'Код скопирован';

  @override
  String get familyContinue => 'Продолжить';

  @override
  String get familyConnectedApps => 'Подключённые приложения';

  @override
  String get familyConnectedAppAdd => 'Подключить приложение';

  @override
  String get familyConnectedAppAddHint =>
      'Home Assistant или другое приложение, записи от его имени';

  @override
  String get familyConnectedAppName => 'Название';

  @override
  String familyConnectedAppTokenTitle(Object name) {
    return 'Токен для $name';
  }

  @override
  String familyConnectedAppTokenBody(Object name) {
    return 'Скопируйте его сейчас — он больше не будет показан. Вставьте его в Home Assistant при добавлении интеграции Nestling. Его записи будут подписаны «$name».';
  }

  @override
  String familyConnectedAppUsed(Object when) {
    return 'Использовано: $when';
  }

  @override
  String get familyConnectedAppNeverUsed => 'Ещё не использовалось';

  @override
  String familyConnectedAppRemoveTitle(Object name) {
    return 'Удалить $name?';
  }

  @override
  String get familyConnectedAppRemoveBody =>
      'Его токен сразу перестанет работать. Сделанные записи останутся.';

  @override
  String get familyCopy => 'Копировать';

  @override
  String get familyCurrentPassword => 'Текущий пароль';

  @override
  String get familyDayNight => 'День и ночь';

  @override
  String familyDaytime(Object end, Object start) {
    return 'День $start–$end';
  }

  @override
  String get familyDelete => 'Удалить семью';

  @override
  String get familyDeleteBody =>
      'Семья, её малыши и все записи будут удалены навсегда для всех, кто ухаживает за малышами. Это нельзя отменить.';

  @override
  String familyDeleteTitle(Object name) {
    return 'Удалить «$name»?';
  }

  @override
  String familyDriveOn(Object account) {
    return 'Вкл. · $account';
  }

  @override
  String get familyDriveSync => 'Синхронизация через Google Диск';

  @override
  String get familyDriveSyncBody =>
      'Каждый телефон хранит свои изменения в папке Nestling на своём Google Диске и читает папки остальных, поэтому они догонят друг друга, даже если не открыты одновременно и не в одной сети Wi-Fi.\n\nGoogle попросит разрешить Nestling доступ к файлам, которые он создаёт на вашем Диске (и только к ним). Всё в папке зашифровано: прочитать это могут только телефоны вашей семьи. Включите на каждом телефоне. Затем дайте телефонам один раз синхронизироваться в одной сети Wi-Fi (или снова свяжите их), чтобы они нашли папки друг друга.';

  @override
  String get familyDriveSyncFailed =>
      'В прошлый раз синхронизация не удалась. Будет новая попытка.';

  @override
  String get familyDriveSyncHint =>
      'Для телефонов, которые не открыты одновременно или не в одной сети Wi-Fi';

  @override
  String get familyDriveSyncOn => 'Синхронизация через Диск включена';

  @override
  String get familyEnterCurrentPassword => 'Введите текущий пароль';

  @override
  String get familyExport => 'Экспорт данных';

  @override
  String get familyExportHint => 'Всё о семье в CSV-файле';

  @override
  String familyExported(Object name) {
    return 'Экспортировано: $name';
  }

  @override
  String get familyImportAccount => 'Аккаунт Nara';

  @override
  String familyImportAccountBody(Object name) {
    return 'Войдите в аккаунт Nara, чтобы скопировать историю в «$name». Пароль Nara используется один раз и не сохраняется.';
  }

  @override
  String get familyImportComplete => 'Импорт завершён';

  @override
  String familyImportCsvBody(Object name) {
    return 'Экспортируйте данные из приложения Nara (получится файл .csv), затем выберите этот файл здесь. Всё попадёт в «$name»; повторный импорт того же файла обновит записи, а не продублирует их.';
  }

  @override
  String get familyImportExportFile => 'Файл экспорта';

  @override
  String get familyImportNara => 'Импорт из Nara';

  @override
  String get familyImportNaraHint => 'Перенесите историю из Nara Baby';

  @override
  String familyImportRecords(num count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировать $count записи в «$name»',
      many: 'Импортировать $count записей в «$name»',
      few: 'Импортировать $count записи в «$name»',
      one: 'Импортировать $count запись в «$name»',
    );
    return '$_temp0';
  }

  @override
  String familyImportedUpdated(Object imported, Object updated) {
    return 'новых: $imported · обновлено: $updated';
  }

  @override
  String get familyInviteBody =>
      'Человек создаёт аккаунт на этом сервере и вводит этот код в разделе «Вступить в семью». Код работает один раз и действует 7 дней.';

  @override
  String get familyInviteBookOnly => 'Будет видна только книга малыша.';

  @override
  String get familyInviteCaregiver => 'Пригласить';

  @override
  String get familyInviteCode => 'Код приглашения';

  @override
  String get familyInviteHint => 'Партнёр, бабушка, няня…';

  @override
  String get familyJoin => 'Вступить в семью';

  @override
  String get familyJoinAnother => 'Вступить в другую семью';

  @override
  String get familyJoinAnotherHint => 'С кодом приглашения от её владельца';

  @override
  String get familyJoinButton => 'Вступить';

  @override
  String familyLastBackup(Object account, Object date) {
    return 'Последняя копия $date · $account';
  }

  @override
  String familyLeave(Object family) {
    return 'Выйти из семьи «$family»';
  }

  @override
  String get familyLeaveAction => 'Выйти';

  @override
  String get familyLeaveBody =>
      'Вы больше не увидите книгу малыша, пока вас снова не пригласят.';

  @override
  String familyLeaveTitle(Object family) {
    return 'Выйти из семьи «$family»?';
  }

  @override
  String get familyMedicines => 'Лекарства и напоминания';

  @override
  String get familyName => 'Название';

  @override
  String get familyNaraEmail => 'Эл. почта Nara';

  @override
  String get familyNaraPassword => 'Пароль Nara';

  @override
  String familyNaraProfile(Object name) {
    return 'Профиль Nara: $name';
  }

  @override
  String get familyNewPassword => 'Новый пароль';

  @override
  String get familyNewToken => 'Новый API-токен';

  @override
  String get familyNext => 'Далее';

  @override
  String get familyOtherDevicesSignedOut =>
      'На других устройствах будет выполнен выход';

  @override
  String get familyPairPhone => 'Связать телефон';

  @override
  String get familyPairPhoneHint =>
      'Телефон партнёра синхронизируется с этим по Wi-Fi';

  @override
  String get familyPasswordChanged => 'Пароль изменён';

  @override
  String familyPendingLost(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count изменения, сделанные офлайн, ещё не дошли до сервера и будут потеряны.',
      many:
          '$count изменений, сделанных офлайн, ещё не дошли до сервера и будут потеряны.',
      few:
          '$count изменения, сделанные офлайн, ещё не дошли до сервера и будут потеряны.',
      one:
          '$count изменение, сделанное офлайн, ещё не дошло до сервера и будет потеряно.',
    );
    return '$_temp0';
  }

  @override
  String get familyPreview => 'Предпросмотр (ничего не сохраняется)';

  @override
  String get familyPreviewAgain => 'Просмотреть снова';

  @override
  String get familyReadyToImport => 'Готово к импорту';

  @override
  String familyRecords(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get familyRemoveDataBody =>
      'Все записи будут стёрты с этого телефона. Связанные телефоны и резервная копия на Google Диске сохранят свою копию.';

  @override
  String get familyRemoveDataTitle =>
      'Удалить данные Nestling с этого телефона?';

  @override
  String get familyRemoveFromPhone => 'Удалить с этого телефона';

  @override
  String familyRemoveMemberBody(Object family) {
    return 'Доступ к семье «$family» будет закрыт.';
  }

  @override
  String familyRemoveMemberTitle(Object name) {
    return 'Удалить: $name?';
  }

  @override
  String get familyServer => 'Сервер';

  @override
  String familyServerValue(Object server) {
    return 'Сервер: $server';
  }

  @override
  String get familySettings => 'Настройки';

  @override
  String get familySignOutAnyway => 'Всё равно выйти?';

  @override
  String familySkipped(Object list) {
    return 'Пропущено: $list';
  }

  @override
  String familySummarySensor(Object url) {
    return 'Сенсор сводки: $url';
  }

  @override
  String familySyncedAgo(Object ago) {
    return 'Синхронизировано $ago';
  }

  @override
  String familySyncedAgoAccount(Object account, Object ago) {
    return 'Синхронизировано $ago · $account';
  }

  @override
  String get familyThemeDark => 'Тёмная';

  @override
  String get familyThemeLight => 'Светлая';

  @override
  String get familyThisBaby => 'этот малыш';

  @override
  String get familyTimeZone => 'Часовой пояс';

  @override
  String get familyTimeZoneHint =>
      'Определяет, где начинается день для дневных итогов';

  @override
  String get familyTitle => 'Семья';

  @override
  String get familyTokenBody =>
      'Скопируйте его сейчас — он больше не будет показан. Используйте как «Authorization: Bearer <token>».';

  @override
  String get familyTypeDiapers => 'Подгузники';

  @override
  String get familyTypeFeeds => 'Кормления';

  @override
  String get familyTypeFirsts => 'Впервые';

  @override
  String get familyTypeGrowth => 'Рост';

  @override
  String get familyTypeHealth => 'Здоровье';

  @override
  String get familyTypeNotes => 'Заметки';

  @override
  String get familyTypePump => 'Сцеживание';

  @override
  String get familyTypeRoutine => 'Режим';

  @override
  String get familyTypeSleep => 'Сон';

  @override
  String get familyUsersHint =>
      'Создание аккаунтов на этом сервере и управление ими';

  @override
  String get familyWithoutServer => 'Без сервера';

  @override
  String get familyWithoutServerHint =>
      'Хранится на этом телефоне и на связанных с ним';

  @override
  String familyYou(Object name) {
    return '$name (вы)';
  }

  @override
  String get formAddNote => 'Добавить заметку…';

  @override
  String get formAmount => 'Объём';

  @override
  String get formBlowout => 'Протёк';

  @override
  String get formBrandOptional => 'Марка (необязательно)';

  @override
  String get formChoose => 'Выбрать';

  @override
  String get formContinue => 'Продолжить';

  @override
  String get formDeleteMessage => 'Запись будет удалена для всей семьи.';

  @override
  String get formDeleteTitle => 'Удалить эту запись?';

  @override
  String get formDiaperRash => 'Опрелости';

  @override
  String get formDiaperWetDirtyDry => 'Подгузник мокрый, грязный или сухой?';

  @override
  String get formDoctor => 'Врач';

  @override
  String get formDose => 'Доза';

  @override
  String get formDuration => 'Длительность';

  @override
  String formEditTitle(Object what) {
    return 'Изменить: $what';
  }

  @override
  String get formFellAsleep => 'Засыпание';

  @override
  String get formFoods => 'Продукты';

  @override
  String get formFormulaName => 'Смесь';

  @override
  String get formHeadSize => 'Окружность головы';

  @override
  String get formHeight => 'Рост';

  @override
  String get formMeasured => 'Дата измерения';

  @override
  String formMedAlreadyGiven(Object last, Object time) {
    return 'Уже дано в $last. Следующая доза в $time.';
  }

  @override
  String formMedLimited(Object count, Object time) {
    return 'Доз за 24 часа: уже $count. Следующая — не раньше $time.';
  }

  @override
  String formMedTooSoon(Object last, Object time) {
    return 'Последняя доза в $last. Следующая — не раньше $time.';
  }

  @override
  String get formMilk => 'Молоко';

  @override
  String get formNotes => 'Заметки';

  @override
  String get formPottyWetOrDirty =>
      'По-маленькому, по-большому или и то и другое?';

  @override
  String get formSaveChanges => 'Сохранить изменения';

  @override
  String get formSleepEndMissing =>
      'Когда закончился сон? Для идущего сна используйте таймер сна.';

  @override
  String get formSleepEndShort => 'Когда закончился сон?';

  @override
  String get formStartTime => 'Время начала';

  @override
  String get formStartedOn => 'Начали с';

  @override
  String get formTextureColor => 'Консистенция и цвет';

  @override
  String get formTime => 'Время';

  @override
  String get formTitleBottle => 'Кормление из бутылочки';

  @override
  String get formTitleCombo => 'Смешанное кормление';

  @override
  String get formTotalTime => 'Общее время';

  @override
  String get formType => 'Тип';

  @override
  String get formUnit => 'Единица';

  @override
  String get formWeight => 'Вес';

  @override
  String get formWhatCame => 'Результат';

  @override
  String get formWhen => 'Когда';

  @override
  String get formWhere => 'Где';

  @override
  String get formWokeUp => 'Пробуждение';

  @override
  String get growthAddBirthDate => 'Указать дату рождения';

  @override
  String growthAddBirthDateNotice(Object name) {
    return '$name: укажите дату рождения, чтобы сравнить с кривыми роста ВОЗ.';
  }

  @override
  String get growthAddMeasurement => 'Добавить измерение';

  @override
  String get growthAge => 'Возраст';

  @override
  String growthAgeDays(Object days) {
    return '$days д';
  }

  @override
  String growthAgeMonthsDays(Object days, Object months) {
    return '$months мес $days д';
  }

  @override
  String growthAgeYearsMonths(Object months, Object years) {
    return '$years г $months мес';
  }

  @override
  String get growthBoys => 'Мальчики';

  @override
  String get growthBoysPercentile => 'Перцентиль для мальчиков';

  @override
  String get growthCompareWith => 'Сравнить с';

  @override
  String growthCurvesNote(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'девочки',
      'other': 'мальчики',
    });
    return 'Кривые: стандарты роста детей ВОЗ ($_temp0, от рождения до 24 месяцев), перцентили от 2 до 98. Одно измерение говорит мало; следите за динамикой и обсуждайте любые сомнения с врачом.';
  }

  @override
  String get growthGirls => 'Девочки';

  @override
  String get growthGirlsPercentile => 'Перцентиль для девочек';

  @override
  String get growthHead => 'Голова';

  @override
  String get growthLength => 'Рост';

  @override
  String get growthMonths => 'месяцы';

  @override
  String get growthNoneHead => 'Окружность головы ещё не измерялась.';

  @override
  String get growthNoneLength => 'Рост ещё не измерялся.';

  @override
  String get growthNoneWeight => 'Вес ещё не измерялся.';

  @override
  String growthPercentile(Object rank) {
    return 'перцентиль $rank';
  }

  @override
  String get growthTitle => 'Графики роста';

  @override
  String get growthWeeks => 'недели';

  @override
  String get growthWeight => 'Вес';

  @override
  String headShort(Object value) {
    return 'Голова $value';
  }

  @override
  String get healthAppointment => 'Приём у врача';

  @override
  String get healthMedicine => 'Лекарство';

  @override
  String get healthSymptom => 'Симптом';

  @override
  String get healthTemperature => 'Температура';

  @override
  String get healthVaccine => 'Прививка';

  @override
  String get homeAddBaby => 'Добавить малыша';

  @override
  String get homeAddNote => 'Добавить заметку';

  @override
  String get homeAsleep => 'спит';

  @override
  String homeAwakeFor(Object duration) {
    return 'Не спит $duration';
  }

  @override
  String homeAwakeLast(Object duration) {
    return 'не спит · сон $duration';
  }

  @override
  String get homeBabyBook => 'Книга малыша';

  @override
  String homeBreastCount(Object count) {
    return 'грудь: $count';
  }

  @override
  String get homeCaptionBottle => 'бутылочка';

  @override
  String get homeCaptionPotty => 'горшок';

  @override
  String get homeCardFeed => 'Кормление';

  @override
  String get homeCardFirsts => 'Впервые';

  @override
  String homeCardHistory(Object title) {
    return 'История: $title';
  }

  @override
  String get homeCardRoutine => 'Режим';

  @override
  String get homeChartsShort => 'Графики';

  @override
  String get homeDiaperReminder => 'Напоминание о подгузнике';

  @override
  String get homeDiapersIn24h => 'подгузники за 24 ч';

  @override
  String get homeDiapersToday => 'подгузники сегодня';

  @override
  String homeDoseDueSince(Object time) {
    return 'Доза на $time ещё не дана';
  }

  @override
  String get homeDoseNow => 'Следующую дозу можно дать сейчас';

  @override
  String homeDosesIn24h(Object given, Object max) {
    return '$given из $max за 24 ч';
  }

  @override
  String get homeFeedReminder => 'Напоминание о кормлении';

  @override
  String get homeFeedsIn24h => 'кормления за 24 ч';

  @override
  String get homeFeedsToday => 'кормления сегодня';

  @override
  String get homeGive => 'Дать';

  @override
  String get homeGrowthCharts => 'Графики роста';

  @override
  String homeHead(Object value) {
    return 'голова $value';
  }

  @override
  String get homeHide => 'Скрыть';

  @override
  String get homeHistoryShort => 'История';

  @override
  String homeLabelPaused(Object label) {
    return '$label · пауза';
  }

  @override
  String get homeLastSide => 'последняя сторона';

  @override
  String homeLiveBreastfeed(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'правая',
      'other': 'левая',
    });
    return 'грудь · $_temp0';
  }

  @override
  String get homeLiveTooltip =>
      'В реальном времени — изменения других взрослых видны сразу';

  @override
  String get homeLog => 'Записать';

  @override
  String homeLogCard(Object title) {
    return 'Записать: $title';
  }

  @override
  String homeNaps(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дневного сна',
      many: '$count дневных снов',
      few: '$count дневных сна',
      one: '$count дневной сон',
    );
    return '$_temp0';
  }

  @override
  String get homeNavBook => 'Книга';

  @override
  String get homeNavCalendar => 'Календарь';

  @override
  String get homeNavHome => 'Главная';

  @override
  String get homeNavTimeline => 'Лента';

  @override
  String get homeNavTrends => 'Статистика';

  @override
  String homeNextDoseOn(Object date, Object time) {
    return 'Следующая доза $date в $time';
  }

  @override
  String homeNextDoseToday(Object time) {
    return 'Следующая доза в $time';
  }

  @override
  String homeNextDoseTomorrow(Object time) {
    return 'Следующая доза завтра в $time';
  }

  @override
  String homeNightSleep(Object duration) {
    return 'ночь $duration';
  }

  @override
  String homeNoDiaperFor(Object duration) {
    return 'Без смены подгузника $duration';
  }

  @override
  String get homeNoDoseYet => 'Доз ещё не давали';

  @override
  String homeNoFeedFor(Object duration) {
    return 'Без кормления $duration';
  }

  @override
  String homeNoPumpFor(Object duration) {
    return 'Без сцеживания $duration';
  }

  @override
  String get homeNotSyncedYet => 'ещё не синхронизировано';

  @override
  String get homeOffline => 'офлайн';

  @override
  String homeOfflinePending(Object count) {
    return 'офлайн · ждут отправки: $count';
  }

  @override
  String homeOfflineTooltip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Офлайн — продолжайте записывать; $count изменения синхронизируются, когда сервер вернётся',
      many:
          'Офлайн — продолжайте записывать; $count изменений синхронизируются, когда сервер вернётся',
      few:
          'Офлайн — продолжайте записывать; $count изменения синхронизируются, когда сервер вернётся',
      one:
          'Офлайн — продолжайте записывать; $count изменение синхронизируется, когда сервер вернётся',
      zero:
          'Офлайн — продолжайте записывать; изменения синхронизируются, когда сервер вернётся',
    );
    return '$_temp0';
  }

  @override
  String get homePaused => 'пауза';

  @override
  String homePottyCount(Object count) {
    return 'горшок: $count';
  }

  @override
  String get homePumpReminder => 'Напоминание о сцеживании';

  @override
  String get homePumped => 'сцежено';

  @override
  String get homePumping => 'Сцеживание';

  @override
  String get homeReconnecting => 'Переподключение…';

  @override
  String get homeServerlessAlone =>
      'Без сервера: хранится на этом телефоне. Свяжите другой телефон в разделе «Семья», чтобы делиться.';

  @override
  String homeServerlessPeers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Без сервера: синхронизация с $count связанными телефонами в той же сети Wi-Fi',
      many:
          'Без сервера: синхронизация с $count связанными телефонами в той же сети Wi-Fi',
      few:
          'Без сервера: синхронизация с $count связанными телефонами в той же сети Wi-Fi',
      one:
          'Без сервера: синхронизация с $count связанным телефоном в той же сети Wi-Fi',
    );
    return '$_temp0';
  }

  @override
  String homeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Правая сторона',
      'other': 'Левая сторона',
    });
    return '$_temp0';
  }

  @override
  String homeSince(Object time) {
    return 'с $time';
  }

  @override
  String get homeSleepIn24h => 'сон за 24 ч';

  @override
  String get homeSleepReminder => 'Напоминание о сне';

  @override
  String get homeSleepToday => 'сон сегодня';

  @override
  String get homeSleeping => 'Сон';

  @override
  String homeSolidsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прикорма',
      many: '$count прикормов',
      few: '$count прикорма',
      one: '$count прикорм',
    );
    return '$_temp0';
  }

  @override
  String get homeStart => 'Старт';

  @override
  String get homeSwitchBaby => 'Сменить малыша';

  @override
  String get homeSyncLocal => 'на этом телефоне';

  @override
  String homeSynced(Object ago) {
    return 'синхронизировано $ago';
  }

  @override
  String get homeSyncing => 'синхронизация';

  @override
  String get homeSyncingTooltip => 'Синхронизация изменений, сделанных офлайн…';

  @override
  String get homeTapToLog => 'Нажмите, чтобы записать';

  @override
  String homeWetDirtyCounts(Object dirty, Object wet) {
    return 'мокрые: $wet · грязные: $dirty';
  }

  @override
  String homeWoke(Object ago) {
    return 'подъём $ago';
  }

  @override
  String get inThePotty => 'В горшок';

  @override
  String get justNow => 'только что';

  @override
  String get kindActivity => 'Занятие';

  @override
  String get kindBottle => 'Бутылочка';

  @override
  String get kindBreastfeed => 'Грудное кормление';

  @override
  String get kindCombo => 'Смешанное';

  @override
  String get kindDiaper => 'Подгузник';

  @override
  String get kindGrowth => 'Рост';

  @override
  String get kindHealth => 'Здоровье';

  @override
  String get kindMilestone => 'Достижение';

  @override
  String get kindNote => 'Заметка';

  @override
  String get kindPotty => 'Горшок';

  @override
  String get kindPump => 'Сцеживание';

  @override
  String get kindSleep => 'Сон';

  @override
  String get kindSolids => 'Прикорм';

  @override
  String get kindTemperature => 'Температура';

  @override
  String get language => 'Язык';

  @override
  String get left => 'Левая';

  @override
  String get leftShort => 'Л';

  @override
  String lengthShort(Object value) {
    return 'Рост $value';
  }

  @override
  String get localNeedsServer =>
      'Для этого нужен сервер Nestling. Без сервера всё остаётся на ваших телефонах.';

  @override
  String get locationArms => 'На руках';

  @override
  String get locationBassinet => 'Люлька';

  @override
  String get locationBed => 'Кровать';

  @override
  String get locationCar => 'Машина';

  @override
  String get locationCrib => 'Кроватка';

  @override
  String get locationStroller => 'Коляска';

  @override
  String get loginAskAdmin =>
      'Ещё нет аккаунта? Попросите того, кто управляет этим сервером Nestling, создать его для вас.';

  @override
  String get loginContinue => 'Продолжить';

  @override
  String get loginCreateAccount => 'Создать аккаунт';

  @override
  String get loginCreateAdmin => 'Создать аккаунт администратора';

  @override
  String get loginCreateYourAccount => 'Создайте аккаунт';

  @override
  String get loginEmail => 'Эл. почта';

  @override
  String get loginEnterEmail => 'Введите эл. почту';

  @override
  String get loginEnterName => 'Введите имя';

  @override
  String get loginEnterPassword => 'Введите пароль';

  @override
  String get loginEnterServer => 'Введите адрес вашего сервера Nestling';

  @override
  String get loginHaveAccount => 'У меня уже есть аккаунт';

  @override
  String get loginNewHere => 'Впервые здесь? Создайте аккаунт';

  @override
  String get loginNewServer =>
      'Новый сервер: создайте аккаунт администратора.\nОстальных взрослых вы добавите потом.';

  @override
  String get loginNoServerIntro =>
      'Нет домашнего сервера? Nestling работает и сам по себе: данные остаются на телефоне, можно связать телефон партнёра по Wi-Fi и делать резервные копии на Google Диск.';

  @override
  String get loginPassword => 'Пароль';

  @override
  String get loginPasswordMin => 'Не менее 8 символов';

  @override
  String get loginServerAddress => 'Адрес сервера';

  @override
  String loginServerLink(Object server) {
    return 'Сервер: $server';
  }

  @override
  String get loginServerless => 'Использовать без сервера';

  @override
  String get loginServerlessIntro =>
      'Всё, что вы записываете, хранится на этом телефоне. Как вас зовут? Другие взрослые увидят это имя.';

  @override
  String get loginSignIn => 'Войти';

  @override
  String get loginWelcomeBack => 'С возвращением';

  @override
  String get loginYourName => 'Ваше имя';

  @override
  String get milkBreastMilk => 'Грудное молоко';

  @override
  String get milkFormula => 'Смесь';

  @override
  String get milkMixed => 'Смешанное';

  @override
  String get notSet => 'Не задано';

  @override
  String get notifBreastfeedPaused => 'Кормление грудью на паузе';

  @override
  String notifBreastfeeding(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Кормление грудью · правая',
      'other': 'Кормление грудью · левая',
    });
    return '$_temp0';
  }

  @override
  String get notifChipPaused => 'Пауза';

  @override
  String notifPausedBody(Object duration) {
    return 'Уже $duration · нажмите, чтобы продолжить';
  }

  @override
  String get notifPumpPaused => 'Сцеживание на паузе';

  @override
  String get notifPumping => 'Сцеживание';

  @override
  String notifRunningBody(Object time) {
    return 'С $time · нажмите, чтобы открыть';
  }

  @override
  String get notifSleepPaused => 'Сон на паузе';

  @override
  String get notifSleeping => 'Сон';

  @override
  String notifTitle(Object child, Object what) {
    return '$child · $what';
  }

  @override
  String get now => 'Сейчас';

  @override
  String get ok => 'ОК';

  @override
  String get onboardingAddBaby => 'Добавить малыша';

  @override
  String onboardingAddLittleOne(Object family) {
    return 'Теперь добавьте малыша в семью «$family».';
  }

  @override
  String get onboardingBack => 'Назад';

  @override
  String get onboardingCreateFamily => 'Создать семью';

  @override
  String get onboardingFamilyName => 'Название семьи';

  @override
  String onboardingHi(Object name) {
    return 'Привет, $name!';
  }

  @override
  String get onboardingIntro =>
      'Создайте семью, чтобы следить за малышом, или вступите в семью по коду приглашения от партнёра.';

  @override
  String get onboardingIntroServerless =>
      'Создайте семью, чтобы следить за малышом, или присоединитесь к семье на телефоне партнёра.';

  @override
  String get onboardingInviteCode => 'Код приглашения';

  @override
  String get onboardingJoinFamily => 'Вступить в семью';

  @override
  String get onboardingJoinWithCode => 'Присоединиться по коду связи';

  @override
  String get onboardingNoBackup =>
      'В этом аккаунте Google нет резервной копии Nestling.';

  @override
  String get onboardingOrJoin => 'Или вступите в существующую';

  @override
  String get onboardingOrJoinPartner => 'Или присоединитесь к семье партнёра';

  @override
  String get onboardingOrRestore => 'Или восстановите резервную копию';

  @override
  String get onboardingOurFamily => 'Наша семья';

  @override
  String get onboardingPairIntro =>
      'Если малыша уже ведут на другом телефоне, свяжитесь с ним: всё перенесётся и будет синхронизироваться.';

  @override
  String get onboardingRestoreDrive => 'Восстановить из Google Диска';

  @override
  String get onboardingStartFamily => 'Создать семью';

  @override
  String get pagesAge => 'Возраст';

  @override
  String get pagesAndAlso => 'А ещё';

  @override
  String get pagesAt => 'Время';

  @override
  String get pagesBirth => 'Рождение';

  @override
  String get pagesBirthGrowthHint =>
      'Вес и рост при рождении берутся из записи «Рост» в день рождения.';

  @override
  String get pagesBirthPeople => 'Кто был рядом';

  @override
  String get pagesBorn => 'Дата рождения';

  @override
  String get pagesBornNoDate =>
      'Укажите дату рождения в разделе «Семья» → малыш, чтобы начать эту страницу.';

  @override
  String get pagesBornPrompt =>
      'Нажмите, чтобы добавить время, место, волосы и глаза.';

  @override
  String get pagesBornTitle => 'День твоего рождения';

  @override
  String get pagesEyes => 'Глаза';

  @override
  String get pagesFullName => 'Полное имя';

  @override
  String get pagesGrowthEmpty =>
      'Записывайте вес и рост в «Росте», и здесь появится каждый месяц.';

  @override
  String get pagesGrowthNoBirth =>
      'Укажите дату рождения, чтобы видеть рост по месяцам.';

  @override
  String get pagesHair => 'Волосы';

  @override
  String get pagesHead => 'Голова';

  @override
  String get pagesHintBirthPeople => 'Оба родителя, акушерка…';

  @override
  String get pagesHintEyes => 'Тёмно-синие';

  @override
  String get pagesHintHair => 'Тёмные и густые';

  @override
  String get pagesHintHospital => 'Если пусто, считается по моменту «Дома!»';

  @override
  String get pagesHintLabourStarted => 'Во вторник вечером, около 23:00';

  @override
  String get pagesHintLabourStory => 'Долгая ночь, дорога, первый крик…';

  @override
  String pagesHintLetter(Object name) {
    return '$name, когда ты будешь это читать…';
  }

  @override
  String get pagesHintLetterFrom => 'Кто пишет';

  @override
  String get pagesHintMeaning => 'Значение или происхождение';

  @override
  String get pagesHintName => 'Имя';

  @override
  String get pagesHintNames => 'Имена, по одному в строке';

  @override
  String get pagesHintNicknames => 'Как тебя зовут дома';

  @override
  String get pagesHintOthers => 'Почти выбранные';

  @override
  String get pagesHintPlace => 'Роддом, дом, город';

  @override
  String get pagesHintRemember => 'Первый крик, кто был рядом, погода…';

  @override
  String get pagesHintWhy => 'От кого или откуда оно';

  @override
  String get pagesHintWorldNote => 'Что-то ещё о том годе';

  @override
  String get pagesHospital => 'В роддоме';

  @override
  String pagesHospitalDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get pagesHospitalSameDay => 'Дома в тот же день';

  @override
  String get pagesLabourStarted => 'Начало родов';

  @override
  String get pagesLabourStory => 'Как всё прошло';

  @override
  String get pagesLength => 'Рост';

  @override
  String pagesLetterFrom(Object name) {
    return 'От: $name';
  }

  @override
  String pagesLetterFromNumber(int n) {
    return 'Письмо $n: от кого';
  }

  @override
  String pagesLetterNumber(int n) {
    return 'Письмо $n';
  }

  @override
  String pagesLetterOpenOn(Object date) {
    return 'Прочитать $date, в 18 лет';
  }

  @override
  String pagesLetterPrompt(Object name) {
    return '$name: напишите письмо, которое прочитают в 18 лет.';
  }

  @override
  String get pagesLetterTitle => 'Письмо на потом';

  @override
  String get pagesLookTitle => 'На кого ты похож(а)?';

  @override
  String get pagesLookSubtitle => 'Твои родители в младенчестве рядом с тобой';

  @override
  String pagesLookPrompt(String name) {
    return 'Нажмите, чтобы поставить детское фото каждого родителя рядом с фото ребёнка ($name).';
  }

  @override
  String get pagesLookBabyPhoto =>
      'Фото на этой странице (если нет, берётся из семейного древа).';

  @override
  String pagesLookNow(String name) {
    return '$name сейчас';
  }

  @override
  String get pagesHintLook => 'Вес при рождении, волосы, первое слово…';

  @override
  String get pagesLookNote => 'В кого ты пошёл(шла)';

  @override
  String get pagesHintLookNote => 'Те же глаза, та же хмурость…';

  @override
  String get pagesMeasured => 'Измерено';

  @override
  String get pagesMonthByMonth => 'Месяц за месяцем';

  @override
  String pagesMonthsShort(Object count) {
    return '$count мес.';
  }

  @override
  String get pagesMoon => 'Луна';

  @override
  String get pagesMoonFirstQuarter => 'Первая четверть';

  @override
  String get pagesMoonFull => 'Полнолуние';

  @override
  String get pagesMoonLastQuarter => 'Последняя четверть';

  @override
  String get pagesMoonNew => 'Новолуние';

  @override
  String get pagesMoonWaningCrescent => 'Убывающий серп';

  @override
  String get pagesMoonWaningGibbous => 'Убывающая луна';

  @override
  String get pagesMoonWaxingCrescent => 'Растущий серп';

  @override
  String get pagesMoonWaxingGibbous => 'Растущая луна';

  @override
  String get pagesNameMeaning => 'Что оно значит';

  @override
  String get pagesNameOthers => 'Какие ещё имена мы думали';

  @override
  String get pagesNamePrompt =>
      'Нажмите, чтобы написать, почему выбрали это имя.';

  @override
  String get pagesNameTitle => 'Твоё имя';

  @override
  String get pagesNameWhy => 'Почему мы его выбрали';

  @override
  String get pagesNicknames => 'Прозвища';

  @override
  String get pagesPriceBread => 'Хлеб';

  @override
  String get pagesPriceCar => 'Новая машина';

  @override
  String get pagesPriceCoffee => 'Кофе';

  @override
  String get pagesPriceDiapers => 'Подгузники';

  @override
  String get pagesPriceGas => 'Бензин';

  @override
  String get pagesPriceHint => 'Цена';

  @override
  String get pagesPriceHouse => 'Дом';

  @override
  String get pagesPriceMilk => 'Молоко';

  @override
  String get pagesPriceMovie => 'Билет в кино';

  @override
  String get pagesPriceRent => 'Аренда';

  @override
  String get pagesSaveToBook => 'Сохранить в книгу';

  @override
  String get pagesSaving => 'Сохранение…';

  @override
  String get pagesSetTime => 'Указать';

  @override
  String get pagesStoryPrompt =>
      'Нажмите, чтобы рассказать, как прошёл этот важный день.';

  @override
  String get pagesStoryTitle => 'История твоего рождения';

  @override
  String pagesTapToEdit(Object title) {
    return '$title. Нажмите, чтобы изменить.';
  }

  @override
  String get pagesTimeOfBirth => 'Время рождения';

  @override
  String get pagesTreeBabyPhoto =>
      'Фото малыша внизу древа, отдельно от фото профиля.';

  @override
  String get pagesTreeOthers => 'Двоюродные и другие родные';

  @override
  String get pagesTreePrompt => 'Нажмите, чтобы записать имена родных.';

  @override
  String get pagesTreeFullScreen => 'Во весь экран';

  @override
  String get pagesTreeTitle => 'Родословное древо';

  @override
  String get pagesWeRemember => 'Мы помним';

  @override
  String get pagesWeighed => 'Вес';

  @override
  String get pagesWeight => 'Вес';

  @override
  String get pagesWhatThingsCost => 'Сколько всё стоило';

  @override
  String get pagesWhere => 'Где';

  @override
  String get pagesWorldLeaders => 'Руководители';

  @override
  String get pagesWorldLeadersHint => 'Премьер-министр, президент, мэр…';

  @override
  String get pagesWorldMovies => 'В кино';

  @override
  String get pagesWorldMoviesHint => 'Что шло в кинотеатрах';

  @override
  String get pagesWorldNews => 'В новостях';

  @override
  String get pagesWorldNewsHint => 'О чём все говорили';

  @override
  String get pagesWorldPeople => 'Знаменитости';

  @override
  String get pagesWorldPeopleHint => 'Актёры, спортсмены, певцы';

  @override
  String get pagesWorldPrompt =>
      'Нажмите, чтобы записать песни, новости и сколько стоил кофе.';

  @override
  String get pagesWorldShows => 'По телевизору';

  @override
  String get pagesWorldShowsHint => 'Что все смотрели';

  @override
  String get pagesWorldSongs => 'Песни по радио';

  @override
  String get pagesWorldSongsHint => 'Хиты того года';

  @override
  String get pagesWorldTech => 'Гаджеты';

  @override
  String get pagesWorldTechHint => 'Телефон в кармане, главная новинка';

  @override
  String get pagesWorldTitle => 'Мир в год твоего рождения';

  @override
  String get pagesZodiac => 'Знак';

  @override
  String pagesZodiacSign(String sign) {
    String _temp0 = intl.Intl.selectLogic(sign, {
      'aries': 'Овен',
      'taurus': 'Телец',
      'gemini': 'Близнецы',
      'cancer': 'Рак',
      'leo': 'Лев',
      'virgo': 'Дева',
      'libra': 'Весы',
      'scorpio': 'Скорпион',
      'sagittarius': 'Стрелец',
      'capricorn': 'Козерог',
      'aquarius': 'Водолей',
      'pisces': 'Рыбы',
      'other': '$sign',
    });
    return '$_temp0';
  }

  @override
  String get pairingCodeCopied =>
      'Код связи скопирован. Отправляйте его только семье: он открывает данные малыша.';

  @override
  String get pairingCopyCode => 'Скопировать код';

  @override
  String get pairingIntro =>
      'На другом телефоне установите Nestling, выберите «Использовать без сервера», затем «Присоединиться по коду связи» и отсканируйте этот код. Оба телефона должны быть в одной сети Wi-Fi.';

  @override
  String get pairingJoinIntro =>
      'На телефоне, где уже есть Nestling: «Семья» → «Связать телефон». Отсканируйте показанный код (оба телефона в одной сети Wi-Fi).';

  @override
  String get pairingJoinTitle => 'Присоединиться по коду связи';

  @override
  String get pairingNeedsAndroid =>
      'Для связи телефонов нужно приложение для Android.';

  @override
  String get pairingNoneYet => 'Пока нет.';

  @override
  String get pairingNotSynced => 'Ещё не синхронизирован';

  @override
  String get pairingPairedPhones => 'Связанные телефоны';

  @override
  String get pairingPasteCode => 'Или вставьте код';

  @override
  String get pairingPhone => 'Телефон';

  @override
  String get pairingSyncNow => 'Синхронизировать';

  @override
  String get pairingTitle => 'Связать телефон';

  @override
  String pairingUnreachable(Object ago) {
    return 'Синхронизирован $ago · сейчас недоступен';
  }

  @override
  String get pickerAddActivity => 'Добавить занятие';

  @override
  String get pickerAddFood => 'Добавить продукт';

  @override
  String get pickerAddMedicine => 'Добавить лекарство';

  @override
  String get pickerAlreadyTried => 'Уже пробовали';

  @override
  String get pickerCommon => 'Популярные';

  @override
  String get pickerFoodApple => 'Яблоко';

  @override
  String get pickerFoodAvocado => 'Авокадо';

  @override
  String get pickerFoodBanana => 'Банан';

  @override
  String get pickerFoodBeef => 'Говядина';

  @override
  String get pickerFoodBlueberries => 'Черника';

  @override
  String get pickerFoodBread => 'Хлеб';

  @override
  String get pickerFoodBroccoli => 'Брокколи';

  @override
  String get pickerFoodCarrot => 'Морковь';

  @override
  String get pickerFoodCheese => 'Сыр';

  @override
  String get pickerFoodChicken => 'Курица';

  @override
  String get pickerFoodEgg => 'Яйцо';

  @override
  String get pickerFoodFish => 'Рыба';

  @override
  String get pickerFoodGreenBeans => 'Стручковая фасоль';

  @override
  String get pickerFoodLentils => 'Чечевица';

  @override
  String get pickerFoodMango => 'Манго';

  @override
  String get pickerFoodOatmeal => 'Овсянка';

  @override
  String get pickerFoodPasta => 'Макароны';

  @override
  String get pickerFoodPeach => 'Персик';

  @override
  String get pickerFoodPeanutButter => 'Арахисовая паста';

  @override
  String get pickerFoodPear => 'Груша';

  @override
  String get pickerFoodPeas => 'Горошек';

  @override
  String get pickerFoodRiceCereal => 'Рисовая каша';

  @override
  String get pickerFoodSquash => 'Кабачок';

  @override
  String get pickerFoodStrawberries => 'Клубника';

  @override
  String get pickerFoodSweetPotato => 'Батат';

  @override
  String get pickerFoodTofu => 'Тофу';

  @override
  String get pickerFoodYogurt => 'Йогурт';

  @override
  String pickerLastDose(Object dose) {
    return 'Последняя доза $dose';
  }

  @override
  String get pickerMedAcetaminophen => 'Парацетамол (Панадол)';

  @override
  String get pickerMedAmoxicillin => 'Амоксициллин';

  @override
  String get pickerMedAntihistamine => 'Антигистаминное (Фенистил)';

  @override
  String get pickerMedDiaperCream => 'Крем под подгузник';

  @override
  String get pickerMedGripeWater => 'Укропная вода';

  @override
  String get pickerMedIbuprofen => 'Ибупрофен (Нурофен)';

  @override
  String get pickerMedIron => 'Капли железа';

  @override
  String get pickerMedProbiotic => 'Пробиотик (BioGaia)';

  @override
  String get pickerMedSaline => 'Солевые капли';

  @override
  String get pickerMedSimethicone => 'Симетикон (Эспумизан)';

  @override
  String get pickerMedTeethingGel => 'Гель для дёсен';

  @override
  String get pickerMedVitaminD => 'Витамин D';

  @override
  String get pickerRecent => 'Недавние';

  @override
  String get pickerSelected => 'Выбрано';

  @override
  String pickerTimes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раза',
      many: '$count раз',
      few: '$count раза',
      one: '$count раз',
    );
    return '$_temp0';
  }

  @override
  String get pickerUseName => 'Использовать это название';

  @override
  String pickerUsedLast(Object day, Object times) {
    return '$times · последний раз $day';
  }

  @override
  String get pottyAccident => 'Мимо';

  @override
  String get pottySatDry => 'Посидели, но сухо';

  @override
  String get pottySuccess => 'Горшок';

  @override
  String get rash => 'опрелости';

  @override
  String get remove => 'Убрать';

  @override
  String get restore => 'Восстановить';

  @override
  String restoreConfirmInto(Object date, Object family) {
    return '«$family» (сохранено $date) будет добавлено в эту семью. Дети сопоставляются по имени; уже имеющиеся записи обновятся, а не продублируются.';
  }

  @override
  String restoreConfirmNew(Object date, Object family) {
    return '«$family» (сохранено $date) вернётся как новая семья с записями, лекарствами, напоминаниями и фото книги малыша.';
  }

  @override
  String get restoreConfirmTitle => 'Восстановить эту копию?';

  @override
  String restoreDone(Object entries, Object photos) {
    return 'Копия восстановлена: записей $entries, фото $photos';
  }

  @override
  String get restoreFromDrive => 'Восстановить из Google Диска';

  @override
  String get restoreFromDriveHint =>
      'Возвращает резервную копию семьи в эту семью';

  @override
  String get restoreWhich => 'Какую копию?';

  @override
  String get right => 'Правая';

  @override
  String get rightShort => 'П';

  @override
  String get roleBookViewer => 'Только книга';

  @override
  String get roleBookViewerHint => 'Видит книгу малыша, ничего не может менять';

  @override
  String get roleCaregiver => 'Помощник';

  @override
  String get roleCaregiverHint =>
      'Записывает кормления, сон, подгузники и всё остальное';

  @override
  String get roleOwner => 'Владелец';

  @override
  String get roleOwnerHint => 'Записывает всё и управляет семьёй';

  @override
  String get save => 'Сохранить';

  @override
  String get scheduleAddMedicine => 'Добавить лекарство';

  @override
  String get scheduleAddTime => 'Добавить время';

  @override
  String get scheduleDaily => 'ежедневно';

  @override
  String scheduleDailyAt(Object times) {
    return 'Ежедневно в $times';
  }

  @override
  String get scheduleDescribeEmpty =>
      'Дозы по расписанию, «без кормления 3 ч»…';

  @override
  String get scheduleDoseLabel => 'Обычная доза (необязательно)';

  @override
  String get scheduleDoses => 'дозы';

  @override
  String get scheduleErrDose => 'Доза должна быть числом.';

  @override
  String get scheduleErrEvery => 'Как часто: от 0,5 до 168 часов.';

  @override
  String get scheduleErrMax => 'Максимум за 24 часа: число от 1 до 24.';

  @override
  String get scheduleErrName => 'Дайте лекарству название.';

  @override
  String get scheduleErrTimes => 'Добавьте хотя бы одно время.';

  @override
  String get scheduleEvery => 'Каждые';

  @override
  String scheduleEveryHours(Object hours) {
    return 'Раз в $hours ч';
  }

  @override
  String scheduleEveryMinutes(Object minutes) {
    return 'Раз в $minutes мин';
  }

  @override
  String get scheduleFeed => 'Кормление';

  @override
  String get scheduleFooterPush =>
      'Наступившее напоминание появляется на главном экране (смахните, чтобы скрыть) и отправляется на телефоны всей семьи. Напоминание о лекарстве на телефон включается в его расписании.';

  @override
  String get scheduleFooterServer =>
      'Наступившее напоминание появляется на главном экране (смахните, чтобы скрыть). Чтобы получать его и как уведомление на телефон, настройте уведомления на сервере (см. «Notifications on phones» в README).';

  @override
  String get scheduleFooterServerless =>
      'Наступившее напоминание появляется на главном экране (смахните, чтобы скрыть). Для уведомлений на телефон нужен сервер Nestling с их настройкой.';

  @override
  String get scheduleHours => 'часов';

  @override
  String scheduleIntro(Object name) {
    return 'Для: $name. Лекарство по расписанию показывается на главном экране со временем, когда можно дать следующую дозу, а слишком ранняя запись вызывает предупреждение.';
  }

  @override
  String get scheduleMaxLabel => 'Максимум за 24 часа (необязательно)';

  @override
  String get scheduleMedicineSection => 'Расписание лекарства';

  @override
  String get scheduleModeAfterDose => 'После каждой дозы';

  @override
  String scheduleModeHint(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'times':
          'В одно и то же время каждый день, когда бы ни дали последнюю дозу.',
      'other':
          'Следующая доза отсчитывается от последней, поэтому сдвигается вместе с ней.',
    });
    return '$_temp0';
  }

  @override
  String get scheduleModeTimes => 'В заданное время';

  @override
  String get scheduleName => 'Название';

  @override
  String scheduleNotifyWhen(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'Уведомить, если не спит дольше:',
      'diaper': 'Уведомить, если подгузник не меняли:',
      'pump': 'Уведомить, если не было сцеживания:',
      'other': 'Уведомить, если не было кормления:',
    });
    return '$_temp0';
  }

  @override
  String get scheduleOff => 'Выкл.';

  @override
  String get scheduleOnceADay => 'Раз в день';

  @override
  String get scheduleOnceAWeek => 'Раз в неделю';

  @override
  String get scheduleRemindDue => 'Напомнить, когда пора дать следующую дозу';

  @override
  String get scheduleReminderOn => 'напоминание вкл.';

  @override
  String scheduleReminderTitle(Object label) {
    return 'Напоминание: $label';
  }

  @override
  String get scheduleReminders => 'Напоминания';

  @override
  String scheduleRemindersList(num count, Object types) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Напоминания: $types',
      many: 'Напоминания: $types',
      few: 'Напоминания: $types',
      one: 'Напоминание: $types',
    );
    return '$_temp0';
  }

  @override
  String get scheduleTimesLabel => 'Давать в';

  @override
  String get scheduleTitle => 'Лекарства и напоминания';

  @override
  String get scheduleUnit => 'Единица';

  @override
  String scheduleUpToPerDay(Object count) {
    return 'в день: не более $count';
  }

  @override
  String scheduleWhenAfter(Object duration, String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'Если не спит $duration',
      'diaper': 'Если подгузник не меняли $duration',
      'pump': 'Если не было сцеживания $duration',
      'other': 'Если не было кормления $duration',
    });
    return '$_temp0';
  }

  @override
  String get settingsLanguageDevice => 'Язык устройства';

  @override
  String get signOut => 'Выйти';

  @override
  String summaryBreastMilk(Object amount) {
    return 'грудное молоко $amount';
  }

  @override
  String get summaryClose => 'Закрыть сводку';

  @override
  String get summaryFirsts => 'Впервые';

  @override
  String summaryFormula(Object amount) {
    return 'смесь $amount';
  }

  @override
  String summaryHead(Object value) {
    return 'голова $value';
  }

  @override
  String get summaryLast24h => 'За последние 24 часа';

  @override
  String summaryLeft(Object duration) {
    return 'левая $duration';
  }

  @override
  String summaryLongest(Object duration) {
    return 'самый долгий $duration';
  }

  @override
  String get summaryNotes => 'Заметки';

  @override
  String get summaryNothing => 'Пока ничего не записано.';

  @override
  String summaryPotty(num accidents, Object inPotty) {
    String _temp0 = intl.Intl.pluralLogic(
      accidents,
      locale: localeName,
      other: '$accidents раза мимо',
      many: '$accidents раз мимо',
      few: '$accidents раза мимо',
      one: '$accidents раз мимо',
    );
    return 'в горшок: $inPotty · $_temp0';
  }

  @override
  String summaryPumping(Object duration) {
    return 'сцеживание $duration';
  }

  @override
  String summaryRight(Object duration) {
    return 'правая $duration';
  }

  @override
  String get summaryRoutine => 'Режим';

  @override
  String summaryTemperature(Object values) {
    return 'температура $values';
  }

  @override
  String get summaryTitle => 'Сводка';

  @override
  String summaryTotal(Object amount) {
    return 'всего $amount';
  }

  @override
  String summaryWetDirty(Object dirty, Object wet) {
    return 'мокрые: $wet · грязные: $dirty';
  }

  @override
  String syncCantReach(Object server) {
    return 'Не удаётся связаться с сервером ($server).';
  }

  @override
  String syncCantReachCheck(Object server) {
    return 'Не удаётся связаться с сервером ($server). Проверьте адрес и подключение.';
  }

  @override
  String syncCantReachNamedPhone(Object name) {
    return 'Не удалось связаться с телефоном ($name). Оба телефона должны быть в одной сети Wi-Fi, а код связи — всё ещё на экране.';
  }

  @override
  String get syncCantReachOtherPhone =>
      'Не удалось связаться с другим телефоном. Оба телефона должны быть в одной сети Wi-Fi, а код связи — всё ещё на экране.';

  @override
  String syncChangeNotSaved(Object message) {
    return 'Не удалось сохранить изменение: $message';
  }

  @override
  String get syncConflict =>
      'То, что вы изменили, изменили и на другом устройстве; сохранено более новое изменение.';

  @override
  String get syncDriveFolderUnreachable =>
      'Папка семьи на Google Диске недоступна. Выключите и снова включите синхронизацию через Диск.';

  @override
  String get syncDriveNeedsAndroid =>
      'Для Google Диска нужно приложение для Android.';

  @override
  String get syncDriveNotGranted => 'Доступ к Google Диску не предоставлен.';

  @override
  String get syncEntryDeleted => 'Эту запись удалили на другом телефоне.';

  @override
  String get syncGoogleNotSignedIn => 'Вход в Google не выполнен.';

  @override
  String syncLoggedNotSaved(Object message) {
    return 'Не удалось сохранить запись: $message';
  }

  @override
  String get syncNotPairingCode => 'Это не код связи Nestling.';

  @override
  String syncOffline(Object host) {
    return 'Вы офлайн. Для этого нужно подключение к серверу ($host).';
  }

  @override
  String syncOfflineNotSent(Object message) {
    return 'Изменения, сделанные офлайн, пока не удалось отправить: $message';
  }

  @override
  String syncOtherPhoneAnswered(Object status) {
    return 'другой телефон ответил $status';
  }

  @override
  String get syncPairingIncomplete =>
      'Код связи неполный. Скопируйте его ещё раз.';

  @override
  String get syncPhonesNeedAndroid =>
      'Для прямой синхронизации телефонов нужно приложение для Android.';

  @override
  String syncServerError(Object status) {
    return 'Ошибка сервера ($status)';
  }

  @override
  String get syncTimerRunning =>
      'Этот таймер уже кто-то запустил. Теперь он показан.';

  @override
  String get syncTimerStopped =>
      'Этот таймер уже остановили на другом телефоне. Экран обновлён.';

  @override
  String get syncWifiFirst => 'Сначала подключите этот телефон к Wi-Fi.';

  @override
  String get system => 'Авто';

  @override
  String teethAgeOld(Object age) {
    return 'в $age';
  }

  @override
  String get teethCameIn => 'Прорезался';

  @override
  String get teethCameInOn => 'Дата прорезывания';

  @override
  String get teethCanine => 'клык';

  @override
  String get teethCentralIncisor => 'центральный резец';

  @override
  String teethChartSemantics(Object count) {
    return 'Схема зубов: прорезалось $count из 20. Нажмите на зуб, чтобы отметить его.';
  }

  @override
  String teethChartSemanticsReadOnly(Object count) {
    return 'Схема зубов: прорезалось $count из 20.';
  }

  @override
  String teethCount(Object count) {
    return '$count из 20';
  }

  @override
  String get teethFirstHint =>
      'Первый зуб попадёт в книгу как «Первый зуб»: добавьте туда фото и историю.';

  @override
  String get teethFirstMolar => 'первый моляр';

  @override
  String get teethItCameIn => 'Прорезался';

  @override
  String get teethLateralIncisor => 'боковой резец';

  @override
  String get teethLegendIn => 'Есть';

  @override
  String get teethLegendNotYet => 'Ещё нет';

  @override
  String get teethLower => 'НИЖНИЕ';

  @override
  String get teethLowerLeft => 'Нижний левый';

  @override
  String get teethLowerRight => 'Нижний правый';

  @override
  String teethName(Object kind, Object position) {
    return '$position $kind';
  }

  @override
  String get teethNotInYet => 'Ещё не прорезался';

  @override
  String get teethSaveDate => 'Сохранить дату';

  @override
  String get teethSecondMolar => 'второй моляр';

  @override
  String get teethTapChange =>
      'Нажмите на зуб, чтобы отметить его или изменить дату.';

  @override
  String get teethTapFirst => 'Нажмите на зуб, когда он прорежется.';

  @override
  String get teethUpper => 'ВЕРХНИЕ';

  @override
  String get teethUpperLeft => 'Верхний левый';

  @override
  String get teethUpperRight => 'Верхний правый';

  @override
  String teethUsually(Object when) {
    return 'Обычно прорезается в $when';
  }

  @override
  String teethWhen(Object range) {
    return '$range мес.';
  }

  @override
  String get timelineAll => 'Все';

  @override
  String get timelineDiapers => 'Подгузники';

  @override
  String get timelineEmpty => 'Здесь пока пусто.';

  @override
  String get timelineFeeds => 'Кормления';

  @override
  String timelineNote(Object note) {
    return '«$note»';
  }

  @override
  String get timelineSummary => 'Сводка';

  @override
  String timelineTitle(Object name) {
    return 'Лента · $name';
  }

  @override
  String timerAwakeFor(Object duration) {
    return 'Не спит $duration';
  }

  @override
  String get timerDeleteBody => 'Ничего не сохранится.';

  @override
  String get timerDeleteTitle => 'Удалить этот таймер?';

  @override
  String timerEditSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Изменить время слева',
      'other': 'Изменить время справа',
    });
    return '$_temp0';
  }

  @override
  String get timerEditTotal => 'Изменить общее время';

  @override
  String timerEndAfterStart(Object time) {
    return 'Конец должен быть после начала ($time).';
  }

  @override
  String get timerEndTime => 'Время окончания';

  @override
  String get timerFellAsleep => 'Засыпание';

  @override
  String get timerKeepsRunning => 'Закройте ✕, и таймер продолжит идти.';

  @override
  String timerLastFeedEnded(Object ago, String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Прошлое кормление закончилось слева',
      'other': 'Прошлое кормление закончилось справа',
    });
    String _temp1 = intl.Intl.selectLogic(side, {
      'left': 'Начните справа',
      'other': 'Начните слева',
    });
    return '$_temp0 · $ago\n$_temp1';
  }

  @override
  String get timerLastSideBadge => 'Прошлая\nсторона';

  @override
  String get timerLeftSide => 'Левая сторона';

  @override
  String get timerLogPast => 'Записать прошедшее';

  @override
  String get timerMinutes => 'Минуты';

  @override
  String get timerNoteHint => 'Заметка (необязательно)';

  @override
  String timerOnSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Слева',
      'other': 'Справа',
    });
    return '$_temp0';
  }

  @override
  String get timerPause => 'Пауза';

  @override
  String timerPauseSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Пауза слева',
      'other': 'Пауза справа',
    });
    return '$_temp0';
  }

  @override
  String get timerPaused => 'Пауза';

  @override
  String get timerPumpHowMuch => 'Сколько сцедили?';

  @override
  String get timerPumping => 'Сцеживание';

  @override
  String get timerResume => 'Продолжить';

  @override
  String timerResumeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Продолжить слева',
      'other': 'Продолжить справа',
    });
    return '$_temp0';
  }

  @override
  String get timerRightSide => 'Правая сторона';

  @override
  String timerSaved(Object what) {
    return 'Сохранено: $what';
  }

  @override
  String get timerSeconds => 'Секунды';

  @override
  String get timerSleeping => 'Сон';

  @override
  String get timerStart => 'Старт';

  @override
  String get timerStartInFuture => 'Начало не может быть в будущем.';

  @override
  String timerStartSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Начать слева',
      'other': 'Начать справа',
    });
    return '$_temp0';
  }

  @override
  String timerStartSideLast(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Начать слева (прошлая сторона)',
      'other': 'Начать справа (прошлая сторона)',
    });
    return '$_temp0';
  }

  @override
  String get timerStartTime => 'Время начала';

  @override
  String timerSwitchSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Перейти на левую',
      'other': 'Перейти на правую',
    });
    return '$_temp0';
  }

  @override
  String get timerTapSide => 'Нажмите на сторону, чтобы начать';

  @override
  String get timerTapStart => 'Нажмите, чтобы начать';

  @override
  String get timerTimeAsleep => 'Время сна';

  @override
  String get timerTotalTime => 'Общее время';

  @override
  String get timerTotalTimeTitle => 'Общее время';

  @override
  String get timerWokeUp => 'Пробуждение';

  @override
  String get today => 'Сегодня';

  @override
  String get trendsAccidents => 'Мимо горшка';

  @override
  String get trendsAmountPumped => 'Объём сцеживания';

  @override
  String get trendsAverage => 'в среднем';

  @override
  String get trendsBottleSize => 'Объём бутылочки';

  @override
  String trendsBottleUnit(Object unit) {
    return 'Бутылочка ($unit)';
  }

  @override
  String get trendsBreastfeedLength => 'Время у груди';

  @override
  String get trendsBreastfeeding => 'Кормление грудью';

  @override
  String trendsCompareArrows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Стрелки — сравнение с $count предыдущими днями.',
      many: 'Стрелки — сравнение с $count предыдущими днями.',
      few: 'Стрелки — сравнение с $count предыдущими днями.',
      one: 'Стрелки — сравнение со вчерашним днём.',
    );
    return '$_temp0';
  }

  @override
  String trendsCompareNone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'За $count предыдущего дня нет записей для сравнения.',
      many: 'За $count предыдущих дней нет записей для сравнения.',
      few: 'За $count предыдущих дня нет записей для сравнения.',
      one: 'Вчера ничего не записано для сравнения.',
    );
    return '$_temp0';
  }

  @override
  String get trendsDay => 'День';

  @override
  String get trendsDayBreastfeeding => 'Грудь днём';

  @override
  String get trendsDayDiapers => 'Подгузники днём';

  @override
  String get trendsDaySleep => 'Дневной сон';

  @override
  String trendsDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get trendsDiapers => 'Подгузники';

  @override
  String get trendsFeed => 'Кормление';

  @override
  String get trendsFeedInterval => 'Между кормлениями';

  @override
  String get trendsFeeds => 'Кормления';

  @override
  String get trendsGrowthChartsSub =>
      'Вес, рост и окружность головы на перцентильных кривых ВОЗ';

  @override
  String trendsIntro(num days, Object end, Object start) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Средние за сутки по $days полного дня; день — $start–$end.',
      many: 'Средние за сутки по $days полным дням; день — $start–$end.',
      few: 'Средние за сутки по $days полным дням; день — $start–$end.',
      one: 'Средние за сутки по $days полному дню; день — $start–$end.',
    );
    return '$_temp0';
  }

  @override
  String trendsIntroToday(Object end, Object start) {
    return 'Сегодня на данный момент; день — $start–$end.';
  }

  @override
  String get trendsLongestSleep => 'Самый долгий сон';

  @override
  String get trendsNapLength => 'Длина дневного сна';

  @override
  String get trendsNaps => 'Дневные сны';

  @override
  String get trendsNight => 'Ночь';

  @override
  String get trendsNightBreastfeeding => 'Грудь ночью';

  @override
  String get trendsNightDiapers => 'Подгузники ночью';

  @override
  String get trendsNightSleep => 'Ночной сон';

  @override
  String get trendsPerDay => 'в день';

  @override
  String get trendsPottyTrips => 'Походы на горшок';

  @override
  String get trendsPumpSessions => 'Сцеживания';

  @override
  String get trendsPumpTime => 'Время сцеживания';

  @override
  String get trendsTitle => 'Статистика';

  @override
  String get trendsWakeWindow => 'Окно бодрствования';

  @override
  String get trendsWetOnly => 'Только мокрые';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get usersAdd => 'Добавить пользователя';

  @override
  String get usersAddTitle => 'Новый пользователь';

  @override
  String usersAddTo(Object family) {
    return 'Добавить в семью «$family»';
  }

  @override
  String get usersAdmin => 'Администратор';

  @override
  String get usersAdminHint => 'Может управлять пользователями';

  @override
  String get usersAdminTag => 'админ';

  @override
  String get usersAsCaregiver => 'Как помощника';

  @override
  String get usersCanChangeLater => 'Пользователь сможет сменить его позже';

  @override
  String usersCanSignIn(Object name) {
    return '$name теперь может войти';
  }

  @override
  String get usersEmail => 'Эл. почта';

  @override
  String get usersEnterEmail => 'Введите эл. почту';

  @override
  String get usersEnterName => 'Введите имя';

  @override
  String get usersIntro =>
      'Только администраторы могут создавать аккаунты на этом сервере. Сообщите людям их эл. почту и пароль; сменить пароль можно в «Настройки» → «Аккаунт».';

  @override
  String get usersMakeAdmin => 'Сделать администратором';

  @override
  String usersManage(Object name) {
    return 'Управление: $name';
  }

  @override
  String usersNewPasswordFor(Object name) {
    return 'Новый пароль: $name';
  }

  @override
  String usersNoLongerAdmin(Object name) {
    return '$name больше не администратор';
  }

  @override
  String usersNowAdmin(Object name) {
    return '$name теперь администратор';
  }

  @override
  String get usersPassword => 'Пароль';

  @override
  String get usersPasswordHelp => 'Не менее 8 символов. Будет выполнен выход.';

  @override
  String usersPasswordSet(Object name) {
    return 'Новый пароль задан: $name';
  }

  @override
  String get usersRemoveAccount => 'Удалить аккаунт';

  @override
  String get usersRemoveAdmin => 'Снять права администратора';

  @override
  String get usersRemoveBody =>
      'Пользователь больше не сможет войти. Его семьи и все записи останутся.';

  @override
  String usersRemoveTitle(Object name) {
    return 'Удалить: $name?';
  }

  @override
  String usersRemoved(Object name) {
    return 'Удалено: $name';
  }

  @override
  String get usersSetPassword => 'Задать новый пароль';

  @override
  String get usersTitle => 'Пользователи';

  @override
  String get wet => 'Мокрый';

  @override
  String get wetAndDirty => 'Мокрый + грязный';

  @override
  String get yesterday => 'Вчера';

  @override
  String get settingsTemperature => 'Температура';

  @override
  String get settingsTimeFormat => 'Часы';

  @override
  String get settingsClock24 => '24 часа';

  @override
  String get settingsClock12 => '12 часов';

  @override
  String get formVolumeUnit => 'Единица для этого объёма';

  @override
  String get homePumpTimer => 'Таймер';

  @override
  String get settingsUnits => 'Единицы';

  @override
  String get settingsMetric => 'Метрич.';

  @override
  String get settingsImperial => 'Имперск.';

  @override
  String get growthUnits => 'Единицы для этих графиков';

  @override
  String get logBreast => 'Грудь';

  @override
  String get logAmount => 'Объём';

  @override
  String get unitMl => 'мл';

  @override
  String get unitOz => 'унц';

  @override
  String get unitKg => 'кг';

  @override
  String get unitLb => 'фнт';

  @override
  String get unitCm => 'см';

  @override
  String get unitIn => 'дюйм';

  @override
  String get aboutTitle => 'О приложении Nestling';

  @override
  String aboutVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get aboutTagline => 'Открытый дневник малыша на своём сервере.';

  @override
  String get aboutAppVersion => 'Версия приложения';

  @override
  String get aboutServerVersion => 'Версия сервера';

  @override
  String get aboutDevBuild => 'Сборка для разработки';

  @override
  String get aboutUnavailable => 'Недоступно';

  @override
  String get aboutSourceCode => 'Исходный код';

  @override
  String get aboutLicense => 'Лицензия';

  @override
  String get aboutLicenseValue => 'MIT: свободная и открытая';

  @override
  String get aboutOpenSource => 'Лицензии открытого ПО';

  @override
  String get aboutOpenSourceHint => 'Библиотеки, из которых собран Nestling';

  @override
  String get sizeSmall => 'Маленький';

  @override
  String get sizeMedium => 'Средний';

  @override
  String get sizeLarge => 'Большой';

  @override
  String get formWetSize => 'Мокрый: размер';

  @override
  String get formDirtySize => 'Грязный: размер';

  @override
  String partSize(Object part, Object size) {
    return '$part ($size)';
  }

  @override
  String get treeMother => 'Мама';

  @override
  String get treeFather => 'Папа';

  @override
  String get treeGrandmother => 'Бабушка';

  @override
  String get treeGrandfather => 'Дедушка';

  @override
  String get treeGreatGrandmother => 'Прабабушка';

  @override
  String get treeGreatGrandfather => 'Прадедушка';

  @override
  String get treeGreat2Grandmother => 'Прапрабабушка';

  @override
  String get treeGreat2Grandfather => 'Прапрадедушка';

  @override
  String treeGreatNGrandmother(int n) {
    return '$n× прабабушка';
  }

  @override
  String treeGreatNGrandfather(int n) {
    return '$n× прадедушка';
  }

  @override
  String get treeSister => 'Сестра';

  @override
  String get treeBrother => 'Брат';

  @override
  String get treeSibling => 'Брат или сестра';

  @override
  String get treeAunt => 'Тётя';

  @override
  String get treeUncle => 'Дядя';

  @override
  String get treeAuntOrUncle => 'Тётя или дядя';

  @override
  String get treeGreatAunt => 'Двоюродная бабушка';

  @override
  String get treeGreatUncle => 'Двоюродный дедушка';

  @override
  String get treeGreatAuntOrUncle => 'Двоюродная бабушка или дедушка';

  @override
  String treeGreatNAunt(int n) {
    return '$n× двоюродная бабушка';
  }

  @override
  String treeGreatNUncle(int n) {
    return '$n× двоюродный дедушка';
  }

  @override
  String treeGreatNAuntOrUncle(int n) {
    return '$n× двоюродная бабушка или дедушка';
  }

  @override
  String treeOnDadSide(String relation) {
    return '$relation по папе';
  }

  @override
  String treeOnMomSide(String relation) {
    return '$relation по маме';
  }

  @override
  String treeParentOf(String name, String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'mother': 'Мама · $name',
      'other': 'Папа · $name',
    });
    return '$_temp0';
  }

  @override
  String treeSiblingOf(String name, String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'sister': 'Сестра · $name',
      'brother': 'Брат · $name',
      'other': 'Брат или сестра · $name',
    });
    return '$_temp0';
  }

  @override
  String treeParentAsBaby(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'mother': 'Мама в младенчестве',
      'other': 'Папа в младенчестве',
    });
    return '$_temp0';
  }

  @override
  String get treeAddParents => 'Добавить родителей';

  @override
  String get treeAddSibling => 'Добавить брата или сестру';

  @override
  String get treeAnotherSibling => 'Ещё брат или сестра';

  @override
  String get treeRemovePerson => 'Убрать с древа';

  @override
  String get treeMoreAbove => 'Выше есть ещё поколения';

  @override
  String get treeTapHint =>
      'Нажмите на человека, чтобы увидеть его родителей. Удерживайте, чтобы изменить.';
}
