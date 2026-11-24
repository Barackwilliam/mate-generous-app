/// Every word the app shows, in Swahili and English.
///
/// Content (devotionals) stays in the language it was written in; only the
/// app's own labels switch. Use `context.s.<word>` from widgets.
class S {
  const S(this.lang);
  final String lang;

  bool get en => lang == 'en';
  String _(String sw, String english) => en ? english : sw;

  // Navigation
  String get home => _('Nyumbani', 'Home');
  String get explore => _('Makundi', 'Explore');
  String get listen => _('Sikiliza', 'Listen');
  String get library => _('Maktaba', 'Library');
  String get mainMenu => _('Menyu kuu', 'Main menu');
  String get language => _('Lugha', 'Language');
  String get appLanguage => _('Lugha ya app', 'App language');
  String get back => _('Rudi', 'Back');

  // Greetings and dates
  String greeting(int hour) => hour < 12
      ? _('Habari za asubuhi', 'Good morning')
      : hour < 16
          ? _('Habari za mchana', 'Good afternoon')
          : _('Habari za jioni', 'Good evening');
  String get welcome => _('Karibu', 'Welcome');

  static const _daysSw = ['Jumatatu', 'Jumanne', 'Jumatano', 'Alhamisi', 'Ijumaa', 'Jumamosi', 'Jumapili'];
  static const _daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _monthsSw = ['Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni', 'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba'];
  static const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _monShortSw = ['JAN', 'FEB', 'MAC', 'APR', 'MEI', 'JUN', 'JUL', 'AGO', 'SEP', 'OKT', 'NOV', 'DES'];
  static const _monShortEn = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  String longDate(DateTime d) =>
      '${(en ? _daysEn : _daysSw)[d.weekday - 1]}, ${d.day} ${(en ? _monthsEn : _monthsSw)[d.month - 1]}';
  String fullDate(DateTime d) => '${d.day} ${(en ? _monthsEn : _monthsSw)[d.month - 1]} ${d.year}';
  String monthShort(DateTime d) => (en ? _monShortEn : _monShortSw)[d.month - 1];
  String get today => _('LEO', 'TODAY');

  // Home
  String get tonightBadge => _('UJUMBE WA USIKU HUU', "TONIGHT'S MESSAGE");
  String read(int? minutes) => minutes == null ? _('Soma', 'Read') : _('Soma · dk $minutes', 'Read · $minutes min');
  String listenFor(String? time) => time == null ? listen : '$listen · $time';
  String get continueReading => _('ENDELEA', 'CONTINUE');
  String get discover => _('Gundua', 'Discover');
  String get seeAll => _('Yote', 'See all');
  String get emptyHome => _('Jumbe zitaonekana hapa hivi karibuni.', 'Messages will appear here soon.');
  /// Home rows: in Swahili the admin's own title; in English the standard name.
  String section(String kind, String adminTitle) {
    if (!en) return adminTitle;
    return switch (kind) {
      'latest' => 'Latest messages',
      'featured' => 'Recommended for you',
      'series_list' => 'Popular series',
      'audio' => 'Listen',
      _ => adminTitle,
    };
  }

  String items(int n) => _('jumbe $n', '$n messages');

  // Search
  String get search => _('Tafuta', 'Search');
  String get searchHint => _('Andiko, mada, series au mwandishi', 'Scripture, topic, series or author');
  String get cancel => _('Ghairi', 'Cancel');
  String get all => _('Zote', 'All');
  String get devotionals => _('Ibada', 'Devotionals');
  String get sermons => _('Mahubiri', 'Sermons');
  String get audio => _('Sauti', 'Audio');
  String get articles => _('Makala', 'Articles');
  String get searchStart => _('Andika angalau herufi mbili. Mfano: “Zaburi 23” au “msamaha”.',
      'Type at least two letters, for example “Psalm 23” or “forgiveness”.');
  String get noResults => _('Hakuna kilichopatikana.', 'Nothing found.');
  String get popularTopics => _('Mada maarufu', 'Popular topics');

  // Reader
  String get bookmark => _('Hifadhi', 'Save');
  String get favourite => _('Pendwa', 'Favourite');
  String get share => _('Shiriki', 'Share');
  String get textAndLook => _('Maandishi na mwonekano', 'Text and appearance');
  String get textSize => _('Ukubwa wa maandishi', 'Text size');
  String get appearance => _('Mwonekano', 'Appearance');
  String get dark => _('Usiku', 'Dark');
  String get light => _('Mchana', 'Light');
  String get system => _('Simu', 'System');
  String get application => _('Matumizi ya vitendo', 'Practical application');
  String get prayer => _('Sala', 'Prayer');
  String get previous => _('Kilichotangulia', 'Previous');
  String get next => _('Kinachofuata', 'Next');
  String minutes(int m) => _('dk $m', '$m min');
  String minRead(int m) => _('dk $m kusoma', '$m min read');
  String get readMoreOn => _('Soma zaidi kwenye Mate Generous', 'Read more on Mate Generous');
  String get membersOnly => _('Ujumbe huu ni kwa wanachama.', 'This message is for members.');
  String get premiumOnly => _('Ujumbe huu ni kwa wanachama wa Premium.', 'This message is for Premium members.');
  String get joinToRead => _('Jiunge ili kusoma ujumbe kamili, sala na kusikiliza sauti.',
      'Join to read the full message and prayer, and to listen.');
  String get joinNow => _('Jiunge sasa', 'Join now');
  String get signInOrUp => _('Ingia au jisajili', 'Sign in or register');

