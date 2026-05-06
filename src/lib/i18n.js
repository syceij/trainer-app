// ── Eastern-Arabic numeral converter ──────────────────────────────────────────
/** Converts Western digits 0–9 to Eastern Arabic numerals ٠–٩ */
export function toEasternArabic(n) {
  return String(n).replace(/[0-9]/g, d => '٠١٢٣٤٥٦٧٨٩'[d]);
}

// ── Translation dictionary ─────────────────────────────────────────────────────
const AR = {
  // Bottom nav
  'Home': 'الرئيسـية',
  'Train': 'تدريـب',
  'Progress': 'التقــدم',
  'PT': 'المـدرب',

  // Greetings
  'Good morning': 'صــباح الخير',
  'Good afternoon': 'مسـاء الخيـر',
  'Good evening': 'مسـاء الخيـر',

  // Home tab
  "TODAY'S SESSION": 'تمــرين اليــوم',
  'exercises': 'تمارين',
  'min': 'دقيقة',
  'Week': 'الأسبوع',
  'Block': 'المرحلة',
  'Rest': 'راحة',
  'Streak': 'التواصل',
  'Sessions': 'جلسات',
  'Last vol.': 'آخر حجم',
  'UP NEXT': 'التالي',
  'View full programme': 'عـرض البرنامج الكامل',

  // Today tab
  'sets complete': 'مجموعات منجزة',
  'Sets': 'مجمـوعات',
  'Reps': 'تكـرارات',
  'Weight': 'الـوزن',
  'RPE': 'مستوى الجهد',
  'compound': 'مركـب',
  'accessory': 'تكـميلي',
  '↑ Ready to progress': '↑ جاهز للتقدم',
  'Finish Session →': '← أنـهِ التمـرين',
  'SESSION COMPLETE': 'اكتمـل التمـرين',
  'Sets done': 'المجمـوعات المنجـزة',
  'Volume': 'الحجم',
  'EDIT FINAL WEIGHTS': 'تعـديل الأوزان النـهائية',
  'Save Session ✓': 'احفـظ التمـرين ✓',
  'BW': 'وزن الجسم',
  'light': 'خفيف',
  'Calibration week — adjust weights as needed. This data trains your future progressions.':
    'أسبوع المعايرة — عدّل الأوزان حسب الحاجة. هذه البيانات تُحسّن برنامجك القادم.',
  'Deload recommended — consider reducing weights by 10-15%.':
    '💤 يُنصح بالتخفيف — فكّر في تخفيض الأوزان بنسبة 10-15%.',
  'No session loaded.': 'لا يوجد تمرين محمّل.',
  'Go to Home to select one.': 'اذهب إلى الرئيسية لتحديد واحد.',

  // Progress tab — lift labels
  'Bench Press':    'بنـش بريـس',
  'Back Squat':     'سكـوات خلـفي',
  'Deadlift':       'رفعـة ميتـة',
  'Overhead Press': 'ضغـط فوق الرأس',
  'View Gym Calendar': 'عـرض التقـويم',
  'MOST IMPROVED': 'الأكثـر تطـوراً',
  'WEEKLY VOLUME': 'الحجم الأسبوعي',
  'HISTORY': 'السجـل',
  'Complete your first session to see history.': 'أكمل تمرينك الأول لعرض السجل.',
  'kg vol.': 'كجم حجم',
  'Done': 'تـم',
  'Update': 'تحديث',

  // Calendar
  'Gym Calendar': 'تقـويم الصـالة',
  'Session logged': 'جلسة مسجلة',
  'Missed training': 'تمرين فائت',
  'Upcoming session': 'جلسة قادمة',
  'Training days': 'أيام التدريب',
  'Completion': 'الإنجاز',
  'STATS': 'إحصاءات',

  // Programme page
  'IMPORTED PROGRAMME': 'برنـامج مستـورد',
  'YOUR PROGRAMME': 'برنامجـك',
  'Auto-generated': 'مولّد تلقائياً',
  'edit': 'تعديل',
  'edits': 'تعديلات',
  'SCHEDULE': 'الجدول',
  'ALL SESSIONS — TAP TO EXPAND & EDIT': 'جميع الجلسات — اضغط للتوسيع والتعديل',
  'Programme cycles automatically. Edits are saved instantly and persist across sessions.':
    'يتكرر البرنامج تلقائياً. تُحفظ التعديلات فوراً وتستمر عبر الجلسات.',
  'TAP ANY FIELD TO EDIT': 'اضغط أي حقل للتعديل',
  'Add notes…': 'أضف ملاحظات…',
  'Add focus tag…': 'أضف وسم التركيز…',
  'DAY OVERVIEW': 'نظرة عامة على الأيام',
  'SESSIONS': 'الجلسات',
  'Edits save instantly and the AI reads your current programme — not the original import.':
    'تُحفظ التعديلات فوراً والذكاء الاصطناعي يقرأ برنامجك الحالي.',
  'Current training week': 'أسبوع التدريب الحالي',

  // Exercise picker
  'SWAP EXERCISE': 'تبـديل التمـرين',
  'Search exercises…': 'ابحـث عن تمـرين…',
  'No exercises match': 'لا توجد تمارين تطابق',

  // Welcome screen
  'Sign out': 'تسجيل الخروج',
  'YOUR DATA SYNCS ACROSS DEVICES': 'بياناتك تتزامن عبر جميع الأجهزة',
  'Build my programme': 'ابنِ برنامجي',
  '7-step setup · auto-generated': '٧ خطوات · مولّد تلقائياً',
  'Build manually': 'بناء يدوي',
  '6-step wizard · fully customisable': '٦ خطوات · قابل للتخصيص',
  'Import existing programme': 'استيراد برنامج موجود',
  'Paste JSON · multi-week support': 'الصق JSON · دعم متعدد الأسابيع',

  // Onboarding
  'Continue': 'متابعة',
  'Tell us about you': 'أخبرنا عنك',
  'First Name': 'الاسم الأول',
  'Age': 'العمر',
  'Sex': 'الجنس',
  'Male': 'ذكر',
  'Female': 'أنثى',
  'Other': 'آخر',
  'Experience level': 'مستوى الخبرة',
  'Beginner': 'مبتدئ',
  'Less than 1 year of consistent training': 'أقل من سنة من التدريب المنتظم',
  'Intermediate': 'متوسط',
  '1–3 years, comfortable with all main lifts': '١-٣ سنوات، مرتاح مع جميع التمارين الأساسية',
  'Advanced': 'متقدم',
  '3+ years, strong technique and high tolerance': 'أكثر من ٣ سنوات، تقنية قوية وتحمل عالٍ',
  'Bodyweight (kg)': 'وزن الجسم (كجم)',
  'Your goal': 'هدفك',
  'Build Muscle': 'بناء العضلات',
  'Get Stronger': 'زيادة القوة',
  'Lose Fat': 'حرق الدهون',
  'Athletic': 'رياضي',
  'Days per week': 'أيام في الأسبوع',
  'None': 'لا',
  'Moderate': 'متوسط',
  'Heavy': 'ثقيل',
  'Your setup': 'إعدادك',
  'Full Gym': 'صالة كاملة',
  'Barbells, machines, cables, dumbbells': 'أثقال، آلات، كابلات، دمبلز',
  'Home Gym': 'صالة منزلية',
  'Barbell, rack, dumbbells (no machines)': 'بار، حامل، دمبلز (بدون آلات)',
  'Dumbbells': 'دمبلز',
  'A pair of dumbbells + bench': 'زوج دمبلز وبنش',
  'Bodyweight': 'وزن الجسم فقط',
  'No equipment — just you and a bar maybe': 'بدون معدات — أنت فقط وربما قضيب',
  'Session length': 'مدة الجلسة',
  'Anything lagging?': 'أي مناطق ضعيفة؟',
  'Optional. We\'ll bias accessory work toward these areas.': 'اختياري. سنركز التمارين الإضافية على هذه المناطق.',
  'Back': 'ظهر',
  'Shoulders': 'أكتاف',
  'Arms': 'ذراعان',
  'Glutes-Hams': 'أرداف وفخذ خلفي',
  'Any injuries?': 'أي إصابات؟',
  'Current injuries (or \'none\')': 'الإصابات الحالية (أو "لا شيء")',
  'Exercises to avoid': 'تمارين يجب تجنبها',
  'Starting weights': 'الأوزان الابتدائية',
  'Barbell Row': 'تجديف بالبار',

  // Import screen
  'Paste your programme': 'الصق برنامجك',
  'Show prompt template for Claude': 'عرض قالب الطلب',
  'Copy prompt': 'نسخ الطلب',
  'Copied!': 'تم النسخ!',
  'Validation errors': 'أخطاء التحقق',
  'Valid programme': 'برنامج صالح',
  'Validate': 'التحقق',

  // PT tab
  'Ask PT': 'اسأل المدرب',
  'Your personal trainer': 'مدرّبك الشخصي',
  'Account': 'الحساب',

  // Gym Bros
  'Gym Bros': 'أصدقاء الصالة',
  'YOUR BROS': 'أصدقاؤك',
  'Add a Bro': 'إضافة صديق',
  'Invite link': 'رابط الدعوة',
  'Search users': 'البحث عن مستخدمين',
  'pts': 'نقطة',
  'Add': 'إضافة',
  'Copy': 'نسخ',
  'Share': 'مشاركة',
  'Sent ✓': 'تم الإرسال ✓',
  'Generating link…': 'جارٍ إنشاء الرابط…',
  'Generate new link': 'إنشاء رابط جديد',
  'Wants to be your Bro': 'يريد أن يكون صديقاً لك',
  'No Bros yet': 'لا أصدقاء بعد',
  'Your Bros': 'أصدقاؤك',
  'You': 'أنت',
  'Gym Bro': 'صديق صالة',

  // Auth screen
  'Welcome back': 'مرحباً بعودتك',
  'Sign in to continue': 'سجّل الدخول للمتابعة',
  'Email or username': 'البريد الإلكتروني أو اسم المستخدم',
  'Password': 'كلمة المرور',
  'Sign in': 'تسجيل الدخول',
  'Create account': 'إنشاء حساب',
  'Start your training journey': 'ابدأ رحلتك التدريبية',
  'Name': 'الاسم',
  'Email': 'البريد الإلكتروني',
  'Check your email': 'تحقق من بريدك الإلكتروني',
  'Verify': 'تحقق',
  'Resend code': 'إعادة إرسال الرمز',
  'Code resent ✓': 'تم إعادة الإرسال ✓',
  'Sending…': 'جارٍ الإرسال…',

  // Privacy (Account page)
  'Show sessions to Bros': 'إظهار الجلسات للأصدقاء',
  'Friends can see your recent workouts': 'يمكن لأصدقائك رؤية تمارينك الأخيرة',
  'Show working weights to Bros': 'إظهار الأوزان للأصدقاء',
  'Friends can see your current lifting weights': 'يمكن لأصدقائك رؤية أوزانك الحالية',
  'Show progress to Bros': 'إظهار التقدم للأصدقاء',
  'Friends can see your muscle improvement chart': 'يمكن لأصدقائك رؤية مخطط تقدمك',
  'Appear on leaderboard': 'الظهور في قائمة المتصدرين',
  'Show your session count in the Bros leaderboard': 'أظهر نقاطك في قائمة متصدري الأصدقاء',

  // Exercise categories
  'Chest': 'صـدر',
  'Front Shoulders': 'أكتـاف أمـامية',
  'Side Shoulders': 'أكتـاف جـانبية',
  'Rear Shoulders': 'أكتـاف خـلفية',
  'Back Width': 'عـرض الظهـر',
  'Back Thickness': 'سمـاكة الظهـر',
  'Biceps': 'بـاي',
  'Triceps': 'تـراي',
  'Quads': 'الفخـذ الأمـامية',
  'Hamstrings & Glutes': 'الفخـذ الخلفـية والأرداف',
  'Calves': 'عضـلات السـاق',
  'Core': 'عضـلات الكـور',
};

