// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get activityBath => 'Bath';

  @override
  String get activityMassage => 'Massage';

  @override
  String get activityMusic => 'Music';

  @override
  String get activityNailTrim => 'Nail trim';

  @override
  String get activityOutdoor => 'Outdoor';

  @override
  String get activityPlay => 'Play';

  @override
  String get activityRead => 'Read';

  @override
  String get activitySkinToSkin => 'Skin to skin';

  @override
  String get activitySwim => 'Swim';

  @override
  String get activityTummyTime => 'Tummy time';

  @override
  String get activityVitamin => 'Vitamin';

  @override
  String get add => 'Add';

  @override
  String ageDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String ageDueIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Due in $_temp0';
  }

  @override
  String ageMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
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
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String ageYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String agoDuration(Object duration) {
    return '$duration ago';
  }

  @override
  String get blowout => 'blowout';

  @override
  String get bookAddMemory => 'Add a memory';

  @override
  String get bookAddPhoto => 'Add a photo';

  @override
  String bookAgeOld(Object age) {
    return '$age old';
  }

  @override
  String bookAsYouLookAt(Object name) {
    return 'as you look at $name';
  }

  @override
  String bookBananaIntro(Object name) {
    return 'The same banana next to $name every month: the best way to see how fast it goes.';
  }

  @override
  String get bookBananaName => 'Banana for scale';

  @override
  String get bookBeforeBirth => 'Before birth';

  @override
  String bookBorn(Object date) {
    return 'Born $date';
  }

  @override
  String get bookChangePhoto => 'Change';

  @override
  String get bookChapter => 'Chapter';

  @override
  String get bookChapterCelebrations => 'Celebrations';

  @override
  String get bookChapterFirsts => 'Firsts';

  @override
  String get bookChapterGrowing => 'Growing up';

  @override
  String get bookChapterHello => 'Hello, world';

  @override
  String bookChapterNumber(Object number) {
    return 'CHAPTER $number';
  }

  @override
  String get bookChapterSubCelebrations => 'Holidays and special days';

  @override
  String get bookChapterSubFirsts => 'Every new thing, month by month';

  @override
  String get bookChapterSubGrowing => 'Teeth, size, and how fast it goes';

  @override
  String get bookChapterSubHello => 'The very beginning';

  @override
  String get bookChapterSubWaiting => 'Before you arrived';

  @override
  String get bookChapterWaiting => 'Waiting for you';

  @override
  String get bookDaysBeforeBirth => 'days before birth';

  @override
  String get bookDeleteBody =>
      'It will be removed for everyone in the family, with its photo.';

  @override
  String get bookDeleteTitle => 'Delete this memory?';

  @override
  String get bookDueDate => 'Due date';

  @override
  String bookDueOn(Object date) {
    return 'Due $date';
  }

  @override
  String get bookEditMemory => 'Edit memory';

  @override
  String get bookEmptyBody =>
      'Pick an idea below or add your own: a photo, the day and a few words about it.';

  @override
  String get bookEmptyReadOnly => 'Memories show here as the family adds them.';

  @override
  String get bookEmptyTitle => 'The first page is waiting';

  @override
  String get bookIdeaBabyShower => 'Baby shower';

  @override
  String get bookIdeaBaptism => 'Baptism or naming day';

  @override
  String get bookIdeaBassinet => 'Outgrew the bassinet';

  @override
  String get bookIdeaBelly => 'The belly';

  @override
  String get bookIdeaBirthday => 'First birthday';

  @override
  String get bookIdeaBoyOrGirl => 'Boy or girl?';

  @override
  String get bookIdeaCameHome => 'Came home';

  @override
  String get bookIdeaCarSeat => 'Forward-facing car seat';

  @override
  String get bookIdeaChristmas => 'First Christmas';

  @override
  String get bookIdeaClapped => 'Clapped hands';

  @override
  String get bookIdeaClothesSize => 'Up a clothes size';

  @override
  String get bookIdeaCooed => 'Cooed';

  @override
  String get bookIdeaCrawled => 'Crawled';

  @override
  String get bookIdeaCup => 'First drink from a cup';

  @override
  String get bookIdeaDada => 'Said \"dada\"';

  @override
  String get bookIdeaDaycare => 'First day at daycare';

  @override
  String get bookIdeaDiaperSize => 'Up a diaper size';

  @override
  String get bookIdeaEaster => 'First Easter';

  @override
  String get bookIdeaFathersDay => 'First Father\'s Day';

  @override
  String get bookIdeaFirstBath => 'First bath';

  @override
  String get bookIdeaFirstBottle => 'First bottle';

  @override
  String get bookIdeaFirstDance => 'First dance';

  @override
  String get bookIdeaFirstLaugh => 'First laugh';

  @override
  String get bookIdeaFirstShoes => 'First shoes';

  @override
  String get bookIdeaFirstSmile => 'First smile';

  @override
  String get bookIdeaFirstSolid => 'First solid food';

  @override
  String get bookIdeaFirstSteps => 'First steps';

  @override
  String get bookIdeaFirstTooth => 'First tooth';

  @override
  String get bookIdeaFirstWalk => 'First walk outside';

  @override
  String get bookIdeaFirstWord => 'First word';

  @override
  String get bookIdeaFoundHands => 'Found hands';

  @override
  String get bookIdeaFoundOut => 'We found out';

  @override
  String get bookIdeaFoundToes => 'Found toes';

  @override
  String get bookIdeaGrandparents => 'Met the grandparents';

  @override
  String get bookIdeaHaircut => 'First haircut';

  @override
  String get bookIdeaHalloween => 'First Halloween';

  @override
  String get bookIdeaHeartbeat => 'Heard the heartbeat';

  @override
  String get bookIdeaHeldHead => 'Held head up';

  @override
  String get bookIdeaKiss => 'Gave a kiss';

  @override
  String get bookIdeaMama => 'Said \"mama\"';

  @override
  String get bookIdeaMothersDay => 'First Mother\'s Day';

  @override
  String get bookIdeaOwnBottle => 'Held own bottle';

  @override
  String get bookIdeaOwnName => 'Knew own name';

  @override
  String get bookIdeaOwnRoom => 'Own room';

  @override
  String get bookIdeaPulledStand => 'Pulled to stand';

  @override
  String get bookIdeaReachedToy => 'Reached for a toy';

  @override
  String get bookIdeaRolledOver => 'Rolled over';

  @override
  String get bookIdeaSatUp => 'Sat up alone';

  @override
  String get bookIdeaSleptNight => 'Slept through the night';

  @override
  String get bookIdeaSnow => 'First snow';

  @override
  String get bookIdeaSounds => 'Turned toward sounds';

  @override
  String get bookIdeaSpoon => 'Fed self with a spoon';

  @override
  String get bookIdeaStoodAlone => 'Stood alone';

  @override
  String get bookIdeaSwim => 'First swim';

  @override
  String get bookIdeaTrip => 'First trip';

  @override
  String get bookIdeaUltrasound => 'First ultrasound';

  @override
  String get bookIdeaWaved => 'Waved bye-bye';

  @override
  String get bookIdeasForChapter => 'Ideas for this chapter';

  @override
  String bookIdeasProgress(Object done, Object total) {
    return '$done of $total in the book. Tap one to add it.';
  }

  @override
  String get bookIdeasToRemember => 'Ideas to remember';

  @override
  String bookMemoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count memories',
      one: '1 memory',
    );
    return '$_temp0';
  }

  @override
  String get bookNameHint => 'First smile, rolled over…';

  @override
  String get bookNameNeeded => 'What happened? Give the memory a name.';

  @override
  String get bookNewMemory => 'New memory';

  @override
  String get bookNewborn => 'Newborn';

  @override
  String bookNoBabyYet(Object family) {
    return 'The baby book shows here once $family adds a baby.';
  }

  @override
  String get bookNoMemories => 'No memories yet';

  @override
  String get bookPhotoAMonth => 'a photo a month';

  @override
  String bookPhotoCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String bookPhotoNotSaved(Object error) {
    return 'The memory is saved, but not its photo: $error';
  }

  @override
  String bookPhotoOf(Object name) {
    return 'Photo: $name';
  }

  @override
  String get bookPreparingPhoto => 'Preparing the photo…';

  @override
  String get bookSaveToBook => 'Save to the book';

  @override
  String get bookSaving => 'Saving…';

  @override
  String get bookSeeAll => 'See all';

  @override
  String get bookSetDueDate => 'Set the due date';

  @override
  String get bookStory => 'The story';

  @override
  String get bookStoryHint => 'Where you were, who was there, how it felt…';

  @override
  String get bookTabCelebrations => 'Celebrations';

  @override
  String get bookTabFirsts => 'Firsts';

  @override
  String get bookTabGrowing => 'Growing';

  @override
  String get bookTabHello => 'Hello';

  @override
  String get bookTabWaiting => 'Waiting';

  @override
  String get bookTakeFirst => 'Take the first one';

  @override
  String get bookTeeth => 'Teeth';

  @override
  String get bookTheBookOf => 'The book of';

  @override
  String get bookTheFamily => 'the family';

  @override
  String get bookThisMonth => 'This month’s';

  @override
  String bookTitle(Object name) {
    return '$name’s book';
  }

  @override
  String bookWeeksAlong(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks along',
      one: '1 week along',
    );
    return '$_temp0';
  }

  @override
  String bookWeeksBeforeBirth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks before birth',
      one: '1 week before birth',
    );
    return '$_temp0';
  }

  @override
  String get bookWhatHappened => 'What happened?';

  @override
  String bookWhenAfterYears(Object count) {
    return 'after $count years';
  }

  @override
  String get bookWhenAnyTime => 'any time';

  @override
  String get bookWhenAnythingSpecial => 'anything special';

  @override
  String bookWhenAroundMonths(Object count) {
    return 'around $count months';
  }

  @override
  String bookWhenAroundWeeks(Object count) {
    return 'around $count weeks';
  }

  @override
  String bookWhenAroundWeeksRange(Object from, Object to) {
    return 'around $from–$to weeks';
  }

  @override
  String get bookWhenFirstDays => 'first days';

  @override
  String get bookWhenFirstWeeks => 'first weeks';

  @override
  String get bookWhenLastWeeks => 'last weeks';

  @override
  String bookWhenMonthsRange(Object from, Object to) {
    return '$from–$to months';
  }

  @override
  String get bookWhenNowAndThen => 'one now and then';

  @override
  String get bookWhenSpring => 'spring';

  @override
  String get bookWhenTest => 'the test';

  @override
  String bookWhenWeeksRange(Object from, Object to) {
    return '$from–$to weeks';
  }

  @override
  String get bookWhenWithFirstSteps => 'first steps';

  @override
  String get bookWhichTooth => 'Which tooth?';

  @override
  String get bookYourOwn => 'Your own';

  @override
  String get both => 'Both';

  @override
  String get breastfeedPlusBottle => 'Breastfeed + bottle';

  @override
  String get calendarDiapers => 'Diapers';

  @override
  String get calendarFeeds => 'Feeds';

  @override
  String get calendarNextWeek => 'Next week';

  @override
  String get calendarOther => 'Other';

  @override
  String get calendarPrevWeek => 'Previous week';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get cancel => 'Cancel';

  @override
  String get childAddPhoto => 'Add a photo';

  @override
  String get childBirthDate => 'Birth date (or due date)';

  @override
  String get childBirthDateMissing => 'Choose a birth date (or due date)';

  @override
  String get childBirthDateRequired => 'Birth date (or due date) *';

  @override
  String get childBoy => 'Boy';

  @override
  String get childChangePhoto => 'Change photo';

  @override
  String get childChoosePhoto => 'Choose a photo';

  @override
  String get childDelete => 'Delete baby';

  @override
  String childDeleteBody(Object name) {
    return 'This permanently deletes $name and everything logged for them, for every caregiver. It can\'t be undone.';
  }

  @override
  String childDeleteTitle(Object name) {
    return 'Delete $name?';
  }

  @override
  String childEditTitle(Object name) {
    return 'Edit $name';
  }

  @override
  String get childEnterName => 'Enter a name';

  @override
  String get childGirl => 'Girl';

  @override
  String get childName => 'Name';

  @override
  String get childSexUnknown => 'Unknown';

  @override
  String get childTapToChoose => 'Tap to choose';

  @override
  String get close => 'Close';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorGray => 'Gray';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorRed => 'Red';

  @override
  String get colorYellow => 'Yellow';

  @override
  String commonChangeDay(Object day) {
    return 'Change day, $day';
  }

  @override
  String commonChangeTime(Object time) {
    return 'Change time, $time';
  }

  @override
  String commonSomethingWrong(Object error) {
    return 'Something went wrong: $error';
  }

  @override
  String commonTypeToConfirm(Object text) {
    return 'Type $text to confirm.';
  }

  @override
  String get consistencyMucousy => 'Mucousy';

  @override
  String get consistencyMushy => 'Mushy';

  @override
  String get consistencyPebbles => 'Pebbles';

  @override
  String get consistencyRunny => 'Runny';

  @override
  String get consistencySolid => 'Solid';

  @override
  String get dayHoursDayStarts => 'Day starts';

  @override
  String get dayHoursDaytime => 'Daytime';

  @override
  String get dayHoursIntro =>
      'These times decide whether a feed, diaper or sleep counts as daytime or nighttime in Trends. Sleep that starts during the day is a nap. They apply to everyone in the family.';

  @override
  String get dayHoursNightStarts => 'Night starts';

  @override
  String get dayHoursStartBeforeEnd => 'Daytime must start before it ends.';

  @override
  String daysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get defaultBabyName => 'Baby';

  @override
  String get delete => 'Delete';

  @override
  String get dirty => 'Dirty';

  @override
  String get done => 'Done';

  @override
  String get dry => 'Dry';

  @override
  String durDaysHours(Object days, Object hours) {
    return '${days}d ${hours}h';
  }

  @override
  String durHoursMinutes(Object hours, Object minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String durMinutesSeconds(Object minutes, Object seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String durSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String get durUnderMinute => '<1m';

  @override
  String get edit => 'Edit';

  @override
  String endedSide(Object side) {
    return 'ended $side';
  }

  @override
  String get familyAccount => 'Account';

  @override
  String get familyAddBaby => 'Add a baby';

  @override
  String get familyAndroidOnly => 'Available in the Android app';

  @override
  String get familyApiToken => 'API token';

  @override
  String get familyApiTokenHint => 'For Home Assistant or scripts';

  @override
  String get familyAppearance => 'Appearance';

  @override
  String get familyAtLeast8 => 'At least 8 characters';

  @override
  String get familyBabies => 'Babies';

  @override
  String get familyBackedUp => 'Backed up to Google Drive';

  @override
  String get familyBackupDrive => 'Back up to Google Drive';

  @override
  String get familyBackupHint =>
      'Keeps a copy in your Google account, once a day';

  @override
  String get familyBookOnlyHint =>
      'You can see the baby book. Ask an owner of the family for more.';

  @override
  String familyBorn(Object date) {
    return 'born $date';
  }

  @override
  String familyCaregiverCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caregivers',
      one: '1 caregiver',
    );
    return '$_temp0';
  }

  @override
  String get familyCaregivers => 'Caregivers';

  @override
  String get familyChangePassword => 'Change password';

  @override
  String get familyChooseAnotherFile => 'Choose another file';

  @override
  String get familyChooseCsv => 'Choose the CSV file';

  @override
  String get familyCodeCopied => 'Code copied';

  @override
  String get familyContinue => 'Continue';

  @override
  String get familyCopy => 'Copy';

  @override
  String get familyCurrentPassword => 'Current password';

  @override
  String get familyDayNight => 'Day and night';

  @override
  String familyDaytime(Object end, Object start) {
    return 'Daytime $start–$end';
  }

  @override
  String get familyDelete => 'Delete family';

  @override
  String get familyDeleteBody =>
      'This permanently deletes the family, its babies and everything logged, for every caregiver. It can\'t be undone.';

  @override
  String familyDeleteTitle(Object name) {
    return 'Delete $name?';
  }

  @override
  String familyDriveOn(Object account) {
    return 'On · $account';
  }

  @override
  String get familyDriveSync => 'Sync through Google Drive';

  @override
  String get familyDriveSyncBody =>
      'Your phones will leave each other their changes in a shared folder in Google Drive, so they catch up even when they aren\'t open at the same time or on the same Wi-Fi.\n\nGoogle will ask to let Nestling use your Drive. Everything in the folder is encrypted: only your family\'s phones can read it. Turn it on on each phone.';

  @override
  String get familyDriveSyncFailed =>
      'Couldn\'t sync last time. It will try again.';

  @override
  String get familyDriveSyncHint =>
      'For phones that aren\'t open at the same time or on the same Wi-Fi';

  @override
  String get familyDriveSyncOn => 'Drive sync is on';

  @override
  String get familyEnterCurrentPassword => 'Enter your current password';

  @override
  String get familyExport => 'Export data';

  @override
  String get familyExportHint => 'Everything for this family as a CSV file';

  @override
  String familyExported(Object name) {
    return 'Exported $name';
  }

  @override
  String get familyImperialUnits => 'Imperial units';

  @override
  String get familyImportAccount => 'Nara account';

  @override
  String familyImportAccountBody(Object name) {
    return 'Sign in with your Nara account to copy your history into $name. Your Nara password is used once and never stored.';
  }

  @override
  String get familyImportComplete => 'Import complete';

  @override
  String familyImportCsvBody(Object name) {
    return 'Export your data from the Nara app (it gives you a .csv file), then pick that file here. Everything goes into $name; importing the same file again updates instead of duplicating.';
  }

  @override
  String get familyImportExportFile => 'Export file';

  @override
  String get familyImportNara => 'Import from Nara';

  @override
  String get familyImportNaraHint => 'Bring over your Nara Baby history';

  @override
  String familyImportRecords(num count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count records into $name',
      one: 'Import 1 record into $name',
    );
    return '$_temp0';
  }

  @override
  String familyImportedUpdated(Object imported, Object updated) {
    return '$imported new · $updated updated';
  }

  @override
  String get familyInviteBody =>
      'They create an account on this server, then enter this code under “Join a family”. It works once and expires in 7 days.';

  @override
  String get familyInviteBookOnly => 'They will only see the baby book.';

  @override
  String get familyInviteCaregiver => 'Invite a caregiver';

  @override
  String get familyInviteCode => 'Invite code';

  @override
  String get familyInviteHint => 'Partner, grandparent, nanny…';

  @override
  String get familyJoin => 'Join a family';

  @override
  String get familyJoinAnother => 'Join another family';

  @override
  String get familyJoinAnotherHint => 'With an invite code from its owner';

  @override
  String get familyJoinButton => 'Join';

  @override
  String familyLastBackup(Object account, Object date) {
    return 'Last backup $date · $account';
  }

  @override
  String familyLeave(Object family) {
    return 'Leave $family';
  }

  @override
  String get familyLeaveAction => 'Leave';

  @override
  String get familyLeaveBody =>
      'You won\'t see its baby book any more, unless invited again.';

  @override
  String familyLeaveTitle(Object family) {
    return 'Leave $family?';
  }

  @override
  String get familyMedicines => 'Medicines and reminders';

  @override
  String get familyName => 'Name';

  @override
  String get familyNaraEmail => 'Nara email';

  @override
  String get familyNaraPassword => 'Nara password';

  @override
  String familyNaraProfile(Object name) {
    return 'Nara profile: $name';
  }

  @override
  String get familyNewPassword => 'New password';

  @override
  String get familyNewToken => 'New API token';

  @override
  String get familyNext => 'Next';

  @override
  String get familyOtherDevicesSignedOut => 'Other devices will be signed out';

  @override
  String get familyPairPhone => 'Pair a phone';

  @override
  String get familyPairPhoneHint =>
      'Your partner\'s phone syncs with this one over Wi-Fi';

  @override
  String get familyPasswordChanged => 'Password changed';

  @override
  String familyPendingLost(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes made offline haven\'t reached the server yet and will be lost.',
      one:
          '1 change made offline hasn\'t reached the server yet and will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get familyPreview => 'Preview (nothing is saved)';

  @override
  String get familyPreviewAgain => 'Preview again';

  @override
  String get familyReadyToImport => 'Ready to import';

  @override
  String familyRecords(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String get familyRemoveDataBody =>
      'Everything logged here is erased from this phone. Paired phones and your Google Drive backup keep their copy.';

  @override
  String get familyRemoveDataTitle =>
      'Remove Nestling\'s data from this phone?';

  @override
  String get familyRemoveFromPhone => 'Remove from this phone';

  @override
  String familyRemoveMemberBody(Object family) {
    return 'They will lose access to $family.';
  }

  @override
  String familyRemoveMemberTitle(Object name) {
    return 'Remove $name?';
  }

  @override
  String get familyServer => 'Server';

  @override
  String familyServerValue(Object server) {
    return 'Server: $server';
  }

  @override
  String get familySettings => 'Settings';

  @override
  String get familySignOutAnyway => 'Sign out anyway?';

  @override
  String familySkipped(Object list) {
    return 'Skipped: $list';
  }

  @override
  String familySummarySensor(Object url) {
    return 'Summary sensor: $url';
  }

  @override
  String familySyncedAgo(Object ago) {
    return 'Synced $ago';
  }

  @override
  String familySyncedAgoAccount(Object account, Object ago) {
    return 'Synced $ago · $account';
  }

  @override
  String get familyThemeDark => 'Dark';

  @override
  String get familyThemeLight => 'Light';

  @override
  String get familyThisBaby => 'this baby';

  @override
  String get familyTimeZone => 'Time zone';

  @override
  String get familyTimeZoneHint =>
      'Sets where each day starts for daily totals';

  @override
  String get familyTitle => 'Family';

  @override
  String get familyTokenBody =>
      'Copy it now — it won’t be shown again. Use it as “Authorization: Bearer <token>”.';

  @override
  String get familyTypeDiapers => 'Diapers';

  @override
  String get familyTypeFeeds => 'Feeds';

  @override
  String get familyTypeFirsts => 'Firsts';

  @override
  String get familyTypeGrowth => 'Growth';

  @override
  String get familyTypeHealth => 'Health';

  @override
  String get familyTypeNotes => 'Notes';

  @override
  String get familyTypePump => 'Pump';

  @override
  String get familyTypeRoutine => 'Routine';

  @override
  String get familyTypeSleep => 'Sleep';

  @override
  String get familyUsersHint => 'Create and manage accounts on this server';

  @override
  String get familyWithoutServer => 'Without a server';

  @override
  String get familyWithoutServerHint =>
      'Saved on this phone and the phones paired with it';

  @override
  String familyYou(Object name) {
    return '$name (you)';
  }

  @override
  String get formAddNote => 'Add a note…';

  @override
  String get formAmount => 'Amount';

  @override
  String get formBlowout => 'Blowout';

  @override
  String get formBrandOptional => 'Brand (optional)';

  @override
  String get formChoose => 'Choose';

  @override
  String get formContinue => 'Continue';

  @override
  String get formDeleteMessage =>
      'It will be removed for everyone in the family.';

  @override
  String get formDeleteTitle => 'Delete this entry?';

  @override
  String get formDiaperRash => 'Diaper Rash';

  @override
  String get formDiaperWetDirtyDry => 'Was the diaper wet, dirty or dry?';

  @override
  String get formDoctor => 'Doctor';

  @override
  String get formDose => 'Dose';

  @override
  String get formDuration => 'Duration';

  @override
  String formEditTitle(Object what) {
    return 'Edit $what';
  }

  @override
  String get formFellAsleep => 'Fell asleep';

  @override
  String get formFoods => 'Foods';

  @override
  String get formFormulaName => 'Formula';

  @override
  String get formHeadSize => 'Head Size';

  @override
  String get formHeight => 'Height';

  @override
  String get formMeasured => 'Measured';

  @override
  String formMedLimited(Object count, Object time) {
    return 'Already $count doses in 24 hours. Next one allowed at $time.';
  }

  @override
  String formMedTooSoon(Object last, Object time) {
    return 'Last dose at $last. Next one allowed at $time.';
  }

  @override
  String get formMilk => 'Milk';

  @override
  String get formNotes => 'Notes';

  @override
  String get formPottyWetOrDirty => 'Was it wet, dirty or both?';

  @override
  String get formSaveChanges => 'Save changes';

  @override
  String get formSleepEndMissing =>
      'When did the sleep end? Use the sleep timer for a nap in progress.';

  @override
  String get formSleepEndShort => 'When did the sleep end?';

  @override
  String get formStartTime => 'Start Time';

  @override
  String get formStartedOn => 'Started on';

  @override
  String get formTextureColor => 'Texture & Color';

  @override
  String get formTime => 'Time';

  @override
  String get formTitleBottle => 'Bottle Feed';

  @override
  String get formTitleCombo => 'Combo Feed';

  @override
  String get formTotalTime => 'Total Time';

  @override
  String get formType => 'Type';

  @override
  String get formUnit => 'Unit';

  @override
  String get formWeight => 'Weight';

  @override
  String get formWhatCame => 'What came';

  @override
  String get formWhen => 'When';

  @override
  String get formWhere => 'Where';

  @override
  String get formWokeUp => 'Woke up';

  @override
  String get growthAddBirthDate => 'Add birth date';

  @override
  String growthAddBirthDateNotice(Object name) {
    return 'Add $name\'s birth date to compare with the WHO growth curves.';
  }

  @override
  String get growthAddMeasurement => 'Add a measurement';

  @override
  String get growthAge => 'Age';

  @override
  String growthAgeDays(Object days) {
    return '${days}d';
  }

  @override
  String growthAgeMonthsDays(Object days, Object months) {
    return '${months}m ${days}d';
  }

  @override
  String growthAgeYearsMonths(Object months, Object years) {
    return '${years}y ${months}m';
  }

  @override
  String get growthBoys => 'Boys';

  @override
  String get growthBoysPercentile => 'Boys percentile';

  @override
  String get growthCompareWith => 'Compare with';

  @override
  String growthCurvesNote(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'girls',
      'other': 'boys',
    });
    return 'Curves: WHO Child Growth Standards ($_temp0, birth to 24 months), percentiles 2 to 98. A single measurement says little; follow the trend, and ask your doctor about any worry.';
  }

  @override
  String get growthGirls => 'Girls';

  @override
  String get growthGirlsPercentile => 'Girls percentile';

  @override
  String get growthHead => 'Head';

  @override
  String get growthLength => 'Length';

  @override
  String get growthMonths => 'months';

  @override
  String get growthNoneHead => 'No head size measured yet.';

  @override
  String get growthNoneLength => 'No length measured yet.';

  @override
  String get growthNoneWeight => 'No weight measured yet.';

  @override
  String growthPercentile(Object rank) {
    return '$rank percentile';
  }

  @override
  String get growthTitle => 'Growth charts';

  @override
  String get growthWeeks => 'weeks';

  @override
  String get growthWeight => 'Weight';

  @override
  String headShort(Object value) {
    return 'Head $value';
  }

  @override
  String get healthAppointment => 'Appointment';

  @override
  String get healthMedicine => 'Medicine';

  @override
  String get healthSymptom => 'Symptom';

  @override
  String get healthTemperature => 'Temperature';

  @override
  String get healthVaccine => 'Vaccine';

  @override
  String get homeAddBaby => 'Add a baby';

  @override
  String get homeAddNote => 'Add a note';

  @override
  String get homeAsleep => 'asleep';

  @override
  String homeAwakeFor(Object duration) {
    return 'Awake for $duration';
  }

  @override
  String homeAwakeLast(Object duration) {
    return 'awake · last $duration';
  }

  @override
  String get homeBabyBook => 'Baby book';

  @override
  String homeBreastCount(Object count) {
    return '$count breast';
  }

  @override
  String get homeCaptionBottle => 'bottle';

  @override
  String get homeCaptionPotty => 'potty';

  @override
  String get homeCardFeed => 'Feed';

  @override
  String get homeCardFirsts => 'Firsts';

  @override
  String homeCardHistory(Object title) {
    return '$title history';
  }

  @override
  String get homeCardRoutine => 'Routine';

  @override
  String get homeChartsShort => 'Charts';

  @override
  String get homeDiaperReminder => 'Diaper reminder';

  @override
  String get homeDiapersIn24h => 'diapers in 24 h';

  @override
  String get homeDiapersToday => 'diapers today';

  @override
  String get homeDoseNow => 'Next dose can be given now';

  @override
  String homeDosesIn24h(Object given, Object max) {
    return '$given of $max in 24 h';
  }

  @override
  String get homeFeedReminder => 'Feed reminder';

  @override
  String get homeFeedsIn24h => 'feeds in 24 h';

  @override
  String get homeFeedsToday => 'feeds today';

  @override
  String get homeGive => 'Give';

  @override
  String get homeGrowthCharts => 'Growth charts';

  @override
  String homeHead(Object value) {
    return 'head $value';
  }

  @override
  String get homeHide => 'Hide';

  @override
  String get homeHistoryShort => 'History';

  @override
  String homeLabelPaused(Object label) {
    return '$label · paused';
  }

  @override
  String get homeLastSide => 'last side';

  @override
  String homeLiveBreastfeed(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'right',
      'other': 'left',
    });
    return 'breastfeed · $_temp0';
  }

  @override
  String get homeLiveTooltip =>
      'Live — changes from other caregivers appear instantly';

  @override
  String get homeLog => 'Log';

  @override
  String homeLogCard(Object title) {
    return 'Log $title';
  }

  @override
  String get homeLogFeed => 'Log a feed';

  @override
  String homeNaps(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count naps',
      one: '1 nap',
    );
    return '$_temp0';
  }

  @override
  String get homeNavBook => 'Book';

  @override
  String get homeNavCalendar => 'Calendar';

  @override
  String get homeNavHome => 'Home';

  @override
  String get homeNavTimeline => 'Timeline';

  @override
  String get homeNavTrends => 'Trends';

  @override
  String homeNextDoseOn(Object date, Object time) {
    return 'Next dose $date at $time';
  }

  @override
  String homeNextDoseToday(Object time) {
    return 'Next dose at $time';
  }

  @override
  String homeNextDoseTomorrow(Object time) {
    return 'Next dose tomorrow at $time';
  }

  @override
  String homeNightSleep(Object duration) {
    return '$duration night';
  }

  @override
  String homeNoDiaperFor(Object duration) {
    return 'No diaper change for $duration';
  }

  @override
  String get homeNoDoseYet => 'No dose given yet';

  @override
  String homeNoFeedFor(Object duration) {
    return 'No feed for $duration';
  }

  @override
  String homeNoPumpFor(Object duration) {
    return 'No pumping for $duration';
  }

  @override
  String get homeNotSyncedYet => 'not synced yet';

  @override
  String get homeOffline => 'offline';

  @override
  String homeOfflinePending(Object count) {
    return 'offline · $count to sync';
  }

  @override
  String homeOfflineTooltip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Offline — keep logging; $count changes will sync when the server is back',
      one: 'Offline — keep logging; 1 change will sync when the server is back',
      zero: 'Offline — keep logging; changes sync when the server is back',
    );
    return '$_temp0';
  }

  @override
  String get homePaused => 'paused';

  @override
  String homePottyCount(Object count) {
    return '$count potty';
  }

  @override
  String get homePumpReminder => 'Pump reminder';

  @override
  String get homePumped => 'pumped';

  @override
  String get homePumping => 'Pumping';

  @override
  String get homeReconnecting => 'Reconnecting…';

  @override
  String get homeServerlessAlone =>
      'Serverless: saved on this phone. Pair another phone in Family to share.';

  @override
  String homeServerlessPeers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Serverless: syncs with $count paired phones on the same Wi-Fi',
      one: 'Serverless: syncs with 1 paired phone on the same Wi-Fi',
    );
    return '$_temp0';
  }

  @override
  String homeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Right side',
      'other': 'Left side',
    });
    return '$_temp0';
  }

  @override
  String homeSince(Object time) {
    return 'since $time';
  }

  @override
  String get homeSleepIn24h => 'sleep in 24 h';

  @override
  String get homeSleepReminder => 'Sleep reminder';

  @override
  String get homeSleepToday => 'sleep today';

  @override
  String get homeSleeping => 'Sleeping';

  @override
  String homeSolidsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solids',
      one: '1 solid',
    );
    return '$_temp0';
  }

  @override
  String get homeStart => 'Start';

  @override
  String get homeSwitchBaby => 'Switch baby';

  @override
  String get homeSyncLocal => 'on this phone';

  @override
  String homeSynced(Object ago) {
    return 'synced $ago';
  }

  @override
  String get homeSyncing => 'syncing';

  @override
  String get homeSyncingTooltip => 'Syncing changes made offline…';

  @override
  String get homeTapToLog => 'Tap to log';

  @override
  String homeWetDirtyCounts(Object dirty, Object wet) {
    return '$wet wet · $dirty dirty';
  }

  @override
  String homeWoke(Object ago) {
    return 'woke $ago';
  }

  @override
  String get inThePotty => 'In the potty';

  @override
  String get justNow => 'just now';

  @override
  String get kindActivity => 'Activity';

  @override
  String get kindBottle => 'Bottle';

  @override
  String get kindBreastfeed => 'Breastfeed';

  @override
  String get kindCombo => 'Combo';

  @override
  String get kindDiaper => 'Diaper';

  @override
  String get kindGrowth => 'Growth';

  @override
  String get kindHealth => 'Health';

  @override
  String get kindMilestone => 'Milestone';

  @override
  String get kindNote => 'Note';

  @override
  String get kindPotty => 'Potty';

  @override
  String get kindPump => 'Pump';

  @override
  String get kindSleep => 'Sleep';

  @override
  String get kindSolids => 'Solids';

  @override
  String get kindTemperature => 'Temperature';

  @override
  String get language => 'Language';

  @override
  String get left => 'Left';

  @override
  String get leftShort => 'L';

  @override
  String lengthShort(Object value) {
    return 'L $value';
  }

  @override
  String get localNeedsServer =>
      'This needs a Nestling server. In serverless mode everything stays on your phones.';

  @override
  String get localPhotosNeedServer =>
      'Photos on memories need the Android app or a Nestling server.';

  @override
  String get locationArms => 'Arms';

  @override
  String get locationBassinet => 'Bassinet';

  @override
  String get locationBed => 'Bed';

  @override
  String get locationCar => 'Car';

  @override
  String get locationCrib => 'Crib';

  @override
  String get locationStroller => 'Stroller';

  @override
  String get loginAskAdmin =>
      'No account yet? Ask whoever runs this Nestling server to create one for you.';

  @override
  String get loginContinue => 'Continue';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get loginCreateAdmin => 'Create admin account';

  @override
  String get loginCreateYourAccount => 'Create your account';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEnterEmail => 'Enter your email';

  @override
  String get loginEnterName => 'Enter your name';

  @override
  String get loginEnterPassword => 'Enter your password';

  @override
  String get loginEnterServer => 'Enter your Nestling server address';

  @override
  String get loginHaveAccount => 'I already have an account';

  @override
  String get loginNewHere => 'New here? Create an account';

  @override
  String get loginNewServer =>
      'New server: create the admin account.\nYou\'ll add the other caregivers afterwards.';

  @override
  String get loginNoServerIntro =>
      'No home server? Nestling also works on its own: your data stays on your phone, and you can pair your partner\'s phone over Wi-Fi and back up to Google Drive.';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPasswordMin => 'At least 8 characters';

  @override
  String get loginServerAddress => 'Server address';

  @override
  String loginServerLink(Object server) {
    return 'Server: $server';
  }

  @override
  String get loginServerless => 'Use without a server';

  @override
  String get loginServerlessIntro =>
      'Everything you log is saved on this phone. What\'s your name? Other caregivers see it.';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginYourName => 'Your name';

  @override
  String get milkBreastMilk => 'Breast milk';

  @override
  String get milkFormula => 'Formula';

  @override
  String get milkMixed => 'Mixed';

  @override
  String get notSet => 'Not set';

  @override
  String get notifBreastfeedPaused => 'Breastfeed paused';

  @override
  String notifBreastfeeding(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Breastfeeding · right side',
      'other': 'Breastfeeding · left side',
    });
    return '$_temp0';
  }

  @override
  String get notifChipPaused => 'Paused';

  @override
  String notifPausedBody(Object duration) {
    return '$duration so far · tap to resume';
  }

  @override
  String get notifPumpPaused => 'Pump paused';

  @override
  String get notifPumping => 'Pumping';

  @override
  String notifRunningBody(Object time) {
    return 'Since $time · tap to open';
  }

  @override
  String get notifSleepPaused => 'Sleep paused';

  @override
  String get notifSleeping => 'Sleeping';

  @override
  String notifTitle(Object child, Object what) {
    return '$child · $what';
  }

  @override
  String get now => 'Now';

  @override
  String get ok => 'OK';

  @override
  String get onboardingAddBaby => 'Add a baby';

  @override
  String onboardingAddLittleOne(Object family) {
    return 'Now add your little one to $family.';
  }

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingCreateFamily => 'Create family';

  @override
  String get onboardingFamilyName => 'Family name';

  @override
  String onboardingHi(Object name) {
    return 'Hi $name!';
  }

  @override
  String get onboardingIntro =>
      'Start a family to track your baby, or join one with an invite code from your partner.';

  @override
  String get onboardingIntroServerless =>
      'Start a family to track your baby, or join the one on your partner\'s phone.';

  @override
  String get onboardingInviteCode => 'Invite code';

  @override
  String get onboardingJoinFamily => 'Join family';

  @override
  String get onboardingJoinWithCode => 'Join with a pairing code';

  @override
  String get onboardingNoBackup => 'No Nestling backup in this Google account.';

  @override
  String get onboardingOrJoin => 'Or join one';

  @override
  String get onboardingOrJoinPartner => 'Or join your partner\'s';

  @override
  String get onboardingOurFamily => 'Our family';

  @override
  String get onboardingPairIntro =>
      'If another phone already tracks your baby, pair with it: everything comes over and stays in sync.';

  @override
  String get onboardingRestoreDrive => 'Restore from Google Drive';

  @override
  String get onboardingStartFamily => 'Start a family';

  @override
  String get pagesAge => 'Age';

  @override
  String get pagesAndAlso => 'And also';

  @override
  String get pagesAt => 'At';

  @override
  String get pagesBirth => 'Birth';

  @override
  String get pagesBirthGrowthHint =>
      'Birth weight and length come from a Growth entry on the birth day.';

  @override
  String get pagesBorn => 'Born';

  @override
  String get pagesBornNoDate =>
      'Add the birth date in Family → the baby to start this page.';

  @override
  String get pagesBornPrompt =>
      'Tap to add the time, the place, hair and eyes.';

  @override
  String get pagesBornTitle => 'The day you were born';

  @override
  String get pagesEyes => 'Eyes';

  @override
  String get pagesFullName => 'Full name';

  @override
  String get pagesGrowthEmpty =>
      'Log weight and length in Growth, and each month shows here.';

  @override
  String get pagesGrowthNoBirth =>
      'Add the birth date to see growth month by month.';

  @override
  String get pagesHair => 'Hair';

  @override
  String get pagesHead => 'Head';

  @override
  String get pagesHintEyes => 'Deep blue';

  @override
  String get pagesHintHair => 'Dark and lots of it';

  @override
  String get pagesHintMeaning => 'Its meaning or origin';

  @override
  String get pagesHintNicknames => 'What we call you at home';

  @override
  String get pagesHintOthers => 'The runners-up';

  @override
  String get pagesHintPlace => 'The hospital, home, the city';

  @override
  String get pagesHintRemember => 'The first cry, who was there, the weather…';

  @override
  String get pagesHintWhy => 'Who or what it comes from';

  @override
  String get pagesHintWorldNote => 'Anything else about that year';

  @override
  String get pagesLength => 'Length';

  @override
  String get pagesMeasured => 'Measured';

  @override
  String get pagesMonthByMonth => 'Month by month';

  @override
  String pagesMonthsShort(Object count) {
    return '$count mo';
  }

  @override
  String get pagesMoon => 'The moon';

  @override
  String get pagesMoonFirstQuarter => 'First quarter';

  @override
  String get pagesMoonFull => 'Full moon';

  @override
  String get pagesMoonLastQuarter => 'Last quarter';

  @override
  String get pagesMoonNew => 'New moon';

  @override
  String get pagesMoonWaningCrescent => 'Waning crescent';

  @override
  String get pagesMoonWaningGibbous => 'Waning gibbous';

  @override
  String get pagesMoonWaxingCrescent => 'Waxing crescent';

  @override
  String get pagesMoonWaxingGibbous => 'Waxing gibbous';

  @override
  String get pagesNameMeaning => 'What it means';

  @override
  String get pagesNameOthers => 'Other names we thought of';

  @override
  String get pagesNamePrompt => 'Tap to write why you chose it.';

  @override
  String get pagesNameTitle => 'Your name';

  @override
  String get pagesNameWhy => 'Why we chose it';

  @override
  String get pagesNicknames => 'Nicknames';

  @override
  String get pagesPriceBread => 'Bread';

  @override
  String get pagesPriceCar => 'A new car';

  @override
  String get pagesPriceCoffee => 'A coffee';

  @override
  String get pagesPriceDiapers => 'Diapers';

  @override
  String get pagesPriceGas => 'Gas';

  @override
  String get pagesPriceHint => 'Price';

  @override
  String get pagesPriceHouse => 'A house';

  @override
  String get pagesPriceMilk => 'Milk';

  @override
  String get pagesPriceMovie => 'A movie ticket';

  @override
  String get pagesPriceRent => 'Rent';

  @override
  String get pagesSaveToBook => 'Save to the book';

  @override
  String get pagesSaving => 'Saving…';

  @override
  String get pagesSetTime => 'Set';

  @override
  String pagesTapToEdit(Object title) {
    return '$title. Tap to edit.';
  }

  @override
  String get pagesTimeOfBirth => 'Time of birth';

  @override
  String get pagesWeRemember => 'We remember';

  @override
  String get pagesWeighed => 'Weighed';

  @override
  String get pagesWeight => 'Weight';

  @override
  String get pagesWhatThingsCost => 'What things cost';

  @override
  String get pagesWhere => 'Where';

  @override
  String get pagesWorldLeaders => 'Leaders';

  @override
  String get pagesWorldLeadersHint => 'Prime minister, president, mayor…';

  @override
  String get pagesWorldMovies => 'At the movies';

  @override
  String get pagesWorldMoviesHint => 'What was playing';

  @override
  String get pagesWorldNews => 'In the news';

  @override
  String get pagesWorldNewsHint => 'What everyone was talking about';

  @override
  String get pagesWorldPeople => 'Famous faces';

  @override
  String get pagesWorldPeopleHint => 'Actors, athletes, singers';

  @override
  String get pagesWorldPrompt =>
      'Tap to note the songs, the news and what a coffee cost.';

  @override
  String get pagesWorldShows => 'On TV';

  @override
  String get pagesWorldShowsHint => 'Shows everyone watched';

  @override
  String get pagesWorldSongs => 'Songs on the radio';

  @override
  String get pagesWorldSongsHint => 'The hits that year';

  @override
  String get pagesWorldTech => 'Gadgets';

  @override
  String get pagesWorldTechHint => 'The phone in our pocket, the new thing';

  @override
  String get pagesWorldTitle => 'The world you were born into';

  @override
  String get pairingCodeCopied =>
      'Pairing code copied. Send it only to your family: it opens your baby\'s data.';

  @override
  String get pairingCopyCode => 'Copy the code instead';

  @override
  String get pairingIntro =>
      'On the other phone, install Nestling, choose \"Use without a server\", then \"Join with a pairing code\" and scan this. Both phones must be on the same Wi-Fi.';

  @override
  String get pairingJoinIntro =>
      'On a phone that already uses Nestling: Family → Pair a phone. Scan the code it shows (same Wi-Fi for both phones).';

  @override
  String get pairingJoinTitle => 'Join with a pairing code';

  @override
  String get pairingNeedsAndroid => 'Pairing phones needs the Android app.';

  @override
  String get pairingNoneYet => 'None yet.';

  @override
  String get pairingNotSynced => 'Not synced yet';

  @override
  String get pairingPairedPhones => 'Paired phones';

  @override
  String get pairingPasteCode => 'Or paste the code';

  @override
  String get pairingPhone => 'Phone';

  @override
  String get pairingSyncNow => 'Sync now';

  @override
  String get pairingTitle => 'Pair a phone';

  @override
  String pairingUnreachable(Object ago) {
    return 'Synced $ago · not reachable right now';
  }

  @override
  String get pickerAddActivity => 'Add an activity';

  @override
  String get pickerAddFood => 'Add a food';

  @override
  String get pickerAddMedicine => 'Add a medicine';

  @override
  String get pickerAlreadyTried => 'Already tried';

  @override
  String get pickerCommon => 'Common';

  @override
  String get pickerFoodApple => 'Apple';

  @override
  String get pickerFoodAvocado => 'Avocado';

  @override
  String get pickerFoodBanana => 'Banana';

  @override
  String get pickerFoodBeef => 'Beef';

  @override
  String get pickerFoodBlueberries => 'Blueberries';

  @override
  String get pickerFoodBread => 'Bread';

  @override
  String get pickerFoodBroccoli => 'Broccoli';

  @override
  String get pickerFoodCarrot => 'Carrot';

  @override
  String get pickerFoodCheese => 'Cheese';

  @override
  String get pickerFoodChicken => 'Chicken';

  @override
  String get pickerFoodEgg => 'Egg';

  @override
  String get pickerFoodFish => 'Fish';

  @override
  String get pickerFoodGreenBeans => 'Green beans';

  @override
  String get pickerFoodLentils => 'Lentils';

  @override
  String get pickerFoodMango => 'Mango';

  @override
  String get pickerFoodOatmeal => 'Oatmeal';

  @override
  String get pickerFoodPasta => 'Pasta';

  @override
  String get pickerFoodPeach => 'Peach';

  @override
  String get pickerFoodPeanutButter => 'Peanut butter';

  @override
  String get pickerFoodPear => 'Pear';

  @override
  String get pickerFoodPeas => 'Peas';

  @override
  String get pickerFoodRiceCereal => 'Rice cereal';

  @override
  String get pickerFoodSquash => 'Squash';

  @override
  String get pickerFoodStrawberries => 'Strawberries';

  @override
  String get pickerFoodSweetPotato => 'Sweet potato';

  @override
  String get pickerFoodTofu => 'Tofu';

  @override
  String get pickerFoodYogurt => 'Yogurt';

  @override
  String pickerLastDose(Object dose) {
    return 'Last dose $dose';
  }

  @override
  String get pickerMedAcetaminophen => 'Acetaminophen (Tylenol)';

  @override
  String get pickerMedAmoxicillin => 'Amoxicillin';

  @override
  String get pickerMedAntihistamine => 'Antihistamine (Benadryl)';

  @override
  String get pickerMedDiaperCream => 'Diaper cream';

  @override
  String get pickerMedGripeWater => 'Gripe water';

  @override
  String get pickerMedIbuprofen => 'Ibuprofen (Advil)';

  @override
  String get pickerMedIron => 'Iron drops';

  @override
  String get pickerMedProbiotic => 'Probiotic (BioGaia)';

  @override
  String get pickerMedSaline => 'Saline drops';

  @override
  String get pickerMedSimethicone => 'Simethicone (Ovol)';

  @override
  String get pickerMedTeethingGel => 'Teething gel';

  @override
  String get pickerMedVitaminD => 'Vitamin D';

  @override
  String get pickerRecent => 'Recent';

  @override
  String get pickerSelected => 'Selected';

  @override
  String pickerTimes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'Once',
    );
    return '$_temp0';
  }

  @override
  String get pickerUseName => 'Use this name';

  @override
  String pickerUsedLast(Object day, Object times) {
    return '$times · last $day';
  }

  @override
  String get pottyAccident => 'Accident';

  @override
  String get pottySatDry => 'Sat but dry';

  @override
  String get pottySuccess => 'Potty';

  @override
  String get rash => 'rash';

  @override
  String get remove => 'Remove';

  @override
  String get right => 'Right';

  @override
  String get rightShort => 'R';

  @override
  String get roleBookViewer => 'Book only';

  @override
  String get roleBookViewerHint => 'Sees the baby book, can\'t change anything';

  @override
  String get roleCaregiver => 'Caregiver';

  @override
  String get roleCaregiverHint =>
      'Logs feeds, sleep, diapers and everything else';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleOwnerHint => 'Logs everything and manages the family';

  @override
  String get save => 'Save';

  @override
  String get scheduleAddMedicine => 'Add a medicine';

  @override
  String get scheduleDaily => 'daily';

  @override
  String get scheduleDescribeEmpty =>
      'Doses on a schedule, \"no feed in 3 h\"…';

  @override
  String get scheduleDoseLabel => 'Usual dose (optional)';

  @override
  String get scheduleDoses => 'doses';

  @override
  String get scheduleErrDose => 'The dose must be a number.';

  @override
  String get scheduleErrEvery => 'How often: between 0.5 and 168 hours.';

  @override
  String get scheduleErrMax => 'At most per 24 hours: a number from 1 to 24.';

  @override
  String get scheduleErrName => 'Give the medicine a name.';

  @override
  String get scheduleEvery => 'Every';

  @override
  String scheduleEveryHours(Object hours) {
    return 'Every $hours h';
  }

  @override
  String scheduleEveryMinutes(Object minutes) {
    return 'Every $minutes min';
  }

  @override
  String get scheduleFeed => 'Feed';

  @override
  String get scheduleFooterPush =>
      'A reminder that is due shows on the home screen (swipe it away to hide it) and is sent to the phones of everyone in the family. A medicine\'s phone reminder is turned on in its schedule.';

  @override
  String get scheduleFooterServer =>
      'A reminder that is due shows on the home screen (swipe it away to hide it). To also get it as a phone notification, set up notifications on the server (see \"Notifications on phones\" in the README).';

  @override
  String get scheduleFooterServerless =>
      'A reminder that is due shows on the home screen (swipe it away to hide it). Phone notifications need a Nestling server with them set up.';

  @override
  String get scheduleHours => 'hours';

  @override
  String scheduleIntro(Object name) {
    return 'For $name. A scheduled medicine shows on the home screen with when the next dose may be given, and logging one too early warns you.';
  }

  @override
  String get scheduleMaxLabel => 'At most per 24 hours (optional)';

  @override
  String get scheduleMedicineSection => 'Medicine schedule';

  @override
  String get scheduleName => 'Name';

  @override
  String scheduleNotifyWhen(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'Notify when awake for this long:',
      'diaper': 'Notify when there was no diaper change for:',
      'pump': 'Notify when there was no pumping for:',
      'other': 'Notify when there was no feed for:',
    });
    return '$_temp0';
  }

  @override
  String get scheduleOff => 'Off';

  @override
  String get scheduleOnceADay => 'Once a day';

  @override
  String get scheduleOnceAWeek => 'Once a week';

  @override
  String get scheduleRemindDue => 'Remind when the next dose is due';

  @override
  String get scheduleReminderOn => 'reminder on';

  @override
  String scheduleReminderTitle(Object label) {
    return '$label reminder';
  }

  @override
  String get scheduleReminders => 'Reminders';

  @override
  String scheduleRemindersList(num count, Object types) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$types reminders',
      one: '$types reminder',
    );
    return '$_temp0';
  }

  @override
  String get scheduleTitle => 'Medicines and reminders';

  @override
  String get scheduleUnit => 'Unit';

  @override
  String scheduleUpToPerDay(Object count) {
    return 'up to $count a day';
  }

  @override
  String scheduleWhenAfter(Object duration, String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'When awake for $duration',
      'diaper': 'When there was no diaper change for $duration',
      'pump': 'When there was no pumping for $duration',
      'other': 'When there was no feed for $duration',
    });
    return '$_temp0';
  }

  @override
  String get settingsLanguageDevice => 'Device language';

  @override
  String get signOut => 'Sign out';

  @override
  String summaryBreastMilk(Object amount) {
    return '$amount breast milk';
  }

  @override
  String get summaryClose => 'Close summary';

  @override
  String get summaryFirsts => 'Firsts';

  @override
  String summaryFormula(Object amount) {
    return '$amount formula';
  }

  @override
  String summaryHead(Object value) {
    return 'head $value';
  }

  @override
  String get summaryLast24h => 'Last 24 hours';

  @override
  String summaryLeft(Object duration) {
    return '$duration left';
  }

  @override
  String summaryLongest(Object duration) {
    return 'longest $duration';
  }

  @override
  String get summaryNotes => 'Notes';

  @override
  String get summaryNothing => 'Nothing logged yet.';

  @override
  String summaryPotty(num accidents, Object inPotty) {
    String _temp0 = intl.Intl.pluralLogic(
      accidents,
      locale: localeName,
      other: '$accidents accidents',
      one: '1 accident',
    );
    return '$inPotty in the potty · $_temp0';
  }

  @override
  String summaryPumping(Object duration) {
    return '$duration pumping';
  }

  @override
  String summaryRight(Object duration) {
    return '$duration right';
  }

  @override
  String get summaryRoutine => 'Routine';

  @override
  String summaryTemperature(Object values) {
    return 'temperature $values';
  }

  @override
  String get summaryTitle => 'Summary';

  @override
  String summaryTotal(Object amount) {
    return '$amount total';
  }

  @override
  String summaryWetDirty(Object dirty, Object wet) {
    return '$wet wet · $dirty dirty';
  }

  @override
  String syncCantReach(Object server) {
    return 'Can\'t reach the server ($server).';
  }

  @override
  String syncCantReachCheck(Object server) {
    return 'Can\'t reach the server ($server). Check the address and your connection.';
  }

  @override
  String syncCantReachNamedPhone(Object name) {
    return 'Couldn\'t reach $name\'s phone. Both phones need to be on the same Wi-Fi, with the pairing code still showing.';
  }

  @override
  String get syncCantReachOtherPhone =>
      'Couldn\'t reach the other phone. Both phones need to be on the same Wi-Fi, with the pairing code still showing.';

  @override
  String syncChangeNotSaved(Object message) {
    return 'A change couldn\'t be saved: $message';
  }

  @override
  String get syncConflict =>
      'Something you changed was also changed on another device; the newer change was kept.';

  @override
  String get syncDriveFolderUnreachable =>
      'The family\'s Drive folder can\'t be reached. Turn Drive sync off and on again.';

  @override
  String get syncDriveNeedsAndroid => 'Google Drive needs the Android app.';

  @override
  String get syncDriveNotGranted => 'Google Drive access wasn\'t granted.';

  @override
  String get syncEntryDeleted => 'This entry was deleted on another phone.';

  @override
  String get syncGoogleNotSignedIn => 'Not signed in to Google.';

  @override
  String syncLoggedNotSaved(Object message) {
    return 'Something you logged couldn\'t be saved: $message';
  }

  @override
  String get syncNotPairingCode => 'This isn\'t a Nestling pairing code.';

  @override
  String syncOffline(Object host) {
    return 'You\'re offline. This needs a connection to the server ($host).';
  }

  @override
  String syncOfflineNotSent(Object message) {
    return 'Changes made offline couldn\'t be sent yet: $message';
  }

  @override
  String syncOtherPhoneAnswered(Object status) {
    return 'the other phone answered $status';
  }

  @override
  String get syncPairingIncomplete =>
      'This pairing code is incomplete. Copy it again.';

  @override
  String get syncPhonesNeedAndroid =>
      'Syncing phones directly needs the Android app.';

  @override
  String syncServerError(Object status) {
    return 'Server error ($status)';
  }

  @override
  String get syncTimerRunning =>
      'Someone already started this timer. It\'s shown now.';

  @override
  String get syncTimerStopped =>
      'This timer was already stopped on another phone. The screen is up to date now.';

  @override
  String get syncWifiFirst => 'Connect this phone to Wi-Fi first.';

  @override
  String get system => 'System';

  @override
  String teethAgeOld(Object age) {
    return '$age old';
  }

  @override
  String get teethCameIn => 'Came in';

  @override
  String get teethCameInOn => 'Came in on';

  @override
  String get teethCanine => 'canine';

  @override
  String get teethCentralIncisor => 'central incisor';

  @override
  String teethChartSemantics(Object count) {
    return 'Teeth chart: $count of 20 teeth in. Tap a tooth to log it.';
  }

  @override
  String teethChartSemanticsReadOnly(Object count) {
    return 'Teeth chart: $count of 20 teeth in.';
  }

  @override
  String teethCount(Object count) {
    return '$count of 20';
  }

  @override
  String get teethFirstHint =>
      'The first one goes in the book as \"First tooth\": add a photo and the story there.';

  @override
  String get teethFirstMolar => 'first molar';

  @override
  String get teethItCameIn => 'It came in';

  @override
  String get teethLateralIncisor => 'lateral incisor';

  @override
  String get teethLegendIn => 'In';

  @override
  String get teethLegendNotYet => 'Not yet';

  @override
  String get teethLower => 'LOWER';

  @override
  String get teethLowerLeft => 'Lower left';

  @override
  String get teethLowerRight => 'Lower right';

  @override
  String teethName(Object kind, Object position) {
    return '$position $kind';
  }

  @override
  String get teethNotInYet => 'Not in yet';

  @override
  String get teethSaveDate => 'Save date';

  @override
  String get teethSecondMolar => 'second molar';

  @override
  String get teethTapChange => 'Tap a tooth to log it or change its date.';

  @override
  String get teethTapFirst => 'Tap a tooth when it comes in.';

  @override
  String get teethUpper => 'UPPER';

  @override
  String get teethUpperLeft => 'Upper left';

  @override
  String get teethUpperRight => 'Upper right';

  @override
  String teethUsually(Object when) {
    return 'Usually comes in at $when';
  }

  @override
  String teethWhen(Object range) {
    return '$range months';
  }

  @override
  String get timelineAll => 'All';

  @override
  String get timelineDiapers => 'Diapers';

  @override
  String get timelineEmpty => 'Nothing here yet.';

  @override
  String get timelineFeeds => 'Feeds';

  @override
  String timelineNote(Object note) {
    return '“$note”';
  }

  @override
  String get timelineOther => 'Other';

  @override
  String get timelineSummary => 'Summary';

  @override
  String timelineTitle(Object name) {
    return '$name’s timeline';
  }

  @override
  String timerAwakeFor(Object duration) {
    return 'Awake for $duration';
  }

  @override
  String get timerDeleteBody => 'Nothing will be saved.';

  @override
  String get timerDeleteTitle => 'Delete this timer?';

  @override
  String timerEditSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Edit left time',
      'other': 'Edit right time',
    });
    return '$_temp0';
  }

  @override
  String get timerEditTotal => 'Edit total time';

  @override
  String timerEndAfterStart(Object time) {
    return 'The end must be after the start ($time).';
  }

  @override
  String get timerEndTime => 'End Time';

  @override
  String get timerFellAsleep => 'Fell asleep';

  @override
  String get timerKeepsRunning => 'Close with ✕ and the timer keeps running.';

  @override
  String timerLastFeedEnded(Object ago, String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Last feed ended on the left',
      'other': 'Last feed ended on the right',
    });
    String _temp1 = intl.Intl.selectLogic(side, {
      'left': 'Start on the right',
      'other': 'Start on the left',
    });
    return '$_temp0 · $ago\n$_temp1';
  }

  @override
  String get timerLastSideBadge => 'Last\nside';

  @override
  String get timerLeftSide => 'Left side';

  @override
  String get timerLogPast => 'Log past';

  @override
  String get timerMinutes => 'Minutes';

  @override
  String get timerNoteHint => 'Note (optional)';

  @override
  String timerOnSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'On the left',
      'other': 'On the right',
    });
    return '$_temp0';
  }

  @override
  String get timerPause => 'Pause';

  @override
  String timerPauseSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Pause left',
      'other': 'Pause right',
    });
    return '$_temp0';
  }

  @override
  String get timerPaused => 'Paused';

  @override
  String get timerPumpHowMuch => 'How much did you pump?';

  @override
  String get timerPumping => 'Pumping';

  @override
  String get timerResume => 'Resume';

  @override
  String timerResumeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Resume left',
      'other': 'Resume right',
    });
    return '$_temp0';
  }

  @override
  String get timerRightSide => 'Right side';

  @override
  String timerSaved(Object what) {
    return '$what saved';
  }

  @override
  String get timerSeconds => 'Seconds';

  @override
  String get timerSleeping => 'Sleeping';

  @override
  String get timerStart => 'Start';

  @override
  String get timerStartInFuture => 'The start can\'t be in the future.';

  @override
  String timerStartSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Start left',
      'other': 'Start right',
    });
    return '$_temp0';
  }

  @override
  String timerStartSideLast(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Start left (last side)',
      'other': 'Start right (last side)',
    });
    return '$_temp0';
  }

  @override
  String get timerStartTime => 'Start Time';

  @override
  String timerSwitchSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Switch to left',
      'other': 'Switch to right',
    });
    return '$_temp0';
  }

  @override
  String get timerTapSide => 'Tap a side to start';

  @override
  String get timerTapStart => 'Tap to start';

  @override
  String get timerTimeAsleep => 'Time asleep';

  @override
  String get timerTotalTime => 'Total Time';

  @override
  String get timerTotalTimeTitle => 'Total time';

  @override
  String get timerWokeUp => 'Woke up';

  @override
  String get today => 'Today';

  @override
  String get trendsAccidents => 'Accidents';

  @override
  String get trendsAmountPumped => 'Amount pumped';

  @override
  String get trendsAverage => 'average';

  @override
  String get trendsBottleSize => 'Bottle size';

  @override
  String trendsBottleUnit(Object unit) {
    return 'Bottle ($unit)';
  }

  @override
  String get trendsBreastfeedLength => 'Breastfeed length';

  @override
  String get trendsBreastfeeding => 'Breastfeeding';

  @override
  String trendsCompareArrows(Object count) {
    return 'Arrows compare with the $count days before.';
  }

  @override
  String trendsCompareNone(Object count) {
    return 'Nothing logged in the $count days before to compare with.';
  }

  @override
  String get trendsDay => 'Day';

  @override
  String get trendsDayBreastfeeding => 'Daytime breastfeeding';

  @override
  String get trendsDayDiapers => 'Daytime diapers';

  @override
  String get trendsDaySleep => 'Daytime sleep';

  @override
  String trendsDays(Object count) {
    return '$count days';
  }

  @override
  String get trendsDiapers => 'Diapers';

  @override
  String get trendsFeed => 'Feed';

  @override
  String get trendsFeedInterval => 'Time between feeds';

  @override
  String get trendsFeeds => 'Feeds';

  @override
  String get trendsGrowthChartsSub =>
      'Weight, length and head size on the WHO percentile curves';

  @override
  String trendsIntro(num days, Object end, Object start) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Daily averages over $days full days; daytime is $start–$end.',
      one: 'Daily averages over 1 full day; daytime is $start–$end.',
    );
    return '$_temp0';
  }

  @override
  String get trendsLongestSleep => 'Longest sleep';

  @override
  String get trendsNapLength => 'Nap length';

  @override
  String get trendsNaps => 'Naps';

  @override
  String get trendsNight => 'Night';

  @override
  String get trendsNightBreastfeeding => 'Nighttime breastfeeding';

  @override
  String get trendsNightDiapers => 'Nighttime diapers';

  @override
  String get trendsNightSleep => 'Nighttime sleep';

  @override
  String get trendsPerDay => 'per day';

  @override
  String get trendsPottyTrips => 'Potty trips';

  @override
  String get trendsPumpSessions => 'Pump sessions';

  @override
  String get trendsPumpTime => 'Pump time';

  @override
  String get trendsTitle => 'Trends';

  @override
  String get trendsWakeWindow => 'Wake window';

  @override
  String get trendsWetOnly => 'Wet only';

  @override
  String get tryAgain => 'Try again';

  @override
  String get usersAdd => 'Add user';

  @override
  String get usersAddTitle => 'Add a user';

  @override
  String usersAddTo(Object family) {
    return 'Add to $family';
  }

  @override
  String get usersAdmin => 'Admin';

  @override
  String get usersAdminHint => 'Can manage users';

  @override
  String get usersAdminTag => 'admin';

  @override
  String get usersAsCaregiver => 'As a caregiver';

  @override
  String get usersCanChangeLater => 'They can change it later';

  @override
  String usersCanSignIn(Object name) {
    return '$name can now sign in';
  }

  @override
  String get usersEmail => 'Email';

  @override
  String get usersEnterEmail => 'Enter an email';

  @override
  String get usersEnterName => 'Enter a name';

  @override
  String get usersIntro =>
      'Only admins can create accounts on this server. Give people their email and password; they can change the password under Settings → Account.';

  @override
  String get usersMakeAdmin => 'Make admin';

  @override
  String usersManage(Object name) {
    return 'Manage $name';
  }

  @override
  String usersNewPasswordFor(Object name) {
    return 'New password for $name';
  }

  @override
  String usersNoLongerAdmin(Object name) {
    return '$name is no longer an admin';
  }

  @override
  String usersNowAdmin(Object name) {
    return '$name is now an admin';
  }

  @override
  String get usersPassword => 'Password';

  @override
  String get usersPasswordHelp =>
      'At least 8 characters. They\'ll be signed out.';

  @override
  String usersPasswordSet(Object name) {
    return 'New password set for $name';
  }

  @override
  String get usersRemoveAccount => 'Remove account';

  @override
  String get usersRemoveAdmin => 'Remove admin';

  @override
  String get usersRemoveBody =>
      'They can no longer sign in. Their families and everything logged stay.';

  @override
  String usersRemoveTitle(Object name) {
    return 'Remove $name?';
  }

  @override
  String usersRemoved(Object name) {
    return '$name removed';
  }

  @override
  String get usersSetPassword => 'Set a new password';

  @override
  String get usersTitle => 'Users';

  @override
  String get wet => 'Wet';

  @override
  String get wetAndDirty => 'Wet + dirty';

  @override
  String get yesterday => 'Yesterday';
}