  // Listen
  String get nowPlayingFrom => _('INACHEZA KUTOKA', 'PLAYING FROM');
  String get upNext => _('KINAFUATA', 'UP NEXT');
  String get speed => _('Kasi ya kucheza', 'Playback speed');
  String get rewind15 => _('Rudi nyuma sekunde 15', 'Back 15 seconds');
  String get forward15 => _('Songa mbele sekunde 15', 'Forward 15 seconds');
  String get play => _('Cheza', 'Play');
  String get pause => _('Simamisha', 'Pause');
  String get nextEpisode => _('Kipindi kijacho', 'Next episode');
  String get prevEpisode => _('Kipindi kilichopita', 'Previous episode');
  String get close => _('Funga', 'Close');
  String get audioMessages => _('Jumbe za kusikiliza', 'Audio messages');
  String get noAudio => _('Jumbe za sauti zitaonekana hapa zikiwekwa.', 'Audio messages will appear here once added.');
  String get audioFailed => _('Imeshindikana kucheza sauti.', 'Could not play the audio.');

  // Library
  String get myLibrary => _('Maktaba Yangu', 'My Library');
  String get streak => _('Usiku mfululizo', 'Nights in a row');
  String get completed => _('Jumbe ulizosoma', 'Messages read');
  String get saved => _('Ulizohifadhi', 'Saved');
  String get history => _('Historia', 'History');
  String get mine => _('Vyangu', 'Mine');
  String get finished => _('Umemaliza', 'Finished');
  String get libraryGuest => _('Ingia ili kuhifadhi jumbe, kuona historia yako na kuendelea ulipoishia.',
      'Sign in to save messages, see your history and continue where you left off.');
  String get emptyHistory => _('Ukianza kusoma, historia itaonekana hapa.', 'Your reading history will appear here.');
  String get emptySaved => _('Bado hujahifadhi ujumbe wowote.', 'You have not saved anything yet.');
  String get emptyFavourites => _('Bado huna jumbe pendwa.', 'No favourites yet.');
  String get emptyOwned => _('Vitabu na rasilimali ulizonunua vitaonekana hapa.', 'Books and resources you buy will appear here.');

  // Plans
  String get plansTitle => _('Kila usiku, ujumbe kamili.', 'Every night, the full message.');
  String get plansIntro => _('Fungua ibada zote, sauti, series na maktaba nzima. Usajili ukiisha, vitabu ulivyonunua vinabaki vyako.',
      'Unlock every devotional, audio, series and the whole library. If your plan ends, the books you bought stay yours.');
  String days(int d) => _('Siku $d', '$d days');
  String get priceSoon => _('Bei inakuja', 'Price soon');
  String get payWith => _('LIPA KWA', 'PAY WITH');
  String get paymentsSoon => _('Malipo yanakuja hivi karibuni', 'Payments are coming soon');
  String get paymentsSoonNote => _('Mpango wako utaanza mara malipo ya M-Pesa, Airtel Money na Mixx yatakapofunguliwa.',
      'Your plan will start once M-Pesa, Airtel Money and Mixx payments open.');
  String get noPlans => _('Mipango itaonekana hapa hivi karibuni.', 'Plans will appear here soon.');
  String get premiumPlus => _('+ Mahubiri', '+ Sermons');

  // Account
  String get account => _('Akaunti', 'Account');
  String get editProfile => _('Hariri wasifu', 'Edit profile');
  String get fullName => _('Jina kamili', 'Full name');
  String get phoneOptional => _('Namba ya simu (hiari)', 'Phone number (optional)');
  String get save => _('Hifadhi', 'Save');
  String get freePlan => _('Mpango wa bure', 'Free plan');
  String get freePlanSub => _('Jiunge ili kufungua jumbe zote', 'Join to unlock every message');
  String planUntil(String date) => _('Inaisha $date', 'Ends $date');
  String get active => _('Hai', 'Active');
  String get manage => _('Simamia', 'Manage');
  String get signOut => _('Toka', 'Sign out');
  String get openSourceFonts => _('Fonti: Lora na Plus Jakarta Sans (SIL OFL)', 'Fonts: Lora and Plus Jakarta Sans (SIL OFL)');