// ── Month & day names ──────────────────────────────────────────────────────────
export const MONTH_NAMES_EN = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];
export const MONTH_NAMES_AR = [
  'يناير','فبراير','مارس','أبريل','مايو','يونيو',
  'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
];
export const DAY_LABELS_EN = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
export const DAY_LABELS_AR = ['إثن','ثلا','أرب','خمس','جمع','سبت','أحد'];

// Full Arabic day names keyed by the short day key used in imported programmes
const DAYS_AR_FULL = {
  sun: 'الأحـد',
  mon: 'الإثنـين',
  tue: 'الثـلاثاء',
  wed: 'الأربـعاء',
  thu: 'الخمـيس',
  fri: 'الجمـعة',
  sat: 'السـبت',
};

/**
 * Translate a day key (mon/tue/…) to a display label.
 * English: capitalised short form (Mon, Tue, …)
 * Arabic:  full Arabic day name
 */
export function translateDay(dayKey, lang) {
  if (!dayKey) return '';
  const key = dayKey.toLowerCase();
  if (lang === 'ar') return DAYS_AR_FULL[key] || dayKey;
  return key.charAt(0).toUpperCase() + key.slice(1);
}

// ── Programme content translations (session names, focus tags, notes, blocks) ──
const CONTENT_AR = {
  // ── Auto-generated session names (buildProgramme actual output) ──
  'Push':        'دفـع',
  'Pull':        'شـد',
  'Legs':        'أرجـل',
  'Push B':      'دفـع ب',
  'Pull B':      'شـد ب',
  'Upper A':     'أعلى الجسم أ',
  'Upper B':     'أعلى الجسم ب',
  'Lower A':     'أسفل الجسم أ',
  'Lower B':     'أسفل الجسم ب',
  'Full Body A': 'الجسم الكامل أ',
  'Full Body B': 'الجسم الكامل ب',
  'Full Body C': 'الجسم الكامل ج',

  // ── Imported programme session names ──
  'Push A':             'دفـع أ',
  'Pull A':             'شـد أ',
  'Pull B + Arms':      'شـد ب + الذراعيـن',
  'Pull B + arms':      'شـد ب + الذراعيـن',
  // Names that include the focus inline (as they appear in the imported JSON)
  'Push A — chest focus':    'دفـع أ — تركيـز الصـدر',
  'Push B — shoulder focus': 'دفـع ب — تركيـز الأكتـاف',
  'Pull A — lat focus':      'شـد أ — تركيـز الظهـر',

  // ── Programme title ──
  'Ahmed 12-Week V-Shape Programme': 'برنـامج أحمـد للشكـل ڤـي - ١٢ أسبـوعاً',

  // ── Simple block labels (auto-generated programmes use plain "Block N") ──
  'Block 1': 'المرحـلة ١',
  'Block 2': 'المرحـلة ٢',
  'Block 3': 'المرحـلة ٣',
  'Block 4': 'المرحـلة ٤',
  'Deload':  'تخـفيـف',

  // ── Auto-generated focus tags (from buildProgramme) ──
  'Full Body':        'الجسم الكامل',
  'Push + Pull':      'دفع + شد',
  'Squat focus':      'تركيـز السكوات',
  'Pull + Push':      'شد + دفع',
  'Hinge focus':      'تركيـز المفصـلة',
  'Chest + Shoulders': 'الصـدر + الأكتـاف',
  'Back + Biceps':    'الظهـر + البايسـبس',
  'Legs + Glutes':    'الأرجـل + الأرداف',
  'Shoulder focus':   'تركيـز الأكتـاف',
  'Arms focus':       'تركيـز الذراعيـن',

  // ── Imported programme focus tags ──
  'chest focus':    'تركيـز الصـدر',
  'shoulder focus': 'تركيـز الأكتـاف',
  'lat focus':      'تركيـز الظهـر',

  // ── Imported programme focus tags (longer form) ──
  'Horizontal push · V-shape foundation':              'دفـع أفقـي · أسـاس الشكـل ڤـي',
  'Vertical push · shoulder width · V-shape priority': 'دفـع عمـودي · عرض الأكتـاف · أولوية الشكـل ڤـي',
  'Vertical pull · back width · V-shape priority':     'شـد عمـودي · عـرض الظهـر · أولوية الشكـل ڤـي',
  'Quad + posterior chain · full lower development':   'عضـلات الفخـذ + السـلسلة الخلفـية · تطـوير الجـزء السفـلي',
  'Back detail · arms · V-shape finishing work':       'تفـاصيل الظهـر · الذراعـين · إنهـاء الشكـل ڤـي',

  // ── Exercise notes ──
  'Calibrate week 1':            'أسبـوع المعـايرة',
  'Hip hinge — feel hamstrings': 'مفصـلة الـورك — اشعـر بعضـلات الفخـذ الخلفـية',
  'Drive elbows to hips':        'اسحـب المرفقـين نحـو الوركـين',
  'Keep chest on pad':           'حافـظ علـى الصـدر علـى الوسـادة',
  'Full stretch at bottom':      'تمـدد كامل في الأسفـل',
  'Controlled tempo':            'إيقـاع منضبـط',
  'Rear delt fullness':          'مـلء عضـلة الدلتـا الخلـفية',
  'Key V-shape movement':        'حركـة أسـاسية للشكـل ڤـي',
  'Core — V-shape waist':        'العضـلات الأساسـية — خصـر الشكـل ڤـي',
};

