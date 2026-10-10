import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @activityBath.
  ///
  /// In en, this message translates to:
  /// **'Bath'**
  String get activityBath;

  /// No description provided for @activityMassage.
  ///
  /// In en, this message translates to:
  /// **'Massage'**
  String get activityMassage;

  /// No description provided for @activityMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get activityMusic;

  /// No description provided for @activityNailTrim.
  ///
  /// In en, this message translates to:
  /// **'Nail trim'**
  String get activityNailTrim;

  /// No description provided for @activityOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get activityOutdoor;

  /// No description provided for @activityPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get activityPlay;

  /// No description provided for @activityRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get activityRead;

  /// No description provided for @activitySkinToSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin to skin'**
  String get activitySkinToSkin;

  /// No description provided for @activitySwim.
  ///
  /// In en, this message translates to:
  /// **'Swim'**
  String get activitySwim;

  /// No description provided for @activityTummyTime.
  ///
  /// In en, this message translates to:
  /// **'Tummy time'**
  String get activityTummyTime;

  /// No description provided for @activityVitamin.
  ///
  /// In en, this message translates to:
  /// **'Vitamin'**
  String get activityVitamin;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @ageDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String ageDays(num count);

  /// No description provided for @ageDueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {count, plural, =1{1 day} other{{count} days}}'**
  String ageDueIn(num count);

  /// No description provided for @ageMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String ageMonths(num count);

  /// Two age parts, e.g. '3 months 2 weeks'.
  ///
  /// In en, this message translates to:
  /// **'{big} {small}'**
  String agePair(Object big, Object small);

  /// No description provided for @ageWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String ageWeeks(num count);

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String ageYears(num count);

  /// No description provided for @agoDuration.
  ///
  /// In en, this message translates to:
  /// **'{duration} ago'**
  String agoDuration(Object duration);

  /// No description provided for @blowout.
  ///
  /// In en, this message translates to:
  /// **'blowout'**
  String get blowout;

  /// No description provided for @bookAddMemory.
  ///
  /// In en, this message translates to:
  /// **'Add a memory'**
  String get bookAddMemory;

  /// No description provided for @bookAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get bookAddPhoto;

  /// After the date of a memory: the baby's age then, e.g. "6 weeks old"
  ///
  /// In en, this message translates to:
  /// **'{age} old'**
  String bookAgeOld(Object age);

  /// Teeth chart is drawn as seen when facing the baby
  ///
  /// In en, this message translates to:
  /// **'as you look at {name}'**
  String bookAsYouLookAt(Object name);

  /// No description provided for @bookBananaIntro.
  ///
  /// In en, this message translates to:
  /// **'The same banana next to {name} every month: the best way to see how fast it goes.'**
  String bookBananaIntro(Object name);

  /// Monthly photo of the baby next to the same banana, to see growth
  ///
  /// In en, this message translates to:
  /// **'Banana for scale'**
  String get bookBananaName;

  /// No description provided for @bookBeforeBirth.
  ///
  /// In en, this message translates to:
  /// **'Before birth'**
  String get bookBeforeBirth;

  /// No description provided for @bookBorn.
  ///
  /// In en, this message translates to:
  /// **'Born {date}'**
  String bookBorn(Object date);

  /// No description provided for @bookChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get bookChangePhoto;

  /// No description provided for @bookChapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get bookChapter;

  /// No description provided for @bookChapterCelebrations.
  ///
  /// In en, this message translates to:
  /// **'Celebrations'**
  String get bookChapterCelebrations;

  /// No description provided for @bookChapterFirsts.
  ///
  /// In en, this message translates to:
  /// **'Firsts'**
  String get bookChapterFirsts;

  /// No description provided for @bookChapterGrowing.
  ///
  /// In en, this message translates to:
  /// **'Growing up'**
  String get bookChapterGrowing;

  /// No description provided for @bookChapterHello.
  ///
  /// In en, this message translates to:
  /// **'Hello, world'**
  String get bookChapterHello;

  /// No description provided for @bookChapterNumber.
  ///
  /// In en, this message translates to:
  /// **'CHAPTER {number}'**
  String bookChapterNumber(Object number);

  /// No description provided for @bookChapterSubCelebrations.
  ///
  /// In en, this message translates to:
  /// **'Holidays and special days'**
  String get bookChapterSubCelebrations;

  /// No description provided for @bookChapterSubFirsts.
  ///
  /// In en, this message translates to:
  /// **'Every new thing, month by month'**
  String get bookChapterSubFirsts;

  /// No description provided for @bookChapterSubGrowing.
  ///
  /// In en, this message translates to:
  /// **'Teeth, size, and how fast it goes'**
  String get bookChapterSubGrowing;

  /// No description provided for @bookChapterSubHello.
  ///
  /// In en, this message translates to:
  /// **'The very beginning'**
  String get bookChapterSubHello;

  /// No description provided for @bookChapterSubWaiting.
  ///
  /// In en, this message translates to:
  /// **'Before you arrived'**
  String get bookChapterSubWaiting;

  /// No description provided for @bookChapterWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get bookChapterWaiting;

  /// No description provided for @bookDaysBeforeBirth.
  ///
  /// In en, this message translates to:
  /// **'days before birth'**
  String get bookDaysBeforeBirth;

  /// No description provided for @bookDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed for everyone in the family, with its photo.'**
  String get bookDeleteBody;

  /// No description provided for @bookDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this memory?'**
  String get bookDeleteTitle;

  /// No description provided for @bookDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get bookDueDate;

  /// No description provided for @bookDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String bookDueOn(Object date);

  /// No description provided for @bookEditMemory.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get bookEditMemory;

  /// No description provided for @bookEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Pick an idea below or add your own: a photo, the day and a few words about it.'**
  String get bookEmptyBody;

  /// No description provided for @bookEmptyReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Memories show here as the family adds them.'**
  String get bookEmptyReadOnly;

  /// No description provided for @bookEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The first page is waiting'**
  String get bookEmptyTitle;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Baby shower'**
  String get bookIdeaBabyShower;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Baptism or naming day'**
  String get bookIdeaBaptism;

  /// No description provided for @bookIdeaBassinet.
  ///
  /// In en, this message translates to:
  /// **'Outgrew the bassinet'**
  String get bookIdeaBassinet;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'The belly'**
  String get bookIdeaBelly;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First birthday'**
  String get bookIdeaBirthday;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Boy or girl?'**
  String get bookIdeaBoyOrGirl;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Came home'**
  String get bookIdeaCameHome;

  /// No description provided for @bookIdeaCarSeat.
  ///
  /// In en, this message translates to:
  /// **'Forward-facing car seat'**
  String get bookIdeaCarSeat;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First Christmas'**
  String get bookIdeaChristmas;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Clapped hands'**
  String get bookIdeaClapped;

  /// No description provided for @bookIdeaClothesSize.
  ///
  /// In en, this message translates to:
  /// **'Up a clothes size'**
  String get bookIdeaClothesSize;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Cooed'**
  String get bookIdeaCooed;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Crawled'**
  String get bookIdeaCrawled;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First drink from a cup'**
  String get bookIdeaCup;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Said \"dada\"'**
  String get bookIdeaDada;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First day at daycare'**
  String get bookIdeaDaycare;

  /// No description provided for @bookIdeaDiaperSize.
  ///
  /// In en, this message translates to:
  /// **'Up a diaper size'**
  String get bookIdeaDiaperSize;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First Easter'**
  String get bookIdeaEaster;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First Father\'s Day'**
  String get bookIdeaFathersDay;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First bath'**
  String get bookIdeaFirstBath;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First bottle'**
  String get bookIdeaFirstBottle;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First dance'**
  String get bookIdeaFirstDance;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First laugh'**
  String get bookIdeaFirstLaugh;

  /// No description provided for @bookIdeaFirstShoes.
  ///
  /// In en, this message translates to:
  /// **'First shoes'**
  String get bookIdeaFirstShoes;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First smile'**
  String get bookIdeaFirstSmile;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First solid food'**
  String get bookIdeaFirstSolid;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First steps'**
  String get bookIdeaFirstSteps;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First tooth'**
  String get bookIdeaFirstTooth;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First walk outside'**
  String get bookIdeaFirstWalk;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First word'**
  String get bookIdeaFirstWord;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Found hands'**
  String get bookIdeaFoundHands;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'We found out'**
  String get bookIdeaFoundOut;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Found toes'**
  String get bookIdeaFoundToes;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Met the grandparents'**
  String get bookIdeaGrandparents;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First haircut'**
  String get bookIdeaHaircut;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First Halloween'**
  String get bookIdeaHalloween;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Heard the heartbeat'**
  String get bookIdeaHeartbeat;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Held head up'**
  String get bookIdeaHeldHead;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Gave a kiss'**
  String get bookIdeaKiss;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Said \"mama\"'**
  String get bookIdeaMama;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First Mother\'s Day'**
  String get bookIdeaMothersDay;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Held own bottle'**
  String get bookIdeaOwnBottle;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Knew own name'**
  String get bookIdeaOwnName;

  /// No description provided for @bookIdeaOwnRoom.
  ///
  /// In en, this message translates to:
  /// **'Own room'**
  String get bookIdeaOwnRoom;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Pulled to stand'**
  String get bookIdeaPulledStand;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Reached for a toy'**
  String get bookIdeaReachedToy;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Rolled over'**
  String get bookIdeaRolledOver;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Sat up alone'**
  String get bookIdeaSatUp;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Slept through the night'**
  String get bookIdeaSleptNight;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First snow'**
  String get bookIdeaSnow;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Turned toward sounds'**
  String get bookIdeaSounds;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Fed self with a spoon'**
  String get bookIdeaSpoon;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Stood alone'**
  String get bookIdeaStoodAlone;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First swim'**
  String get bookIdeaSwim;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First trip'**
  String get bookIdeaTrip;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'First ultrasound'**
  String get bookIdeaUltrasound;

  /// A memory idea in the baby book; saved as the memory name
  ///
  /// In en, this message translates to:
  /// **'Waved bye-bye'**
  String get bookIdeaWaved;

  /// No description provided for @bookIdeasForChapter.
  ///
  /// In en, this message translates to:
  /// **'Ideas for this chapter'**
  String get bookIdeasForChapter;

  /// No description provided for @bookIdeasProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} in the book. Tap one to add it.'**
  String bookIdeasProgress(Object done, Object total);

  /// No description provided for @bookIdeasToRemember.
  ///
  /// In en, this message translates to:
  /// **'Ideas to remember'**
  String get bookIdeasToRemember;

  /// No description provided for @bookMemoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 memory} other{{count} memories}}'**
  String bookMemoryCount(num count);

  /// No description provided for @bookNameHint.
  ///
  /// In en, this message translates to:
  /// **'First smile, rolled over…'**
  String get bookNameHint;

  /// No description provided for @bookNameNeeded.
  ///
  /// In en, this message translates to:
  /// **'What happened? Give the memory a name.'**
  String get bookNameNeeded;

  /// No description provided for @bookNewMemory.
  ///
  /// In en, this message translates to:
  /// **'New memory'**
  String get bookNewMemory;

  /// No description provided for @bookNewborn.
  ///
  /// In en, this message translates to:
  /// **'Newborn'**
  String get bookNewborn;

  /// No description provided for @bookNoBabyYet.
  ///
  /// In en, this message translates to:
  /// **'The baby book shows here once {family} adds a baby.'**
  String bookNoBabyYet(Object family);

  /// No description provided for @bookNoMemories.
  ///
  /// In en, this message translates to:
  /// **'No memories yet'**
  String get bookNoMemories;

  /// No description provided for @bookPhotoAMonth.
  ///
  /// In en, this message translates to:
  /// **'a photo a month'**
  String get bookPhotoAMonth;

  /// No description provided for @bookPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String bookPhotoCount(num count);

  /// No description provided for @bookPhotoNotSaved.
  ///
  /// In en, this message translates to:
  /// **'The memory is saved, but not its photo: {error}'**
  String bookPhotoNotSaved(Object error);

  /// No description provided for @bookPhotoOf.
  ///
  /// In en, this message translates to:
  /// **'Photo: {name}'**
  String bookPhotoOf(Object name);

  /// No description provided for @bookPreparingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Preparing the photo…'**
  String get bookPreparingPhoto;

  /// No description provided for @bookSaveToBook.
  ///
  /// In en, this message translates to:
  /// **'Save to the book'**
  String get bookSaveToBook;

  /// No description provided for @bookSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get bookSaving;

  /// No description provided for @bookSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get bookSeeAll;

  /// No description provided for @bookSetDueDate.
  ///
  /// In en, this message translates to:
  /// **'Set the due date'**
  String get bookSetDueDate;

  /// No description provided for @bookStory.
  ///
  /// In en, this message translates to:
  /// **'The story'**
  String get bookStory;

  /// No description provided for @bookStoryHint.
  ///
  /// In en, this message translates to:
  /// **'Where you were, who was there, how it felt…'**
  String get bookStoryHint;

  /// No description provided for @bookTabCelebrations.
  ///
  /// In en, this message translates to:
  /// **'Celebrations'**
  String get bookTabCelebrations;

  /// No description provided for @bookTabFirsts.
  ///
  /// In en, this message translates to:
  /// **'Firsts'**
  String get bookTabFirsts;

  /// No description provided for @bookTabGrowing.
  ///
  /// In en, this message translates to:
  /// **'Growing'**
  String get bookTabGrowing;

  /// No description provided for @bookTabHello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get bookTabHello;

  /// No description provided for @bookTabWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get bookTabWaiting;

  /// No description provided for @bookTakeFirst.
  ///
  /// In en, this message translates to:
  /// **'Take the first one'**
  String get bookTakeFirst;

  /// No description provided for @bookTeeth.
  ///
  /// In en, this message translates to:
  /// **'Teeth'**
  String get bookTeeth;

  /// No description provided for @bookTheBookOf.
  ///
  /// In en, this message translates to:
  /// **'The book of'**
  String get bookTheBookOf;

  /// No description provided for @bookTheFamily.
  ///
  /// In en, this message translates to:
  /// **'the family'**
  String get bookTheFamily;

  /// No description provided for @bookThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month’s'**
  String get bookThisMonth;

  /// No description provided for @bookTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}’s book'**
  String bookTitle(Object name);

  /// No description provided for @bookWeeksAlong.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week along} other{{count} weeks along}}'**
  String bookWeeksAlong(num count);

  /// No description provided for @bookWeeksBeforeBirth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week before birth} other{{count} weeks before birth}}'**
  String bookWeeksBeforeBirth(num count);

  /// No description provided for @bookWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get bookWhatHappened;

  /// No description provided for @bookWhenAfterYears.
  ///
  /// In en, this message translates to:
  /// **'after {count} years'**
  String bookWhenAfterYears(Object count);

  /// No description provided for @bookWhenAnyTime.
  ///
  /// In en, this message translates to:
  /// **'any time'**
  String get bookWhenAnyTime;

  /// No description provided for @bookWhenAnythingSpecial.
  ///
  /// In en, this message translates to:
  /// **'anything special'**
  String get bookWhenAnythingSpecial;

  /// No description provided for @bookWhenAroundMonths.
  ///
  /// In en, this message translates to:
  /// **'around {count} months'**
  String bookWhenAroundMonths(Object count);

  /// No description provided for @bookWhenAroundWeeks.
  ///
  /// In en, this message translates to:
  /// **'around {count} weeks'**
  String bookWhenAroundWeeks(Object count);

  /// No description provided for @bookWhenAroundWeeksRange.
  ///
  /// In en, this message translates to:
  /// **'around {from}–{to} weeks'**
  String bookWhenAroundWeeksRange(Object from, Object to);

  /// No description provided for @bookWhenFirstDays.
  ///
  /// In en, this message translates to:
  /// **'first days'**
  String get bookWhenFirstDays;

  /// No description provided for @bookWhenFirstWeeks.
  ///
  /// In en, this message translates to:
  /// **'first weeks'**
  String get bookWhenFirstWeeks;

  /// No description provided for @bookWhenLastWeeks.
  ///
  /// In en, this message translates to:
  /// **'last weeks'**
  String get bookWhenLastWeeks;

  /// No description provided for @bookWhenMonthsRange.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to} months'**
  String bookWhenMonthsRange(Object from, Object to);

  /// No description provided for @bookWhenNowAndThen.
  ///
  /// In en, this message translates to:
  /// **'one now and then'**
  String get bookWhenNowAndThen;

  /// No description provided for @bookWhenSpring.
  ///
  /// In en, this message translates to:
  /// **'spring'**
  String get bookWhenSpring;

  /// No description provided for @bookWhenTest.
  ///
  /// In en, this message translates to:
  /// **'the test'**
  String get bookWhenTest;

  /// No description provided for @bookWhenWeeksRange.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to} weeks'**
  String bookWhenWeeksRange(Object from, Object to);

  /// No description provided for @bookWhenWithFirstSteps.
  ///
  /// In en, this message translates to:
  /// **'first steps'**
  String get bookWhenWithFirstSteps;

  /// No description provided for @bookWhichTooth.
  ///
  /// In en, this message translates to:
  /// **'Which tooth?'**
  String get bookWhichTooth;

  /// No description provided for @bookYourOwn.
  ///
  /// In en, this message translates to:
  /// **'Your own'**
  String get bookYourOwn;

  /// No description provided for @both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get both;

  /// No description provided for @breastfeedPlusBottle.
  ///
  /// In en, this message translates to:
  /// **'Breastfeed + bottle'**
  String get breastfeedPlusBottle;

  /// No description provided for @calendarDiapers.
  ///
  /// In en, this message translates to:
  /// **'Diapers'**
  String get calendarDiapers;

  /// No description provided for @calendarFeeds.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get calendarFeeds;

  /// No description provided for @calendarNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get calendarNextWeek;

  /// No description provided for @calendarOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get calendarOther;

  /// No description provided for @calendarPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get calendarPrevWeek;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @childAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get childAddPhoto;

  /// No description provided for @childBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date (or due date)'**
  String get childBirthDate;

  /// No description provided for @childBirthDateMissing.
  ///
  /// In en, this message translates to:
  /// **'Choose a birth date (or due date)'**
  String get childBirthDateMissing;

  /// No description provided for @childBirthDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Birth date (or due date) *'**
  String get childBirthDateRequired;

  /// No description provided for @childBoy.
  ///
  /// In en, this message translates to:
  /// **'Boy'**
  String get childBoy;

  /// No description provided for @childChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get childChangePhoto;

  /// No description provided for @childChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get childChoosePhoto;

  /// No description provided for @childDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete baby'**
  String get childDelete;

  /// No description provided for @childDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {name} and everything logged for them, for every caregiver. It can\'t be undone.'**
  String childDeleteBody(Object name);

  /// No description provided for @childDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String childDeleteTitle(Object name);

  /// No description provided for @childEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String childEditTitle(Object name);

  /// No description provided for @childEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get childEnterName;

  /// No description provided for @childGirl.
  ///
  /// In en, this message translates to:
  /// **'Girl'**
  String get childGirl;

  /// No description provided for @childName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get childName;

  /// No description provided for @childSexUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get childSexUnknown;

  /// No description provided for @childTapToChoose.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose'**
  String get childTapToChoose;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// Screen reader label of the date pill
  ///
  /// In en, this message translates to:
  /// **'Change day, {day}'**
  String commonChangeDay(Object day);

  /// Screen reader label of the time pill
  ///
  /// In en, this message translates to:
  /// **'Change time, {time}'**
  String commonChangeTime(Object time);

  /// No description provided for @commonSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String commonSomethingWrong(Object error);

  /// No description provided for @commonTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {text} to confirm.'**
  String commonTypeToConfirm(Object text);

  /// No description provided for @consistencyMucousy.
  ///
  /// In en, this message translates to:
  /// **'Mucousy'**
  String get consistencyMucousy;

  /// No description provided for @consistencyMushy.
  ///
  /// In en, this message translates to:
  /// **'Mushy'**
  String get consistencyMushy;

  /// No description provided for @consistencyPebbles.
  ///
  /// In en, this message translates to:
  /// **'Pebbles'**
  String get consistencyPebbles;

  /// No description provided for @consistencyRunny.
  ///
  /// In en, this message translates to:
  /// **'Runny'**
  String get consistencyRunny;

  /// No description provided for @consistencySolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get consistencySolid;

  /// No description provided for @dayHoursDayStarts.
  ///
  /// In en, this message translates to:
  /// **'Day starts'**
  String get dayHoursDayStarts;

  /// No description provided for @dayHoursDaytime.
  ///
  /// In en, this message translates to:
  /// **'Daytime'**
  String get dayHoursDaytime;

  /// No description provided for @dayHoursIntro.
  ///
  /// In en, this message translates to:
  /// **'These times decide whether a feed, diaper or sleep counts as daytime or nighttime in Trends. Sleep that starts during the day is a nap. They apply to everyone in the family.'**
  String get dayHoursIntro;

  /// No description provided for @dayHoursNightStarts.
  ///
  /// In en, this message translates to:
  /// **'Night starts'**
  String get dayHoursNightStarts;

  /// No description provided for @dayHoursStartBeforeEnd.
  ///
  /// In en, this message translates to:
  /// **'Daytime must start before it ends.'**
  String get dayHoursStartBeforeEnd;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(Object count);

  /// No description provided for @defaultBabyName.
  ///
  /// In en, this message translates to:
  /// **'Baby'**
  String get defaultBabyName;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @dirty.
  ///
  /// In en, this message translates to:
  /// **'Dirty'**
  String get dirty;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @dry.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get dry;

  /// No description provided for @durDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String durDaysHours(Object days, Object hours);

  /// minutes is already zero-padded, e.g. 05.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durHoursMinutes(Object hours, Object minutes);

  /// No description provided for @durMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durMinutes(Object minutes);

  /// No description provided for @durMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String durMinutesSeconds(Object minutes, Object seconds);

  /// No description provided for @durSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durSeconds(Object seconds);

  /// No description provided for @durUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'<1m'**
  String get durUnderMinute;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @endedSide.
  ///
  /// In en, this message translates to:
  /// **'ended {side}'**
  String endedSide(Object side);

  /// No description provided for @familyAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get familyAccount;

  /// No description provided for @familyAddBaby.
  ///
  /// In en, this message translates to:
  /// **'Add a baby'**
  String get familyAddBaby;

  /// No description provided for @familyAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Available in the Android app'**
  String get familyAndroidOnly;

  /// No description provided for @familyApiToken.
  ///
  /// In en, this message translates to:
  /// **'API token'**
  String get familyApiToken;

  /// No description provided for @familyApiTokenHint.
  ///
  /// In en, this message translates to:
  /// **'For Home Assistant or scripts'**
  String get familyApiTokenHint;

  /// No description provided for @familyAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get familyAppearance;

  /// No description provided for @familyAtLeast8.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get familyAtLeast8;

  /// No description provided for @familyBabies.
  ///
  /// In en, this message translates to:
  /// **'Babies'**
  String get familyBabies;

  /// No description provided for @familyBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Backed up to Google Drive'**
  String get familyBackedUp;

  /// No description provided for @familyBackupDrive.
  ///
  /// In en, this message translates to:
  /// **'Back up to Google Drive'**
  String get familyBackupDrive;

  /// No description provided for @familyBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps a copy in your Google account, once a day'**
  String get familyBackupHint;

  /// No description provided for @familyBookOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'You can see the baby book. Ask an owner of the family for more.'**
  String get familyBookOnlyHint;

  /// No description provided for @familyBorn.
  ///
  /// In en, this message translates to:
  /// **'born {date}'**
  String familyBorn(Object date);

  /// No description provided for @familyCaregiverCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 caregiver} other{{count} caregivers}}'**
  String familyCaregiverCount(num count);

  /// No description provided for @familyCaregivers.
  ///
  /// In en, this message translates to:
  /// **'Caregivers'**
  String get familyCaregivers;

  /// No description provided for @familyChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get familyChangePassword;

  /// No description provided for @familyChooseAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get familyChooseAnotherFile;

  /// No description provided for @familyChooseCsv.
  ///
  /// In en, this message translates to:
  /// **'Choose the CSV file'**
  String get familyChooseCsv;

  /// No description provided for @familyCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get familyCodeCopied;

  /// No description provided for @familyContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get familyContinue;

  /// No description provided for @familyCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get familyCopy;

  /// No description provided for @familyCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get familyCurrentPassword;

  /// No description provided for @familyDayNight.
  ///
  /// In en, this message translates to:
  /// **'Day and night'**
  String get familyDayNight;

  /// No description provided for @familyDaytime.
  ///
  /// In en, this message translates to:
  /// **'Daytime {start}–{end}'**
  String familyDaytime(Object end, Object start);

  /// No description provided for @familyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete family'**
  String get familyDelete;

  /// No description provided for @familyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the family, its babies and everything logged, for every caregiver. It can\'t be undone.'**
  String get familyDeleteBody;

  /// No description provided for @familyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String familyDeleteTitle(Object name);

  /// No description provided for @familyDriveOn.
  ///
  /// In en, this message translates to:
  /// **'On · {account}'**
  String familyDriveOn(Object account);

  /// No description provided for @familyDriveSync.
  ///
  /// In en, this message translates to:
  /// **'Sync through Google Drive'**
  String get familyDriveSync;

  /// No description provided for @familyDriveSyncBody.
  ///
  /// In en, this message translates to:
  /// **'Your phones will leave each other their changes in a shared folder in Google Drive, so they catch up even when they aren\'t open at the same time or on the same Wi-Fi.\n\nGoogle will ask to let Nestling use your Drive. Everything in the folder is encrypted: only your family\'s phones can read it. Turn it on on each phone.'**
  String get familyDriveSyncBody;

  /// No description provided for @familyDriveSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync last time. It will try again.'**
  String get familyDriveSyncFailed;

  /// No description provided for @familyDriveSyncHint.
  ///
  /// In en, this message translates to:
  /// **'For phones that aren\'t open at the same time or on the same Wi-Fi'**
  String get familyDriveSyncHint;

  /// No description provided for @familyDriveSyncOn.
  ///
  /// In en, this message translates to:
  /// **'Drive sync is on'**
  String get familyDriveSyncOn;

  /// No description provided for @familyEnterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get familyEnterCurrentPassword;

  /// No description provided for @familyExport.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get familyExport;

  /// No description provided for @familyExportHint.
  ///
  /// In en, this message translates to:
  /// **'Everything for this family as a CSV file'**
  String get familyExportHint;

  /// No description provided for @familyExported.
  ///
  /// In en, this message translates to:
  /// **'Exported {name}'**
  String familyExported(Object name);

  /// No description provided for @familyImperialUnits.
  ///
  /// In en, this message translates to:
  /// **'Imperial units'**
  String get familyImperialUnits;

  /// No description provided for @familyImportAccount.
  ///
  /// In en, this message translates to:
  /// **'Nara account'**
  String get familyImportAccount;

  /// No description provided for @familyImportAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Nara account to copy your history into {name}. Your Nara password is used once and never stored.'**
  String familyImportAccountBody(Object name);

  /// No description provided for @familyImportComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get familyImportComplete;

  /// No description provided for @familyImportCsvBody.
  ///
  /// In en, this message translates to:
  /// **'Export your data from the Nara app (it gives you a .csv file), then pick that file here. Everything goes into {name}; importing the same file again updates instead of duplicating.'**
  String familyImportCsvBody(Object name);

  /// No description provided for @familyImportExportFile.
  ///
  /// In en, this message translates to:
  /// **'Export file'**
  String get familyImportExportFile;

  /// No description provided for @familyImportNara.
  ///
  /// In en, this message translates to:
  /// **'Import from Nara'**
  String get familyImportNara;

  /// No description provided for @familyImportNaraHint.
  ///
  /// In en, this message translates to:
  /// **'Bring over your Nara Baby history'**
  String get familyImportNaraHint;

  /// No description provided for @familyImportRecords.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 record into {name}} other{Import {count} records into {name}}}'**
  String familyImportRecords(num count, Object name);

  /// No description provided for @familyImportedUpdated.
  ///
  /// In en, this message translates to:
  /// **'{imported} new · {updated} updated'**
  String familyImportedUpdated(Object imported, Object updated);

  /// No description provided for @familyInviteBody.
  ///
  /// In en, this message translates to:
  /// **'They create an account on this server, then enter this code under “Join a family”. It works once and expires in 7 days.'**
  String get familyInviteBody;

  /// No description provided for @familyInviteBookOnly.
  ///
  /// In en, this message translates to:
  /// **'They will only see the baby book.'**
  String get familyInviteBookOnly;

  /// No description provided for @familyInviteCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Invite a caregiver'**
  String get familyInviteCaregiver;

  /// No description provided for @familyInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get familyInviteCode;

  /// No description provided for @familyInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Partner, grandparent, nanny…'**
  String get familyInviteHint;

  /// No description provided for @familyJoin.
  ///
  /// In en, this message translates to:
  /// **'Join a family'**
  String get familyJoin;

  /// No description provided for @familyJoinAnother.
  ///
  /// In en, this message translates to:
  /// **'Join another family'**
  String get familyJoinAnother;

  /// No description provided for @familyJoinAnotherHint.
  ///
  /// In en, this message translates to:
  /// **'With an invite code from its owner'**
  String get familyJoinAnotherHint;

  /// No description provided for @familyJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get familyJoinButton;

  /// No description provided for @familyLastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup {date} · {account}'**
  String familyLastBackup(Object account, Object date);

  /// No description provided for @familyLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave {family}'**
  String familyLeave(Object family);

  /// No description provided for @familyLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get familyLeaveAction;

  /// No description provided for @familyLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see its baby book any more, unless invited again.'**
  String get familyLeaveBody;

  /// No description provided for @familyLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {family}?'**
  String familyLeaveTitle(Object family);

  /// No description provided for @familyMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines and reminders'**
  String get familyMedicines;

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get familyName;

  /// No description provided for @familyNaraEmail.
  ///
  /// In en, this message translates to:
  /// **'Nara email'**
  String get familyNaraEmail;

  /// No description provided for @familyNaraPassword.
  ///
  /// In en, this message translates to:
  /// **'Nara password'**
  String get familyNaraPassword;

  /// No description provided for @familyNaraProfile.
  ///
  /// In en, this message translates to:
  /// **'Nara profile: {name}'**
  String familyNaraProfile(Object name);

  /// No description provided for @familyNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get familyNewPassword;

  /// No description provided for @familyNewToken.
  ///
  /// In en, this message translates to:
  /// **'New API token'**
  String get familyNewToken;

  /// No description provided for @familyNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get familyNext;

  /// No description provided for @familyOtherDevicesSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Other devices will be signed out'**
  String get familyOtherDevicesSignedOut;

  /// No description provided for @familyPairPhone.
  ///
  /// In en, this message translates to:
  /// **'Pair a phone'**
  String get familyPairPhone;

  /// No description provided for @familyPairPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Your partner\'s phone syncs with this one over Wi-Fi'**
  String get familyPairPhoneHint;

  /// No description provided for @familyPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get familyPasswordChanged;

  /// No description provided for @familyPendingLost.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change made offline hasn\'t reached the server yet and will be lost.} other{{count} changes made offline haven\'t reached the server yet and will be lost.}}'**
  String familyPendingLost(num count);

  /// No description provided for @familyPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview (nothing is saved)'**
  String get familyPreview;

  /// No description provided for @familyPreviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Preview again'**
  String get familyPreviewAgain;

  /// No description provided for @familyReadyToImport.
  ///
  /// In en, this message translates to:
  /// **'Ready to import'**
  String get familyReadyToImport;

  /// No description provided for @familyRecords.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record} other{{count} records}}'**
  String familyRecords(num count);

  /// No description provided for @familyRemoveDataBody.
  ///
  /// In en, this message translates to:
  /// **'Everything logged here is erased from this phone. Paired phones and your Google Drive backup keep their copy.'**
  String get familyRemoveDataBody;

  /// No description provided for @familyRemoveDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Nestling\'s data from this phone?'**
  String get familyRemoveDataTitle;

  /// No description provided for @familyRemoveFromPhone.
  ///
  /// In en, this message translates to:
  /// **'Remove from this phone'**
  String get familyRemoveFromPhone;

  /// No description provided for @familyRemoveMemberBody.
  ///
  /// In en, this message translates to:
  /// **'They will lose access to {family}.'**
  String familyRemoveMemberBody(Object family);

  /// No description provided for @familyRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String familyRemoveMemberTitle(Object name);

  /// No description provided for @familyServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get familyServer;

  /// No description provided for @familyServerValue.
  ///
  /// In en, this message translates to:
  /// **'Server: {server}'**
  String familyServerValue(Object server);

  /// No description provided for @familySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get familySettings;

  /// No description provided for @familySignOutAnyway.
  ///
  /// In en, this message translates to:
  /// **'Sign out anyway?'**
  String get familySignOutAnyway;

  /// No description provided for @familySkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped: {list}'**
  String familySkipped(Object list);

  /// No description provided for @familySummarySensor.
  ///
  /// In en, this message translates to:
  /// **'Summary sensor: {url}'**
  String familySummarySensor(Object url);

  /// No description provided for @familySyncedAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {ago}'**
  String familySyncedAgo(Object ago);

  /// No description provided for @familySyncedAgoAccount.
  ///
  /// In en, this message translates to:
  /// **'Synced {ago} · {account}'**
  String familySyncedAgoAccount(Object account, Object ago);

  /// No description provided for @familyThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get familyThemeDark;

  /// No description provided for @familyThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get familyThemeLight;

  /// No description provided for @familyThisBaby.
  ///
  /// In en, this message translates to:
  /// **'this baby'**
  String get familyThisBaby;

  /// No description provided for @familyTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get familyTimeZone;

  /// No description provided for @familyTimeZoneHint.
  ///
  /// In en, this message translates to:
  /// **'Sets where each day starts for daily totals'**
  String get familyTimeZoneHint;

  /// No description provided for @familyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyTitle;

  /// No description provided for @familyTokenBody.
  ///
  /// In en, this message translates to:
  /// **'Copy it now — it won’t be shown again. Use it as “Authorization: Bearer <token>”.'**
  String get familyTokenBody;

  /// No description provided for @familyTypeDiapers.
  ///
  /// In en, this message translates to:
  /// **'Diapers'**
  String get familyTypeDiapers;

  /// No description provided for @familyTypeFeeds.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get familyTypeFeeds;

  /// No description provided for @familyTypeFirsts.
  ///
  /// In en, this message translates to:
  /// **'Firsts'**
  String get familyTypeFirsts;

  /// No description provided for @familyTypeGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get familyTypeGrowth;

  /// No description provided for @familyTypeHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get familyTypeHealth;

  /// No description provided for @familyTypeNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get familyTypeNotes;

  /// No description provided for @familyTypePump.
  ///
  /// In en, this message translates to:
  /// **'Pump'**
  String get familyTypePump;

  /// No description provided for @familyTypeRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get familyTypeRoutine;

  /// No description provided for @familyTypeSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get familyTypeSleep;

  /// No description provided for @familyUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Create and manage accounts on this server'**
  String get familyUsersHint;

  /// No description provided for @familyWithoutServer.
  ///
  /// In en, this message translates to:
  /// **'Without a server'**
  String get familyWithoutServer;

  /// No description provided for @familyWithoutServerHint.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone and the phones paired with it'**
  String get familyWithoutServerHint;

  /// No description provided for @familyYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String familyYou(Object name);

  /// No description provided for @formAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note…'**
  String get formAddNote;

  /// No description provided for @formAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get formAmount;

  /// No description provided for @formBlowout.
  ///
  /// In en, this message translates to:
  /// **'Blowout'**
  String get formBlowout;

  /// No description provided for @formBrandOptional.
  ///
  /// In en, this message translates to:
  /// **'Brand (optional)'**
  String get formBrandOptional;

  /// No description provided for @formChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get formChoose;

  /// Button: turn a saved entry back into a running timer
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get formContinue;

  /// No description provided for @formDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'It will be removed for everyone in the family.'**
  String get formDeleteMessage;

  /// No description provided for @formDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get formDeleteTitle;

  /// No description provided for @formDiaperRash.
  ///
  /// In en, this message translates to:
  /// **'Diaper Rash'**
  String get formDiaperRash;

  /// No description provided for @formDiaperWetDirtyDry.
  ///
  /// In en, this message translates to:
  /// **'Was the diaper wet, dirty or dry?'**
  String get formDiaperWetDirtyDry;

  /// No description provided for @formDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get formDoctor;

  /// No description provided for @formDose.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get formDose;

  /// No description provided for @formDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get formDuration;

  /// Form title when editing; {what} is the lowercased entry title
  ///
  /// In en, this message translates to:
  /// **'Edit {what}'**
  String formEditTitle(Object what);

  /// No description provided for @formFellAsleep.
  ///
  /// In en, this message translates to:
  /// **'Fell asleep'**
  String get formFellAsleep;

  /// No description provided for @formFoods.
  ///
  /// In en, this message translates to:
  /// **'Foods'**
  String get formFoods;

  /// Label of the formula brand field
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get formFormulaName;

  /// No description provided for @formHeadSize.
  ///
  /// In en, this message translates to:
  /// **'Head Size'**
  String get formHeadSize;

  /// No description provided for @formHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get formHeight;

  /// No description provided for @formMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get formMeasured;

  /// No description provided for @formMedLimited.
  ///
  /// In en, this message translates to:
  /// **'Already {count} doses in 24 hours. Next one allowed at {time}.'**
  String formMedLimited(Object count, Object time);

  /// No description provided for @formMedTooSoon.
  ///
  /// In en, this message translates to:
  /// **'Last dose at {last}. Next one allowed at {time}.'**
  String formMedTooSoon(Object last, Object time);

  /// No description provided for @formMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get formMilk;

  /// No description provided for @formNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get formNotes;

  /// No description provided for @formPottyWetOrDirty.
  ///
  /// In en, this message translates to:
  /// **'Was it wet, dirty or both?'**
  String get formPottyWetOrDirty;

  /// No description provided for @formSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get formSaveChanges;

  /// No description provided for @formSleepEndMissing.
  ///
  /// In en, this message translates to:
  /// **'When did the sleep end? Use the sleep timer for a nap in progress.'**
  String get formSleepEndMissing;

  /// No description provided for @formSleepEndShort.
  ///
  /// In en, this message translates to:
  /// **'When did the sleep end?'**
  String get formSleepEndShort;

  /// No description provided for @formStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get formStartTime;

  /// Which breast the feed started on (Left/Right)
  ///
  /// In en, this message translates to:
  /// **'Started on'**
  String get formStartedOn;

  /// No description provided for @formTextureColor.
  ///
  /// In en, this message translates to:
  /// **'Texture & Color'**
  String get formTextureColor;

  /// No description provided for @formTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get formTime;

  /// No description provided for @formTitleBottle.
  ///
  /// In en, this message translates to:
  /// **'Bottle Feed'**
  String get formTitleBottle;

  /// No description provided for @formTitleCombo.
  ///
  /// In en, this message translates to:
  /// **'Combo Feed'**
  String get formTitleCombo;

  /// No description provided for @formTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get formTotalTime;

  /// No description provided for @formType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get formType;

  /// No description provided for @formUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get formUnit;

  /// No description provided for @formWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get formWeight;

  /// Potty trip: wet (pee) and/or dirty (poo)
  ///
  /// In en, this message translates to:
  /// **'What came'**
  String get formWhatCame;

  /// No description provided for @formWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get formWhen;

  /// No description provided for @formWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get formWhere;

  /// No description provided for @formWokeUp.
  ///
  /// In en, this message translates to:
  /// **'Woke up'**
  String get formWokeUp;

  /// No description provided for @growthAddBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Add birth date'**
  String get growthAddBirthDate;

  /// No description provided for @growthAddBirthDateNotice.
  ///
  /// In en, this message translates to:
  /// **'Add {name}\'s birth date to compare with the WHO growth curves.'**
  String growthAddBirthDateNotice(Object name);

  /// No description provided for @growthAddMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Add a measurement'**
  String get growthAddMeasurement;

  /// No description provided for @growthAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get growthAge;

  /// Short age, e.g. 12d.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String growthAgeDays(Object days);

  /// Short age, e.g. 2m 5d.
  ///
  /// In en, this message translates to:
  /// **'{months}m {days}d'**
  String growthAgeMonthsDays(Object days, Object months);

  /// Short age, e.g. 1y 3m.
  ///
  /// In en, this message translates to:
  /// **'{years}y {months}m'**
  String growthAgeYearsMonths(Object months, Object years);

  /// No description provided for @growthBoys.
  ///
  /// In en, this message translates to:
  /// **'Boys'**
  String get growthBoys;

  /// No description provided for @growthBoysPercentile.
  ///
  /// In en, this message translates to:
  /// **'Boys percentile'**
  String get growthBoysPercentile;

  /// No description provided for @growthCompareWith.
  ///
  /// In en, this message translates to:
  /// **'Compare with'**
  String get growthCompareWith;

  /// No description provided for @growthCurvesNote.
  ///
  /// In en, this message translates to:
  /// **'Curves: WHO Child Growth Standards ({sex, select, female{girls} other{boys}}, birth to 24 months), percentiles 2 to 98. A single measurement says little; follow the trend, and ask your doctor about any worry.'**
  String growthCurvesNote(String sex);

  /// No description provided for @growthGirls.
  ///
  /// In en, this message translates to:
  /// **'Girls'**
  String get growthGirls;

  /// No description provided for @growthGirlsPercentile.
  ///
  /// In en, this message translates to:
  /// **'Girls percentile'**
  String get growthGirlsPercentile;

  /// No description provided for @growthHead.
  ///
  /// In en, this message translates to:
  /// **'Head'**
  String get growthHead;

  /// No description provided for @growthLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get growthLength;

  /// Axis title.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get growthMonths;

  /// No description provided for @growthNoneHead.
  ///
  /// In en, this message translates to:
  /// **'No head size measured yet.'**
  String get growthNoneHead;

  /// No description provided for @growthNoneLength.
  ///
  /// In en, this message translates to:
  /// **'No length measured yet.'**
  String get growthNoneLength;

  /// No description provided for @growthNoneWeight.
  ///
  /// In en, this message translates to:
  /// **'No weight measured yet.'**
  String get growthNoneWeight;

  /// rank is an ordinal made by the app: 50th (English), 50e / 1er (French), 50 (Spanish).
  ///
  /// In en, this message translates to:
  /// **'{rank} percentile'**
  String growthPercentile(Object rank);

  /// No description provided for @growthTitle.
  ///
  /// In en, this message translates to:
  /// **'Growth charts'**
  String get growthTitle;

  /// Axis title.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get growthWeeks;

  /// No description provided for @growthWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get growthWeight;

  /// No description provided for @headShort.
  ///
  /// In en, this message translates to:
  /// **'Head {value}'**
  String headShort(Object value);

  /// No description provided for @healthAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get healthAppointment;

  /// No description provided for @healthMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get healthMedicine;

  /// No description provided for @healthSymptom.
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get healthSymptom;

  /// No description provided for @healthTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get healthTemperature;

  /// No description provided for @healthVaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get healthVaccine;

  /// No description provided for @homeAddBaby.
  ///
  /// In en, this message translates to:
  /// **'Add a baby'**
  String get homeAddBaby;

  /// No description provided for @homeAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get homeAddNote;

  /// No description provided for @homeAsleep.
  ///
  /// In en, this message translates to:
  /// **'asleep'**
  String get homeAsleep;

  /// No description provided for @homeAwakeFor.
  ///
  /// In en, this message translates to:
  /// **'Awake for {duration}'**
  String homeAwakeFor(Object duration);

  /// Sleep card caption: awake now; the last sleep lasted duration.
  ///
  /// In en, this message translates to:
  /// **'awake · last {duration}'**
  String homeAwakeLast(Object duration);

  /// Screen-reader label of the Firsts card's button that opens the baby book.
  ///
  /// In en, this message translates to:
  /// **'Baby book'**
  String get homeBabyBook;

  /// No description provided for @homeBreastCount.
  ///
  /// In en, this message translates to:
  /// **'{count} breast'**
  String homeBreastCount(Object count);

  /// No description provided for @homeCaptionBottle.
  ///
  /// In en, this message translates to:
  /// **'bottle'**
  String get homeCaptionBottle;

  /// No description provided for @homeCaptionPotty.
  ///
  /// In en, this message translates to:
  /// **'potty'**
  String get homeCaptionPotty;

  /// Home card title.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get homeCardFeed;

  /// Home card title (milestones).
  ///
  /// In en, this message translates to:
  /// **'Firsts'**
  String get homeCardFirsts;

  /// No description provided for @homeCardHistory.
  ///
  /// In en, this message translates to:
  /// **'{title} history'**
  String homeCardHistory(Object title);

  /// Home card title (activities: bath, tummy time…).
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get homeCardRoutine;

  /// Short word on the Growth card's header button that opens the growth charts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get homeChartsShort;

  /// No description provided for @homeDiaperReminder.
  ///
  /// In en, this message translates to:
  /// **'Diaper reminder'**
  String get homeDiaperReminder;

  /// No description provided for @homeDiapersIn24h.
  ///
  /// In en, this message translates to:
  /// **'diapers in 24 h'**
  String get homeDiapersIn24h;

  /// No description provided for @homeDiapersToday.
  ///
  /// In en, this message translates to:
  /// **'diapers today'**
  String get homeDiapersToday;

  /// No description provided for @homeDoseNow.
  ///
  /// In en, this message translates to:
  /// **'Next dose can be given now'**
  String get homeDoseNow;

  /// No description provided for @homeDosesIn24h.
  ///
  /// In en, this message translates to:
  /// **'{given} of {max} in 24 h'**
  String homeDosesIn24h(Object given, Object max);

  /// No description provided for @homeFeedReminder.
  ///
  /// In en, this message translates to:
  /// **'Feed reminder'**
  String get homeFeedReminder;

  /// No description provided for @homeFeedsIn24h.
  ///
  /// In en, this message translates to:
  /// **'feeds in 24 h'**
  String get homeFeedsIn24h;

  /// No description provided for @homeFeedsToday.
  ///
  /// In en, this message translates to:
  /// **'feeds today'**
  String get homeFeedsToday;

  /// No description provided for @homeGive.
  ///
  /// In en, this message translates to:
  /// **'Give'**
  String get homeGive;

  /// No description provided for @homeGrowthCharts.
  ///
  /// In en, this message translates to:
  /// **'Growth charts'**
  String get homeGrowthCharts;

  /// Head circumference, lower case caption.
  ///
  /// In en, this message translates to:
  /// **'head {value}'**
  String homeHead(Object value);

  /// No description provided for @homeHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get homeHide;

  /// Short word on a home card's header button that opens its history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get homeHistoryShort;

  /// No description provided for @homeLabelPaused.
  ///
  /// In en, this message translates to:
  /// **'{label} · paused'**
  String homeLabelPaused(Object label);

  /// No description provided for @homeLastSide.
  ///
  /// In en, this message translates to:
  /// **'last side'**
  String get homeLastSide;

  /// Feed card caption while nursing; side is left or right.
  ///
  /// In en, this message translates to:
  /// **'breastfeed · {side, select, right{right} other{left}}'**
  String homeLiveBreastfeed(String side);

  /// No description provided for @homeLiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Live — changes from other caregivers appear instantly'**
  String get homeLiveTooltip;

  /// No description provided for @homeLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get homeLog;

  /// Screen-reader label of a home card.
  ///
  /// In en, this message translates to:
  /// **'Log {title}'**
  String homeLogCard(Object title);

  /// No description provided for @homeLogFeed.
  ///
  /// In en, this message translates to:
  /// **'Log a feed'**
  String get homeLogFeed;

  /// No description provided for @homeNaps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 nap} other{{count} naps}}'**
  String homeNaps(num count);

  /// No description provided for @homeNavBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get homeNavBook;

  /// Bottom navigation tab.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get homeNavCalendar;

  /// Bottom navigation tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavHome;

  /// Bottom navigation tab: the list of entries.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get homeNavTimeline;

  /// Bottom navigation tab.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get homeNavTrends;

  /// date is e.g. "Oct 12".
  ///
  /// In en, this message translates to:
  /// **'Next dose {date} at {time}'**
  String homeNextDoseOn(Object date, Object time);

  /// No description provided for @homeNextDoseToday.
  ///
  /// In en, this message translates to:
  /// **'Next dose at {time}'**
  String homeNextDoseToday(Object time);

  /// No description provided for @homeNextDoseTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Next dose tomorrow at {time}'**
  String homeNextDoseTomorrow(Object time);

  /// No description provided for @homeNightSleep.
  ///
  /// In en, this message translates to:
  /// **'{duration} night'**
  String homeNightSleep(Object duration);

  /// No description provided for @homeNoDiaperFor.
  ///
  /// In en, this message translates to:
  /// **'No diaper change for {duration}'**
  String homeNoDiaperFor(Object duration);

  /// No description provided for @homeNoDoseYet.
  ///
  /// In en, this message translates to:
  /// **'No dose given yet'**
  String get homeNoDoseYet;

  /// No description provided for @homeNoFeedFor.
  ///
  /// In en, this message translates to:
  /// **'No feed for {duration}'**
  String homeNoFeedFor(Object duration);

  /// No description provided for @homeNoPumpFor.
  ///
  /// In en, this message translates to:
  /// **'No pumping for {duration}'**
  String homeNoPumpFor(Object duration);

  /// No description provided for @homeNotSyncedYet.
  ///
  /// In en, this message translates to:
  /// **'not synced yet'**
  String get homeNotSyncedYet;

  /// No description provided for @homeOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get homeOffline;

  /// No description provided for @homeOfflinePending.
  ///
  /// In en, this message translates to:
  /// **'offline · {count} to sync'**
  String homeOfflinePending(Object count);

  /// No description provided for @homeOfflineTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Offline — keep logging; changes sync when the server is back} =1{Offline — keep logging; 1 change will sync when the server is back} other{Offline — keep logging; {count} changes will sync when the server is back}}'**
  String homeOfflineTooltip(num count);

  /// No description provided for @homePaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get homePaused;

  /// No description provided for @homePottyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} potty'**
  String homePottyCount(Object count);

  /// No description provided for @homePumpReminder.
  ///
  /// In en, this message translates to:
  /// **'Pump reminder'**
  String get homePumpReminder;

  /// No description provided for @homePumped.
  ///
  /// In en, this message translates to:
  /// **'pumped'**
  String get homePumped;

  /// Running pump timer banner.
  ///
  /// In en, this message translates to:
  /// **'Pumping'**
  String get homePumping;

  /// No description provided for @homeReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get homeReconnecting;

  /// No description provided for @homeServerlessAlone.
  ///
  /// In en, this message translates to:
  /// **'Serverless: saved on this phone. Pair another phone in Family to share.'**
  String get homeServerlessAlone;

  /// No description provided for @homeServerlessPeers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Serverless: syncs with 1 paired phone on the same Wi-Fi} other{Serverless: syncs with {count} paired phones on the same Wi-Fi}}'**
  String homeServerlessPeers(num count);

  /// No description provided for @homeSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, right{Right side} other{Left side}}'**
  String homeSide(String side);

  /// No description provided for @homeSince.
  ///
  /// In en, this message translates to:
  /// **'since {time}'**
  String homeSince(Object time);

  /// No description provided for @homeSleepIn24h.
  ///
  /// In en, this message translates to:
  /// **'sleep in 24 h'**
  String get homeSleepIn24h;

  /// No description provided for @homeSleepReminder.
  ///
  /// In en, this message translates to:
  /// **'Sleep reminder'**
  String get homeSleepReminder;

  /// No description provided for @homeSleepToday.
  ///
  /// In en, this message translates to:
  /// **'sleep today'**
  String get homeSleepToday;

  /// Running sleep timer banner.
  ///
  /// In en, this message translates to:
  /// **'Sleeping'**
  String get homeSleeping;

  /// No description provided for @homeSolidsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 solid} other{{count} solids}}'**
  String homeSolidsCount(num count);

  /// No description provided for @homeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get homeStart;

  /// No description provided for @homeSwitchBaby.
  ///
  /// In en, this message translates to:
  /// **'Switch baby'**
  String get homeSwitchBaby;

  /// No description provided for @homeSyncLocal.
  ///
  /// In en, this message translates to:
  /// **'on this phone'**
  String get homeSyncLocal;

  /// No description provided for @homeSynced.
  ///
  /// In en, this message translates to:
  /// **'synced {ago}'**
  String homeSynced(Object ago);

  /// No description provided for @homeSyncing.
  ///
  /// In en, this message translates to:
  /// **'syncing'**
  String get homeSyncing;

  /// No description provided for @homeSyncingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Syncing changes made offline…'**
  String get homeSyncingTooltip;

  /// No description provided for @homeTapToLog.
  ///
  /// In en, this message translates to:
  /// **'Tap to log'**
  String get homeTapToLog;

  /// No description provided for @homeWetDirtyCounts.
  ///
  /// In en, this message translates to:
  /// **'{wet} wet · {dirty} dirty'**
  String homeWetDirtyCounts(Object dirty, Object wet);

  /// ago is e.g. "2h 5m ago" / "just now".
  ///
  /// In en, this message translates to:
  /// **'woke {ago}'**
  String homeWoke(Object ago);

  /// No description provided for @inThePotty.
  ///
  /// In en, this message translates to:
  /// **'In the potty'**
  String get inThePotty;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @kindActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get kindActivity;

  /// No description provided for @kindBottle.
  ///
  /// In en, this message translates to:
  /// **'Bottle'**
  String get kindBottle;

  /// No description provided for @kindBreastfeed.
  ///
  /// In en, this message translates to:
  /// **'Breastfeed'**
  String get kindBreastfeed;

  /// No description provided for @kindCombo.
  ///
  /// In en, this message translates to:
  /// **'Combo'**
  String get kindCombo;

  /// No description provided for @kindDiaper.
  ///
  /// In en, this message translates to:
  /// **'Diaper'**
  String get kindDiaper;

  /// No description provided for @kindGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get kindGrowth;

  /// No description provided for @kindHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get kindHealth;

  /// No description provided for @kindMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get kindMilestone;

  /// No description provided for @kindNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get kindNote;

  /// No description provided for @kindPotty.
  ///
  /// In en, this message translates to:
  /// **'Potty'**
  String get kindPotty;

  /// No description provided for @kindPump.
  ///
  /// In en, this message translates to:
  /// **'Pump'**
  String get kindPump;

  /// No description provided for @kindSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get kindSleep;

  /// No description provided for @kindSolids.
  ///
  /// In en, this message translates to:
  /// **'Solids'**
  String get kindSolids;

  /// No description provided for @kindTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get kindTemperature;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// One-letter abbreviation of the left side (breastfeeding, pumping).
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get leftShort;

  /// Length (height) of the baby in a one-line summary.
  ///
  /// In en, this message translates to:
  /// **'L {value}'**
  String lengthShort(Object value);

  /// No description provided for @localNeedsServer.
  ///
  /// In en, this message translates to:
  /// **'This needs a Nestling server. In serverless mode everything stays on your phones.'**
  String get localNeedsServer;

  /// No description provided for @localPhotosNeedServer.
  ///
  /// In en, this message translates to:
  /// **'Photos on memories need the Android app or a Nestling server.'**
  String get localPhotosNeedServer;

  /// No description provided for @locationArms.
  ///
  /// In en, this message translates to:
  /// **'Arms'**
  String get locationArms;

  /// No description provided for @locationBassinet.
  ///
  /// In en, this message translates to:
  /// **'Bassinet'**
  String get locationBassinet;

  /// No description provided for @locationBed.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get locationBed;

  /// No description provided for @locationCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get locationCar;

  /// No description provided for @locationCrib.
  ///
  /// In en, this message translates to:
  /// **'Crib'**
  String get locationCrib;

  /// No description provided for @locationStroller.
  ///
  /// In en, this message translates to:
  /// **'Stroller'**
  String get locationStroller;

  /// No description provided for @loginAskAdmin.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Ask whoever runs this Nestling server to create one for you.'**
  String get loginAskAdmin;

  /// No description provided for @loginContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get loginContinue;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginCreateAccount;

  /// No description provided for @loginCreateAdmin.
  ///
  /// In en, this message translates to:
  /// **'Create admin account'**
  String get loginCreateAdmin;

  /// No description provided for @loginCreateYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get loginCreateYourAccount;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get loginEnterEmail;

  /// No description provided for @loginEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get loginEnterName;

  /// No description provided for @loginEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginEnterPassword;

  /// No description provided for @loginEnterServer.
  ///
  /// In en, this message translates to:
  /// **'Enter your Nestling server address'**
  String get loginEnterServer;

  /// No description provided for @loginHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get loginHaveAccount;

  /// No description provided for @loginNewHere.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get loginNewHere;

  /// No description provided for @loginNewServer.
  ///
  /// In en, this message translates to:
  /// **'New server: create the admin account.\nYou\'ll add the other caregivers afterwards.'**
  String get loginNewServer;

  /// No description provided for @loginNoServerIntro.
  ///
  /// In en, this message translates to:
  /// **'No home server? Nestling also works on its own: your data stays on your phone, and you can pair your partner\'s phone over Wi-Fi and back up to Google Drive.'**
  String get loginNoServerIntro;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get loginPasswordMin;

  /// No description provided for @loginServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get loginServerAddress;

  /// No description provided for @loginServerLink.
  ///
  /// In en, this message translates to:
  /// **'Server: {server}'**
  String loginServerLink(Object server);

  /// No description provided for @loginServerless.
  ///
  /// In en, this message translates to:
  /// **'Use without a server'**
  String get loginServerless;

  /// No description provided for @loginServerlessIntro.
  ///
  /// In en, this message translates to:
  /// **'Everything you log is saved on this phone. What\'s your name? Other caregivers see it.'**
  String get loginServerlessIntro;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get loginYourName;

  /// No description provided for @milkBreastMilk.
  ///
  /// In en, this message translates to:
  /// **'Breast milk'**
  String get milkBreastMilk;

  /// No description provided for @milkFormula.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get milkFormula;

  /// No description provided for @milkMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get milkMixed;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @notifBreastfeedPaused.
  ///
  /// In en, this message translates to:
  /// **'Breastfeed paused'**
  String get notifBreastfeedPaused;

  /// No description provided for @notifBreastfeeding.
  ///
  /// In en, this message translates to:
  /// **'{side, select, right{Breastfeeding · right side} other{Breastfeeding · left side}}'**
  String notifBreastfeeding(String side);

  /// No description provided for @notifChipPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get notifChipPaused;

  /// No description provided for @notifPausedBody.
  ///
  /// In en, this message translates to:
  /// **'{duration} so far · tap to resume'**
  String notifPausedBody(Object duration);

  /// No description provided for @notifPumpPaused.
  ///
  /// In en, this message translates to:
  /// **'Pump paused'**
  String get notifPumpPaused;

  /// No description provided for @notifPumping.
  ///
  /// In en, this message translates to:
  /// **'Pumping'**
  String get notifPumping;

  /// No description provided for @notifRunningBody.
  ///
  /// In en, this message translates to:
  /// **'Since {time} · tap to open'**
  String notifRunningBody(Object time);

  /// No description provided for @notifSleepPaused.
  ///
  /// In en, this message translates to:
  /// **'Sleep paused'**
  String get notifSleepPaused;

  /// No description provided for @notifSleeping.
  ///
  /// In en, this message translates to:
  /// **'Sleeping'**
  String get notifSleeping;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'{child} · {what}'**
  String notifTitle(Object child, Object what);

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @onboardingAddBaby.
  ///
  /// In en, this message translates to:
  /// **'Add a baby'**
  String get onboardingAddBaby;

  /// No description provided for @onboardingAddLittleOne.
  ///
  /// In en, this message translates to:
  /// **'Now add your little one to {family}.'**
  String onboardingAddLittleOne(Object family);

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingCreateFamily.
  ///
  /// In en, this message translates to:
  /// **'Create family'**
  String get onboardingCreateFamily;

  /// No description provided for @onboardingFamilyName.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get onboardingFamilyName;

  /// No description provided for @onboardingHi.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}!'**
  String onboardingHi(Object name);

  /// No description provided for @onboardingIntro.
  ///
  /// In en, this message translates to:
  /// **'Start a family to track your baby, or join one with an invite code from your partner.'**
  String get onboardingIntro;

  /// No description provided for @onboardingIntroServerless.
  ///
  /// In en, this message translates to:
  /// **'Start a family to track your baby, or join the one on your partner\'s phone.'**
  String get onboardingIntroServerless;

  /// No description provided for @onboardingInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get onboardingInviteCode;

  /// No description provided for @onboardingJoinFamily.
  ///
  /// In en, this message translates to:
  /// **'Join family'**
  String get onboardingJoinFamily;

  /// No description provided for @onboardingJoinWithCode.
  ///
  /// In en, this message translates to:
  /// **'Join with a pairing code'**
  String get onboardingJoinWithCode;

  /// No description provided for @onboardingNoBackup.
  ///
  /// In en, this message translates to:
  /// **'No Nestling backup in this Google account.'**
  String get onboardingNoBackup;

  /// No description provided for @onboardingOrJoin.
  ///
  /// In en, this message translates to:
  /// **'Or join one'**
  String get onboardingOrJoin;

  /// No description provided for @onboardingOrJoinPartner.
  ///
  /// In en, this message translates to:
  /// **'Or join your partner\'s'**
  String get onboardingOrJoinPartner;

  /// Default family name.
  ///
  /// In en, this message translates to:
  /// **'Our family'**
  String get onboardingOurFamily;

  /// No description provided for @onboardingPairIntro.
  ///
  /// In en, this message translates to:
  /// **'If another phone already tracks your baby, pair with it: everything comes over and stays in sync.'**
  String get onboardingPairIntro;

  /// No description provided for @onboardingRestoreDrive.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google Drive'**
  String get onboardingRestoreDrive;

  /// No description provided for @onboardingStartFamily.
  ///
  /// In en, this message translates to:
  /// **'Start a family'**
  String get onboardingStartFamily;

  /// No description provided for @pagesAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get pagesAge;

  /// No description provided for @pagesAndAlso.
  ///
  /// In en, this message translates to:
  /// **'And also'**
  String get pagesAndAlso;

  /// Label of the time of birth on the birth page.
  ///
  /// In en, this message translates to:
  /// **'At'**
  String get pagesAt;

  /// No description provided for @pagesBirth.
  ///
  /// In en, this message translates to:
  /// **'Birth'**
  String get pagesBirth;

  /// No description provided for @pagesBirthGrowthHint.
  ///
  /// In en, this message translates to:
  /// **'Birth weight and length come from a Growth entry on the birth day.'**
  String get pagesBirthGrowthHint;

  /// No description provided for @pagesBorn.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get pagesBorn;

  /// No description provided for @pagesBornNoDate.
  ///
  /// In en, this message translates to:
  /// **'Add the birth date in Family → the baby to start this page.'**
  String get pagesBornNoDate;

  /// No description provided for @pagesBornPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap to add the time, the place, hair and eyes.'**
  String get pagesBornPrompt;

  /// No description provided for @pagesBornTitle.
  ///
  /// In en, this message translates to:
  /// **'The day you were born'**
  String get pagesBornTitle;

  /// No description provided for @pagesEyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get pagesEyes;

  /// No description provided for @pagesFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get pagesFullName;

  /// No description provided for @pagesGrowthEmpty.
  ///
  /// In en, this message translates to:
  /// **'Log weight and length in Growth, and each month shows here.'**
  String get pagesGrowthEmpty;

  /// No description provided for @pagesGrowthNoBirth.
  ///
  /// In en, this message translates to:
  /// **'Add the birth date to see growth month by month.'**
  String get pagesGrowthNoBirth;

  /// No description provided for @pagesHair.
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get pagesHair;

  /// No description provided for @pagesHead.
  ///
  /// In en, this message translates to:
  /// **'Head'**
  String get pagesHead;

  /// No description provided for @pagesHintEyes.
  ///
  /// In en, this message translates to:
  /// **'Deep blue'**
  String get pagesHintEyes;

  /// No description provided for @pagesHintHair.
  ///
  /// In en, this message translates to:
  /// **'Dark and lots of it'**
  String get pagesHintHair;

  /// No description provided for @pagesHintMeaning.
  ///
  /// In en, this message translates to:
  /// **'Its meaning or origin'**
  String get pagesHintMeaning;

  /// No description provided for @pagesHintNicknames.
  ///
  /// In en, this message translates to:
  /// **'What we call you at home'**
  String get pagesHintNicknames;

  /// No description provided for @pagesHintOthers.
  ///
  /// In en, this message translates to:
  /// **'The runners-up'**
  String get pagesHintOthers;

  /// No description provided for @pagesHintPlace.
  ///
  /// In en, this message translates to:
  /// **'The hospital, home, the city'**
  String get pagesHintPlace;

  /// No description provided for @pagesHintRemember.
  ///
  /// In en, this message translates to:
  /// **'The first cry, who was there, the weather…'**
  String get pagesHintRemember;

  /// No description provided for @pagesHintWhy.
  ///
  /// In en, this message translates to:
  /// **'Who or what it comes from'**
  String get pagesHintWhy;

  /// No description provided for @pagesHintWorldNote.
  ///
  /// In en, this message translates to:
  /// **'Anything else about that year'**
  String get pagesHintWorldNote;

  /// No description provided for @pagesLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get pagesLength;

  /// No description provided for @pagesMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get pagesMeasured;

  /// No description provided for @pagesMonthByMonth.
  ///
  /// In en, this message translates to:
  /// **'Month by month'**
  String get pagesMonthByMonth;

  /// Age in months, short, in the growth table.
  ///
  /// In en, this message translates to:
  /// **'{count} mo'**
  String pagesMonthsShort(Object count);

  /// No description provided for @pagesMoon.
  ///
  /// In en, this message translates to:
  /// **'The moon'**
  String get pagesMoon;

  /// No description provided for @pagesMoonFirstQuarter.
  ///
  /// In en, this message translates to:
  /// **'First quarter'**
  String get pagesMoonFirstQuarter;

  /// No description provided for @pagesMoonFull.
  ///
  /// In en, this message translates to:
  /// **'Full moon'**
  String get pagesMoonFull;

  /// No description provided for @pagesMoonLastQuarter.
  ///
  /// In en, this message translates to:
  /// **'Last quarter'**
  String get pagesMoonLastQuarter;

  /// No description provided for @pagesMoonNew.
  ///
  /// In en, this message translates to:
  /// **'New moon'**
  String get pagesMoonNew;

  /// No description provided for @pagesMoonWaningCrescent.
  ///
  /// In en, this message translates to:
  /// **'Waning crescent'**
  String get pagesMoonWaningCrescent;

  /// No description provided for @pagesMoonWaningGibbous.
  ///
  /// In en, this message translates to:
  /// **'Waning gibbous'**
  String get pagesMoonWaningGibbous;

  /// No description provided for @pagesMoonWaxingCrescent.
  ///
  /// In en, this message translates to:
  /// **'Waxing crescent'**
  String get pagesMoonWaxingCrescent;

  /// No description provided for @pagesMoonWaxingGibbous.
  ///
  /// In en, this message translates to:
  /// **'Waxing gibbous'**
  String get pagesMoonWaxingGibbous;

  /// No description provided for @pagesNameMeaning.
  ///
  /// In en, this message translates to:
  /// **'What it means'**
  String get pagesNameMeaning;

  /// No description provided for @pagesNameOthers.
  ///
  /// In en, this message translates to:
  /// **'Other names we thought of'**
  String get pagesNameOthers;

  /// No description provided for @pagesNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap to write why you chose it.'**
  String get pagesNamePrompt;

  /// No description provided for @pagesNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get pagesNameTitle;

  /// No description provided for @pagesNameWhy.
  ///
  /// In en, this message translates to:
  /// **'Why we chose it'**
  String get pagesNameWhy;

  /// No description provided for @pagesNicknames.
  ///
  /// In en, this message translates to:
  /// **'Nicknames'**
  String get pagesNicknames;

  /// No description provided for @pagesPriceBread.
  ///
  /// In en, this message translates to:
  /// **'Bread'**
  String get pagesPriceBread;

  /// No description provided for @pagesPriceCar.
  ///
  /// In en, this message translates to:
  /// **'A new car'**
  String get pagesPriceCar;

  /// No description provided for @pagesPriceCoffee.
  ///
  /// In en, this message translates to:
  /// **'A coffee'**
  String get pagesPriceCoffee;

  /// No description provided for @pagesPriceDiapers.
  ///
  /// In en, this message translates to:
  /// **'Diapers'**
  String get pagesPriceDiapers;

  /// No description provided for @pagesPriceGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get pagesPriceGas;

  /// No description provided for @pagesPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get pagesPriceHint;

  /// No description provided for @pagesPriceHouse.
  ///
  /// In en, this message translates to:
  /// **'A house'**
  String get pagesPriceHouse;

  /// No description provided for @pagesPriceMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get pagesPriceMilk;

  /// No description provided for @pagesPriceMovie.
  ///
  /// In en, this message translates to:
  /// **'A movie ticket'**
  String get pagesPriceMovie;

  /// No description provided for @pagesPriceRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get pagesPriceRent;

  /// No description provided for @pagesSaveToBook.
  ///
  /// In en, this message translates to:
  /// **'Save to the book'**
  String get pagesSaveToBook;

  /// No description provided for @pagesSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get pagesSaving;

  /// No description provided for @pagesSetTime.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get pagesSetTime;

  /// Screen-reader label of a baby book page.
  ///
  /// In en, this message translates to:
  /// **'{title}. Tap to edit.'**
  String pagesTapToEdit(Object title);

  /// No description provided for @pagesTimeOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Time of birth'**
  String get pagesTimeOfBirth;

  /// No description provided for @pagesWeRemember.
  ///
  /// In en, this message translates to:
  /// **'We remember'**
  String get pagesWeRemember;

  /// No description provided for @pagesWeighed.
  ///
  /// In en, this message translates to:
  /// **'Weighed'**
  String get pagesWeighed;

  /// No description provided for @pagesWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get pagesWeight;

  /// No description provided for @pagesWhatThingsCost.
  ///
  /// In en, this message translates to:
  /// **'What things cost'**
  String get pagesWhatThingsCost;

  /// No description provided for @pagesWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get pagesWhere;

  /// No description provided for @pagesWorldLeaders.
  ///
  /// In en, this message translates to:
  /// **'Leaders'**
  String get pagesWorldLeaders;

  /// No description provided for @pagesWorldLeadersHint.
  ///
  /// In en, this message translates to:
  /// **'Prime minister, president, mayor…'**
  String get pagesWorldLeadersHint;

  /// No description provided for @pagesWorldMovies.
  ///
  /// In en, this message translates to:
  /// **'At the movies'**
  String get pagesWorldMovies;

  /// No description provided for @pagesWorldMoviesHint.
  ///
  /// In en, this message translates to:
  /// **'What was playing'**
  String get pagesWorldMoviesHint;

  /// No description provided for @pagesWorldNews.
  ///
  /// In en, this message translates to:
  /// **'In the news'**
  String get pagesWorldNews;

  /// No description provided for @pagesWorldNewsHint.
  ///
  /// In en, this message translates to:
  /// **'What everyone was talking about'**
  String get pagesWorldNewsHint;

  /// No description provided for @pagesWorldPeople.
  ///
  /// In en, this message translates to:
  /// **'Famous faces'**
  String get pagesWorldPeople;

  /// No description provided for @pagesWorldPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'Actors, athletes, singers'**
  String get pagesWorldPeopleHint;

  /// No description provided for @pagesWorldPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap to note the songs, the news and what a coffee cost.'**
  String get pagesWorldPrompt;

  /// No description provided for @pagesWorldShows.
  ///
  /// In en, this message translates to:
  /// **'On TV'**
  String get pagesWorldShows;

  /// No description provided for @pagesWorldShowsHint.
  ///
  /// In en, this message translates to:
  /// **'Shows everyone watched'**
  String get pagesWorldShowsHint;

  /// No description provided for @pagesWorldSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs on the radio'**
  String get pagesWorldSongs;

  /// No description provided for @pagesWorldSongsHint.
  ///
  /// In en, this message translates to:
  /// **'The hits that year'**
  String get pagesWorldSongsHint;

  /// No description provided for @pagesWorldTech.
  ///
  /// In en, this message translates to:
  /// **'Gadgets'**
  String get pagesWorldTech;

  /// No description provided for @pagesWorldTechHint.
  ///
  /// In en, this message translates to:
  /// **'The phone in our pocket, the new thing'**
  String get pagesWorldTechHint;

  /// No description provided for @pagesWorldTitle.
  ///
  /// In en, this message translates to:
  /// **'The world you were born into'**
  String get pagesWorldTitle;

  /// No description provided for @pairingCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Pairing code copied. Send it only to your family: it opens your baby\'s data.'**
  String get pairingCodeCopied;

  /// No description provided for @pairingCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy the code instead'**
  String get pairingCopyCode;

  /// No description provided for @pairingIntro.
  ///
  /// In en, this message translates to:
  /// **'On the other phone, install Nestling, choose \"Use without a server\", then \"Join with a pairing code\" and scan this. Both phones must be on the same Wi-Fi.'**
  String get pairingIntro;

  /// No description provided for @pairingJoinIntro.
  ///
  /// In en, this message translates to:
  /// **'On a phone that already uses Nestling: Family → Pair a phone. Scan the code it shows (same Wi-Fi for both phones).'**
  String get pairingJoinIntro;

  /// No description provided for @pairingJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join with a pairing code'**
  String get pairingJoinTitle;

  /// No description provided for @pairingNeedsAndroid.
  ///
  /// In en, this message translates to:
  /// **'Pairing phones needs the Android app.'**
  String get pairingNeedsAndroid;

  /// No description provided for @pairingNoneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet.'**
  String get pairingNoneYet;

  /// No description provided for @pairingNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get pairingNotSynced;

  /// No description provided for @pairingPairedPhones.
  ///
  /// In en, this message translates to:
  /// **'Paired phones'**
  String get pairingPairedPhones;

  /// No description provided for @pairingPasteCode.
  ///
  /// In en, this message translates to:
  /// **'Or paste the code'**
  String get pairingPasteCode;

  /// No description provided for @pairingPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get pairingPhone;

  /// No description provided for @pairingSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get pairingSyncNow;

  /// No description provided for @pairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair a phone'**
  String get pairingTitle;

  /// No description provided for @pairingUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Synced {ago} · not reachable right now'**
  String pairingUnreachable(Object ago);

  /// No description provided for @pickerAddActivity.
  ///
  /// In en, this message translates to:
  /// **'Add an activity'**
  String get pickerAddActivity;

  /// No description provided for @pickerAddFood.
  ///
  /// In en, this message translates to:
  /// **'Add a food'**
  String get pickerAddFood;

  /// No description provided for @pickerAddMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add a medicine'**
  String get pickerAddMedicine;

  /// No description provided for @pickerAlreadyTried.
  ///
  /// In en, this message translates to:
  /// **'Already tried'**
  String get pickerAlreadyTried;

  /// No description provided for @pickerCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get pickerCommon;

  /// No description provided for @pickerFoodApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get pickerFoodApple;

  /// No description provided for @pickerFoodAvocado.
  ///
  /// In en, this message translates to:
  /// **'Avocado'**
  String get pickerFoodAvocado;

  /// No description provided for @pickerFoodBanana.
  ///
  /// In en, this message translates to:
  /// **'Banana'**
  String get pickerFoodBanana;

  /// No description provided for @pickerFoodBeef.
  ///
  /// In en, this message translates to:
  /// **'Beef'**
  String get pickerFoodBeef;

  /// No description provided for @pickerFoodBlueberries.
  ///
  /// In en, this message translates to:
  /// **'Blueberries'**
  String get pickerFoodBlueberries;

  /// No description provided for @pickerFoodBread.
  ///
  /// In en, this message translates to:
  /// **'Bread'**
  String get pickerFoodBread;

  /// No description provided for @pickerFoodBroccoli.
  ///
  /// In en, this message translates to:
  /// **'Broccoli'**
  String get pickerFoodBroccoli;

  /// No description provided for @pickerFoodCarrot.
  ///
  /// In en, this message translates to:
  /// **'Carrot'**
  String get pickerFoodCarrot;

  /// No description provided for @pickerFoodCheese.
  ///
  /// In en, this message translates to:
  /// **'Cheese'**
  String get pickerFoodCheese;

  /// No description provided for @pickerFoodChicken.
  ///
  /// In en, this message translates to:
  /// **'Chicken'**
  String get pickerFoodChicken;

  /// No description provided for @pickerFoodEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get pickerFoodEgg;

  /// No description provided for @pickerFoodFish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get pickerFoodFish;

  /// No description provided for @pickerFoodGreenBeans.
  ///
  /// In en, this message translates to:
  /// **'Green beans'**
  String get pickerFoodGreenBeans;

  /// No description provided for @pickerFoodLentils.
  ///
  /// In en, this message translates to:
  /// **'Lentils'**
  String get pickerFoodLentils;

  /// No description provided for @pickerFoodMango.
  ///
  /// In en, this message translates to:
  /// **'Mango'**
  String get pickerFoodMango;

  /// No description provided for @pickerFoodOatmeal.
  ///
  /// In en, this message translates to:
  /// **'Oatmeal'**
  String get pickerFoodOatmeal;

  /// No description provided for @pickerFoodPasta.
  ///
  /// In en, this message translates to:
  /// **'Pasta'**
  String get pickerFoodPasta;

  /// No description provided for @pickerFoodPeach.
  ///
  /// In en, this message translates to:
  /// **'Peach'**
  String get pickerFoodPeach;

  /// No description provided for @pickerFoodPeanutButter.
  ///
  /// In en, this message translates to:
  /// **'Peanut butter'**
  String get pickerFoodPeanutButter;

  /// No description provided for @pickerFoodPear.
  ///
  /// In en, this message translates to:
  /// **'Pear'**
  String get pickerFoodPear;

  /// No description provided for @pickerFoodPeas.
  ///
  /// In en, this message translates to:
  /// **'Peas'**
  String get pickerFoodPeas;

  /// No description provided for @pickerFoodRiceCereal.
  ///
  /// In en, this message translates to:
  /// **'Rice cereal'**
  String get pickerFoodRiceCereal;

  /// No description provided for @pickerFoodSquash.
  ///
  /// In en, this message translates to:
  /// **'Squash'**
  String get pickerFoodSquash;

  /// No description provided for @pickerFoodStrawberries.
  ///
  /// In en, this message translates to:
  /// **'Strawberries'**
  String get pickerFoodStrawberries;

  /// No description provided for @pickerFoodSweetPotato.
  ///
  /// In en, this message translates to:
  /// **'Sweet potato'**
  String get pickerFoodSweetPotato;

  /// No description provided for @pickerFoodTofu.
  ///
  /// In en, this message translates to:
  /// **'Tofu'**
  String get pickerFoodTofu;

  /// No description provided for @pickerFoodYogurt.
  ///
  /// In en, this message translates to:
  /// **'Yogurt'**
  String get pickerFoodYogurt;

  /// No description provided for @pickerLastDose.
  ///
  /// In en, this message translates to:
  /// **'Last dose {dose}'**
  String pickerLastDose(Object dose);

  /// No description provided for @pickerMedAcetaminophen.
  ///
  /// In en, this message translates to:
  /// **'Acetaminophen (Tylenol)'**
  String get pickerMedAcetaminophen;

  /// No description provided for @pickerMedAmoxicillin.
  ///
  /// In en, this message translates to:
  /// **'Amoxicillin'**
  String get pickerMedAmoxicillin;

  /// No description provided for @pickerMedAntihistamine.
  ///
  /// In en, this message translates to:
  /// **'Antihistamine (Benadryl)'**
  String get pickerMedAntihistamine;

  /// No description provided for @pickerMedDiaperCream.
  ///
  /// In en, this message translates to:
  /// **'Diaper cream'**
  String get pickerMedDiaperCream;

  /// No description provided for @pickerMedGripeWater.
  ///
  /// In en, this message translates to:
  /// **'Gripe water'**
  String get pickerMedGripeWater;

  /// No description provided for @pickerMedIbuprofen.
  ///
  /// In en, this message translates to:
  /// **'Ibuprofen (Advil)'**
  String get pickerMedIbuprofen;

  /// No description provided for @pickerMedIron.
  ///
  /// In en, this message translates to:
  /// **'Iron drops'**
  String get pickerMedIron;

  /// No description provided for @pickerMedProbiotic.
  ///
  /// In en, this message translates to:
  /// **'Probiotic (BioGaia)'**
  String get pickerMedProbiotic;

  /// No description provided for @pickerMedSaline.
  ///
  /// In en, this message translates to:
  /// **'Saline drops'**
  String get pickerMedSaline;

  /// No description provided for @pickerMedSimethicone.
  ///
  /// In en, this message translates to:
  /// **'Simethicone (Ovol)'**
  String get pickerMedSimethicone;

  /// No description provided for @pickerMedTeethingGel.
  ///
  /// In en, this message translates to:
  /// **'Teething gel'**
  String get pickerMedTeethingGel;

  /// No description provided for @pickerMedVitaminD.
  ///
  /// In en, this message translates to:
  /// **'Vitamin D'**
  String get pickerMedVitaminD;

  /// No description provided for @pickerRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get pickerRecent;

  /// No description provided for @pickerSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get pickerSelected;

  /// No description provided for @pickerTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Once} other{{count} times}}'**
  String pickerTimes(num count);

  /// No description provided for @pickerUseName.
  ///
  /// In en, this message translates to:
  /// **'Use this name'**
  String get pickerUseName;

  /// No description provided for @pickerUsedLast.
  ///
  /// In en, this message translates to:
  /// **'{times} · last {day}'**
  String pickerUsedLast(Object day, Object times);

  /// No description provided for @pottyAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get pottyAccident;

  /// No description provided for @pottySatDry.
  ///
  /// In en, this message translates to:
  /// **'Sat but dry'**
  String get pottySatDry;

  /// No description provided for @pottySuccess.
  ///
  /// In en, this message translates to:
  /// **'Potty'**
  String get pottySuccess;

  /// No description provided for @rash.
  ///
  /// In en, this message translates to:
  /// **'rash'**
  String get rash;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// One-letter abbreviation of the right side.
  ///
  /// In en, this message translates to:
  /// **'R'**
  String get rightShort;

  /// No description provided for @roleBookViewer.
  ///
  /// In en, this message translates to:
  /// **'Book only'**
  String get roleBookViewer;

  /// No description provided for @roleBookViewerHint.
  ///
  /// In en, this message translates to:
  /// **'Sees the baby book, can\'t change anything'**
  String get roleBookViewerHint;

  /// No description provided for @roleCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get roleCaregiver;

  /// No description provided for @roleCaregiverHint.
  ///
  /// In en, this message translates to:
  /// **'Logs feeds, sleep, diapers and everything else'**
  String get roleCaregiverHint;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Logs everything and manages the family'**
  String get roleOwnerHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @scheduleAddMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add a medicine'**
  String get scheduleAddMedicine;

  /// No description provided for @scheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'daily'**
  String get scheduleDaily;

  /// No description provided for @scheduleDescribeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Doses on a schedule, \"no feed in 3 h\"…'**
  String get scheduleDescribeEmpty;

  /// No description provided for @scheduleDoseLabel.
  ///
  /// In en, this message translates to:
  /// **'Usual dose (optional)'**
  String get scheduleDoseLabel;

  /// No description provided for @scheduleDoses.
  ///
  /// In en, this message translates to:
  /// **'doses'**
  String get scheduleDoses;

  /// No description provided for @scheduleErrDose.
  ///
  /// In en, this message translates to:
  /// **'The dose must be a number.'**
  String get scheduleErrDose;

  /// No description provided for @scheduleErrEvery.
  ///
  /// In en, this message translates to:
  /// **'How often: between 0.5 and 168 hours.'**
  String get scheduleErrEvery;

  /// No description provided for @scheduleErrMax.
  ///
  /// In en, this message translates to:
  /// **'At most per 24 hours: a number from 1 to 24.'**
  String get scheduleErrMax;

  /// No description provided for @scheduleErrName.
  ///
  /// In en, this message translates to:
  /// **'Give the medicine a name.'**
  String get scheduleErrName;

  /// No description provided for @scheduleEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get scheduleEvery;

  /// No description provided for @scheduleEveryHours.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} h'**
  String scheduleEveryHours(Object hours);

  /// No description provided for @scheduleEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} min'**
  String scheduleEveryMinutes(Object minutes);

  /// No description provided for @scheduleFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get scheduleFeed;

  /// No description provided for @scheduleFooterPush.
  ///
  /// In en, this message translates to:
  /// **'A reminder that is due shows on the home screen (swipe it away to hide it) and is sent to the phones of everyone in the family. A medicine\'s phone reminder is turned on in its schedule.'**
  String get scheduleFooterPush;

  /// No description provided for @scheduleFooterServer.
  ///
  /// In en, this message translates to:
  /// **'A reminder that is due shows on the home screen (swipe it away to hide it). To also get it as a phone notification, set up notifications on the server (see \"Notifications on phones\" in the README).'**
  String get scheduleFooterServer;

  /// No description provided for @scheduleFooterServerless.
  ///
  /// In en, this message translates to:
  /// **'A reminder that is due shows on the home screen (swipe it away to hide it). Phone notifications need a Nestling server with them set up.'**
  String get scheduleFooterServerless;

  /// No description provided for @scheduleHours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get scheduleHours;

  /// No description provided for @scheduleIntro.
  ///
  /// In en, this message translates to:
  /// **'For {name}. A scheduled medicine shows on the home screen with when the next dose may be given, and logging one too early warns you.'**
  String scheduleIntro(Object name);

  /// No description provided for @scheduleMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'At most per 24 hours (optional)'**
  String get scheduleMaxLabel;

  /// No description provided for @scheduleMedicineSection.
  ///
  /// In en, this message translates to:
  /// **'Medicine schedule'**
  String get scheduleMedicineSection;

  /// No description provided for @scheduleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get scheduleName;

  /// No description provided for @scheduleNotifyWhen.
  ///
  /// In en, this message translates to:
  /// **'{type, select, sleep{Notify when awake for this long:} diaper{Notify when there was no diaper change for:} pump{Notify when there was no pumping for:} other{Notify when there was no feed for:}}'**
  String scheduleNotifyWhen(String type);

  /// No description provided for @scheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get scheduleOff;

  /// No description provided for @scheduleOnceADay.
  ///
  /// In en, this message translates to:
  /// **'Once a day'**
  String get scheduleOnceADay;

  /// No description provided for @scheduleOnceAWeek.
  ///
  /// In en, this message translates to:
  /// **'Once a week'**
  String get scheduleOnceAWeek;

  /// No description provided for @scheduleRemindDue.
  ///
  /// In en, this message translates to:
  /// **'Remind when the next dose is due'**
  String get scheduleRemindDue;

  /// No description provided for @scheduleReminderOn.
  ///
  /// In en, this message translates to:
  /// **'reminder on'**
  String get scheduleReminderOn;

  /// No description provided for @scheduleReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} reminder'**
  String scheduleReminderTitle(Object label);

  /// No description provided for @scheduleReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get scheduleReminders;

  /// types = comma-separated list such as "feed, sleep"
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{types} reminder} other{{types} reminders}}'**
  String scheduleRemindersList(num count, Object types);

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines and reminders'**
  String get scheduleTitle;

  /// No description provided for @scheduleUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get scheduleUnit;

  /// No description provided for @scheduleUpToPerDay.
  ///
  /// In en, this message translates to:
  /// **'up to {count} a day'**
  String scheduleUpToPerDay(Object count);

  /// No description provided for @scheduleWhenAfter.
  ///
  /// In en, this message translates to:
  /// **'{type, select, sleep{When awake for {duration}} diaper{When there was no diaper change for {duration}} pump{When there was no pumping for {duration}} other{When there was no feed for {duration}}}'**
  String scheduleWhenAfter(Object duration, String type);

  /// Language setting: follow the phone's or browser's language.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get settingsLanguageDevice;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @summaryBreastMilk.
  ///
  /// In en, this message translates to:
  /// **'{amount} breast milk'**
  String summaryBreastMilk(Object amount);

  /// No description provided for @summaryClose.
  ///
  /// In en, this message translates to:
  /// **'Close summary'**
  String get summaryClose;

  /// No description provided for @summaryFirsts.
  ///
  /// In en, this message translates to:
  /// **'Firsts'**
  String get summaryFirsts;

  /// No description provided for @summaryFormula.
  ///
  /// In en, this message translates to:
  /// **'{amount} formula'**
  String summaryFormula(Object amount);

  /// No description provided for @summaryHead.
  ///
  /// In en, this message translates to:
  /// **'head {value}'**
  String summaryHead(Object value);

  /// No description provided for @summaryLast24h.
  ///
  /// In en, this message translates to:
  /// **'Last 24 hours'**
  String get summaryLast24h;

  /// No description provided for @summaryLeft.
  ///
  /// In en, this message translates to:
  /// **'{duration} left'**
  String summaryLeft(Object duration);

  /// No description provided for @summaryLongest.
  ///
  /// In en, this message translates to:
  /// **'longest {duration}'**
  String summaryLongest(Object duration);

  /// No description provided for @summaryNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get summaryNotes;

  /// No description provided for @summaryNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get summaryNothing;

  /// No description provided for @summaryPotty.
  ///
  /// In en, this message translates to:
  /// **'{inPotty} in the potty · {accidents, plural, =1{1 accident} other{{accidents} accidents}}'**
  String summaryPotty(num accidents, Object inPotty);

  /// No description provided for @summaryPumping.
  ///
  /// In en, this message translates to:
  /// **'{duration} pumping'**
  String summaryPumping(Object duration);

  /// No description provided for @summaryRight.
  ///
  /// In en, this message translates to:
  /// **'{duration} right'**
  String summaryRight(Object duration);

  /// No description provided for @summaryRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get summaryRoutine;

  /// No description provided for @summaryTemperature.
  ///
  /// In en, this message translates to:
  /// **'temperature {values}'**
  String summaryTemperature(Object values);

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTitle;

  /// No description provided for @summaryTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} total'**
  String summaryTotal(Object amount);

  /// No description provided for @summaryWetDirty.
  ///
  /// In en, this message translates to:
  /// **'{wet} wet · {dirty} dirty'**
  String summaryWetDirty(Object dirty, Object wet);

  /// No description provided for @syncCantReach.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server ({server}).'**
  String syncCantReach(Object server);

  /// No description provided for @syncCantReachCheck.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server ({server}). Check the address and your connection.'**
  String syncCantReachCheck(Object server);

  /// No description provided for @syncCantReachNamedPhone.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {name}\'s phone. Both phones need to be on the same Wi-Fi, with the pairing code still showing.'**
  String syncCantReachNamedPhone(Object name);

  /// No description provided for @syncCantReachOtherPhone.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the other phone. Both phones need to be on the same Wi-Fi, with the pairing code still showing.'**
  String get syncCantReachOtherPhone;

  /// message comes from the server (English).
  ///
  /// In en, this message translates to:
  /// **'A change couldn\'t be saved: {message}'**
  String syncChangeNotSaved(Object message);

  /// No description provided for @syncConflict.
  ///
  /// In en, this message translates to:
  /// **'Something you changed was also changed on another device; the newer change was kept.'**
  String get syncConflict;

  /// No description provided for @syncDriveFolderUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The family\'s Drive folder can\'t be reached. Turn Drive sync off and on again.'**
  String get syncDriveFolderUnreachable;

  /// No description provided for @syncDriveNeedsAndroid.
  ///
  /// In en, this message translates to:
  /// **'Google Drive needs the Android app.'**
  String get syncDriveNeedsAndroid;

  /// No description provided for @syncDriveNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Google Drive access wasn\'t granted.'**
  String get syncDriveNotGranted;

  /// No description provided for @syncEntryDeleted.
  ///
  /// In en, this message translates to:
  /// **'This entry was deleted on another phone.'**
  String get syncEntryDeleted;

  /// No description provided for @syncGoogleNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in to Google.'**
  String get syncGoogleNotSignedIn;

  /// No description provided for @syncLoggedNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Something you logged couldn\'t be saved: {message}'**
  String syncLoggedNotSaved(Object message);

  /// No description provided for @syncNotPairingCode.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Nestling pairing code.'**
  String get syncNotPairingCode;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. This needs a connection to the server ({host}).'**
  String syncOffline(Object host);

  /// No description provided for @syncOfflineNotSent.
  ///
  /// In en, this message translates to:
  /// **'Changes made offline couldn\'t be sent yet: {message}'**
  String syncOfflineNotSent(Object message);

  /// No description provided for @syncOtherPhoneAnswered.
  ///
  /// In en, this message translates to:
  /// **'the other phone answered {status}'**
  String syncOtherPhoneAnswered(Object status);

  /// No description provided for @syncPairingIncomplete.
  ///
  /// In en, this message translates to:
  /// **'This pairing code is incomplete. Copy it again.'**
  String get syncPairingIncomplete;

  /// No description provided for @syncPhonesNeedAndroid.
  ///
  /// In en, this message translates to:
  /// **'Syncing phones directly needs the Android app.'**
  String get syncPhonesNeedAndroid;

  /// No description provided for @syncServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error ({status})'**
  String syncServerError(Object status);

  /// No description provided for @syncTimerRunning.
  ///
  /// In en, this message translates to:
  /// **'Someone already started this timer. It\'s shown now.'**
  String get syncTimerRunning;

  /// No description provided for @syncTimerStopped.
  ///
  /// In en, this message translates to:
  /// **'This timer was already stopped on another phone. The screen is up to date now.'**
  String get syncTimerStopped;

  /// No description provided for @syncWifiFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect this phone to Wi-Fi first.'**
  String get syncWifiFirst;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// The baby's age when the tooth came in, e.g. '7 months old'.
  ///
  /// In en, this message translates to:
  /// **'{age} old'**
  String teethAgeOld(Object age);

  /// No description provided for @teethCameIn.
  ///
  /// In en, this message translates to:
  /// **'Came in'**
  String get teethCameIn;

  /// No description provided for @teethCameInOn.
  ///
  /// In en, this message translates to:
  /// **'Came in on'**
  String get teethCameInOn;

  /// No description provided for @teethCanine.
  ///
  /// In en, this message translates to:
  /// **'canine'**
  String get teethCanine;

  /// No description provided for @teethCentralIncisor.
  ///
  /// In en, this message translates to:
  /// **'central incisor'**
  String get teethCentralIncisor;

  /// No description provided for @teethChartSemantics.
  ///
  /// In en, this message translates to:
  /// **'Teeth chart: {count} of 20 teeth in. Tap a tooth to log it.'**
  String teethChartSemantics(Object count);

  /// No description provided for @teethChartSemanticsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Teeth chart: {count} of 20 teeth in.'**
  String teethChartSemanticsReadOnly(Object count);

  /// No description provided for @teethCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of 20'**
  String teethCount(Object count);

  /// No description provided for @teethFirstHint.
  ///
  /// In en, this message translates to:
  /// **'The first one goes in the book as \"First tooth\": add a photo and the story there.'**
  String get teethFirstHint;

  /// No description provided for @teethFirstMolar.
  ///
  /// In en, this message translates to:
  /// **'first molar'**
  String get teethFirstMolar;

  /// No description provided for @teethItCameIn.
  ///
  /// In en, this message translates to:
  /// **'It came in'**
  String get teethItCameIn;

  /// No description provided for @teethLateralIncisor.
  ///
  /// In en, this message translates to:
  /// **'lateral incisor'**
  String get teethLateralIncisor;

  /// Legend: the tooth has come in.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get teethLegendIn;

  /// No description provided for @teethLegendNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get teethLegendNotYet;

  /// No description provided for @teethLower.
  ///
  /// In en, this message translates to:
  /// **'LOWER'**
  String get teethLower;

  /// No description provided for @teethLowerLeft.
  ///
  /// In en, this message translates to:
  /// **'Lower left'**
  String get teethLowerLeft;

  /// No description provided for @teethLowerRight.
  ///
  /// In en, this message translates to:
  /// **'Lower right'**
  String get teethLowerRight;

  /// A tooth's name: position (e.g. 'Upper right') and kind (e.g. 'central incisor'). The app capitalizes the first letter.
  ///
  /// In en, this message translates to:
  /// **'{position} {kind}'**
  String teethName(Object kind, Object position);

  /// No description provided for @teethNotInYet.
  ///
  /// In en, this message translates to:
  /// **'Not in yet'**
  String get teethNotInYet;

  /// No description provided for @teethSaveDate.
  ///
  /// In en, this message translates to:
  /// **'Save date'**
  String get teethSaveDate;

  /// No description provided for @teethSecondMolar.
  ///
  /// In en, this message translates to:
  /// **'second molar'**
  String get teethSecondMolar;

  /// No description provided for @teethTapChange.
  ///
  /// In en, this message translates to:
  /// **'Tap a tooth to log it or change its date.'**
  String get teethTapChange;

  /// No description provided for @teethTapFirst.
  ///
  /// In en, this message translates to:
  /// **'Tap a tooth when it comes in.'**
  String get teethTapFirst;

  /// No description provided for @teethUpper.
  ///
  /// In en, this message translates to:
  /// **'UPPER'**
  String get teethUpper;

  /// No description provided for @teethUpperLeft.
  ///
  /// In en, this message translates to:
  /// **'Upper left'**
  String get teethUpperLeft;

  /// Tooth position; combined with a tooth kind by teethName.
  ///
  /// In en, this message translates to:
  /// **'Upper right'**
  String get teethUpperRight;

  /// No description provided for @teethUsually.
  ///
  /// In en, this message translates to:
  /// **'Usually comes in at {when}'**
  String teethUsually(Object when);

  /// When a tooth usually comes in, e.g. '8–12 months'.
  ///
  /// In en, this message translates to:
  /// **'{range} months'**
  String teethWhen(Object range);

  /// No description provided for @timelineAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get timelineAll;

  /// No description provided for @timelineDiapers.
  ///
  /// In en, this message translates to:
  /// **'Diapers'**
  String get timelineDiapers;

  /// No description provided for @timelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get timelineEmpty;

  /// No description provided for @timelineFeeds.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get timelineFeeds;

  /// A note shown under an entry, in quotes.
  ///
  /// In en, this message translates to:
  /// **'“{note}”'**
  String timelineNote(Object note);

  /// No description provided for @timelineOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get timelineOther;

  /// No description provided for @timelineSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get timelineSummary;

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}’s timeline'**
  String timelineTitle(Object name);

  /// No description provided for @timerAwakeFor.
  ///
  /// In en, this message translates to:
  /// **'Awake for {duration}'**
  String timerAwakeFor(Object duration);

  /// No description provided for @timerDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing will be saved.'**
  String get timerDeleteBody;

  /// No description provided for @timerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this timer?'**
  String get timerDeleteTitle;

  /// No description provided for @timerEditSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{Edit left time} other{Edit right time}}'**
  String timerEditSide(String side);

  /// No description provided for @timerEditTotal.
  ///
  /// In en, this message translates to:
  /// **'Edit total time'**
  String get timerEditTotal;

  /// No description provided for @timerEndAfterStart.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start ({time}).'**
  String timerEndAfterStart(Object time);

  /// No description provided for @timerEndTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get timerEndTime;

  /// No description provided for @timerFellAsleep.
  ///
  /// In en, this message translates to:
  /// **'Fell asleep'**
  String get timerFellAsleep;

  /// No description provided for @timerKeepsRunning.
  ///
  /// In en, this message translates to:
  /// **'Close with ✕ and the timer keeps running.'**
  String get timerKeepsRunning;

  /// side = the side the last feed ended on; ago = e.g. "2h ago"
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{Last feed ended on the left} other{Last feed ended on the right}} · {ago}\n{side, select, left{Start on the right} other{Start on the left}}'**
  String timerLastFeedEnded(Object ago, String side);

  /// Small round badge, two short lines
  ///
  /// In en, this message translates to:
  /// **'Last\nside'**
  String get timerLastSideBadge;

  /// No description provided for @timerLeftSide.
  ///
  /// In en, this message translates to:
  /// **'Left side'**
  String get timerLeftSide;

  /// Button: log a finished session by hand instead of timing it
  ///
  /// In en, this message translates to:
  /// **'Log past'**
  String get timerLogPast;

  /// No description provided for @timerMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get timerMinutes;

  /// No description provided for @timerNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get timerNoteHint;

  /// No description provided for @timerOnSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{On the left} other{On the right}}'**
  String timerOnSide(String side);

  /// No description provided for @timerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get timerPause;

  /// No description provided for @timerPauseSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{Pause left} other{Pause right}}'**
  String timerPauseSide(String side);

  /// No description provided for @timerPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get timerPaused;

  /// No description provided for @timerPumpHowMuch.
  ///
  /// In en, this message translates to:
  /// **'How much did you pump?'**
  String get timerPumpHowMuch;

  /// No description provided for @timerPumping.
  ///
  /// In en, this message translates to:
  /// **'Pumping'**
  String get timerPumping;

  /// No description provided for @timerResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get timerResume;

  /// No description provided for @timerResumeSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{Resume left} other{Resume right}}'**
  String timerResumeSide(String side);

  /// No description provided for @timerRightSide.
  ///
  /// In en, this message translates to:
  /// **'Right side'**
  String get timerRightSide;

  /// Snackbar after saving a timer; what = Breastfeed / Sleep / Pump
  ///
  /// In en, this message translates to:
  /// **'{what} saved'**
  String timerSaved(Object what);

  /// No description provided for @timerSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get timerSeconds;

  /// No description provided for @timerSleeping.
  ///
  /// In en, this message translates to:
  /// **'Sleeping'**
  String get timerSleeping;

  /// No description provided for @timerStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timerStart;

  /// No description provided for @timerStartInFuture.
  ///
  /// In en, this message translates to:
  /// **'The start can\'t be in the future.'**
  String get timerStartInFuture;

  /// No description provided for @timerStartSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{Start left} other{Start right}}'**
  String timerStartSide(String side);

  /// No description provided for @timerStartSideLast.
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{Start left (last side)} other{Start right (last side)}}'**
  String timerStartSideLast(String side);

  /// No description provided for @timerStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get timerStartTime;

  /// No description provided for @timerSwitchSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, left{Switch to left} other{Switch to right}}'**
  String timerSwitchSide(String side);

  /// No description provided for @timerTapSide.
  ///
  /// In en, this message translates to:
  /// **'Tap a side to start'**
  String get timerTapSide;

  /// No description provided for @timerTapStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get timerTapStart;

  /// No description provided for @timerTimeAsleep.
  ///
  /// In en, this message translates to:
  /// **'Time asleep'**
  String get timerTimeAsleep;

  /// No description provided for @timerTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get timerTotalTime;

  /// No description provided for @timerTotalTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get timerTotalTimeTitle;

  /// No description provided for @timerWokeUp.
  ///
  /// In en, this message translates to:
  /// **'Woke up'**
  String get timerWokeUp;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @trendsAccidents.
  ///
  /// In en, this message translates to:
  /// **'Accidents'**
  String get trendsAccidents;

  /// No description provided for @trendsAmountPumped.
  ///
  /// In en, this message translates to:
  /// **'Amount pumped'**
  String get trendsAmountPumped;

  /// No description provided for @trendsAverage.
  ///
  /// In en, this message translates to:
  /// **'average'**
  String get trendsAverage;

  /// No description provided for @trendsBottleSize.
  ///
  /// In en, this message translates to:
  /// **'Bottle size'**
  String get trendsBottleSize;

  /// No description provided for @trendsBottleUnit.
  ///
  /// In en, this message translates to:
  /// **'Bottle ({unit})'**
  String trendsBottleUnit(Object unit);

  /// No description provided for @trendsBreastfeedLength.
  ///
  /// In en, this message translates to:
  /// **'Breastfeed length'**
  String get trendsBreastfeedLength;

  /// No description provided for @trendsBreastfeeding.
  ///
  /// In en, this message translates to:
  /// **'Breastfeeding'**
  String get trendsBreastfeeding;

  /// No description provided for @trendsCompareArrows.
  ///
  /// In en, this message translates to:
  /// **'Arrows compare with the {count} days before.'**
  String trendsCompareArrows(Object count);

  /// No description provided for @trendsCompareNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged in the {count} days before to compare with.'**
  String trendsCompareNone(Object count);

  /// No description provided for @trendsDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get trendsDay;

  /// No description provided for @trendsDayBreastfeeding.
  ///
  /// In en, this message translates to:
  /// **'Daytime breastfeeding'**
  String get trendsDayBreastfeeding;

  /// No description provided for @trendsDayDiapers.
  ///
  /// In en, this message translates to:
  /// **'Daytime diapers'**
  String get trendsDayDiapers;

  /// No description provided for @trendsDaySleep.
  ///
  /// In en, this message translates to:
  /// **'Daytime sleep'**
  String get trendsDaySleep;

  /// No description provided for @trendsDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String trendsDays(Object count);

  /// No description provided for @trendsDiapers.
  ///
  /// In en, this message translates to:
  /// **'Diapers'**
  String get trendsDiapers;

  /// No description provided for @trendsFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get trendsFeed;

  /// No description provided for @trendsFeedInterval.
  ///
  /// In en, this message translates to:
  /// **'Time between feeds'**
  String get trendsFeedInterval;

  /// No description provided for @trendsFeeds.
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get trendsFeeds;

  /// No description provided for @trendsGrowthChartsSub.
  ///
  /// In en, this message translates to:
  /// **'Weight, length and head size on the WHO percentile curves'**
  String get trendsGrowthChartsSub;

  /// start and end are times like 06:00 (when daytime starts and ends).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Daily averages over 1 full day; daytime is {start}–{end}.} other{Daily averages over {days} full days; daytime is {start}–{end}.}}'**
  String trendsIntro(num days, Object end, Object start);

  /// No description provided for @trendsLongestSleep.
  ///
  /// In en, this message translates to:
  /// **'Longest sleep'**
  String get trendsLongestSleep;

  /// No description provided for @trendsNapLength.
  ///
  /// In en, this message translates to:
  /// **'Nap length'**
  String get trendsNapLength;

  /// No description provided for @trendsNaps.
  ///
  /// In en, this message translates to:
  /// **'Naps'**
  String get trendsNaps;

  /// No description provided for @trendsNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get trendsNight;

  /// No description provided for @trendsNightBreastfeeding.
  ///
  /// In en, this message translates to:
  /// **'Nighttime breastfeeding'**
  String get trendsNightBreastfeeding;

  /// No description provided for @trendsNightDiapers.
  ///
  /// In en, this message translates to:
  /// **'Nighttime diapers'**
  String get trendsNightDiapers;

  /// No description provided for @trendsNightSleep.
  ///
  /// In en, this message translates to:
  /// **'Nighttime sleep'**
  String get trendsNightSleep;

  /// No description provided for @trendsPerDay.
  ///
  /// In en, this message translates to:
  /// **'per day'**
  String get trendsPerDay;

  /// No description provided for @trendsPottyTrips.
  ///
  /// In en, this message translates to:
  /// **'Potty trips'**
  String get trendsPottyTrips;

  /// No description provided for @trendsPumpSessions.
  ///
  /// In en, this message translates to:
  /// **'Pump sessions'**
  String get trendsPumpSessions;

  /// No description provided for @trendsPumpTime.
  ///
  /// In en, this message translates to:
  /// **'Pump time'**
  String get trendsPumpTime;

  /// No description provided for @trendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trendsTitle;

  /// No description provided for @trendsWakeWindow.
  ///
  /// In en, this message translates to:
  /// **'Wake window'**
  String get trendsWakeWindow;

  /// No description provided for @trendsWetOnly.
  ///
  /// In en, this message translates to:
  /// **'Wet only'**
  String get trendsWetOnly;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @usersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get usersAdd;

  /// No description provided for @usersAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a user'**
  String get usersAddTitle;

  /// No description provided for @usersAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to {family}'**
  String usersAddTo(Object family);

  /// No description provided for @usersAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get usersAdmin;

  /// No description provided for @usersAdminHint.
  ///
  /// In en, this message translates to:
  /// **'Can manage users'**
  String get usersAdminHint;

  /// No description provided for @usersAdminTag.
  ///
  /// In en, this message translates to:
  /// **'admin'**
  String get usersAdminTag;

  /// No description provided for @usersAsCaregiver.
  ///
  /// In en, this message translates to:
  /// **'As a caregiver'**
  String get usersAsCaregiver;

  /// No description provided for @usersCanChangeLater.
  ///
  /// In en, this message translates to:
  /// **'They can change it later'**
  String get usersCanChangeLater;

  /// No description provided for @usersCanSignIn.
  ///
  /// In en, this message translates to:
  /// **'{name} can now sign in'**
  String usersCanSignIn(Object name);

  /// No description provided for @usersEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get usersEmail;

  /// No description provided for @usersEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an email'**
  String get usersEnterEmail;

  /// No description provided for @usersEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get usersEnterName;

  /// No description provided for @usersIntro.
  ///
  /// In en, this message translates to:
  /// **'Only admins can create accounts on this server. Give people their email and password; they can change the password under Settings → Account.'**
  String get usersIntro;

  /// No description provided for @usersMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get usersMakeAdmin;

  /// No description provided for @usersManage.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String usersManage(Object name);

  /// No description provided for @usersNewPasswordFor.
  ///
  /// In en, this message translates to:
  /// **'New password for {name}'**
  String usersNewPasswordFor(Object name);

  /// No description provided for @usersNoLongerAdmin.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer an admin'**
  String usersNoLongerAdmin(Object name);

  /// No description provided for @usersNowAdmin.
  ///
  /// In en, this message translates to:
  /// **'{name} is now an admin'**
  String usersNowAdmin(Object name);

  /// No description provided for @usersPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get usersPassword;

  /// No description provided for @usersPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters. They\'ll be signed out.'**
  String get usersPasswordHelp;

  /// No description provided for @usersPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'New password set for {name}'**
  String usersPasswordSet(Object name);

  /// No description provided for @usersRemoveAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get usersRemoveAccount;

  /// No description provided for @usersRemoveAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove admin'**
  String get usersRemoveAdmin;

  /// No description provided for @usersRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'They can no longer sign in. Their families and everything logged stay.'**
  String get usersRemoveBody;

  /// No description provided for @usersRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String usersRemoveTitle(Object name);

  /// No description provided for @usersRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String usersRemoved(Object name);

  /// No description provided for @usersSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get usersSetPassword;

  /// No description provided for @usersTitle.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get usersTitle;

  /// No description provided for @wet.
  ///
  /// In en, this message translates to:
  /// **'Wet'**
  String get wet;

  /// No description provided for @wetAndDirty.
  ///
  /// In en, this message translates to:
  /// **'Wet + dirty'**
  String get wetAndDirty;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
