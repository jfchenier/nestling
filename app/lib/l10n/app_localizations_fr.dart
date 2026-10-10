// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get activityBath => 'Bain';

  @override
  String get activityMassage => 'Massage';

  @override
  String get activityMusic => 'Musique';

  @override
  String get activityNailTrim => 'Coupe des ongles';

  @override
  String get activityOutdoor => 'Dehors';

  @override
  String get activityPlay => 'Jeu';

  @override
  String get activityRead => 'Lecture';

  @override
  String get activitySkinToSkin => 'Peau à peau';

  @override
  String get activitySwim => 'Baignade';

  @override
  String get activityTummyTime => 'Temps sur le ventre';

  @override
  String get activityVitamin => 'Vitamine';

  @override
  String get add => 'Ajouter';

  @override
  String ageDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
      zero: '0 jour',
    );
    return '$_temp0';
  }

  @override
  String ageDueIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return 'Naissance prévue dans $_temp0';
  }

  @override
  String ageMonths(num count) {
    return '$count mois';
  }

  @override
  String agePair(Object big, Object small) {
    return '$big et $small';
  }

  @override
  String ageWeeks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '1 semaine',
    );
    return '$_temp0';
  }

  @override
  String ageYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String agoDuration(Object duration) {
    return 'il y a $duration';
  }

  @override
  String get blowout => 'débordement';

  @override
  String get bookAddMemory => 'Ajouter un souvenir';

  @override
  String get bookAddPhoto => 'Ajouter une photo';

  @override
  String bookAgeOld(Object age) {
    return 'à $age';
  }

  @override
  String bookAsYouLookAt(Object name) {
    return 'face à $name';
  }

  @override
  String bookBananaIntro(Object name) {
    return 'La même banane à côté de $name chaque mois : le meilleur moyen de voir le temps filer.';
  }

  @override
  String get bookBananaName => 'Une banane pour comparer';

  @override
  String get bookBeforeBirth => 'Avant la naissance';

  @override
  String bookBorn(Object date) {
    return 'Naissance : $date';
  }

  @override
  String get bookChangePhoto => 'Changer';

  @override
  String get bookChapter => 'Chapitre';

  @override
  String get bookChapterCelebrations => 'Fêtes';

  @override
  String get bookChapterFirsts => 'Premières fois';

  @override
  String get bookChapterGrowing => 'Grandir';

  @override
  String get bookChapterHello => 'Bonjour, le monde';

  @override
  String bookChapterNumber(Object number) {
    return 'CHAPITRE $number';
  }

  @override
  String get bookChapterSubCelebrations => 'Fêtes et jours spéciaux';

  @override
  String get bookChapterSubFirsts => 'Chaque nouveauté, mois après mois';

  @override
  String get bookChapterSubGrowing =>
      'Les dents, la taille, et le temps qui file';

  @override
  String get bookChapterSubHello => 'Tout au début';

  @override
  String get bookChapterSubWaiting => 'Avant ton arrivée';

  @override
  String get bookChapterWaiting => 'En t\'attendant';

  @override
  String get bookDaysBeforeBirth => 'quelques jours avant la naissance';

  @override
  String get bookDeleteBody =>
      'Il sera supprimé pour toute la famille, avec sa photo.';

  @override
  String get bookDeleteTitle => 'Supprimer ce souvenir ?';

  @override
  String get bookDueDate => 'Date prévue';

  @override
  String bookDueOn(Object date) {
    return 'Prévu le $date';
  }

  @override
  String get bookEditMemory => 'Modifier le souvenir';

  @override
  String get bookEmptyBody =>
      'Choisissez une idée ci-dessous ou ajoutez la vôtre : une photo, le jour et quelques mots.';

  @override
  String get bookEmptyReadOnly =>
      'Les souvenirs s\'affichent ici à mesure que la famille les ajoute.';

  @override
  String get bookEmptyTitle => 'La première page attend';

  @override
  String get bookIdeaBabyShower => 'Baby shower';

  @override
  String get bookIdeaBaptism => 'Baptême ou fête de bienvenue';

  @override
  String get bookIdeaBassinet => 'Trop grand pour le berceau';

  @override
  String get bookIdeaBelly => 'Le ventre rond';

  @override
  String get bookIdeaBirthday => 'Premier anniversaire';

  @override
  String get bookIdeaBoyOrGirl => 'Fille ou garçon ?';

  @override
  String get bookIdeaCameHome => 'Arrivée à la maison';

  @override
  String get bookIdeaCarSeat => 'Siège d\'auto face à la route';

  @override
  String get bookIdeaChristmas => 'Premier Noël';

  @override
  String get bookIdeaClapped => 'Tape des mains';

  @override
  String get bookIdeaClothesSize => 'Taille de vêtements suivante';

  @override
  String get bookIdeaCooed => 'Premiers gazouillis';

  @override
  String get bookIdeaCrawled => 'Marche à quatre pattes';

  @override
  String get bookIdeaCup => 'Boit au verre';

  @override
  String get bookIdeaDada => 'Dit « papa »';

  @override
  String get bookIdeaDaycare => 'Premier jour à la garderie';

  @override
  String get bookIdeaDiaperSize => 'Taille de couche suivante';

  @override
  String get bookIdeaEaster => 'Premières Pâques';

  @override
  String get bookIdeaFathersDay => 'Première fête des Pères';

  @override
  String get bookIdeaFirstBath => 'Premier bain';

  @override
  String get bookIdeaFirstBottle => 'Premier biberon';

  @override
  String get bookIdeaFirstDance => 'Première danse';

  @override
  String get bookIdeaFirstLaugh => 'Premier rire';

  @override
  String get bookIdeaFirstShoes => 'Premières chaussures';

  @override
  String get bookIdeaFirstSmile => 'Premier sourire';

  @override
  String get bookIdeaFirstSolid => 'Premier repas solide';

  @override
  String get bookIdeaFirstSteps => 'Premiers pas';

  @override
  String get bookIdeaFirstTooth => 'Première dent';

  @override
  String get bookIdeaFirstWalk => 'Première promenade';

  @override
  String get bookIdeaFirstWord => 'Premier mot';

  @override
  String get bookIdeaFoundHands => 'Découvre ses mains';

  @override
  String get bookIdeaFoundOut => 'La grande nouvelle';

  @override
  String get bookIdeaFoundToes => 'Découvre ses pieds';

  @override
  String get bookIdeaGrandparents => 'Rencontre avec les grands-parents';

  @override
  String get bookIdeaHaircut => 'Première coupe de cheveux';

  @override
  String get bookIdeaHalloween => 'Premier Halloween';

  @override
  String get bookIdeaHeartbeat => 'Les battements du cœur';

  @override
  String get bookIdeaHeldHead => 'Tient sa tête';

  @override
  String get bookIdeaKiss => 'Fait un bisou';

  @override
  String get bookIdeaMama => 'Dit « maman »';

  @override
  String get bookIdeaMothersDay => 'Première fête des Mères';

  @override
  String get bookIdeaOwnBottle => 'Tient son biberon';

  @override
  String get bookIdeaOwnName => 'Reconnaît son prénom';

  @override
  String get bookIdeaOwnRoom => 'Sa propre chambre';

  @override
  String get bookIdeaPulledStand => 'Se met debout';

  @override
  String get bookIdeaReachedToy => 'Attrape un jouet';

  @override
  String get bookIdeaRolledOver => 'Se retourne';

  @override
  String get bookIdeaSatUp => 'S\'assoit sans aide';

  @override
  String get bookIdeaSleptNight => 'Fait ses nuits';

  @override
  String get bookIdeaSnow => 'Première neige';

  @override
  String get bookIdeaSounds => 'Se tourne vers les sons';

  @override
  String get bookIdeaSpoon => 'Mange à la cuillère';

  @override
  String get bookIdeaStoodAlone => 'Debout sans appui';

  @override
  String get bookIdeaSwim => 'Première baignade';

  @override
  String get bookIdeaTrip => 'Premier voyage';

  @override
  String get bookIdeaUltrasound => 'Première échographie';

  @override
  String get bookIdeaWaved => 'Fait bye-bye';

  @override
  String get bookIdeasForChapter => 'Idées pour ce chapitre';

  @override
  String bookIdeasProgress(Object done, Object total) {
    return '$done sur $total dans le livre. Touchez-en une pour l\'ajouter.';
  }

  @override
  String get bookIdeasToRemember => 'Idées de souvenirs';

  @override
  String bookMemoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count souvenirs',
      one: '1 souvenir',
    );
    return '$_temp0';
  }

  @override
  String get bookNameHint => 'Premier sourire, se retourne…';

  @override
  String get bookNameNeeded =>
      'Que s\'est-il passé ? Donnez un nom au souvenir.';

  @override
  String get bookNewMemory => 'Nouveau souvenir';

  @override
  String get bookNewborn => 'Nouveau-né';

  @override
  String bookNoBabyYet(Object family) {
    return 'L\'album de bébé s\'affichera ici dès que $family ajoutera un bébé.';
  }

  @override
  String get bookNoMemories => 'Aucun souvenir pour l\'instant';

  @override
  String get bookPhotoAMonth => 'une photo par mois';

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
    return 'Le souvenir est enregistré, mais pas sa photo : $error';
  }

  @override
  String bookPhotoOf(Object name) {
    return 'Photo : $name';
  }

  @override
  String get bookPreparingPhoto => 'Préparation de la photo…';

  @override
  String get bookSaveToBook => 'Ajouter au livre';

  @override
  String get bookSaving => 'Enregistrement…';

  @override
  String get bookSeeAll => 'Tout voir';

  @override
  String get bookSetDueDate => 'Indiquer la date prévue';

  @override
  String get bookStory => 'L\'histoire';

  @override
  String get bookStoryHint =>
      'Où vous étiez, qui était là, ce que vous avez ressenti…';

  @override
  String get bookTabCelebrations => 'Fêtes';

  @override
  String get bookTabFirsts => 'Premières';

  @override
  String get bookTabGrowing => 'Grandir';

  @override
  String get bookTabHello => 'Bonjour';

  @override
  String get bookTabWaiting => 'Attente';

  @override
  String get bookTakeFirst => 'Prendre la première';

  @override
  String get bookTeeth => 'Dents';

  @override
  String get bookTheBookOf => 'Le livre de';

  @override
  String get bookTheFamily => 'la famille';

  @override
  String get bookThisMonth => 'Celle du mois';

  @override
  String bookTitle(Object name) {
    return 'Le livre de $name';
  }

  @override
  String bookWeeksAlong(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines de grossesse',
      one: '1 semaine de grossesse',
    );
    return '$_temp0';
  }

  @override
  String bookWeeksBeforeBirth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines avant la naissance',
      one: '1 semaine avant la naissance',
    );
    return '$_temp0';
  }

  @override
  String get bookWhatHappened => 'Que s\'est-il passé ?';

  @override
  String bookWhenAfterYears(Object count) {
    return 'après $count ans';
  }

  @override
  String get bookWhenAnyTime => 'n\'importe quand';

  @override
  String get bookWhenAnythingSpecial => 'un moment spécial';

  @override
  String bookWhenAroundMonths(Object count) {
    return 'vers $count mois';
  }

  @override
  String bookWhenAroundWeeks(Object count) {
    return 'vers $count semaines';
  }

  @override
  String bookWhenAroundWeeksRange(Object from, Object to) {
    return 'vers $from–$to semaines';
  }

  @override
  String get bookWhenFirstDays => 'premiers jours';

  @override
  String get bookWhenFirstWeeks => 'premières semaines';

  @override
  String get bookWhenLastWeeks => 'dernières semaines';

  @override
  String bookWhenMonthsRange(Object from, Object to) {
    return '$from–$to mois';
  }

  @override
  String get bookWhenNowAndThen => 'de temps en temps';

  @override
  String get bookWhenSpring => 'printemps';

  @override
  String get bookWhenTest => 'le test';

  @override
  String bookWhenWeeksRange(Object from, Object to) {
    return '$from–$to semaines';
  }

  @override
  String get bookWhenWithFirstSteps => 'aux premiers pas';

  @override
  String get bookWhichTooth => 'Quelle dent ?';

  @override
  String get bookYourOwn => 'Votre idée';

  @override
  String get both => 'Les deux';

  @override
  String get breastfeedPlusBottle => 'Allaitement + biberon';

  @override
  String get calendarDiapers => 'Couches';

  @override
  String get calendarFeeds => 'Repas';

  @override
  String get calendarNextWeek => 'Semaine suivante';

  @override
  String get calendarOther => 'Autres';

  @override
  String get calendarPrevWeek => 'Semaine précédente';

  @override
  String get calendarTitle => 'Calendrier';

  @override
  String get cancel => 'Annuler';

  @override
  String get childAddPhoto => 'Ajouter une photo';

  @override
  String get childBirthDate => 'Date de naissance (ou prévue)';

  @override
  String get childBirthDateMissing =>
      'Choisir une date de naissance (ou prévue)';

  @override
  String get childBirthDateRequired => 'Date de naissance (ou prévue) *';

  @override
  String get childBoy => 'Garçon';

  @override
  String get childChangePhoto => 'Changer la photo';

  @override
  String get childChoosePhoto => 'Choisir une photo';

  @override
  String get childDelete => 'Supprimer le bébé';

  @override
  String childDeleteBody(Object name) {
    return 'Cela supprime définitivement $name et tout ce qui a été noté pour ce bébé, pour tous les membres. C\'est irréversible.';
  }

  @override
  String childDeleteTitle(Object name) {
    return 'Supprimer $name ?';
  }

  @override
  String childEditTitle(Object name) {
    return 'Modifier $name';
  }

  @override
  String get childEnterName => 'Saisir un nom';

  @override
  String get childGirl => 'Fille';

  @override
  String get childName => 'Prénom';

  @override
  String get childSexUnknown => 'Inconnu';

  @override
  String get childTapToChoose => 'Toucher pour choisir';

  @override
  String get close => 'Fermer';

  @override
  String get colorBlack => 'Noir';

  @override
  String get colorBrown => 'Brun';

  @override
  String get colorGray => 'Gris';

  @override
  String get colorGreen => 'Vert';

  @override
  String get colorRed => 'Rouge';

  @override
  String get colorYellow => 'Jaune';

  @override
  String commonChangeDay(Object day) {
    return 'Changer le jour, $day';
  }

  @override
  String commonChangeTime(Object time) {
    return 'Changer l\'heure, $time';
  }

  @override
  String commonSomethingWrong(Object error) {
    return 'Une erreur est survenue : $error';
  }

  @override
  String commonTypeToConfirm(Object text) {
    return 'Taper $text pour confirmer.';
  }

  @override
  String get consistencyMucousy => 'Glaireuse';

  @override
  String get consistencyMushy => 'Molle';

  @override
  String get consistencyPebbles => 'En billes';

  @override
  String get consistencyRunny => 'Liquide';

  @override
  String get consistencySolid => 'Dure';

  @override
  String get dayHoursDayStarts => 'Début du jour';

  @override
  String get dayHoursDaytime => 'Jour';

  @override
  String get dayHoursIntro =>
      'Ces heures déterminent si un repas, une couche ou un sommeil compte comme de jour ou de nuit dans Tendances. Un sommeil qui commence le jour est une sieste. Elles s\'appliquent à toute la famille.';

  @override
  String get dayHoursNightStarts => 'Début de la nuit';

  @override
  String get dayHoursStartBeforeEnd => 'Le jour doit commencer avant de finir.';

  @override
  String daysAgo(Object count) {
    return 'il y a $count jours';
  }

  @override
  String get defaultBabyName => 'Bébé';

  @override
  String get delete => 'Supprimer';

  @override
  String get dirty => 'Selles';

  @override
  String get done => 'Terminé';

  @override
  String get dry => 'Sèche';

  @override
  String durDaysHours(Object days, Object hours) {
    return '$days j $hours h';
  }

  @override
  String durHoursMinutes(Object hours, Object minutes) {
    return '$hours h $minutes';
  }

  @override
  String durMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String durMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String durSeconds(Object seconds) {
    return '$seconds s';
  }

  @override
  String get durUnderMinute => '<1 min';

  @override
  String get edit => 'Modifier';

  @override
  String endedSide(Object side) {
    return 'fini $side';
  }

  @override
  String get familyAccount => 'Compte';

  @override
  String get familyAddBaby => 'Ajouter un bébé';

  @override
  String get familyAndroidOnly => 'Disponible dans l\'app Android';

  @override
  String get familyApiToken => 'Jeton d\'API';

  @override
  String get familyApiTokenHint => 'Pour Home Assistant ou des scripts';

  @override
  String get familyAppearance => 'Apparence';

  @override
  String get familyAtLeast8 => 'Au moins 8 caractères';

  @override
  String get familyBabies => 'Bébés';

  @override
  String get familyBackedUp => 'Sauvegardé sur Google Drive';

  @override
  String get familyBackupDrive => 'Sauvegarder sur Google Drive';

  @override
  String get familyBackupHint =>
      'Garde une copie dans votre compte Google, une fois par jour';

  @override
  String get familyBookOnlyHint =>
      'Vous pouvez voir l\'album de bébé. Demandez plus d\'accès à un propriétaire de la famille.';

  @override
  String familyBorn(Object date) {
    return 'né(e) le $date';
  }

  @override
  String familyCaregiverCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get familyCaregivers => 'Membres de la famille';

  @override
  String get familyChangePassword => 'Changer le mot de passe';

  @override
  String get familyChooseAnotherFile => 'Choisir un autre fichier';

  @override
  String get familyChooseCsv => 'Choisir le fichier CSV';

  @override
  String get familyCodeCopied => 'Code copié';

  @override
  String get familyContinue => 'Continuer';

  @override
  String get familyCopy => 'Copier';

  @override
  String get familyCurrentPassword => 'Mot de passe actuel';

  @override
  String get familyDayNight => 'Jour et nuit';

  @override
  String familyDaytime(Object end, Object start) {
    return 'Jour $start–$end';
  }

  @override
  String get familyDelete => 'Supprimer la famille';

  @override
  String get familyDeleteBody =>
      'Cela supprime définitivement la famille, ses bébés et tout ce qui a été noté, pour tous les membres. C\'est irréversible.';

  @override
  String familyDeleteTitle(Object name) {
    return 'Supprimer $name ?';
  }

  @override
  String familyDriveOn(Object account) {
    return 'Activé · $account';
  }

  @override
  String get familyDriveSync => 'Synchroniser via Google Drive';

  @override
  String get familyDriveSyncBody =>
      'Vos téléphones se laissent leurs modifications dans un dossier partagé sur Google Drive, pour se mettre à jour même s\'ils ne sont pas ouverts en même temps ni sur le même Wi-Fi.\n\nGoogle demandera d\'autoriser Nestling à utiliser votre Drive. Tout le contenu du dossier est chiffré : seuls les téléphones de votre famille peuvent le lire. Activez-le sur chaque téléphone.';

  @override
  String get familyDriveSyncFailed =>
      'La dernière synchro a échoué. Nouvel essai bientôt.';

  @override
  String get familyDriveSyncHint =>
      'Pour les téléphones qui ne sont pas ouverts en même temps ni sur le même Wi-Fi';

  @override
  String get familyDriveSyncOn => 'La synchro Drive est activée';

  @override
  String get familyEnterCurrentPassword => 'Saisir votre mot de passe actuel';

  @override
  String get familyExport => 'Exporter les données';

  @override
  String get familyExportHint => 'Tout pour cette famille dans un fichier CSV';

  @override
  String familyExported(Object name) {
    return '$name exporté';
  }

  @override
  String get familyImperialUnits => 'Unités impériales';

  @override
  String get familyImportAccount => 'Compte Nara';

  @override
  String familyImportAccountBody(Object name) {
    return 'Connectez-vous à votre compte Nara pour copier votre historique dans le profil de $name. Votre mot de passe Nara sert une seule fois et n\'est jamais conservé.';
  }

  @override
  String get familyImportComplete => 'Importation terminée';

  @override
  String familyImportCsvBody(Object name) {
    return 'Exportez vos données depuis l\'app Nara (vous obtenez un fichier .csv), puis choisissez ce fichier ici. Tout va dans le profil de $name ; réimporter le même fichier met à jour sans créer de doublons.';
  }

  @override
  String get familyImportExportFile => 'Fichier d\'export';

  @override
  String get familyImportNara => 'Importer depuis Nara';

  @override
  String get familyImportNaraHint => 'Récupérer votre historique Nara Baby';

  @override
  String familyImportRecords(num count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importer $count entrées pour $name',
      one: 'Importer 1 entrée pour $name',
    );
    return '$_temp0';
  }

  @override
  String familyImportedUpdated(Object imported, Object updated) {
    return '$imported nouvelles · $updated mises à jour';
  }

  @override
  String get familyInviteBody =>
      'La personne crée un compte sur ce serveur, puis saisit ce code sous « Rejoindre une famille ». Il ne sert qu\'une fois et expire dans 7 jours.';

  @override
  String get familyInviteBookOnly =>
      'Cette personne verra seulement l\'album de bébé.';

  @override
  String get familyInviteCaregiver => 'Inviter un membre';

  @override
  String get familyInviteCode => 'Code d\'invitation';

  @override
  String get familyInviteHint => 'Partenaire, grand-parent, nounou…';

  @override
  String get familyJoin => 'Rejoindre une famille';

  @override
  String get familyJoinAnother => 'Rejoindre une autre famille';

  @override
  String get familyJoinAnotherHint =>
      'Avec un code d\'invitation de son propriétaire';

  @override
  String get familyJoinButton => 'Rejoindre';

  @override
  String familyLastBackup(Object account, Object date) {
    return 'Dernière sauvegarde $date · $account';
  }

  @override
  String familyLeave(Object family) {
    return 'Quitter $family';
  }

  @override
  String get familyLeaveAction => 'Quitter';

  @override
  String get familyLeaveBody =>
      'Vous ne verrez plus son album de bébé, sauf si on vous invite de nouveau.';

  @override
  String familyLeaveTitle(Object family) {
    return 'Quitter $family ?';
  }

  @override
  String get familyMedicines => 'Médicaments et rappels';

  @override
  String get familyName => 'Nom';

  @override
  String get familyNaraEmail => 'Courriel Nara';

  @override
  String get familyNaraPassword => 'Mot de passe Nara';

  @override
  String familyNaraProfile(Object name) {
    return 'Profil Nara : $name';
  }

  @override
  String get familyNewPassword => 'Nouveau mot de passe';

  @override
  String get familyNewToken => 'Nouveau jeton d\'API';

  @override
  String get familyNext => 'Suivant';

  @override
  String get familyOtherDevicesSignedOut =>
      'Les autres appareils seront déconnectés';

  @override
  String get familyPairPhone => 'Associer un téléphone';

  @override
  String get familyPairPhoneHint =>
      'Le téléphone de votre partenaire se synchronise avec celui-ci par Wi-Fi';

  @override
  String get familyPasswordChanged => 'Mot de passe changé';

  @override
  String familyPendingLost(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modifications faites hors ligne n\'ont pas encore atteint le serveur et seront perdues.',
      one:
          '1 modification faite hors ligne n\'a pas encore atteint le serveur et sera perdue.',
    );
    return '$_temp0';
  }

  @override
  String get familyPreview => 'Aperçu (rien n\'est enregistré)';

  @override
  String get familyPreviewAgain => 'Nouvel aperçu';

  @override
  String get familyReadyToImport => 'Prêt à importer';

  @override
  String familyRecords(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      one: '1 entrée',
    );
    return '$_temp0';
  }

  @override
  String get familyRemoveDataBody =>
      'Tout ce qui a été noté ici est effacé de ce téléphone. Les téléphones associés et votre sauvegarde Google Drive gardent leur copie.';

  @override
  String get familyRemoveDataTitle =>
      'Retirer les données de Nestling de ce téléphone ?';

  @override
  String get familyRemoveFromPhone => 'Retirer de ce téléphone';

  @override
  String familyRemoveMemberBody(Object family) {
    return 'Cette personne n\'aura plus accès à $family.';
  }

  @override
  String familyRemoveMemberTitle(Object name) {
    return 'Retirer $name ?';
  }

  @override
  String get familyServer => 'Serveur';

  @override
  String familyServerValue(Object server) {
    return 'Serveur : $server';
  }

  @override
  String get familySettings => 'Réglages';

  @override
  String get familySignOutAnyway => 'Se déconnecter quand même ?';

  @override
  String familySkipped(Object list) {
    return 'Ignorés : $list';
  }

  @override
  String familySummarySensor(Object url) {
    return 'Capteur de résumé : $url';
  }

  @override
  String familySyncedAgo(Object ago) {
    return 'Synchronisé $ago';
  }

  @override
  String familySyncedAgoAccount(Object account, Object ago) {
    return 'Synchronisé $ago · $account';
  }

  @override
  String get familyThemeDark => 'Sombre';

  @override
  String get familyThemeLight => 'Clair';

  @override
  String get familyThisBaby => 'ce bébé';

  @override
  String get familyTimeZone => 'Fuseau horaire';

  @override
  String get familyTimeZoneHint =>
      'Définit le début de chaque jour pour les totaux';

  @override
  String get familyTitle => 'Famille';

  @override
  String get familyTokenBody =>
      'Copiez-le maintenant : il ne sera plus affiché. Utilisez-le ainsi : « Authorization: Bearer <token> ».';

  @override
  String get familyTypeDiapers => 'Couches';

  @override
  String get familyTypeFeeds => 'Repas';

  @override
  String get familyTypeFirsts => 'Premières fois';

  @override
  String get familyTypeGrowth => 'Croissance';

  @override
  String get familyTypeHealth => 'Santé';

  @override
  String get familyTypeNotes => 'Notes';

  @override
  String get familyTypePump => 'Tire-lait';

  @override
  String get familyTypeRoutine => 'Routine';

  @override
  String get familyTypeSleep => 'Sommeil';

  @override
  String get familyUsersHint => 'Créer et gérer les comptes de ce serveur';

  @override
  String get familyWithoutServer => 'Sans serveur';

  @override
  String get familyWithoutServerHint =>
      'Enregistré sur ce téléphone et ceux associés';

  @override
  String familyYou(Object name) {
    return '$name (vous)';
  }

  @override
  String get formAddNote => 'Ajouter une note…';

  @override
  String get formAmount => 'Quantité';

  @override
  String get formBlowout => 'Débordement';

  @override
  String get formBrandOptional => 'Marque (facultatif)';

  @override
  String get formChoose => 'Choisir';

  @override
  String get formContinue => 'Reprendre';

  @override
  String get formDeleteMessage => 'Elle sera supprimée pour toute la famille.';

  @override
  String get formDeleteTitle => 'Supprimer cette entrée ?';

  @override
  String get formDiaperRash => 'Érythème fessier';

  @override
  String get formDiaperWetDirtyDry =>
      'La couche : urine, selles, mixte ou sèche ?';

  @override
  String get formDoctor => 'Médecin';

  @override
  String get formDose => 'Dose';

  @override
  String get formDuration => 'Durée';

  @override
  String formEditTitle(Object what) {
    return 'Modifier : $what';
  }

  @override
  String get formFellAsleep => 'Endormi';

  @override
  String get formFoods => 'Aliments';

  @override
  String get formFormulaName => 'Préparation';

  @override
  String get formHeadSize => 'Tour de tête';

  @override
  String get formHeight => 'Taille';

  @override
  String get formMeasured => 'Mesuré le';

  @override
  String formMedLimited(Object count, Object time) {
    return 'Déjà $count doses en 24 heures. Prochaine permise à $time.';
  }

  @override
  String formMedTooSoon(Object last, Object time) {
    return 'Dernière dose à $last. Prochaine permise à $time.';
  }

  @override
  String get formMilk => 'Lait';

  @override
  String get formNotes => 'Notes';

  @override
  String get formPottyWetOrDirty => 'Urine, selles ou mixte ?';

  @override
  String get formSaveChanges => 'Enregistrer';

  @override
  String get formSleepEndMissing =>
      'Quand le sommeil a-t-il pris fin ? Utiliser le minuteur pour une sieste en cours.';

  @override
  String get formSleepEndShort => 'Quand le sommeil a-t-il pris fin ?';

  @override
  String get formStartTime => 'Début';

  @override
  String get formStartedOn => 'Commencé à';

  @override
  String get formTextureColor => 'Texture et couleur';

  @override
  String get formTime => 'Heure';

  @override
  String get formTitleBottle => 'Biberon';

  @override
  String get formTitleCombo => 'Sein + biberon';

  @override
  String get formTotalTime => 'Durée totale';

  @override
  String get formType => 'Type';

  @override
  String get formUnit => 'Unité';

  @override
  String get formWeight => 'Poids';

  @override
  String get formWhatCame => 'Résultat';

  @override
  String get formWhen => 'Quand';

  @override
  String get formWhere => 'Où';

  @override
  String get formWokeUp => 'Réveillé';

  @override
  String get growthAddBirthDate => 'Ajouter la date de naissance';

  @override
  String growthAddBirthDateNotice(Object name) {
    return 'Ajouter la date de naissance de $name pour comparer avec les courbes de croissance de l\'OMS.';
  }

  @override
  String get growthAddMeasurement => 'Ajouter une mesure';

  @override
  String get growthAge => 'Âge';

  @override
  String growthAgeDays(Object days) {
    return '$days j';
  }

  @override
  String growthAgeMonthsDays(Object days, Object months) {
    return '$months m $days j';
  }

  @override
  String growthAgeYearsMonths(Object months, Object years) {
    return '$years a $months m';
  }

  @override
  String get growthBoys => 'Garçons';

  @override
  String get growthBoysPercentile => 'Centile (garçons)';

  @override
  String get growthCompareWith => 'Comparer avec';

  @override
  String growthCurvesNote(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'filles',
      'other': 'garçons',
    });
    return 'Courbes : normes de croissance de l\'enfant de l\'OMS ($_temp0, de 0 à 24 mois), centiles 2 à 98. Une seule mesure dit peu de chose : suivre la tendance et demander l\'avis du médecin en cas d\'inquiétude.';
  }

  @override
  String get growthGirls => 'Filles';

  @override
  String get growthGirlsPercentile => 'Centile (filles)';

  @override
  String get growthHead => 'Tête';

  @override
  String get growthLength => 'Taille';

  @override
  String get growthMonths => 'mois';

  @override
  String get growthNoneHead => 'Aucun tour de tête mesuré pour l\'instant.';

  @override
  String get growthNoneLength => 'Aucune taille mesurée pour l\'instant.';

  @override
  String get growthNoneWeight => 'Aucun poids mesuré pour l\'instant.';

  @override
  String growthPercentile(Object rank) {
    return '$rank centile';
  }

  @override
  String get growthTitle => 'Courbes de croissance';

  @override
  String get growthWeeks => 'semaines';

  @override
  String get growthWeight => 'Poids';

  @override
  String headShort(Object value) {
    return 'Tête $value';
  }

  @override
  String get healthAppointment => 'Rendez-vous';

  @override
  String get healthMedicine => 'Médicament';

  @override
  String get healthSymptom => 'Symptôme';

  @override
  String get healthTemperature => 'Température';

  @override
  String get healthVaccine => 'Vaccin';

  @override
  String get homeAddBaby => 'Ajouter un bébé';

  @override
  String get homeAddNote => 'Ajouter une note';

  @override
  String get homeAsleep => 'dort';

  @override
  String homeAwakeFor(Object duration) {
    return 'Éveillé depuis $duration';
  }

  @override
  String homeAwakeLast(Object duration) {
    return 'éveil · a dormi $duration';
  }

  @override
  String get homeBabyBook => 'Album de bébé';

  @override
  String homeBreastCount(Object count) {
    return '$count au sein';
  }

  @override
  String get homeCaptionBottle => 'biberon';

  @override
  String get homeCaptionPotty => 'pot';

  @override
  String get homeCardFeed => 'Repas';

  @override
  String get homeCardFirsts => 'Premières fois';

  @override
  String homeCardHistory(Object title) {
    return 'Historique : $title';
  }

  @override
  String get homeCardRoutine => 'Routine';

  @override
  String get homeChartsShort => 'Courbes';

  @override
  String get homeDiaperReminder => 'Rappel couche';

  @override
  String get homeDiapersIn24h => 'couches en 24 h';

  @override
  String get homeDiapersToday => 'couches aujourd\'hui';

  @override
  String get homeDoseNow => 'Prochaine dose possible maintenant';

  @override
  String homeDosesIn24h(Object given, Object max) {
    return '$given sur $max en 24 h';
  }

  @override
  String get homeFeedReminder => 'Rappel repas';

  @override
  String get homeFeedsIn24h => 'repas en 24 h';

  @override
  String get homeFeedsToday => 'repas aujourd\'hui';

  @override
  String get homeGive => 'Donner';

  @override
  String get homeGrowthCharts => 'Courbes de croissance';

  @override
  String homeHead(Object value) {
    return 'tête $value';
  }

  @override
  String get homeHide => 'Masquer';

  @override
  String get homeHistoryShort => 'Historique';

  @override
  String homeLabelPaused(Object label) {
    return '$label · en pause';
  }

  @override
  String get homeLastSide => 'dernier côté';

  @override
  String homeLiveBreastfeed(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'droit',
      'other': 'gauche',
    });
    return 'allaitement · $_temp0';
  }

  @override
  String get homeLiveTooltip =>
      'En direct — les changements des autres membres de la famille apparaissent aussitôt';

  @override
  String get homeLog => 'Noter';

  @override
  String homeLogCard(Object title) {
    return 'Noter : $title';
  }

  @override
  String get homeLogFeed => 'Noter un repas';

  @override
  String homeNaps(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count siestes',
      one: '1 sieste',
      zero: '0 sieste',
    );
    return '$_temp0';
  }

  @override
  String get homeNavBook => 'Album';

  @override
  String get homeNavCalendar => 'Calendrier';

  @override
  String get homeNavHome => 'Accueil';

  @override
  String get homeNavTimeline => 'Journal';

  @override
  String get homeNavTrends => 'Tendances';

  @override
  String homeNextDoseOn(Object date, Object time) {
    return 'Prochaine dose le $date à $time';
  }

  @override
  String homeNextDoseToday(Object time) {
    return 'Prochaine dose à $time';
  }

  @override
  String homeNextDoseTomorrow(Object time) {
    return 'Prochaine dose demain à $time';
  }

  @override
  String homeNightSleep(Object duration) {
    return '$duration nuit';
  }

  @override
  String homeNoDiaperFor(Object duration) {
    return 'Pas de change depuis $duration';
  }

  @override
  String get homeNoDoseYet => 'Aucune dose donnée';

  @override
  String homeNoFeedFor(Object duration) {
    return 'Pas de repas depuis $duration';
  }

  @override
  String homeNoPumpFor(Object duration) {
    return 'Pas de tire-lait depuis $duration';
  }

  @override
  String get homeNotSyncedYet => 'pas encore synchro';

  @override
  String get homeOffline => 'hors ligne';

  @override
  String homeOfflinePending(Object count) {
    return 'hors ligne · $count à synchro';
  }

  @override
  String homeOfflineTooltip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Hors ligne — continuez à noter ; $count changements seront synchronisés au retour du serveur',
      one:
          'Hors ligne — continuez à noter ; 1 changement sera synchronisé au retour du serveur',
      zero:
          'Hors ligne — continuez à noter ; les changements seront synchronisés au retour du serveur',
    );
    return '$_temp0';
  }

  @override
  String get homePaused => 'en pause';

  @override
  String homePottyCount(Object count) {
    return '$count pot';
  }

  @override
  String get homePumpReminder => 'Rappel tire-lait';

  @override
  String get homePumped => 'tiré';

  @override
  String get homePumping => 'Tire-lait';

  @override
  String get homeReconnecting => 'Reconnexion…';

  @override
  String get homeServerlessAlone =>
      'Sans serveur : données sur ce téléphone. Associer un autre téléphone dans Famille pour partager.';

  @override
  String homeServerlessPeers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sans serveur : synchro avec $count téléphones associés sur le même Wi-Fi',
      one: 'Sans serveur : synchro avec 1 téléphone associé sur le même Wi-Fi',
    );
    return '$_temp0';
  }

  @override
  String homeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Sein droit',
      'other': 'Sein gauche',
    });
    return '$_temp0';
  }

  @override
  String homeSince(Object time) {
    return 'depuis $time';
  }

  @override
  String get homeSleepIn24h => 'sommeil en 24 h';

  @override
  String get homeSleepReminder => 'Rappel sommeil';

  @override
  String get homeSleepToday => 'sommeil aujourd\'hui';

  @override
  String get homeSleeping => 'Dodo';

  @override
  String homeSolidsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solides',
      one: '1 solide',
    );
    return '$_temp0';
  }

  @override
  String get homeStart => 'Démarrer';

  @override
  String get homeSwitchBaby => 'Changer de bébé';

  @override
  String get homeSyncLocal => 'sur ce téléphone';

  @override
  String homeSynced(Object ago) {
    return 'synchro $ago';
  }

  @override
  String get homeSyncing => 'synchro…';

  @override
  String get homeSyncingTooltip =>
      'Synchronisation des changements faits hors ligne…';

  @override
  String get homeTapToLog => 'Toucher pour noter';

  @override
  String homeWetDirtyCounts(Object dirty, Object wet) {
    return '$wet urine · $dirty selles';
  }

  @override
  String homeWoke(Object ago) {
    return 'réveil $ago';
  }

  @override
  String get inThePotty => 'Dans le pot';

  @override
  String get justNow => 'à l\'instant';

  @override
  String get kindActivity => 'Activité';

  @override
  String get kindBottle => 'Biberon';

  @override
  String get kindBreastfeed => 'Allaitement';

  @override
  String get kindCombo => 'Mixte';

  @override
  String get kindDiaper => 'Couche';

  @override
  String get kindGrowth => 'Croissance';

  @override
  String get kindHealth => 'Santé';

  @override
  String get kindMilestone => 'Étape';

  @override
  String get kindNote => 'Note';

  @override
  String get kindPotty => 'Pot';

  @override
  String get kindPump => 'Tire-lait';

  @override
  String get kindSleep => 'Sommeil';

  @override
  String get kindSolids => 'Solides';

  @override
  String get kindTemperature => 'Température';

  @override
  String get language => 'Langue';

  @override
  String get left => 'Gauche';

  @override
  String get leftShort => 'G';

  @override
  String lengthShort(Object value) {
    return 'T $value';
  }

  @override
  String get localNeedsServer =>
      'Il faut un serveur Nestling pour ceci. Sans serveur, tout reste sur vos téléphones.';

  @override
  String get localPhotosNeedServer =>
      'Les photos des souvenirs demandent l\'app Android ou un serveur Nestling.';

  @override
  String get locationArms => 'Dans les bras';

  @override
  String get locationBassinet => 'Berceau';

  @override
  String get locationBed => 'Lit';

  @override
  String get locationCar => 'Voiture';

  @override
  String get locationCrib => 'Lit de bébé';

  @override
  String get locationStroller => 'Poussette';

  @override
  String get loginAskAdmin =>
      'Pas encore de compte ? Demandez à la personne qui gère ce serveur Nestling de vous en créer un.';

  @override
  String get loginContinue => 'Continuer';

  @override
  String get loginCreateAccount => 'Créer le compte';

  @override
  String get loginCreateAdmin => 'Créer le compte admin';

  @override
  String get loginCreateYourAccount => 'Créer votre compte';

  @override
  String get loginEmail => 'E-mail';

  @override
  String get loginEnterEmail => 'Entrez votre e-mail';

  @override
  String get loginEnterName => 'Entrez votre nom';

  @override
  String get loginEnterPassword => 'Entrez votre mot de passe';

  @override
  String get loginEnterServer => 'Entrez l\'adresse de votre serveur Nestling';

  @override
  String get loginHaveAccount => 'J\'ai déjà un compte';

  @override
  String get loginNewHere => 'Nouveau ? Créer un compte';

  @override
  String get loginNewServer =>
      'Nouveau serveur : créer le compte administrateur.\nLes autres membres de la famille s\'ajoutent ensuite.';

  @override
  String get loginNoServerIntro =>
      'Pas de serveur à la maison ? Nestling fonctionne aussi seul : vos données restent sur votre téléphone, et vous pouvez jumeler le téléphone de votre partenaire en Wi-Fi et sauvegarder sur Google Drive.';

  @override
  String get loginPassword => 'Mot de passe';

  @override
  String get loginPasswordMin => 'Au moins 8 caractères';

  @override
  String get loginServerAddress => 'Adresse du serveur';

  @override
  String loginServerLink(Object server) {
    return 'Serveur : $server';
  }

  @override
  String get loginServerless => 'Utiliser sans serveur';

  @override
  String get loginServerlessIntro =>
      'Tout ce que vous notez est enregistré sur ce téléphone. Quel est votre nom ? Les autres membres de la famille le verront.';

  @override
  String get loginSignIn => 'Se connecter';

  @override
  String get loginWelcomeBack => 'Bon retour';

  @override
  String get loginYourName => 'Votre nom';

  @override
  String get milkBreastMilk => 'Lait maternel';

  @override
  String get milkFormula => 'Préparation';

  @override
  String get milkMixed => 'Mélange';

  @override
  String get notSet => 'Non défini';

  @override
  String get notifBreastfeedPaused => 'Allaitement en pause';

  @override
  String notifBreastfeeding(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Allaitement · sein droit',
      'other': 'Allaitement · sein gauche',
    });
    return '$_temp0';
  }

  @override
  String get notifChipPaused => 'Pause';

  @override
  String notifPausedBody(Object duration) {
    return '$duration jusqu’ici · toucher pour reprendre';
  }

  @override
  String get notifPumpPaused => 'Tire-lait en pause';

  @override
  String get notifPumping => 'Tire-lait en cours';

  @override
  String notifRunningBody(Object time) {
    return 'Depuis $time · toucher pour ouvrir';
  }

  @override
  String get notifSleepPaused => 'Sommeil en pause';

  @override
  String get notifSleeping => 'Dodo en cours';

  @override
  String notifTitle(Object child, Object what) {
    return '$child · $what';
  }

  @override
  String get now => 'Maintenant';

  @override
  String get ok => 'OK';

  @override
  String get onboardingAddBaby => 'Ajouter un bébé';

  @override
  String onboardingAddLittleOne(Object family) {
    return 'Ajoutez maintenant votre bébé à $family.';
  }

  @override
  String get onboardingBack => 'Retour';

  @override
  String get onboardingCreateFamily => 'Créer la famille';

  @override
  String get onboardingFamilyName => 'Nom de la famille';

  @override
  String onboardingHi(Object name) {
    return 'Bonjour $name !';
  }

  @override
  String get onboardingIntro =>
      'Créer une famille pour suivre votre bébé, ou en rejoindre une avec un code d\'invitation de votre partenaire.';

  @override
  String get onboardingIntroServerless =>
      'Créer une famille pour suivre votre bébé, ou rejoindre celle du téléphone de votre partenaire.';

  @override
  String get onboardingInviteCode => 'Code d\'invitation';

  @override
  String get onboardingJoinFamily => 'Rejoindre la famille';

  @override
  String get onboardingJoinWithCode => 'Rejoindre avec un code de jumelage';

  @override
  String get onboardingNoBackup =>
      'Aucune sauvegarde Nestling dans ce compte Google.';

  @override
  String get onboardingOrJoin => 'Ou en rejoindre une';

  @override
  String get onboardingOrJoinPartner =>
      'Ou rejoindre celle de votre partenaire';

  @override
  String get onboardingOurFamily => 'Notre famille';

  @override
  String get onboardingPairIntro =>
      'Si un autre téléphone suit déjà votre bébé, jumelez-le : tout est copié et reste synchronisé.';

  @override
  String get onboardingRestoreDrive => 'Restaurer depuis Google Drive';

  @override
  String get onboardingStartFamily => 'Créer une famille';

  @override
  String get pagesAge => 'Âge';

  @override
  String get pagesAndAlso => 'Et aussi';

  @override
  String get pagesAt => 'Heure';

  @override
  String get pagesBirth => 'Naissance';

  @override
  String get pagesBirthGrowthHint =>
      'Le poids et la taille de naissance viennent d\'une entrée Croissance du jour de la naissance.';

  @override
  String get pagesBorn => 'Naissance';

  @override
  String get pagesBornNoDate =>
      'Ajouter la date de naissance dans Famille → le bébé pour commencer cette page.';

  @override
  String get pagesBornPrompt =>
      'Touchez pour ajouter l\'heure, le lieu, les cheveux et les yeux.';

  @override
  String get pagesBornTitle => 'Le jour de ta naissance';

  @override
  String get pagesEyes => 'Yeux';

  @override
  String get pagesFullName => 'Nom complet';

  @override
  String get pagesGrowthEmpty =>
      'Noter le poids et la taille dans Croissance : chaque mois s\'affiche ici.';

  @override
  String get pagesGrowthNoBirth =>
      'Ajouter la date de naissance pour voir la croissance mois par mois.';

  @override
  String get pagesHair => 'Cheveux';

  @override
  String get pagesHead => 'Tête';

  @override
  String get pagesHintEyes => 'Bleu profond';

  @override
  String get pagesHintHair => 'Foncés et abondants';

  @override
  String get pagesHintMeaning => 'Son sens ou son origine';

  @override
  String get pagesHintNicknames => 'Comment on t\'appelle à la maison';

  @override
  String get pagesHintOthers => 'Les autres finalistes';

  @override
  String get pagesHintPlace => 'L\'hôpital, la maison, la ville';

  @override
  String get pagesHintRemember => 'Le premier cri, qui était là, la météo…';

  @override
  String get pagesHintWhy => 'D\'où ou de qui il vient';

  @override
  String get pagesHintWorldNote => 'Autre chose sur cette année-là';

  @override
  String get pagesLength => 'Taille';

  @override
  String get pagesMeasured => 'Taille';

  @override
  String get pagesMonthByMonth => 'Mois par mois';

  @override
  String pagesMonthsShort(Object count) {
    return '$count mois';
  }

  @override
  String get pagesMoon => 'La lune';

  @override
  String get pagesMoonFirstQuarter => 'Premier quartier';

  @override
  String get pagesMoonFull => 'Pleine lune';

  @override
  String get pagesMoonLastQuarter => 'Dernier quartier';

  @override
  String get pagesMoonNew => 'Nouvelle lune';

  @override
  String get pagesMoonWaningCrescent => 'Dernier croissant';

  @override
  String get pagesMoonWaningGibbous => 'Gibbeuse décroissante';

  @override
  String get pagesMoonWaxingCrescent => 'Premier croissant';

  @override
  String get pagesMoonWaxingGibbous => 'Gibbeuse croissante';

  @override
  String get pagesNameMeaning => 'Ce qu\'il veut dire';

  @override
  String get pagesNameOthers => 'Les autres prénoms envisagés';

  @override
  String get pagesNamePrompt => 'Touchez pour raconter pourquoi ce prénom.';

  @override
  String get pagesNameTitle => 'Ton prénom';

  @override
  String get pagesNameWhy => 'Pourquoi ce choix';

  @override
  String get pagesNicknames => 'Surnoms';

  @override
  String get pagesPriceBread => 'Pain';

  @override
  String get pagesPriceCar => 'Une voiture neuve';

  @override
  String get pagesPriceCoffee => 'Un café';

  @override
  String get pagesPriceDiapers => 'Couches';

  @override
  String get pagesPriceGas => 'Essence';

  @override
  String get pagesPriceHint => 'Prix';

  @override
  String get pagesPriceHouse => 'Une maison';

  @override
  String get pagesPriceMilk => 'Lait';

  @override
  String get pagesPriceMovie => 'Une place de cinéma';

  @override
  String get pagesPriceRent => 'Loyer';

  @override
  String get pagesSaveToBook => 'Enregistrer dans le livre';

  @override
  String get pagesSaving => 'Enregistrement…';

  @override
  String get pagesSetTime => 'Choisir';

  @override
  String pagesTapToEdit(Object title) {
    return '$title. Touchez pour modifier.';
  }

  @override
  String get pagesTimeOfBirth => 'Heure de naissance';

  @override
  String get pagesWeRemember => 'On se souvient';

  @override
  String get pagesWeighed => 'Poids';

  @override
  String get pagesWeight => 'Poids';

  @override
  String get pagesWhatThingsCost => 'Ce que coûtaient les choses';

  @override
  String get pagesWhere => 'Lieu';

  @override
  String get pagesWorldLeaders => 'Dirigeants';

  @override
  String get pagesWorldLeadersHint => 'Premier ministre, président, maire…';

  @override
  String get pagesWorldMovies => 'Au cinéma';

  @override
  String get pagesWorldMoviesHint => 'Ce qui était à l\'affiche';

  @override
  String get pagesWorldNews => 'À l\'actualité';

  @override
  String get pagesWorldNewsHint => 'Ce dont tout le monde parlait';

  @override
  String get pagesWorldPeople => 'Visages célèbres';

  @override
  String get pagesWorldPeopleHint => 'Acteurs, sportifs, chanteurs';

  @override
  String get pagesWorldPrompt =>
      'Touchez pour noter les chansons, l\'actualité et le prix d\'un café.';

  @override
  String get pagesWorldShows => 'À la télé';

  @override
  String get pagesWorldShowsHint => 'Les émissions que tout le monde regardait';

  @override
  String get pagesWorldSongs => 'Chansons à la radio';

  @override
  String get pagesWorldSongsHint => 'Les tubes de l\'année';

  @override
  String get pagesWorldTech => 'Gadgets';

  @override
  String get pagesWorldTechHint => 'Le téléphone dans nos poches, la nouveauté';

  @override
  String get pagesWorldTitle => 'Le monde à ta naissance';

  @override
  String get pairingCodeCopied =>
      'Code d\'association copié. Envoyez-le seulement à votre famille : il donne accès aux données de votre bébé.';

  @override
  String get pairingCopyCode => 'Copier le code à la place';

  @override
  String get pairingIntro =>
      'Sur l\'autre téléphone, installez Nestling, choisissez « Utiliser sans serveur », puis « Rejoindre avec un code d\'association » et scannez ceci. Les deux téléphones doivent être sur le même Wi-Fi.';

  @override
  String get pairingJoinIntro =>
      'Sur un téléphone qui utilise déjà Nestling : Famille → Associer un téléphone. Scannez le code affiché (même Wi-Fi pour les deux téléphones).';

  @override
  String get pairingJoinTitle => 'Rejoindre avec un code d\'association';

  @override
  String get pairingNeedsAndroid =>
      'L\'association de téléphones nécessite l\'app Android.';

  @override
  String get pairingNoneYet => 'Aucun pour l\'instant.';

  @override
  String get pairingNotSynced => 'Pas encore synchronisé';

  @override
  String get pairingPairedPhones => 'Téléphones associés';

  @override
  String get pairingPasteCode => 'Ou coller le code';

  @override
  String get pairingPhone => 'Téléphone';

  @override
  String get pairingSyncNow => 'Synchroniser';

  @override
  String get pairingTitle => 'Associer un téléphone';

  @override
  String pairingUnreachable(Object ago) {
    return 'Synchronisé $ago · injoignable pour l\'instant';
  }

  @override
  String get pickerAddActivity => 'Ajouter une activité';

  @override
  String get pickerAddFood => 'Ajouter un aliment';

  @override
  String get pickerAddMedicine => 'Ajouter un médicament';

  @override
  String get pickerAlreadyTried => 'Déjà goûtés';

  @override
  String get pickerCommon => 'Courants';

  @override
  String get pickerFoodApple => 'Pomme';

  @override
  String get pickerFoodAvocado => 'Avocat';

  @override
  String get pickerFoodBanana => 'Banane';

  @override
  String get pickerFoodBeef => 'Bœuf';

  @override
  String get pickerFoodBlueberries => 'Myrtilles';

  @override
  String get pickerFoodBread => 'Pain';

  @override
  String get pickerFoodBroccoli => 'Brocoli';

  @override
  String get pickerFoodCarrot => 'Carotte';

  @override
  String get pickerFoodCheese => 'Fromage';

  @override
  String get pickerFoodChicken => 'Poulet';

  @override
  String get pickerFoodEgg => 'Œuf';

  @override
  String get pickerFoodFish => 'Poisson';

  @override
  String get pickerFoodGreenBeans => 'Haricots verts';

  @override
  String get pickerFoodLentils => 'Lentilles';

  @override
  String get pickerFoodMango => 'Mangue';

  @override
  String get pickerFoodOatmeal => 'Flocons d\'avoine';

  @override
  String get pickerFoodPasta => 'Pâtes';

  @override
  String get pickerFoodPeach => 'Pêche';

  @override
  String get pickerFoodPeanutButter => 'Beurre d\'arachide';

  @override
  String get pickerFoodPear => 'Poire';

  @override
  String get pickerFoodPeas => 'Petits pois';

  @override
  String get pickerFoodRiceCereal => 'Céréales de riz';

  @override
  String get pickerFoodSquash => 'Courge';

  @override
  String get pickerFoodStrawberries => 'Fraises';

  @override
  String get pickerFoodSweetPotato => 'Patate douce';

  @override
  String get pickerFoodTofu => 'Tofu';

  @override
  String get pickerFoodYogurt => 'Yaourt';

  @override
  String pickerLastDose(Object dose) {
    return 'Dernière dose $dose';
  }

  @override
  String get pickerMedAcetaminophen => 'Acétaminophène (Tylenol)';

  @override
  String get pickerMedAmoxicillin => 'Amoxicilline';

  @override
  String get pickerMedAntihistamine => 'Antihistaminique (Benadryl)';

  @override
  String get pickerMedDiaperCream => 'Crème pour le siège';

  @override
  String get pickerMedGripeWater => 'Eau contre les coliques';

  @override
  String get pickerMedIbuprofen => 'Ibuprofène (Advil)';

  @override
  String get pickerMedIron => 'Gouttes de fer';

  @override
  String get pickerMedProbiotic => 'Probiotique (BioGaia)';

  @override
  String get pickerMedSaline => 'Gouttes salines';

  @override
  String get pickerMedSimethicone => 'Siméthicone (Ovol)';

  @override
  String get pickerMedTeethingGel => 'Gel de dentition';

  @override
  String get pickerMedVitaminD => 'Vitamine D';

  @override
  String get pickerRecent => 'Récents';

  @override
  String get pickerSelected => 'Sélectionné';

  @override
  String pickerTimes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fois',
      one: 'Une fois',
    );
    return '$_temp0';
  }

  @override
  String get pickerUseName => 'Utiliser ce nom';

  @override
  String pickerUsedLast(Object day, Object times) {
    return '$times · dernière fois $day';
  }

  @override
  String get pottyAccident => 'Accident';

  @override
  String get pottySatDry => 'Assis, rien';

  @override
  String get pottySuccess => 'Pot';

  @override
  String get rash => 'irritation';

  @override
  String get remove => 'Retirer';

  @override
  String get right => 'Droit';

  @override
  String get rightShort => 'D';

  @override
  String get roleBookViewer => 'Album seulement';

  @override
  String get roleBookViewerHint =>
      'Voit l\'album de bébé, sans rien pouvoir modifier';

  @override
  String get roleCaregiver => 'Membre';

  @override
  String get roleCaregiverHint =>
      'Note les repas, le sommeil, les couches et tout le reste';

  @override
  String get roleOwner => 'Propriétaire';

  @override
  String get roleOwnerHint => 'Note tout et gère la famille';

  @override
  String get save => 'Enregistrer';

  @override
  String get scheduleAddMedicine => 'Ajouter un médicament';

  @override
  String get scheduleDaily => 'par jour';

  @override
  String get scheduleDescribeEmpty =>
      'Doses à horaire fixe, « pas de repas depuis 3 h »…';

  @override
  String get scheduleDoseLabel => 'Dose habituelle (facultatif)';

  @override
  String get scheduleDoses => 'doses';

  @override
  String get scheduleErrDose => 'La dose doit être un nombre.';

  @override
  String get scheduleErrEvery => 'Fréquence : entre 0,5 et 168 heures.';

  @override
  String get scheduleErrMax => 'Maximum par 24 heures : un nombre de 1 à 24.';

  @override
  String get scheduleErrName => 'Donnez un nom au médicament.';

  @override
  String get scheduleEvery => 'Toutes les';

  @override
  String scheduleEveryHours(Object hours) {
    return 'Toutes les $hours h';
  }

  @override
  String scheduleEveryMinutes(Object minutes) {
    return 'Toutes les $minutes min';
  }

  @override
  String get scheduleFeed => 'Repas';

  @override
  String get scheduleFooterPush =>
      'Un rappel dû s\'affiche sur l\'accueil (balayez-le pour le masquer) et est envoyé aux téléphones de toute la famille. Le rappel d\'un médicament s\'active dans son horaire.';

  @override
  String get scheduleFooterServer =>
      'Un rappel dû s\'affiche sur l\'accueil (balayez-le pour le masquer). Pour le recevoir aussi en notification, configurez les notifications sur le serveur (voir « Notifications on phones » dans le README).';

  @override
  String get scheduleFooterServerless =>
      'Un rappel dû s\'affiche sur l\'accueil (balayez-le pour le masquer). Les notifications sur téléphone exigent un serveur Nestling configuré pour cela.';

  @override
  String get scheduleHours => 'heures';

  @override
  String scheduleIntro(Object name) {
    return 'Pour $name. Un médicament à horaire fixe s\'affiche sur l\'accueil avec l\'heure de la prochaine dose possible, et une saisie trop tôt vous avertit.';
  }

  @override
  String get scheduleMaxLabel => 'Maximum par 24 heures (facultatif)';

  @override
  String get scheduleMedicineSection => 'Horaire des médicaments';

  @override
  String get scheduleName => 'Nom';

  @override
  String scheduleNotifyWhen(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'Avertir après une période d\'éveil de :',
      'diaper': 'Avertir sans changement de couche depuis :',
      'pump': 'Avertir sans tirage depuis :',
      'other': 'Avertir sans repas depuis :',
    });
    return '$_temp0';
  }

  @override
  String get scheduleOff => 'Désactivé';

  @override
  String get scheduleOnceADay => 'Une fois par jour';

  @override
  String get scheduleOnceAWeek => 'Une fois par semaine';

  @override
  String get scheduleRemindDue => 'Rappeler quand la prochaine dose est due';

  @override
  String get scheduleReminderOn => 'rappel activé';

  @override
  String scheduleReminderTitle(Object label) {
    return 'Rappel : $label';
  }

  @override
  String get scheduleReminders => 'Rappels';

  @override
  String scheduleRemindersList(num count, Object types) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'rappels $types',
      one: 'rappel $types',
    );
    return '$_temp0';
  }

  @override
  String get scheduleTitle => 'Médicaments et rappels';

  @override
  String get scheduleUnit => 'Unité';

  @override
  String scheduleUpToPerDay(Object count) {
    return 'jusqu\'à $count par jour';
  }

  @override
  String scheduleWhenAfter(Object duration, String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'Après $duration d\'éveil',
      'diaper': 'Sans changement de couche depuis $duration',
      'pump': 'Sans tirage depuis $duration',
      'other': 'Sans repas depuis $duration',
    });
    return '$_temp0';
  }

  @override
  String get settingsLanguageDevice => 'Langue de l\'appareil';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String summaryBreastMilk(Object amount) {
    return '$amount de lait maternel';
  }

  @override
  String get summaryClose => 'Fermer le résumé';

  @override
  String get summaryFirsts => 'Premières fois';

  @override
  String summaryFormula(Object amount) {
    return '$amount de préparation';
  }

  @override
  String summaryHead(Object value) {
    return 'tête $value';
  }

  @override
  String get summaryLast24h => 'Dernières 24 h';

  @override
  String summaryLeft(Object duration) {
    return '$duration gauche';
  }

  @override
  String summaryLongest(Object duration) {
    return 'le plus long $duration';
  }

  @override
  String get summaryNotes => 'Notes';

  @override
  String get summaryNothing => 'Rien de noté pour l\'instant.';

  @override
  String summaryPotty(num accidents, Object inPotty) {
    String _temp0 = intl.Intl.pluralLogic(
      accidents,
      locale: localeName,
      other: '$accidents accidents',
      one: '1 accident',
      zero: '0 accident',
    );
    return '$inPotty dans le pot · $_temp0';
  }

  @override
  String summaryPumping(Object duration) {
    return '$duration de tirage';
  }

  @override
  String summaryRight(Object duration) {
    return '$duration droit';
  }

  @override
  String get summaryRoutine => 'Routine';

  @override
  String summaryTemperature(Object values) {
    return 'température $values';
  }

  @override
  String get summaryTitle => 'Résumé';

  @override
  String summaryTotal(Object amount) {
    return '$amount au total';
  }

  @override
  String summaryWetDirty(Object dirty, Object wet) {
    return '$wet urine · $dirty selles';
  }

  @override
  String syncCantReach(Object server) {
    return 'Impossible de joindre le serveur ($server).';
  }

  @override
  String syncCantReachCheck(Object server) {
    return 'Impossible de joindre le serveur ($server). Vérifiez l\'adresse et votre connexion.';
  }

  @override
  String syncCantReachNamedPhone(Object name) {
    return 'Impossible de joindre le téléphone de $name. Les deux téléphones doivent être sur le même Wi-Fi, avec le code de jumelage encore affiché.';
  }

  @override
  String get syncCantReachOtherPhone =>
      'Impossible de joindre l\'autre téléphone. Les deux téléphones doivent être sur le même Wi-Fi, avec le code de jumelage encore affiché.';

  @override
  String syncChangeNotSaved(Object message) {
    return 'Une modification n\'a pas pu être enregistrée : $message';
  }

  @override
  String get syncConflict =>
      'Une de vos modifications a aussi été faite sur un autre appareil ; la plus récente a été gardée.';

  @override
  String get syncDriveFolderUnreachable =>
      'Le dossier Drive de la famille est inaccessible. Désactiver puis réactiver la synchro Drive.';

  @override
  String get syncDriveNeedsAndroid =>
      'Google Drive nécessite l\'application Android.';

  @override
  String get syncDriveNotGranted =>
      'L\'accès à Google Drive n\'a pas été autorisé.';

  @override
  String get syncEntryDeleted =>
      'Cette entrée a été supprimée sur un autre téléphone.';

  @override
  String get syncGoogleNotSignedIn => 'Pas connecté à Google.';

  @override
  String syncLoggedNotSaved(Object message) {
    return 'Une entrée n\'a pas pu être enregistrée : $message';
  }

  @override
  String get syncNotPairingCode =>
      'Ce n\'est pas un code de jumelage Nestling.';

  @override
  String syncOffline(Object host) {
    return 'Vous êtes hors ligne. Il faut une connexion au serveur ($host).';
  }

  @override
  String syncOfflineNotSent(Object message) {
    return 'Les modifications faites hors ligne n\'ont pas encore pu être envoyées : $message';
  }

  @override
  String syncOtherPhoneAnswered(Object status) {
    return 'l\'autre téléphone a répondu $status';
  }

  @override
  String get syncPairingIncomplete =>
      'Ce code de jumelage est incomplet. Copiez-le à nouveau.';

  @override
  String get syncPhonesNeedAndroid =>
      'La synchro directe entre téléphones nécessite l\'application Android.';

  @override
  String syncServerError(Object status) {
    return 'Erreur du serveur ($status)';
  }

  @override
  String get syncTimerRunning =>
      'Quelqu\'un a déjà lancé ce minuteur. Il est affiché maintenant.';

  @override
  String get syncTimerStopped =>
      'Ce minuteur a déjà été arrêté sur un autre téléphone. L\'écran est maintenant à jour.';

  @override
  String get syncWifiFirst => 'Connectez d\'abord ce téléphone au Wi-Fi.';

  @override
  String get system => 'Système';

  @override
  String teethAgeOld(Object age) {
    return 'à $age';
  }

  @override
  String get teethCameIn => 'Sortie';

  @override
  String get teethCameInOn => 'Sortie le';

  @override
  String get teethCanine => 'canine';

  @override
  String get teethCentralIncisor => 'incisive centrale';

  @override
  String teethChartSemantics(Object count) {
    return 'Tableau des dents : $count dents sur 20 sorties. Touchez une dent pour la noter.';
  }

  @override
  String teethChartSemanticsReadOnly(Object count) {
    return 'Dents : $count sur 20 sont sorties.';
  }

  @override
  String teethCount(Object count) {
    return '$count sur 20';
  }

  @override
  String get teethFirstHint =>
      'La première va dans le livre comme « Première dent » : ajoutez-y une photo et l\'histoire.';

  @override
  String get teethFirstMolar => 'première molaire';

  @override
  String get teethItCameIn => 'Elle est sortie';

  @override
  String get teethLateralIncisor => 'incisive latérale';

  @override
  String get teethLegendIn => 'Sortie';

  @override
  String get teethLegendNotYet => 'Pas encore';

  @override
  String get teethLower => 'BAS';

  @override
  String get teethLowerLeft => 'inférieure gauche';

  @override
  String get teethLowerRight => 'inférieure droite';

  @override
  String teethName(Object kind, Object position) {
    return '$kind $position';
  }

  @override
  String get teethNotInYet => 'Pas encore sortie';

  @override
  String get teethSaveDate => 'Enregistrer la date';

  @override
  String get teethSecondMolar => 'deuxième molaire';

  @override
  String get teethTapChange =>
      'Touchez une dent pour la noter ou changer sa date.';

  @override
  String get teethTapFirst => 'Touchez une dent quand elle sort.';

  @override
  String get teethUpper => 'HAUT';

  @override
  String get teethUpperLeft => 'supérieure gauche';

  @override
  String get teethUpperRight => 'supérieure droite';

  @override
  String teethUsually(Object when) {
    return 'Sort en général vers $when';
  }

  @override
  String teethWhen(Object range) {
    return '$range mois';
  }

  @override
  String get timelineAll => 'Tout';

  @override
  String get timelineDiapers => 'Couches';

  @override
  String get timelineEmpty => 'Rien pour l\'instant.';

  @override
  String get timelineFeeds => 'Repas';

  @override
  String timelineNote(Object note) {
    return '« $note »';
  }

  @override
  String get timelineOther => 'Autre';

  @override
  String get timelineSummary => 'Résumé';

  @override
  String timelineTitle(Object name) {
    return 'Journal de $name';
  }

  @override
  String timerAwakeFor(Object duration) {
    return 'Éveillé depuis $duration';
  }

  @override
  String get timerDeleteBody => 'Rien ne sera enregistré.';

  @override
  String get timerDeleteTitle => 'Supprimer ce minuteur ?';

  @override
  String timerEditSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Modifier le temps à gauche',
      'other': 'Modifier le temps à droite',
    });
    return '$_temp0';
  }

  @override
  String get timerEditTotal => 'Modifier la durée totale';

  @override
  String timerEndAfterStart(Object time) {
    return 'La fin doit être après le début ($time).';
  }

  @override
  String get timerEndTime => 'Fin';

  @override
  String get timerFellAsleep => 'Endormi';

  @override
  String get timerKeepsRunning => 'Fermez avec ✕ : le minuteur continue.';

  @override
  String timerLastFeedEnded(Object ago, String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Dernière tétée finie à gauche',
      'other': 'Dernière tétée finie à droite',
    });
    String _temp1 = intl.Intl.selectLogic(side, {
      'left': 'Commencer à droite',
      'other': 'Commencer à gauche',
    });
    return '$_temp0 · $ago\n$_temp1';
  }

  @override
  String get timerLastSideBadge => 'Dernier\ncôté';

  @override
  String get timerLeftSide => 'Côté gauche';

  @override
  String get timerLogPast => 'Saisir après';

  @override
  String get timerMinutes => 'Minutes';

  @override
  String get timerNoteHint => 'Note (facultatif)';

  @override
  String timerOnSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'À gauche',
      'other': 'À droite',
    });
    return '$_temp0';
  }

  @override
  String get timerPause => 'Pause';

  @override
  String timerPauseSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Pause à gauche',
      'other': 'Pause à droite',
    });
    return '$_temp0';
  }

  @override
  String get timerPaused => 'En pause';

  @override
  String get timerPumpHowMuch => 'Quelle quantité tirée ?';

  @override
  String get timerPumping => 'Tirage en cours';

  @override
  String get timerResume => 'Reprendre';

  @override
  String timerResumeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Reprendre à gauche',
      'other': 'Reprendre à droite',
    });
    return '$_temp0';
  }

  @override
  String get timerRightSide => 'Côté droit';

  @override
  String timerSaved(Object what) {
    return '$what enregistré';
  }

  @override
  String get timerSeconds => 'Secondes';

  @override
  String get timerSleeping => 'Dort';

  @override
  String get timerStart => 'Démarrer';

  @override
  String get timerStartInFuture => 'Le début ne peut pas être dans le futur.';

  @override
  String timerStartSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Commencer à gauche',
      'other': 'Commencer à droite',
    });
    return '$_temp0';
  }

  @override
  String timerStartSideLast(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Commencer à gauche (dernier côté)',
      'other': 'Commencer à droite (dernier côté)',
    });
    return '$_temp0';
  }

  @override
  String get timerStartTime => 'Début';

  @override
  String timerSwitchSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Passer à gauche',
      'other': 'Passer à droite',
    });
    return '$_temp0';
  }

  @override
  String get timerTapSide => 'Touchez un côté pour commencer';

  @override
  String get timerTapStart => 'Touchez pour commencer';

  @override
  String get timerTimeAsleep => 'Temps de sommeil';

  @override
  String get timerTotalTime => 'Durée totale';

  @override
  String get timerTotalTimeTitle => 'Durée totale';

  @override
  String get timerWokeUp => 'Réveillé';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get trendsAccidents => 'Accidents';

  @override
  String get trendsAmountPumped => 'Quantité tirée';

  @override
  String get trendsAverage => 'en moyenne';

  @override
  String get trendsBottleSize => 'Taille du biberon';

  @override
  String trendsBottleUnit(Object unit) {
    return 'Biberon ($unit)';
  }

  @override
  String get trendsBreastfeedLength => 'Durée d\'une tétée';

  @override
  String get trendsBreastfeeding => 'Allaitement';

  @override
  String trendsCompareArrows(Object count) {
    return 'Les flèches comparent avec les $count jours précédents.';
  }

  @override
  String trendsCompareNone(Object count) {
    return 'Rien de noté dans les $count jours précédents pour comparer.';
  }

  @override
  String get trendsDay => 'Jour';

  @override
  String get trendsDayBreastfeeding => 'Allaitement de jour';

  @override
  String get trendsDayDiapers => 'Couches de jour';

  @override
  String get trendsDaySleep => 'Sommeil de jour';

  @override
  String trendsDays(Object count) {
    return '$count jours';
  }

  @override
  String get trendsDiapers => 'Couches';

  @override
  String get trendsFeed => 'Alimentation';

  @override
  String get trendsFeedInterval => 'Temps entre les repas';

  @override
  String get trendsFeeds => 'Repas';

  @override
  String get trendsGrowthChartsSub =>
      'Poids, taille et tour de tête sur les courbes de l\'OMS';

  @override
  String trendsIntro(num days, Object end, Object start) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Moyennes par jour sur $days jours complets ; la journée va de $start à $end.',
      one:
          'Moyennes par jour sur 1 jour complet ; la journée va de $start à $end.',
      zero:
          'Moyennes par jour sur 0 jour complet ; la journée va de $start à $end.',
    );
    return '$_temp0';
  }

  @override
  String get trendsLongestSleep => 'Plus long sommeil';

  @override
  String get trendsNapLength => 'Durée des siestes';

  @override
  String get trendsNaps => 'Siestes';

  @override
  String get trendsNight => 'Nuit';

  @override
  String get trendsNightBreastfeeding => 'Allaitement de nuit';

  @override
  String get trendsNightDiapers => 'Couches de nuit';

  @override
  String get trendsNightSleep => 'Sommeil de nuit';

  @override
  String get trendsPerDay => 'par jour';

  @override
  String get trendsPottyTrips => 'Passages au pot';

  @override
  String get trendsPumpSessions => 'Séances de tirage';

  @override
  String get trendsPumpTime => 'Temps de tirage';

  @override
  String get trendsTitle => 'Tendances';

  @override
  String get trendsWakeWindow => 'Temps d\'éveil';

  @override
  String get trendsWetOnly => 'Urine seule';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get usersAdd => 'Ajouter';

  @override
  String get usersAddTitle => 'Ajouter un utilisateur';

  @override
  String usersAddTo(Object family) {
    return 'Ajouter à $family';
  }

  @override
  String get usersAdmin => 'Administrateur';

  @override
  String get usersAdminHint => 'Peut gérer les utilisateurs';

  @override
  String get usersAdminTag => 'admin';

  @override
  String get usersAsCaregiver => 'Comme membre';

  @override
  String get usersCanChangeLater => 'Modifiable plus tard';

  @override
  String usersCanSignIn(Object name) {
    return '$name peut maintenant se connecter';
  }

  @override
  String get usersEmail => 'Courriel';

  @override
  String get usersEnterEmail => 'Saisir un courriel';

  @override
  String get usersEnterName => 'Saisir un nom';

  @override
  String get usersIntro =>
      'Seuls les administrateurs peuvent créer des comptes sur ce serveur. Donnez aux personnes leur courriel et leur mot de passe ; elles pourront le changer sous Réglages → Compte.';

  @override
  String get usersMakeAdmin => 'Rendre admin';

  @override
  String usersManage(Object name) {
    return 'Gérer $name';
  }

  @override
  String usersNewPasswordFor(Object name) {
    return 'Nouveau mot de passe pour $name';
  }

  @override
  String usersNoLongerAdmin(Object name) {
    return '$name n\'est plus administrateur';
  }

  @override
  String usersNowAdmin(Object name) {
    return '$name est maintenant administrateur';
  }

  @override
  String get usersPassword => 'Mot de passe';

  @override
  String get usersPasswordHelp =>
      'Au moins 8 caractères. La personne sera déconnectée.';

  @override
  String usersPasswordSet(Object name) {
    return 'Nouveau mot de passe défini pour $name';
  }

  @override
  String get usersRemoveAccount => 'Supprimer le compte';

  @override
  String get usersRemoveAdmin => 'Retirer l\'admin';

  @override
  String get usersRemoveBody =>
      'Cette personne ne pourra plus se connecter. Ses familles et tout ce qui a été noté restent.';

  @override
  String usersRemoveTitle(Object name) {
    return 'Retirer $name ?';
  }

  @override
  String usersRemoved(Object name) {
    return '$name retiré';
  }

  @override
  String get usersSetPassword => 'Définir un nouveau mot de passe';

  @override
  String get usersTitle => 'Utilisateurs';

  @override
  String get wet => 'Urine';

  @override
  String get wetAndDirty => 'Mixte';

  @override
  String get yesterday => 'Hier';
}