// Block description keywords (the middle segment of "Block N · desc · week N")
const BLOCK_DESCS_AR = {
  'base volume':          'حجـم أسـاسي',
  'progressive overload': 'زيـادة تدريجـية',
  'intensification':      'تكثيـف',
};

/**
 * Translate programme content (session names, focus tags, notes, block labels).
 * Returns the original string if no translation exists, so English data stays intact.
 */
export function translateContent(text, lang) {
  if (!text || lang !== 'ar') return text;

  // 1. Exact match
  if (CONTENT_AR[text]) return CONTENT_AR[text];

  // 2. Block label: "Block N · description · week N"
  const blockMatch = text.match(/^Block (\d+) · (.+) · week (\d+)$/i);
  if (blockMatch) {
    const [, blockNum, desc, weekNum] = blockMatch;
    const arDesc = BLOCK_DESCS_AR[desc.toLowerCase().trim()] || desc;
    return `المرحـلة ${toEasternArabic(blockNum)} · ${arDesc} · الأسبـوع ${toEasternArabic(weekNum)}`;
  }

  // 3. Deload block: "Deload · week N"
  const deloadMatch = text.match(/^Deload · week (\d+)$/i);
  if (deloadMatch) {
    return `تخـفيـف · الأسبـوع ${toEasternArabic(deloadMatch[1])}`;
  }

  return text;
}

// ── Helpers ────────────────────────────────────────────────────────────────────
/** Returns a function t(key) → translated string (or the key itself as fallback). */
export function getT(lang) {
  const dict = lang === 'ar' ? AR : {};
  return (key) => dict[key] ?? key;
}

/** True when the UI should be right-to-left. */
export function isRTL(lang) {
  return lang === 'ar';
}

/** fontFamily for h1 / page headings when Arabic. Pass undefined for English (inherited). */
export function headingFont(lang) {
  return lang === 'ar' ? "'ThmanyahSans', sans-serif" : undefined;
}
