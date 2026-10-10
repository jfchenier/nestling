// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get activityBath => 'Baño';

  @override
  String get activityMassage => 'Masaje';

  @override
  String get activityMusic => 'Música';

  @override
  String get activityNailTrim => 'Corte de uñas';

  @override
  String get activityOutdoor => 'Al aire libre';

  @override
  String get activityPlay => 'Juego';

  @override
  String get activityRead => 'Lectura';

  @override
  String get activitySkinToSkin => 'Piel con piel';

  @override
  String get activitySwim => 'Natación';

  @override
  String get activityTummyTime => 'Tiempo boca abajo';

  @override
  String get activityVitamin => 'Vitamina';

  @override
  String get add => 'Añadir';

  @override
  String ageDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String ageDueIn(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return 'Nace en $_temp0';
  }

  @override
  String ageMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '1 mes',
    );
    return '$_temp0';
  }

  @override
  String agePair(Object big, Object small) {
    return '$big y $small';
  }

  @override
  String ageWeeks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas',
      one: '1 semana',
    );
    return '$_temp0';
  }

  @override
  String ageYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años',
      one: '1 año',
    );
    return '$_temp0';
  }

  @override
  String agoDuration(Object duration) {
    return 'hace $duration';
  }

  @override
  String get blowout => 'escape';

  @override
  String get bookAddMemory => 'Añadir un recuerdo';

  @override
  String get bookAddPhoto => 'Añadir una foto';

  @override
  String bookAgeOld(Object age) {
    return 'con $age';
  }

  @override
  String bookAsYouLookAt(Object name) {
    return 'mirando a $name';
  }

  @override
  String bookBananaIntro(Object name) {
    return 'El mismo plátano junto a $name cada mes: la mejor forma de ver lo rápido que pasa.';
  }

  @override
  String get bookBananaName => 'Un plátano de referencia';

  @override
  String get bookBeforeBirth => 'Antes de nacer';

  @override
  String bookBorn(Object date) {
    return 'Nacimiento: $date';
  }

  @override
  String get bookChangePhoto => 'Cambiar';

  @override
  String get bookChapter => 'Capítulo';

  @override
  String get bookChapterCelebrations => 'Celebraciones';

  @override
  String get bookChapterFirsts => 'Primeras veces';

  @override
  String get bookChapterGrowing => 'Creciendo';

  @override
  String get bookChapterHello => 'Hola, mundo';

  @override
  String bookChapterNumber(Object number) {
    return 'CAPÍTULO $number';
  }

  @override
  String get bookChapterSubCelebrations => 'Fiestas y días especiales';

  @override
  String get bookChapterSubFirsts => 'Cada novedad, mes a mes';

  @override
  String get bookChapterSubGrowing => 'Dientes, tamaño y lo rápido que pasa';

  @override
  String get bookChapterSubHello => 'El comienzo';

  @override
  String get bookChapterSubWaiting => 'Antes de que llegaras';

  @override
  String get bookChapterWaiting => 'Esperándote';

  @override
  String get bookDaysBeforeBirth => 'días antes de nacer';

  @override
  String get bookDeleteBody =>
      'Se eliminará para toda la familia, con su foto.';

  @override
  String get bookDeleteTitle => '¿Eliminar este recuerdo?';

  @override
  String get bookDueDate => 'Fecha prevista';

  @override
  String bookDueOn(Object date) {
    return 'Previsto el $date';
  }

  @override
  String get bookEditMemory => 'Editar recuerdo';

  @override
  String get bookEmptyBody =>
      'Elige una idea de abajo o añade la tuya: una foto, el día y unas palabras.';

  @override
  String get bookEmptyReadOnly =>
      'Los recuerdos aparecen aquí a medida que la familia los añade.';

  @override
  String get bookEmptyTitle => 'La primera página te espera';

  @override
  String get bookIdeaBabyShower => 'Baby shower';

  @override
  String get bookIdeaBaptism => 'Bautizo o bienvenida';

  @override
  String get bookIdeaBassinet => 'Ya no cabe en el moisés';

  @override
  String get bookIdeaBelly => 'La barriga';

  @override
  String get bookIdeaBirthday => 'Primer cumpleaños';

  @override
  String get bookIdeaBoyOrGirl => '¿Niño o niña?';

  @override
  String get bookIdeaCameHome => 'Llegada a casa';

  @override
  String get bookIdeaCarSeat => 'Silla de coche mirando al frente';

  @override
  String get bookIdeaChristmas => 'Primera Navidad';

  @override
  String get bookIdeaClapped => 'Aplaude';

  @override
  String get bookIdeaClothesSize => 'Talla de ropa más grande';

  @override
  String get bookIdeaCooed => 'Primeros gorjeos';

  @override
  String get bookIdeaCrawled => 'Gatea';

  @override
  String get bookIdeaCup => 'Bebe de un vaso';

  @override
  String get bookIdeaDada => 'Dice «papá»';

  @override
  String get bookIdeaDaycare => 'Primer día en la guardería';

  @override
  String get bookIdeaDiaperSize => 'Talla de pañal más grande';

  @override
  String get bookIdeaEaster => 'Primera Pascua';

  @override
  String get bookIdeaFathersDay => 'Primer Día del Padre';

  @override
  String get bookIdeaFirstBath => 'Primer baño';

  @override
  String get bookIdeaFirstBottle => 'Primer biberón';

  @override
  String get bookIdeaFirstDance => 'Primer baile';

  @override
  String get bookIdeaFirstLaugh => 'Primera risa';

  @override
  String get bookIdeaFirstShoes => 'Primeros zapatos';

  @override
  String get bookIdeaFirstSmile => 'Primera sonrisa';

  @override
  String get bookIdeaFirstSolid => 'Primera comida sólida';

  @override
  String get bookIdeaFirstSteps => 'Primeros pasos';

  @override
  String get bookIdeaFirstTooth => 'Primer diente';

  @override
  String get bookIdeaFirstWalk => 'Primer paseo';

  @override
  String get bookIdeaFirstWord => 'Primera palabra';

  @override
  String get bookIdeaFoundHands => 'Descubre sus manos';

  @override
  String get bookIdeaFoundOut => 'La gran noticia';

  @override
  String get bookIdeaFoundToes => 'Descubre sus pies';

  @override
  String get bookIdeaGrandparents => 'Conoce a los abuelos';

  @override
  String get bookIdeaHaircut => 'Primer corte de pelo';

  @override
  String get bookIdeaHalloween => 'Primer Halloween';

  @override
  String get bookIdeaHeartbeat => 'Escuchamos su corazón';

  @override
  String get bookIdeaHeldHead => 'Sostiene la cabeza';

  @override
  String get bookIdeaKiss => 'Da un beso';

  @override
  String get bookIdeaMama => 'Dice «mamá»';

  @override
  String get bookIdeaMothersDay => 'Primer Día de la Madre';

  @override
  String get bookIdeaOwnBottle => 'Sostiene su biberón';

  @override
  String get bookIdeaOwnName => 'Reconoce su nombre';

  @override
  String get bookIdeaOwnRoom => 'Su propio cuarto';

  @override
  String get bookIdeaPulledStand => 'Se pone de pie';

  @override
  String get bookIdeaReachedToy => 'Agarra un juguete';

  @override
  String get bookIdeaRolledOver => 'Se da la vuelta';

  @override
  String get bookIdeaSatUp => 'Se sienta sin ayuda';

  @override
  String get bookIdeaSleptNight => 'Duerme toda la noche';

  @override
  String get bookIdeaSnow => 'Primera nieve';

  @override
  String get bookIdeaSounds => 'Se gira hacia los sonidos';

  @override
  String get bookIdeaSpoon => 'Come con cuchara';

  @override
  String get bookIdeaStoodAlone => 'De pie sin apoyo';

  @override
  String get bookIdeaSwim => 'Primer chapuzón';

  @override
  String get bookIdeaTrip => 'Primer viaje';

  @override
  String get bookIdeaUltrasound => 'Primera ecografía';

  @override
  String get bookIdeaWaved => 'Dice adiós con la mano';

  @override
  String get bookIdeasForChapter => 'Ideas para este capítulo';

  @override
  String bookIdeasProgress(Object done, Object total) {
    return '$done de $total en el libro. Toca una para añadirla.';
  }

  @override
  String get bookIdeasToRemember => 'Ideas para recordar';

  @override
  String bookMemoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recuerdos',
      one: '1 recuerdo',
    );
    return '$_temp0';
  }

  @override
  String get bookNameHint => 'Primera sonrisa, se da la vuelta…';

  @override
  String get bookNameNeeded => '¿Qué pasó? Ponle un nombre al recuerdo.';

  @override
  String get bookNewMemory => 'Nuevo recuerdo';

  @override
  String get bookNewborn => 'Recién nacido';

  @override
  String bookNoBabyYet(Object family) {
    return 'El álbum del bebé aparecerá aquí cuando $family añada un bebé.';
  }

  @override
  String get bookNoMemories => 'Aún no hay recuerdos';

  @override
  String get bookPhotoAMonth => 'una foto al mes';

  @override
  String bookPhotoCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String bookPhotoNotSaved(Object error) {
    return 'El recuerdo se guardó, pero no su foto: $error';
  }

  @override
  String bookPhotoOf(Object name) {
    return 'Foto: $name';
  }

  @override
  String get bookPreparingPhoto => 'Preparando la foto…';

  @override
  String get bookSaveToBook => 'Guardar en el libro';

  @override
  String get bookSaving => 'Guardando…';

  @override
  String get bookSeeAll => 'Ver todo';

  @override
  String get bookSetDueDate => 'Indicar la fecha prevista';

  @override
  String get bookStory => 'La historia';

  @override
  String get bookStoryHint => 'Dónde estaban, quién estaba, cómo se sintió…';

  @override
  String get bookTabCelebrations => 'Fiestas';

  @override
  String get bookTabFirsts => 'Primeras';

  @override
  String get bookTabGrowing => 'Creciendo';

  @override
  String get bookTabHello => 'Hola';

  @override
  String get bookTabWaiting => 'Espera';

  @override
  String get bookTakeFirst => 'Tomar la primera';

  @override
  String get bookTeeth => 'Dientes';

  @override
  String get bookTheBookOf => 'El libro de';

  @override
  String get bookTheFamily => 'la familia';

  @override
  String get bookThisMonth => 'La de este mes';

  @override
  String bookTitle(Object name) {
    return 'El libro de $name';
  }

  @override
  String bookWeeksAlong(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas de embarazo',
      one: '1 semana de embarazo',
    );
    return '$_temp0';
  }

  @override
  String bookWeeksBeforeBirth(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas antes de nacer',
      one: '1 semana antes de nacer',
    );
    return '$_temp0';
  }

  @override
  String get bookWhatHappened => '¿Qué pasó?';

  @override
  String bookWhenAfterYears(Object count) {
    return 'después de los $count años';
  }

  @override
  String get bookWhenAnyTime => 'en cualquier momento';

  @override
  String get bookWhenAnythingSpecial => 'algo especial';

  @override
  String bookWhenAroundMonths(Object count) {
    return 'hacia los $count meses';
  }

  @override
  String bookWhenAroundWeeks(Object count) {
    return 'hacia las $count semanas';
  }

  @override
  String bookWhenAroundWeeksRange(Object from, Object to) {
    return 'hacia las $from–$to semanas';
  }

  @override
  String get bookWhenFirstDays => 'primeros días';

  @override
  String get bookWhenFirstWeeks => 'primeras semanas';

  @override
  String get bookWhenLastWeeks => 'últimas semanas';

  @override
  String bookWhenMonthsRange(Object from, Object to) {
    return '$from–$to meses';
  }

  @override
  String get bookWhenNowAndThen => 'de vez en cuando';

  @override
  String get bookWhenSpring => 'primavera';

  @override
  String get bookWhenTest => 'la prueba';

  @override
  String bookWhenWeeksRange(Object from, Object to) {
    return '$from–$to semanas';
  }

  @override
  String get bookWhenWithFirstSteps => 'con los primeros pasos';

  @override
  String get bookWhichTooth => '¿Qué diente?';

  @override
  String get bookYourOwn => 'Tu idea';

  @override
  String get both => 'Ambos';

  @override
  String get breastfeedPlusBottle => 'Pecho + biberón';

  @override
  String get calendarDiapers => 'Pañales';

  @override
  String get calendarFeeds => 'Tomas';

  @override
  String get calendarNextWeek => 'Semana siguiente';

  @override
  String get calendarOther => 'Otros';

  @override
  String get calendarPrevWeek => 'Semana anterior';

  @override
  String get calendarTitle => 'Calendario';

  @override
  String get cancel => 'Cancelar';

  @override
  String get childAddPhoto => 'Añadir una foto';

  @override
  String get childBirthDate => 'Fecha de nacimiento (o prevista)';

  @override
  String get childBirthDateMissing =>
      'Elige una fecha de nacimiento (o prevista)';

  @override
  String get childBirthDateRequired => 'Fecha de nacimiento (o prevista) *';

  @override
  String get childBoy => 'Niño';

  @override
  String get childChangePhoto => 'Cambiar foto';

  @override
  String get childChoosePhoto => 'Elegir una foto';

  @override
  String get childDelete => 'Eliminar bebé';

  @override
  String childDeleteBody(Object name) {
    return 'Esto elimina para siempre a $name y todo lo registrado, para todos los cuidadores. No se puede deshacer.';
  }

  @override
  String childDeleteTitle(Object name) {
    return '¿Eliminar a $name?';
  }

  @override
  String childEditTitle(Object name) {
    return 'Editar a $name';
  }

  @override
  String get childEnterName => 'Escribe un nombre';

  @override
  String get childGirl => 'Niña';

  @override
  String get childName => 'Nombre';

  @override
  String get childSexUnknown => 'Desconocido';

  @override
  String get childTapToChoose => 'Toca para elegir';

  @override
  String get close => 'Cerrar';

  @override
  String get colorBlack => 'Negro';

  @override
  String get colorBrown => 'Marrón';

  @override
  String get colorGray => 'Gris';

  @override
  String get colorGreen => 'Verde';

  @override
  String get colorRed => 'Rojo';

  @override
  String get colorYellow => 'Amarillo';

  @override
  String commonChangeDay(Object day) {
    return 'Cambiar el día, $day';
  }

  @override
  String commonChangeTime(Object time) {
    return 'Cambiar la hora, $time';
  }

  @override
  String commonSomethingWrong(Object error) {
    return 'Algo salió mal: $error';
  }

  @override
  String commonTypeToConfirm(Object text) {
    return 'Escribe $text para confirmar.';
  }

  @override
  String get consistencyMucousy => 'Mucosa';

  @override
  String get consistencyMushy => 'Pastosa';

  @override
  String get consistencyPebbles => 'En bolitas';

  @override
  String get consistencyRunny => 'Líquida';

  @override
  String get consistencySolid => 'Dura';

  @override
  String get dayHoursDayStarts => 'Empieza el día';

  @override
  String get dayHoursDaytime => 'Día';

  @override
  String get dayHoursIntro =>
      'Estas horas deciden si una toma, un pañal o un sueño cuenta como de día o de noche en Tendencias. El sueño que empieza de día es una siesta. Se aplican a toda la familia.';

  @override
  String get dayHoursNightStarts => 'Empieza la noche';

  @override
  String get dayHoursStartBeforeEnd => 'El día debe empezar antes de terminar.';

  @override
  String daysAgo(Object count) {
    return 'hace $count días';
  }

  @override
  String get defaultBabyName => 'Bebé';

  @override
  String get delete => 'Eliminar';

  @override
  String get dirty => 'Caca';

  @override
  String get done => 'Listo';

  @override
  String get dry => 'Seco';

  @override
  String durDaysHours(Object days, Object hours) {
    return '$days d $hours h';
  }

  @override
  String durHoursMinutes(Object hours, Object minutes) {
    return '$hours h $minutes min';
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
  String get edit => 'Editar';

  @override
  String endedSide(Object side) {
    return 'terminó $side';
  }

  @override
  String get familyAccount => 'Cuenta';

  @override
  String get familyAddBaby => 'Añadir un bebé';

  @override
  String get familyAndroidOnly => 'Disponible en la app de Android';

  @override
  String get familyApiToken => 'Token de API';

  @override
  String get familyApiTokenHint => 'Para Home Assistant o scripts';

  @override
  String get familyAppearance => 'Apariencia';

  @override
  String get familyAtLeast8 => 'Al menos 8 caracteres';

  @override
  String get familyBabies => 'Bebés';

  @override
  String get familyBackedUp => 'Copia guardada en Google Drive';

  @override
  String get familyBackupDrive => 'Copia en Google Drive';

  @override
  String get familyBackupHint =>
      'Guarda una copia en tu cuenta de Google, una vez al día';

  @override
  String get familyBookOnlyHint =>
      'Puedes ver el álbum del bebé. Pide más acceso a un propietario de la familia.';

  @override
  String familyBorn(Object date) {
    return 'nació el $date';
  }

  @override
  String familyCaregiverCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuidadores',
      one: '1 cuidador',
    );
    return '$_temp0';
  }

  @override
  String get familyCaregivers => 'Cuidadores';

  @override
  String get familyChangePassword => 'Cambiar contraseña';

  @override
  String get familyChooseAnotherFile => 'Elegir otro archivo';

  @override
  String get familyChooseCsv => 'Elegir el archivo CSV';

  @override
  String get familyCodeCopied => 'Código copiado';

  @override
  String get familyContinue => 'Continuar';

  @override
  String get familyCopy => 'Copiar';

  @override
  String get familyCurrentPassword => 'Contraseña actual';

  @override
  String get familyDayNight => 'Día y noche';

  @override
  String familyDaytime(Object end, Object start) {
    return 'Día $start–$end';
  }

  @override
  String get familyDelete => 'Eliminar familia';

  @override
  String get familyDeleteBody =>
      'Esto elimina para siempre la familia, sus bebés y todo lo registrado, para todos los cuidadores. No se puede deshacer.';

  @override
  String familyDeleteTitle(Object name) {
    return '¿Eliminar $name?';
  }

  @override
  String familyDriveOn(Object account) {
    return 'Activado · $account';
  }

  @override
  String get familyDriveSync => 'Sincronizar con Google Drive';

  @override
  String get familyDriveSyncBody =>
      'Tus teléfonos se dejarán sus cambios en una carpeta compartida de Google Drive, para ponerse al día aunque no estén abiertos a la vez ni en la misma Wi-Fi.\n\nGoogle te pedirá permiso para que Nestling use tu Drive. Todo lo de la carpeta está cifrado: solo los teléfonos de tu familia pueden leerlo. Actívalo en cada teléfono.';

  @override
  String get familyDriveSyncFailed =>
      'No se pudo sincronizar la última vez. Lo volverá a intentar.';

  @override
  String get familyDriveSyncHint =>
      'Para teléfonos que no están abiertos a la vez ni en la misma Wi-Fi';

  @override
  String get familyDriveSyncOn => 'La sincronización con Drive está activada';

  @override
  String get familyEnterCurrentPassword => 'Escribe tu contraseña actual';

  @override
  String get familyExport => 'Exportar datos';

  @override
  String get familyExportHint => 'Todo lo de esta familia en un archivo CSV';

  @override
  String familyExported(Object name) {
    return '$name exportado';
  }

  @override
  String get familyImperialUnits => 'Unidades imperiales';

  @override
  String get familyImportAccount => 'Cuenta de Nara';

  @override
  String familyImportAccountBody(Object name) {
    return 'Inicia sesión con tu cuenta de Nara para copiar tu historial a $name. Tu contraseña de Nara se usa una vez y nunca se guarda.';
  }

  @override
  String get familyImportComplete => 'Importación completa';

  @override
  String familyImportCsvBody(Object name) {
    return 'Exporta tus datos desde la app Nara (te da un archivo .csv) y elige ese archivo aquí. Todo va a $name; importar de nuevo el mismo archivo actualiza en lugar de duplicar.';
  }

  @override
  String get familyImportExportFile => 'Archivo exportado';

  @override
  String get familyImportNara => 'Importar desde Nara';

  @override
  String get familyImportNaraHint => 'Trae tu historial de Nara Baby';

  @override
  String familyImportRecords(num count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count registros a $name',
      one: 'Importar 1 registro a $name',
    );
    return '$_temp0';
  }

  @override
  String familyImportedUpdated(Object imported, Object updated) {
    return '$imported nuevos · $updated actualizados';
  }

  @override
  String get familyInviteBody =>
      'La persona crea una cuenta en este servidor y luego introduce este código en «Unirse a una familia». Sirve una sola vez y caduca en 7 días.';

  @override
  String get familyInviteBookOnly => 'Esa persona solo verá el álbum del bebé.';

  @override
  String get familyInviteCaregiver => 'Invitar a un cuidador';

  @override
  String get familyInviteCode => 'Código de invitación';

  @override
  String get familyInviteHint => 'Pareja, abuelos, niñera…';

  @override
  String get familyJoin => 'Unirse a una familia';

  @override
  String get familyJoinAnother => 'Unirse a otra familia';

  @override
  String get familyJoinAnotherHint =>
      'Con un código de invitación de su propietario';

  @override
  String get familyJoinButton => 'Unirse';

  @override
  String familyLastBackup(Object account, Object date) {
    return 'Última copia $date · $account';
  }

  @override
  String familyLeave(Object family) {
    return 'Salir de $family';
  }

  @override
  String get familyLeaveAction => 'Salir';

  @override
  String get familyLeaveBody =>
      'Ya no verás su álbum del bebé, salvo que te inviten de nuevo.';

  @override
  String familyLeaveTitle(Object family) {
    return '¿Salir de $family?';
  }

  @override
  String get familyMedicines => 'Medicinas y recordatorios';

  @override
  String get familyName => 'Nombre';

  @override
  String get familyNaraEmail => 'Correo de Nara';

  @override
  String get familyNaraPassword => 'Contraseña de Nara';

  @override
  String familyNaraProfile(Object name) {
    return 'Perfil de Nara: $name';
  }

  @override
  String get familyNewPassword => 'Nueva contraseña';

  @override
  String get familyNewToken => 'Nuevo token de API';

  @override
  String get familyNext => 'Siguiente';

  @override
  String get familyOtherDevicesSignedOut =>
      'Se cerrará la sesión en los demás dispositivos';

  @override
  String get familyPairPhone => 'Vincular un teléfono';

  @override
  String get familyPairPhoneHint =>
      'El teléfono de tu pareja se sincroniza con este por Wi-Fi';

  @override
  String get familyPasswordChanged => 'Contraseña cambiada';

  @override
  String familyPendingLost(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cambios hechos sin conexión aún no llegaron al servidor y se perderán.',
      one: '1 cambio hecho sin conexión aún no llegó al servidor y se perderá.',
    );
    return '$_temp0';
  }

  @override
  String get familyPreview => 'Vista previa (no se guarda nada)';

  @override
  String get familyPreviewAgain => 'Ver de nuevo';

  @override
  String get familyReadyToImport => 'Listo para importar';

  @override
  String familyRecords(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registros',
      one: '1 registro',
    );
    return '$_temp0';
  }

  @override
  String get familyRemoveDataBody =>
      'Todo lo registrado aquí se borra de este teléfono. Los teléfonos vinculados y tu copia en Google Drive conservan sus datos.';

  @override
  String get familyRemoveDataTitle =>
      '¿Quitar los datos de Nestling de este teléfono?';

  @override
  String get familyRemoveFromPhone => 'Quitar de este teléfono';

  @override
  String familyRemoveMemberBody(Object family) {
    return 'Perderá el acceso a $family.';
  }

  @override
  String familyRemoveMemberTitle(Object name) {
    return '¿Quitar a $name?';
  }

  @override
  String get familyServer => 'Servidor';

  @override
  String familyServerValue(Object server) {
    return 'Servidor: $server';
  }

  @override
  String get familySettings => 'Ajustes';

  @override
  String get familySignOutAnyway => '¿Cerrar sesión de todos modos?';

  @override
  String familySkipped(Object list) {
    return 'Omitidos: $list';
  }

  @override
  String familySummarySensor(Object url) {
    return 'Sensor de resumen: $url';
  }

  @override
  String familySyncedAgo(Object ago) {
    return 'Sincronizado $ago';
  }

  @override
  String familySyncedAgoAccount(Object account, Object ago) {
    return 'Sincronizado $ago · $account';
  }

  @override
  String get familyThemeDark => 'Oscuro';

  @override
  String get familyThemeLight => 'Claro';

  @override
  String get familyThisBaby => 'este bebé';

  @override
  String get familyTimeZone => 'Zona horaria';

  @override
  String get familyTimeZoneHint =>
      'Define cuándo empieza cada día para los totales';

  @override
  String get familyTitle => 'Familia';

  @override
  String get familyTokenBody =>
      'Cópialo ahora: no se volverá a mostrar. Úsalo como «Authorization: Bearer <token>».';

  @override
  String get familyTypeDiapers => 'Pañales';

  @override
  String get familyTypeFeeds => 'Tomas';

  @override
  String get familyTypeFirsts => 'Primeras veces';

  @override
  String get familyTypeGrowth => 'Crecimiento';

  @override
  String get familyTypeHealth => 'Salud';

  @override
  String get familyTypeNotes => 'Notas';

  @override
  String get familyTypePump => 'Extractor';

  @override
  String get familyTypeRoutine => 'Rutina';

  @override
  String get familyTypeSleep => 'Sueño';

  @override
  String get familyUsersHint =>
      'Crear y gestionar las cuentas de este servidor';

  @override
  String get familyWithoutServer => 'Sin servidor';

  @override
  String get familyWithoutServerHint =>
      'Guardado en este teléfono y en los vinculados';

  @override
  String familyYou(Object name) {
    return '$name (tú)';
  }

  @override
  String get formAddNote => 'Añadir una nota…';

  @override
  String get formAmount => 'Cantidad';

  @override
  String get formBlowout => 'Escape';

  @override
  String get formBrandOptional => 'Marca (opcional)';

  @override
  String get formChoose => 'Elegir';

  @override
  String get formContinue => 'Continuar';

  @override
  String get formDeleteMessage => 'Se eliminará para toda la familia.';

  @override
  String get formDeleteTitle => '¿Eliminar esta entrada?';

  @override
  String get formDiaperRash => 'Dermatitis del pañal';

  @override
  String get formDiaperWetDirtyDry => 'El pañal: ¿pipí, caca o seco?';

  @override
  String get formDoctor => 'Médico';

  @override
  String get formDose => 'Dosis';

  @override
  String get formDuration => 'Duración';

  @override
  String formEditTitle(Object what) {
    return 'Editar: $what';
  }

  @override
  String get formFellAsleep => 'Se durmió';

  @override
  String get formFoods => 'Alimentos';

  @override
  String get formFormulaName => 'Fórmula';

  @override
  String get formHeadSize => 'Perímetro cefálico';

  @override
  String get formHeight => 'Talla';

  @override
  String get formMeasured => 'Medido';

  @override
  String formMedLimited(Object count, Object time) {
    return 'Ya $count dosis en 24 horas. La próxima se permite a las $time.';
  }

  @override
  String formMedTooSoon(Object last, Object time) {
    return 'Última dosis a las $last. La próxima se permite a las $time.';
  }

  @override
  String get formMilk => 'Leche';

  @override
  String get formNotes => 'Notas';

  @override
  String get formPottyWetOrDirty => '¿Pipí, caca o ambos?';

  @override
  String get formSaveChanges => 'Guardar cambios';

  @override
  String get formSleepEndMissing =>
      '¿Cuándo terminó el sueño? Usa el temporizador para una siesta en curso.';

  @override
  String get formSleepEndShort => '¿Cuándo terminó el sueño?';

  @override
  String get formStartTime => 'Inicio';

  @override
  String get formStartedOn => 'Empezó con';

  @override
  String get formTextureColor => 'Textura y color';

  @override
  String get formTime => 'Hora';

  @override
  String get formTitleBottle => 'Biberón';

  @override
  String get formTitleCombo => 'Pecho + biberón';

  @override
  String get formTotalTime => 'Tiempo total';

  @override
  String get formType => 'Tipo';

  @override
  String get formUnit => 'Unidad';

  @override
  String get formWeight => 'Peso';

  @override
  String get formWhatCame => 'Qué hizo';

  @override
  String get formWhen => 'Cuándo';

  @override
  String get formWhere => 'Dónde';

  @override
  String get formWokeUp => 'Se despertó';

  @override
  String get growthAddBirthDate => 'Añadir fecha de nacimiento';

  @override
  String growthAddBirthDateNotice(Object name) {
    return 'Añade la fecha de nacimiento de $name para comparar con las curvas de crecimiento de la OMS.';
  }

  @override
  String get growthAddMeasurement => 'Añadir una medida';

  @override
  String get growthAge => 'Edad';

  @override
  String growthAgeDays(Object days) {
    return '$days d';
  }

  @override
  String growthAgeMonthsDays(Object days, Object months) {
    return '$months m $days d';
  }

  @override
  String growthAgeYearsMonths(Object months, Object years) {
    return '$years a $months m';
  }

  @override
  String get growthBoys => 'Niños';

  @override
  String get growthBoysPercentile => 'Percentil (niños)';

  @override
  String get growthCompareWith => 'Comparar con';

  @override
  String growthCurvesNote(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'niñas',
      'other': 'niños',
    });
    return 'Curvas: patrones de crecimiento infantil de la OMS ($_temp0, de 0 a 24 meses), percentiles 2 a 98. Una sola medida dice poco; sigue la tendencia y consulta al médico ante cualquier duda.';
  }

  @override
  String get growthGirls => 'Niñas';

  @override
  String get growthGirlsPercentile => 'Percentil (niñas)';

  @override
  String get growthHead => 'Cabeza';

  @override
  String get growthLength => 'Talla';

  @override
  String get growthMonths => 'meses';

  @override
  String get growthNoneHead => 'Todavía no hay ningún perímetro cefálico.';

  @override
  String get growthNoneLength => 'Todavía no hay ninguna talla.';

  @override
  String get growthNoneWeight => 'Todavía no hay ningún peso.';

  @override
  String growthPercentile(Object rank) {
    return 'percentil $rank';
  }

  @override
  String get growthTitle => 'Curvas de crecimiento';

  @override
  String get growthWeeks => 'semanas';

  @override
  String get growthWeight => 'Peso';

  @override
  String headShort(Object value) {
    return 'Cabeza $value';
  }

  @override
  String get healthAppointment => 'Cita';

  @override
  String get healthMedicine => 'Medicamento';

  @override
  String get healthSymptom => 'Síntoma';

  @override
  String get healthTemperature => 'Temperatura';

  @override
  String get healthVaccine => 'Vacuna';

  @override
  String get homeAddBaby => 'Añadir un bebé';

  @override
  String get homeAddNote => 'Añadir una nota';

  @override
  String get homeAsleep => 'durmiendo';

  @override
  String homeAwakeFor(Object duration) {
    return 'Despierto desde hace $duration';
  }

  @override
  String homeAwakeLast(Object duration) {
    return 'despierto · durmió $duration';
  }

  @override
  String get homeBabyBook => 'Álbum del bebé';

  @override
  String homeBreastCount(Object count) {
    return '$count al pecho';
  }

  @override
  String get homeCaptionBottle => 'biberón';

  @override
  String get homeCaptionPotty => 'orinal';

  @override
  String get homeCardFeed => 'Tomas';

  @override
  String get homeCardFirsts => 'Primeras veces';

  @override
  String homeCardHistory(Object title) {
    return 'Historial: $title';
  }

  @override
  String get homeCardRoutine => 'Rutina';

  @override
  String get homeChartsShort => 'Gráficas';

  @override
  String get homeDiaperReminder => 'Recordatorio de pañal';

  @override
  String get homeDiapersIn24h => 'pañales en 24 h';

  @override
  String get homeDiapersToday => 'pañales hoy';

  @override
  String get homeDoseNow => 'Ya se puede dar la siguiente dosis';

  @override
  String homeDosesIn24h(Object given, Object max) {
    return '$given de $max en 24 h';
  }

  @override
  String get homeFeedReminder => 'Recordatorio de toma';

  @override
  String get homeFeedsIn24h => 'tomas en 24 h';

  @override
  String get homeFeedsToday => 'tomas hoy';

  @override
  String get homeGive => 'Dar';

  @override
  String get homeGrowthCharts => 'Curvas de crecimiento';

  @override
  String homeHead(Object value) {
    return 'cabeza $value';
  }

  @override
  String get homeHide => 'Ocultar';

  @override
  String get homeHistoryShort => 'Historial';

  @override
  String homeLabelPaused(Object label) {
    return '$label · en pausa';
  }

  @override
  String get homeLastSide => 'último lado';

  @override
  String homeLiveBreastfeed(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'derecho',
      'other': 'izquierdo',
    });
    return 'pecho · $_temp0';
  }

  @override
  String get homeLiveTooltip =>
      'En directo: los cambios de otros cuidadores aparecen al instante';

  @override
  String get homeLog => 'Registrar';

  @override
  String homeLogCard(Object title) {
    return 'Registrar: $title';
  }

  @override
  String get homeLogFeed => 'Registrar una toma';

  @override
  String homeNaps(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count siestas',
      one: '1 siesta',
    );
    return '$_temp0';
  }

  @override
  String get homeNavBook => 'Álbum';

  @override
  String get homeNavCalendar => 'Calendario';

  @override
  String get homeNavHome => 'Inicio';

  @override
  String get homeNavTimeline => 'Historial';

  @override
  String get homeNavTrends => 'Tendencias';

  @override
  String homeNextDoseOn(Object date, Object time) {
    return 'Próxima dosis el $date a las $time';
  }

  @override
  String homeNextDoseToday(Object time) {
    return 'Próxima dosis a las $time';
  }

  @override
  String homeNextDoseTomorrow(Object time) {
    return 'Próxima dosis mañana a las $time';
  }

  @override
  String homeNightSleep(Object duration) {
    return '$duration noche';
  }

  @override
  String homeNoDiaperFor(Object duration) {
    return 'Sin cambio de pañal desde hace $duration';
  }

  @override
  String get homeNoDoseYet => 'Aún no se ha dado ninguna dosis';

  @override
  String homeNoFeedFor(Object duration) {
    return 'Sin tomas desde hace $duration';
  }

  @override
  String homeNoPumpFor(Object duration) {
    return 'Sin extracción desde hace $duration';
  }

  @override
  String get homeNotSyncedYet => 'sin sincronizar';

  @override
  String get homeOffline => 'sin conexión';

  @override
  String homeOfflinePending(Object count) {
    return 'sin conexión · $count por sincronizar';
  }

  @override
  String homeOfflineTooltip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sin conexión: sigue registrando; $count cambios se sincronizarán cuando vuelva el servidor',
      one:
          'Sin conexión: sigue registrando; 1 cambio se sincronizará cuando vuelva el servidor',
      zero:
          'Sin conexión: sigue registrando; los cambios se sincronizarán cuando vuelva el servidor',
    );
    return '$_temp0';
  }

  @override
  String get homePaused => 'en pausa';

  @override
  String homePottyCount(Object count) {
    return '$count orinal';
  }

  @override
  String get homePumpReminder => 'Recordatorio de extracción';

  @override
  String get homePumped => 'extraído';

  @override
  String get homePumping => 'Extrayendo';

  @override
  String get homeReconnecting => 'Reconectando…';

  @override
  String get homeServerlessAlone =>
      'Sin servidor: guardado en este teléfono. Vincula otro teléfono en Familia para compartir.';

  @override
  String homeServerlessPeers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sin servidor: se sincroniza con $count teléfonos vinculados en la misma Wi-Fi',
      one:
          'Sin servidor: se sincroniza con 1 teléfono vinculado en la misma Wi-Fi',
    );
    return '$_temp0';
  }

  @override
  String homeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Lado derecho',
      'other': 'Lado izquierdo',
    });
    return '$_temp0';
  }

  @override
  String homeSince(Object time) {
    return 'desde las $time';
  }

  @override
  String get homeSleepIn24h => 'sueño en 24 h';

  @override
  String get homeSleepReminder => 'Recordatorio de sueño';

  @override
  String get homeSleepToday => 'sueño hoy';

  @override
  String get homeSleeping => 'Durmiendo';

  @override
  String homeSolidsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sólidos',
      one: '1 sólido',
    );
    return '$_temp0';
  }

  @override
  String get homeStart => 'Iniciar';

  @override
  String get homeSwitchBaby => 'Cambiar de bebé';

  @override
  String get homeSyncLocal => 'en este teléfono';

  @override
  String homeSynced(Object ago) {
    return 'sincronizado $ago';
  }

  @override
  String get homeSyncing => 'sincronizando';

  @override
  String get homeSyncingTooltip =>
      'Sincronizando los cambios hechos sin conexión…';

  @override
  String get homeTapToLog => 'Toca para registrar';

  @override
  String homeWetDirtyCounts(Object dirty, Object wet) {
    return '$wet pipí · $dirty caca';
  }

  @override
  String homeWoke(Object ago) {
    return 'despertó $ago';
  }

  @override
  String get inThePotty => 'En el orinal';

  @override
  String get justNow => 'justo ahora';

  @override
  String get kindActivity => 'Actividad';

  @override
  String get kindBottle => 'Biberón';

  @override
  String get kindBreastfeed => 'Pecho';

  @override
  String get kindCombo => 'Mixto';

  @override
  String get kindDiaper => 'Pañal';

  @override
  String get kindGrowth => 'Crecimiento';

  @override
  String get kindHealth => 'Salud';

  @override
  String get kindMilestone => 'Hito';

  @override
  String get kindNote => 'Nota';

  @override
  String get kindPotty => 'Orinal';

  @override
  String get kindPump => 'Extractor';

  @override
  String get kindSleep => 'Sueño';

  @override
  String get kindSolids => 'Sólidos';

  @override
  String get kindTemperature => 'Temperatura';

  @override
  String get language => 'Idioma';

  @override
  String get left => 'Izquierdo';

  @override
  String get leftShort => 'I';

  @override
  String lengthShort(Object value) {
    return 'T $value';
  }

  @override
  String get localNeedsServer =>
      'Esto necesita un servidor Nestling. Sin servidor, todo se queda en tus teléfonos.';

  @override
  String get localPhotosNeedServer =>
      'Las fotos de los recuerdos necesitan la app de Android o un servidor Nestling.';

  @override
  String get locationArms => 'En brazos';

  @override
  String get locationBassinet => 'Moisés';

  @override
  String get locationBed => 'Cama';

  @override
  String get locationCar => 'Coche';

  @override
  String get locationCrib => 'Cuna';

  @override
  String get locationStroller => 'Carriola';

  @override
  String get loginAskAdmin =>
      '¿Aún no tienes cuenta? Pide a quien administra este servidor Nestling que te cree una.';

  @override
  String get loginContinue => 'Continuar';

  @override
  String get loginCreateAccount => 'Crear cuenta';

  @override
  String get loginCreateAdmin => 'Crear cuenta de administrador';

  @override
  String get loginCreateYourAccount => 'Crea tu cuenta';

  @override
  String get loginEmail => 'Correo electrónico';

  @override
  String get loginEnterEmail => 'Escribe tu correo';

  @override
  String get loginEnterName => 'Escribe tu nombre';

  @override
  String get loginEnterPassword => 'Escribe tu contraseña';

  @override
  String get loginEnterServer => 'Escribe la dirección de tu servidor Nestling';

  @override
  String get loginHaveAccount => 'Ya tengo una cuenta';

  @override
  String get loginNewHere => '¿Eres nuevo? Crea una cuenta';

  @override
  String get loginNewServer =>
      'Servidor nuevo: crea la cuenta de administrador.\nDespués añadirás a los demás cuidadores.';

  @override
  String get loginNoServerIntro =>
      '¿No tienes servidor en casa? Nestling también funciona solo: tus datos se quedan en tu teléfono, y puedes vincular el teléfono de tu pareja por Wi-Fi y hacer copias en Google Drive.';

  @override
  String get loginPassword => 'Contraseña';

  @override
  String get loginPasswordMin => 'Al menos 8 caracteres';

  @override
  String get loginServerAddress => 'Dirección del servidor';

  @override
  String loginServerLink(Object server) {
    return 'Servidor: $server';
  }

  @override
  String get loginServerless => 'Usar sin servidor';

  @override
  String get loginServerlessIntro =>
      'Todo lo que registres se guarda en este teléfono. ¿Cómo te llamas? Los demás cuidadores lo verán.';

  @override
  String get loginSignIn => 'Iniciar sesión';

  @override
  String get loginWelcomeBack => 'Hola de nuevo';

  @override
  String get loginYourName => 'Tu nombre';

  @override
  String get milkBreastMilk => 'Leche materna';

  @override
  String get milkFormula => 'Fórmula';

  @override
  String get milkMixed => 'Mixta';

  @override
  String get notSet => 'Sin definir';

  @override
  String get notifBreastfeedPaused => 'Pecho en pausa';

  @override
  String notifBreastfeeding(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'right': 'Pecho · lado derecho',
      'other': 'Pecho · lado izquierdo',
    });
    return '$_temp0';
  }

  @override
  String get notifChipPaused => 'Pausa';

  @override
  String notifPausedBody(Object duration) {
    return '$duration hasta ahora · toca para reanudar';
  }

  @override
  String get notifPumpPaused => 'Extracción en pausa';

  @override
  String get notifPumping => 'Extrayendo';

  @override
  String notifRunningBody(Object time) {
    return 'Desde las $time · toca para abrir';
  }

  @override
  String get notifSleepPaused => 'Sueño en pausa';

  @override
  String get notifSleeping => 'Durmiendo';

  @override
  String notifTitle(Object child, Object what) {
    return '$child · $what';
  }

  @override
  String get now => 'Ahora';

  @override
  String get ok => 'Aceptar';

  @override
  String get onboardingAddBaby => 'Añadir un bebé';

  @override
  String onboardingAddLittleOne(Object family) {
    return 'Ahora añade a tu bebé a $family.';
  }

  @override
  String get onboardingBack => 'Atrás';

  @override
  String get onboardingCreateFamily => 'Crear familia';

  @override
  String get onboardingFamilyName => 'Nombre de la familia';

  @override
  String onboardingHi(Object name) {
    return '¡Hola, $name!';
  }

  @override
  String get onboardingIntro =>
      'Crea una familia para seguir a tu bebé, o únete a una con un código de invitación de tu pareja.';

  @override
  String get onboardingIntroServerless =>
      'Crea una familia para seguir a tu bebé, o únete a la del teléfono de tu pareja.';

  @override
  String get onboardingInviteCode => 'Código de invitación';

  @override
  String get onboardingJoinFamily => 'Unirse a la familia';

  @override
  String get onboardingJoinWithCode => 'Unirse con un código de vinculación';

  @override
  String get onboardingNoBackup =>
      'No hay ninguna copia de Nestling en esta cuenta de Google.';

  @override
  String get onboardingOrJoin => 'O únete a una';

  @override
  String get onboardingOrJoinPartner => 'O únete a la de tu pareja';

  @override
  String get onboardingOurFamily => 'Nuestra familia';

  @override
  String get onboardingPairIntro =>
      'Si otro teléfono ya sigue a tu bebé, vincúlalo: todo se copia y se mantiene sincronizado.';

  @override
  String get onboardingRestoreDrive => 'Restaurar desde Google Drive';

  @override
  String get onboardingStartFamily => 'Crear una familia';

  @override
  String get pagesAge => 'Edad';

  @override
  String get pagesAndAlso => 'Y también';

  @override
  String get pagesAt => 'Hora';

  @override
  String get pagesBirth => 'Al nacer';

  @override
  String get pagesBirthGrowthHint =>
      'El peso y la talla al nacer vienen de una entrada de Crecimiento del día del nacimiento.';

  @override
  String get pagesBorn => 'Nacimiento';

  @override
  String get pagesBornNoDate =>
      'Añade la fecha de nacimiento en Familia → el bebé para empezar esta página.';

  @override
  String get pagesBornPrompt =>
      'Toca para añadir la hora, el lugar, el pelo y los ojos.';

  @override
  String get pagesBornTitle => 'El día que naciste';

  @override
  String get pagesEyes => 'Ojos';

  @override
  String get pagesFullName => 'Nombre completo';

  @override
  String get pagesGrowthEmpty =>
      'Anota el peso y la talla en Crecimiento y cada mes aparecerá aquí.';

  @override
  String get pagesGrowthNoBirth =>
      'Añade la fecha de nacimiento para ver el crecimiento mes a mes.';

  @override
  String get pagesHair => 'Pelo';

  @override
  String get pagesHead => 'Cabeza';

  @override
  String get pagesHintEyes => 'Azul intenso';

  @override
  String get pagesHintHair => 'Oscuro y abundante';

  @override
  String get pagesHintMeaning => 'Su significado u origen';

  @override
  String get pagesHintNicknames => 'Cómo te llamamos en casa';

  @override
  String get pagesHintOthers => 'Los otros finalistas';

  @override
  String get pagesHintPlace => 'El hospital, la casa, la ciudad';

  @override
  String get pagesHintRemember => 'El primer llanto, quién estaba, el tiempo…';

  @override
  String get pagesHintWhy => 'De quién o de dónde viene';

  @override
  String get pagesHintWorldNote => 'Algo más sobre ese año';

  @override
  String get pagesLength => 'Talla';

  @override
  String get pagesMeasured => 'Talla';

  @override
  String get pagesMonthByMonth => 'Mes a mes';

  @override
  String pagesMonthsShort(Object count) {
    return '$count m';
  }

  @override
  String get pagesMoon => 'La luna';

  @override
  String get pagesMoonFirstQuarter => 'Cuarto creciente';

  @override
  String get pagesMoonFull => 'Luna llena';

  @override
  String get pagesMoonLastQuarter => 'Cuarto menguante';

  @override
  String get pagesMoonNew => 'Luna nueva';

  @override
  String get pagesMoonWaningCrescent => 'Luna menguante';

  @override
  String get pagesMoonWaningGibbous => 'Gibosa menguante';

  @override
  String get pagesMoonWaxingCrescent => 'Luna creciente';

  @override
  String get pagesMoonWaxingGibbous => 'Gibosa creciente';

  @override
  String get pagesNameMeaning => 'Qué significa';

  @override
  String get pagesNameOthers => 'Otros nombres que pensamos';

  @override
  String get pagesNamePrompt => 'Toca para escribir por qué lo elegiste.';

  @override
  String get pagesNameTitle => 'Tu nombre';

  @override
  String get pagesNameWhy => 'Por qué lo elegimos';

  @override
  String get pagesNicknames => 'Apodos';

  @override
  String get pagesPriceBread => 'Pan';

  @override
  String get pagesPriceCar => 'Un coche nuevo';

  @override
  String get pagesPriceCoffee => 'Un café';

  @override
  String get pagesPriceDiapers => 'Pañales';

  @override
  String get pagesPriceGas => 'Gasolina';

  @override
  String get pagesPriceHint => 'Precio';

  @override
  String get pagesPriceHouse => 'Una casa';

  @override
  String get pagesPriceMilk => 'Leche';

  @override
  String get pagesPriceMovie => 'Una entrada de cine';

  @override
  String get pagesPriceRent => 'Alquiler';

  @override
  String get pagesSaveToBook => 'Guardar en el libro';

  @override
  String get pagesSaving => 'Guardando…';

  @override
  String get pagesSetTime => 'Elegir';

  @override
  String pagesTapToEdit(Object title) {
    return '$title. Toca para editar.';
  }

  @override
  String get pagesTimeOfBirth => 'Hora de nacimiento';

  @override
  String get pagesWeRemember => 'Recordamos';

  @override
  String get pagesWeighed => 'Peso';

  @override
  String get pagesWeight => 'Peso';

  @override
  String get pagesWhatThingsCost => 'Lo que costaban las cosas';

  @override
  String get pagesWhere => 'Lugar';

  @override
  String get pagesWorldLeaders => 'Gobernantes';

  @override
  String get pagesWorldLeadersHint => 'Primer ministro, presidente, alcalde…';

  @override
  String get pagesWorldMovies => 'En el cine';

  @override
  String get pagesWorldMoviesHint => 'Lo que estaba en cartelera';

  @override
  String get pagesWorldNews => 'En las noticias';

  @override
  String get pagesWorldNewsHint => 'De lo que todos hablaban';

  @override
  String get pagesWorldPeople => 'Caras famosas';

  @override
  String get pagesWorldPeopleHint => 'Actores, deportistas, cantantes';

  @override
  String get pagesWorldPrompt =>
      'Toca para anotar las canciones, las noticias y lo que costaba un café.';

  @override
  String get pagesWorldShows => 'En la tele';

  @override
  String get pagesWorldShowsHint => 'Los programas que todos veían';

  @override
  String get pagesWorldSongs => 'Canciones en la radio';

  @override
  String get pagesWorldSongsHint => 'Los éxitos de ese año';

  @override
  String get pagesWorldTech => 'Aparatos';

  @override
  String get pagesWorldTechHint => 'El móvil en el bolsillo, la novedad';

  @override
  String get pagesWorldTitle => 'El mundo cuando naciste';

  @override
  String get pairingCodeCopied =>
      'Código copiado. Envíalo solo a tu familia: da acceso a los datos de tu bebé.';

  @override
  String get pairingCopyCode => 'Copiar el código';

  @override
  String get pairingIntro =>
      'En el otro teléfono, instala Nestling, elige «Usar sin servidor», luego «Unirse con un código» y escanea esto. Ambos teléfonos deben estar en la misma Wi-Fi.';

  @override
  String get pairingJoinIntro =>
      'En un teléfono que ya usa Nestling: Familia → Vincular un teléfono. Escanea el código que muestra (misma Wi-Fi en ambos).';

  @override
  String get pairingJoinTitle => 'Unirse con un código';

  @override
  String get pairingNeedsAndroid =>
      'Vincular teléfonos requiere la app de Android.';

  @override
  String get pairingNoneYet => 'Ninguno todavía.';

  @override
  String get pairingNotSynced => 'Aún sin sincronizar';

  @override
  String get pairingPairedPhones => 'Teléfonos vinculados';

  @override
  String get pairingPasteCode => 'O pega el código';

  @override
  String get pairingPhone => 'Teléfono';

  @override
  String get pairingSyncNow => 'Sincronizar ahora';

  @override
  String get pairingTitle => 'Vincular un teléfono';

  @override
  String pairingUnreachable(Object ago) {
    return 'Sincronizado $ago · no disponible ahora';
  }

  @override
  String get pickerAddActivity => 'Añadir una actividad';

  @override
  String get pickerAddFood => 'Añadir un alimento';

  @override
  String get pickerAddMedicine => 'Añadir un medicamento';

  @override
  String get pickerAlreadyTried => 'Ya probados';

  @override
  String get pickerCommon => 'Comunes';

  @override
  String get pickerFoodApple => 'Manzana';

  @override
  String get pickerFoodAvocado => 'Aguacate';

  @override
  String get pickerFoodBanana => 'Plátano';

  @override
  String get pickerFoodBeef => 'Ternera';

  @override
  String get pickerFoodBlueberries => 'Arándanos';

  @override
  String get pickerFoodBread => 'Pan';

  @override
  String get pickerFoodBroccoli => 'Brócoli';

  @override
  String get pickerFoodCarrot => 'Zanahoria';

  @override
  String get pickerFoodCheese => 'Queso';

  @override
  String get pickerFoodChicken => 'Pollo';

  @override
  String get pickerFoodEgg => 'Huevo';

  @override
  String get pickerFoodFish => 'Pescado';

  @override
  String get pickerFoodGreenBeans => 'Judías verdes';

  @override
  String get pickerFoodLentils => 'Lentejas';

  @override
  String get pickerFoodMango => 'Mango';

  @override
  String get pickerFoodOatmeal => 'Avena';

  @override
  String get pickerFoodPasta => 'Pasta';

  @override
  String get pickerFoodPeach => 'Melocotón';

  @override
  String get pickerFoodPeanutButter => 'Mantequilla de cacahuete';

  @override
  String get pickerFoodPear => 'Pera';

  @override
  String get pickerFoodPeas => 'Guisantes';

  @override
  String get pickerFoodRiceCereal => 'Cereal de arroz';

  @override
  String get pickerFoodSquash => 'Calabaza';

  @override
  String get pickerFoodStrawberries => 'Fresas';

  @override
  String get pickerFoodSweetPotato => 'Batata';

  @override
  String get pickerFoodTofu => 'Tofu';

  @override
  String get pickerFoodYogurt => 'Yogur';

  @override
  String pickerLastDose(Object dose) {
    return 'Última dosis $dose';
  }

  @override
  String get pickerMedAcetaminophen => 'Paracetamol (Tylenol)';

  @override
  String get pickerMedAmoxicillin => 'Amoxicilina';

  @override
  String get pickerMedAntihistamine => 'Antihistamínico (Benadryl)';

  @override
  String get pickerMedDiaperCream => 'Crema para el pañal';

  @override
  String get pickerMedGripeWater => 'Agua para cólicos';

  @override
  String get pickerMedIbuprofen => 'Ibuprofeno (Advil)';

  @override
  String get pickerMedIron => 'Gotas de hierro';

  @override
  String get pickerMedProbiotic => 'Probiótico (BioGaia)';

  @override
  String get pickerMedSaline => 'Gotas salinas';

  @override
  String get pickerMedSimethicone => 'Simeticona (Ovol)';

  @override
  String get pickerMedTeethingGel => 'Gel para la dentición';

  @override
  String get pickerMedVitaminD => 'Vitamina D';

  @override
  String get pickerRecent => 'Recientes';

  @override
  String get pickerSelected => 'Seleccionado';

  @override
  String pickerTimes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veces',
      one: 'Una vez',
    );
    return '$_temp0';
  }

  @override
  String get pickerUseName => 'Usar este nombre';

  @override
  String pickerUsedLast(Object day, Object times) {
    return '$times · última vez $day';
  }

  @override
  String get pottyAccident => 'Accidente';

  @override
  String get pottySatDry => 'Sentado, nada';

  @override
  String get pottySuccess => 'Orinal';

  @override
  String get rash => 'irritación';

  @override
  String get remove => 'Quitar';

  @override
  String get right => 'Derecho';

  @override
  String get rightShort => 'D';

  @override
  String get roleBookViewer => 'Solo el álbum';

  @override
  String get roleBookViewerHint =>
      'Ve el álbum del bebé, sin poder cambiar nada';

  @override
  String get roleCaregiver => 'Cuidador';

  @override
  String get roleCaregiverHint =>
      'Registra tomas, sueño, pañales y todo lo demás';

  @override
  String get roleOwner => 'Propietario';

  @override
  String get roleOwnerHint => 'Registra todo y administra la familia';

  @override
  String get save => 'Guardar';

  @override
  String get scheduleAddMedicine => 'Añadir un medicamento';

  @override
  String get scheduleDaily => 'diario';

  @override
  String get scheduleDescribeEmpty => 'Dosis programadas, \"sin toma en 3 h\"…';

  @override
  String get scheduleDoseLabel => 'Dosis habitual (opcional)';

  @override
  String get scheduleDoses => 'dosis';

  @override
  String get scheduleErrDose => 'La dosis debe ser un número.';

  @override
  String get scheduleErrEvery => 'Frecuencia: entre 0,5 y 168 horas.';

  @override
  String get scheduleErrMax => 'Máximo en 24 horas: un número del 1 al 24.';

  @override
  String get scheduleErrName => 'Ponle un nombre al medicamento.';

  @override
  String get scheduleEvery => 'Cada';

  @override
  String scheduleEveryHours(Object hours) {
    return 'Cada $hours h';
  }

  @override
  String scheduleEveryMinutes(Object minutes) {
    return 'Cada $minutes min';
  }

  @override
  String get scheduleFeed => 'Toma';

  @override
  String get scheduleFooterPush =>
      'Un recordatorio pendiente aparece en la pantalla de inicio (deslízalo para ocultarlo) y se envía a los teléfonos de toda la familia. El recordatorio de un medicamento se activa en su horario.';

  @override
  String get scheduleFooterServer =>
      'Un recordatorio pendiente aparece en la pantalla de inicio (deslízalo para ocultarlo). Para recibirlo también como notificación, configura las notificaciones en el servidor (consulta \"Notifications on phones\" en el README).';

  @override
  String get scheduleFooterServerless =>
      'Un recordatorio pendiente aparece en la pantalla de inicio (deslízalo para ocultarlo). Las notificaciones en el teléfono necesitan un servidor Nestling configurado para ello.';

  @override
  String get scheduleHours => 'horas';

  @override
  String scheduleIntro(Object name) {
    return 'Para $name. Un medicamento programado aparece en la pantalla de inicio con la hora de la próxima dosis posible, y registrarlo demasiado pronto te avisa.';
  }

  @override
  String get scheduleMaxLabel => 'Máximo en 24 horas (opcional)';

  @override
  String get scheduleMedicineSection => 'Horario de medicamentos';

  @override
  String get scheduleName => 'Nombre';

  @override
  String scheduleNotifyWhen(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'Avisar tras estar despierto durante:',
      'diaper': 'Avisar si no hubo cambio de pañal en:',
      'pump': 'Avisar si no hubo extracción en:',
      'other': 'Avisar si no hubo toma en:',
    });
    return '$_temp0';
  }

  @override
  String get scheduleOff => 'Desactivado';

  @override
  String get scheduleOnceADay => 'Una vez al día';

  @override
  String get scheduleOnceAWeek => 'Una vez a la semana';

  @override
  String get scheduleRemindDue => 'Recordar cuando toque la próxima dosis';

  @override
  String get scheduleReminderOn => 'recordatorio activado';

  @override
  String scheduleReminderTitle(Object label) {
    return 'Recordatorio: $label';
  }

  @override
  String get scheduleReminders => 'Recordatorios';

  @override
  String scheduleRemindersList(num count, Object types) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'recordatorios de $types',
      one: 'recordatorio de $types',
    );
    return '$_temp0';
  }

  @override
  String get scheduleTitle => 'Medicamentos y recordatorios';

  @override
  String get scheduleUnit => 'Unidad';

  @override
  String scheduleUpToPerDay(Object count) {
    return 'hasta $count al día';
  }

  @override
  String scheduleWhenAfter(Object duration, String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'sleep': 'Tras $duration despierto',
      'diaper': 'Sin cambio de pañal en $duration',
      'pump': 'Sin extracción en $duration',
      'other': 'Sin toma en $duration',
    });
    return '$_temp0';
  }

  @override
  String get settingsLanguageDevice => 'Idioma del dispositivo';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String summaryBreastMilk(Object amount) {
    return '$amount de leche materna';
  }

  @override
  String get summaryClose => 'Cerrar resumen';

  @override
  String get summaryFirsts => 'Primeras veces';

  @override
  String summaryFormula(Object amount) {
    return '$amount de fórmula';
  }

  @override
  String summaryHead(Object value) {
    return 'cabeza $value';
  }

  @override
  String get summaryLast24h => 'Últimas 24 horas';

  @override
  String summaryLeft(Object duration) {
    return '$duration izquierdo';
  }

  @override
  String summaryLongest(Object duration) {
    return 'el más largo $duration';
  }

  @override
  String get summaryNotes => 'Notas';

  @override
  String get summaryNothing => 'Nada registrado todavía.';

  @override
  String summaryPotty(num accidents, Object inPotty) {
    String _temp0 = intl.Intl.pluralLogic(
      accidents,
      locale: localeName,
      other: '$accidents accidentes',
      one: '1 accidente',
    );
    return '$inPotty en el orinal · $_temp0';
  }

  @override
  String summaryPumping(Object duration) {
    return '$duration de extracción';
  }

  @override
  String summaryRight(Object duration) {
    return '$duration derecho';
  }

  @override
  String get summaryRoutine => 'Rutina';

  @override
  String summaryTemperature(Object values) {
    return 'temperatura $values';
  }

  @override
  String get summaryTitle => 'Resumen';

  @override
  String summaryTotal(Object amount) {
    return '$amount en total';
  }

  @override
  String summaryWetDirty(Object dirty, Object wet) {
    return '$wet pipí · $dirty caca';
  }

  @override
  String syncCantReach(Object server) {
    return 'No se puede conectar con el servidor ($server).';
  }

  @override
  String syncCantReachCheck(Object server) {
    return 'No se puede conectar con el servidor ($server). Revisa la dirección y tu conexión.';
  }

  @override
  String syncCantReachNamedPhone(Object name) {
    return 'No se pudo conectar con el teléfono de $name. Ambos teléfonos deben estar en la misma red Wi-Fi, con el código de vinculación aún visible.';
  }

  @override
  String get syncCantReachOtherPhone =>
      'No se pudo conectar con el otro teléfono. Ambos teléfonos deben estar en la misma red Wi-Fi, con el código de vinculación aún visible.';

  @override
  String syncChangeNotSaved(Object message) {
    return 'No se pudo guardar un cambio: $message';
  }

  @override
  String get syncConflict =>
      'Algo que cambiaste también se cambió en otro dispositivo; se guardó el cambio más reciente.';

  @override
  String get syncDriveFolderUnreachable =>
      'No se puede acceder a la carpeta de Drive de la familia. Desactiva y vuelve a activar la sincronización con Drive.';

  @override
  String get syncDriveNeedsAndroid =>
      'Google Drive necesita la aplicación de Android.';

  @override
  String get syncDriveNotGranted => 'No se concedió acceso a Google Drive.';

  @override
  String get syncEntryDeleted => 'Esta entrada se eliminó en otro teléfono.';

  @override
  String get syncGoogleNotSignedIn => 'No has iniciado sesión en Google.';

  @override
  String syncLoggedNotSaved(Object message) {
    return 'No se pudo guardar algo que registraste: $message';
  }

  @override
  String get syncNotPairingCode =>
      'Esto no es un código de vinculación de Nestling.';

  @override
  String syncOffline(Object host) {
    return 'Estás sin conexión. Esto necesita conexión con el servidor ($host).';
  }

  @override
  String syncOfflineNotSent(Object message) {
    return 'Los cambios hechos sin conexión aún no se pudieron enviar: $message';
  }

  @override
  String syncOtherPhoneAnswered(Object status) {
    return 'el otro teléfono respondió $status';
  }

  @override
  String get syncPairingIncomplete =>
      'Este código de vinculación está incompleto. Cópialo de nuevo.';

  @override
  String get syncPhonesNeedAndroid =>
      'Sincronizar teléfonos directamente necesita la aplicación de Android.';

  @override
  String syncServerError(Object status) {
    return 'Error del servidor ($status)';
  }

  @override
  String get syncTimerRunning =>
      'Alguien ya inició este temporizador. Ya se muestra.';

  @override
  String get syncTimerStopped =>
      'Este temporizador ya se detuvo en otro teléfono. La pantalla ya está actualizada.';

  @override
  String get syncWifiFirst => 'Primero conecta este teléfono a una red Wi-Fi.';

  @override
  String get system => 'Sistema';

  @override
  String teethAgeOld(Object age) {
    return 'con $age';
  }

  @override
  String get teethCameIn => 'Salió';

  @override
  String get teethCameInOn => 'Salió el';

  @override
  String get teethCanine => 'canino';

  @override
  String get teethCentralIncisor => 'incisivo central';

  @override
  String teethChartSemantics(Object count) {
    return 'Tabla de dientes: $count de 20 dientes han salido. Toca un diente para anotarlo.';
  }

  @override
  String teethChartSemanticsReadOnly(Object count) {
    return 'Dientes: $count de 20 han salido.';
  }

  @override
  String teethCount(Object count) {
    return '$count de 20';
  }

  @override
  String get teethFirstHint =>
      'El primero va al libro como «Primer diente»: añade ahí una foto y la historia.';

  @override
  String get teethFirstMolar => 'primer molar';

  @override
  String get teethItCameIn => 'Ya salió';

  @override
  String get teethLateralIncisor => 'incisivo lateral';

  @override
  String get teethLegendIn => 'Salió';

  @override
  String get teethLegendNotYet => 'Aún no';

  @override
  String get teethLower => 'ABAJO';

  @override
  String get teethLowerLeft => 'inferior izquierdo';

  @override
  String get teethLowerRight => 'inferior derecho';

  @override
  String teethName(Object kind, Object position) {
    return '$kind $position';
  }

  @override
  String get teethNotInYet => 'Aún no salió';

  @override
  String get teethSaveDate => 'Guardar fecha';

  @override
  String get teethSecondMolar => 'segundo molar';

  @override
  String get teethTapChange =>
      'Toca un diente para anotarlo o cambiar su fecha.';

  @override
  String get teethTapFirst => 'Toca un diente cuando salga.';

  @override
  String get teethUpper => 'ARRIBA';

  @override
  String get teethUpperLeft => 'superior izquierdo';

  @override
  String get teethUpperRight => 'superior derecho';

  @override
  String teethUsually(Object when) {
    return 'Suele salir a los $when';
  }

  @override
  String teethWhen(Object range) {
    return '$range meses';
  }

  @override
  String get timelineAll => 'Todo';

  @override
  String get timelineDiapers => 'Pañales';

  @override
  String get timelineEmpty => 'Aún no hay nada.';

  @override
  String get timelineFeeds => 'Tomas';

  @override
  String timelineNote(Object note) {
    return '«$note»';
  }

  @override
  String get timelineOther => 'Otros';

  @override
  String get timelineSummary => 'Resumen';

  @override
  String timelineTitle(Object name) {
    return 'Historial de $name';
  }

  @override
  String timerAwakeFor(Object duration) {
    return 'Despierto desde hace $duration';
  }

  @override
  String get timerDeleteBody => 'No se guardará nada.';

  @override
  String get timerDeleteTitle => '¿Eliminar este temporizador?';

  @override
  String timerEditSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Editar tiempo izquierdo',
      'other': 'Editar tiempo derecho',
    });
    return '$_temp0';
  }

  @override
  String get timerEditTotal => 'Editar tiempo total';

  @override
  String timerEndAfterStart(Object time) {
    return 'El final debe ser después del inicio ($time).';
  }

  @override
  String get timerEndTime => 'Fin';

  @override
  String get timerFellAsleep => 'Se durmió';

  @override
  String get timerKeepsRunning => 'Cierra con ✕ y el temporizador sigue.';

  @override
  String timerLastFeedEnded(Object ago, String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'La última toma terminó en el izquierdo',
      'other': 'La última toma terminó en el derecho',
    });
    String _temp1 = intl.Intl.selectLogic(side, {
      'left': 'Empieza por el derecho',
      'other': 'Empieza por el izquierdo',
    });
    return '$_temp0 · $ago\n$_temp1';
  }

  @override
  String get timerLastSideBadge => 'Último\nlado';

  @override
  String get timerLeftSide => 'Lado izquierdo';

  @override
  String get timerLogPast => 'Registrar';

  @override
  String get timerMinutes => 'Minutos';

  @override
  String get timerNoteHint => 'Nota (opcional)';

  @override
  String timerOnSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'En el izquierdo',
      'other': 'En el derecho',
    });
    return '$_temp0';
  }

  @override
  String get timerPause => 'Pausa';

  @override
  String timerPauseSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Pausar izquierdo',
      'other': 'Pausar derecho',
    });
    return '$_temp0';
  }

  @override
  String get timerPaused => 'En pausa';

  @override
  String get timerPumpHowMuch => '¿Cuánto te extrajiste?';

  @override
  String get timerPumping => 'Extrayendo';

  @override
  String get timerResume => 'Reanudar';

  @override
  String timerResumeSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Reanudar izquierdo',
      'other': 'Reanudar derecho',
    });
    return '$_temp0';
  }

  @override
  String get timerRightSide => 'Lado derecho';

  @override
  String timerSaved(Object what) {
    return '$what guardado';
  }

  @override
  String get timerSeconds => 'Segundos';

  @override
  String get timerSleeping => 'Durmiendo';

  @override
  String get timerStart => 'Iniciar';

  @override
  String get timerStartInFuture => 'El inicio no puede estar en el futuro.';

  @override
  String timerStartSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Empezar izquierdo',
      'other': 'Empezar derecho',
    });
    return '$_temp0';
  }

  @override
  String timerStartSideLast(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Empezar izquierdo (último lado)',
      'other': 'Empezar derecho (último lado)',
    });
    return '$_temp0';
  }

  @override
  String get timerStartTime => 'Inicio';

  @override
  String timerSwitchSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Cambiar al izquierdo',
      'other': 'Cambiar al derecho',
    });
    return '$_temp0';
  }

  @override
  String get timerTapSide => 'Toca un lado para empezar';

  @override
  String get timerTapStart => 'Toca para empezar';

  @override
  String get timerTimeAsleep => 'Tiempo dormido';

  @override
  String get timerTotalTime => 'Tiempo total';

  @override
  String get timerTotalTimeTitle => 'Tiempo total';

  @override
  String get timerWokeUp => 'Se despertó';

  @override
  String get today => 'Hoy';

  @override
  String get trendsAccidents => 'Accidentes';

  @override
  String get trendsAmountPumped => 'Cantidad extraída';

  @override
  String get trendsAverage => 'promedio';

  @override
  String get trendsBottleSize => 'Tamaño del biberón';

  @override
  String trendsBottleUnit(Object unit) {
    return 'Biberón ($unit)';
  }

  @override
  String get trendsBreastfeedLength => 'Duración de la toma';

  @override
  String get trendsBreastfeeding => 'Lactancia';

  @override
  String trendsCompareArrows(Object count) {
    return 'Las flechas comparan con los $count días anteriores.';
  }

  @override
  String trendsCompareNone(Object count) {
    return 'No hay nada registrado en los $count días anteriores para comparar.';
  }

  @override
  String get trendsDay => 'Día';

  @override
  String get trendsDayBreastfeeding => 'Lactancia de día';

  @override
  String get trendsDayDiapers => 'Pañales de día';

  @override
  String get trendsDaySleep => 'Sueño de día';

  @override
  String trendsDays(Object count) {
    return '$count días';
  }

  @override
  String get trendsDiapers => 'Pañales';

  @override
  String get trendsFeed => 'Alimentación';

  @override
  String get trendsFeedInterval => 'Tiempo entre tomas';

  @override
  String get trendsFeeds => 'Tomas';

  @override
  String get trendsGrowthChartsSub =>
      'Peso, talla y perímetro cefálico en las curvas de la OMS';

  @override
  String trendsIntro(num days, Object end, Object start) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'Promedios diarios de $days días completos; el día va de $start a $end.',
      one: 'Promedios diarios de 1 día completo; el día va de $start a $end.',
    );
    return '$_temp0';
  }

  @override
  String get trendsLongestSleep => 'Sueño más largo';

  @override
  String get trendsNapLength => 'Duración de la siesta';

  @override
  String get trendsNaps => 'Siestas';

  @override
  String get trendsNight => 'Noche';

  @override
  String get trendsNightBreastfeeding => 'Lactancia de noche';

  @override
  String get trendsNightDiapers => 'Pañales de noche';

  @override
  String get trendsNightSleep => 'Sueño de noche';

  @override
  String get trendsPerDay => 'por día';

  @override
  String get trendsPottyTrips => 'Idas al orinal';

  @override
  String get trendsPumpSessions => 'Extracciones';

  @override
  String get trendsPumpTime => 'Tiempo de extracción';

  @override
  String get trendsTitle => 'Tendencias';

  @override
  String get trendsWakeWindow => 'Ventana de vigilia';

  @override
  String get trendsWetOnly => 'Solo pipí';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get usersAdd => 'Añadir usuario';

  @override
  String get usersAddTitle => 'Añadir un usuario';

  @override
  String usersAddTo(Object family) {
    return 'Añadir a $family';
  }

  @override
  String get usersAdmin => 'Administrador';

  @override
  String get usersAdminHint => 'Puede gestionar usuarios';

  @override
  String get usersAdminTag => 'admin';

  @override
  String get usersAsCaregiver => 'Como cuidador';

  @override
  String get usersCanChangeLater => 'Podrá cambiarla después';

  @override
  String usersCanSignIn(Object name) {
    return '$name ya puede iniciar sesión';
  }

  @override
  String get usersEmail => 'Correo';

  @override
  String get usersEnterEmail => 'Escribe un correo';

  @override
  String get usersEnterName => 'Escribe un nombre';

  @override
  String get usersIntro =>
      'Solo los administradores pueden crear cuentas en este servidor. Da a cada persona su correo y contraseña; podrá cambiarla en Ajustes → Cuenta.';

  @override
  String get usersMakeAdmin => 'Hacer admin';

  @override
  String usersManage(Object name) {
    return 'Gestionar a $name';
  }

  @override
  String usersNewPasswordFor(Object name) {
    return 'Nueva contraseña para $name';
  }

  @override
  String usersNoLongerAdmin(Object name) {
    return '$name ya no es administrador';
  }

  @override
  String usersNowAdmin(Object name) {
    return '$name ahora es administrador';
  }

  @override
  String get usersPassword => 'Contraseña';

  @override
  String get usersPasswordHelp =>
      'Al menos 8 caracteres. Se cerrará su sesión.';

  @override
  String usersPasswordSet(Object name) {
    return 'Nueva contraseña para $name';
  }

  @override
  String get usersRemoveAccount => 'Eliminar cuenta';

  @override
  String get usersRemoveAdmin => 'Quitar admin';

  @override
  String get usersRemoveBody =>
      'Ya no podrá iniciar sesión. Sus familias y todo lo registrado se conservan.';

  @override
  String usersRemoveTitle(Object name) {
    return '¿Quitar a $name?';
  }

  @override
  String usersRemoved(Object name) {
    return '$name eliminado';
  }

  @override
  String get usersSetPassword => 'Poner una nueva contraseña';

  @override
  String get usersTitle => 'Usuarios';

  @override
  String get wet => 'Pipí';

  @override
  String get wetAndDirty => 'Pipí + caca';

  @override
  String get yesterday => 'Ayer';
}