  // Auth
  String get signIn => _('Ingia', 'Sign in');
  String get register => _('Jisajili', 'Register');
  String get welcomeBack => _('Karibu tena', 'Welcome back');
  String get welcomeBackSub => _('Endelea ulipoishia usiku wa jana.', 'Pick up where you left off last night.');
  String get createAccount => _('Fungua akaunti', 'Create an account');
  String get createAccountSub => _('Hifadhi jumbe na uendelee kwenye simu yoyote.', 'Save messages and continue on any phone.');
  String get emailOrPhone => _('Barua pepe au namba ya simu', 'Email or phone number');
  String get email => _('Barua pepe', 'Email');
  String get password => _('Nenosiri', 'Password');
  String get passwordHelp => _('Angalau herufi 8, isiwe namba tu', 'At least 8 characters, not only numbers');
  String get required => _('Tafadhali jaza hapa', 'Please fill this in');
  String get badEmail => _('Weka barua pepe sahihi', 'Enter a valid email');
  String get shortPassword => _('Angalau herufi 8', 'At least 8 characters');
  String get continueAsGuest => _('Endelea kama mgeni', 'Continue as a guest');
  String get or => _('au', 'or');
  String get noAccount => _('Huna akaunti?', 'No account?');
  String get registerFree => _('Jisajili bure', 'Register free');
  String get haveAccount => _('Tayari una akaunti?', 'Already have an account?');
  String get showPassword => _('Onyesha nenosiri', 'Show password');

  // Template additions
  String get nothingYet => _('Bado hakuna ujumbe', 'No messages yet');
  String get loadingTitle => _('Inapakia maudhui...', 'Loading content...');
  String get pleaseWait => _('Tafadhali subiri kidogo.', 'Please wait a moment.');
  String get backHome => _('Rudi Nyumbani', 'Back home');
  String get tagline => _('Kua katika Imani,\nIshi kwa Kusudi.', 'Grow in Faith,\nLive in Purpose.');
  String get libraryLine => _('Maktaba ya Kikristo ya Kidijitali', 'Christian Digital Library');
  String get exploreMore => _('Gundua Zaidi', 'Explore more');
  String get otherResults => _('Matokeo mengine', 'Other results');
  String get searchContent => _('Tafuta maudhui...', 'Search content...');
  String get nights => _('Usiku', 'Nights');
  String get lessons => _('Mafundisho', 'Read');
  String get favourites => _('Vipendwa', 'Favourites');
  String get myBooks => _('Vitabu Vyangu', 'My Books');
  String get booksAndSeries => _('Vitabu na Series', 'Books & Series');
  String get seeAllArrow => _('Ona Zote', 'See all');
  String get settings => _('Mipangilio', 'Settings');
  String get upNextShort => _('Ijayo', 'Up next');
  String get joinTitle => _('Jiunge na Mate Generous', 'Join Mate Generous');
  String get joinSub => _('Upate zaidi ya maudhui', 'Get more content');
  String get perkSermons => _('Mahubiri na Sermons', 'Sermons and preaching resources');
  String get perkCourses => _('Kozi za Kikristo', 'Christian courses');
  String get perkPremium => _('Maudhui ya Premium', 'Premium content');
  String get freePreview => _('Bure', 'Free');
  String get preview => _('(Onjo)', '(Preview)');
  String get bestValue => _('BEST VALUE', 'BEST VALUE');
  String get joinNowArrow => _('Jiunge Sasa', 'Join now');
  String get continueBtn => _('Endelea', 'Continue');
  String get signInToContinue => _('Ingia ili kuendelea', 'Sign in to continue');
  String get welcomeBang => _('Karibu tena!', 'Welcome back!');
  String get createAccountShort => _('Sajili Akaunti', 'Create account');
  String get forgotPassword => _('Umesahau Nenosiri?', 'Forgot password?');
  String get resetTitle => _('Badilisha nenosiri', 'Reset password');
  String get resetIntro => _('Andika barua pepe au namba ya simu uliyosajili. Tutatuma namba ya siri ya tarakimu 6 kwenye barua pepe yako.',
      'Enter the email or phone number you registered with. We will email you a 6-digit code.');
  String get sendCode => _('Tuma namba', 'Send code');
  String get codeSent => _('Kama akaunti ipo, tumetuma namba kwenye barua pepe yake. Angalia pia folda ya Spam.',
      'If the account exists, we emailed a code to it. Check your spam folder too.');
  String get code => _('Namba ya siri (tarakimu 6)', '6-digit code');
  String get newPassword => _('Nenosiri jipya', 'New password');
  String get setPassword => _('Badilisha na uingie', 'Reset and sign in');
  String get sixDigits => _('Weka tarakimu 6', 'Enter 6 digits');
  String get readerLook => _('Mwonekano wa kusoma', 'Reading look');
  String get syncedOffline => _('Unatumia nakala iliyohifadhiwa kwenye simu.', 'Showing the copy saved on your phone.');

  // Errors
  String get retry => _('Jaribu tena', 'Try again');
  String get offline => _('Hakuna mtandao. Jaribu tena.', 'No connection. Please try again.');
  String get slow => _('Seva inachelewa kujibu. Jaribu tena baada ya muda mfupi.',
      'The server is slow to respond. Try again in a moment.');
}
