import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const arabic = Locale('ar');
  static const english = Locale('en');
  Locale _locale = arabic;
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  void setLocale(Locale locale, {bool persist = true}) {
    if (locale.languageCode != 'ar' && locale.languageCode != 'en') return;
    if (_locale.languageCode == locale.languageCode) {
      if (persist) _persistLocale(locale);
      return;
    }
    _locale = locale;
    _LocaleBridge.current = locale;
    notifyListeners();
    if (persist) _persistLocale(locale);
  }

  Future<void> _persistLocale(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', locale.languageCode);
    } catch (_) {
      // Language switching must remain functional even if local persistence is unavailable.
    }
  }

  void toggle() => setLocale(isArabic ? english : arabic);
}

class I18n {
  static String tr(String source, String languageCode) {
    if (languageCode == 'ar') {
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(source)) return source;
      for (final entry in _en.entries) {
        if (entry.value == source) return entry.key;
      }
      return source;
    }
    final exact = _en[source];
    if (exact != null) return exact;
    return _dynamic(source);
  }

  static String _dynamic(String source) {
    var s = source;
    s = s.replaceFirst(RegExp(r'^إعداد (.+)\n\nيمكن تعديل هذه الإعدادات لاحقًا من مركز إعدادات المنظومة\.$'), r'Configure $1' + '\n\nThese settings can be changed later from System Settings.');
    s = s.replaceFirst(RegExp(r'^(.+) بانتظار المزامنة$'), r'$1 pending sync');
    s = s.replaceFirst(RegExp(r'^آخر مزامنة: (.+)$'), r'Last sync: $1');
    s = s.replaceFirst(RegExp(r'^تعذر حفظ الصورة: (.+)$'), r'Unable to save image: $1');
    s = s.replaceFirst(RegExp(r'^تعذر تحميل التقارير: (.+)$'), r'Unable to load reports: $1');
    s = s.replaceFirst(RegExp(r'^تحديث (.+)$'), r'Updated $1');
    s = s.replaceFirst(RegExp(r'^النطاق: (.+)$'), r'Scope: $1');
    s = s.replaceFirst(RegExp(r'^لا يوجد نشاط منذ (.+)$'), r'No activity for $1');
    s = s.replaceFirst(RegExp(r'^بلاغ مخلفات حربية #(.+)$'), r'UXO incident #$1');
    s = s.replaceFirst(RegExp(r'^المدة الحالية: (.+) يوم$'), r'Current duration: $1 days');
    s = s.replaceFirst(RegExp(r'^تاريخ الإنشاء: (.+)$'), r'Created: $1');
    s = s.replaceFirst(RegExp(r'^ساعات الآليات الثقيلة: (.+)$'), r'Heavy machinery hours: $1');
    s = s.replaceFirst(RegExp(r'^الطوارئ المفتوحة: (.+) — المؤمنة: (.+)$'), r'Open emergencies: $1 — secured: $2');
    s = s.replaceFirst(RegExp(r'^تعذر حفظ الصلاحية: (.+)$'), r'Unable to save permission: $1');
    s = s.replaceFirst(RegExp(r'^تسجيل جارٍ (.+) ثوانٍ$'), r'Recording: $1 seconds');
    s = s.replaceFirst(RegExp(r'^مرحبًا، (.+)$'), r'Hello, $1');
    s = s.replaceFirst(RegExp(r'^تم فتح (.+) من الاختصار\.$'), r'Opened $1 from shortcut.');
    s = s.replaceFirst(RegExp(r'^تم قبول (.+) سجل؛ (.+) يحتاج مراجعة؛ التكرارات: (.+)\.$'), r'Accepted $1 records; $2 need review; duplicates: $3.');
    s = s.replaceFirst(RegExp(r'^تم حفظ صورة (.+) محليًا وستتم مزامنتها تلقائيًا عند توفر الاتصال\.$'), r'Photo $1 was saved locally and will sync automatically when connected.');
    return s;
  }

  static const Map<String, String> _en = {
    'الوردية المعتمدة': 'Approved shift',
    'اسم الشارع / المربع': 'Street / area name',
    'حالة العامل': 'Worker status',
    'المكب / نقطة التجميع': 'Landfill / collection point',
    'الكمية التقديرية (طن/حاويات)': 'Estimated quantity (tons/containers)',
    'مشكلة/عطل/إغلاق طريق': 'Problem / failure / road closure',
    'الحل الفوري المتخذ': 'Immediate solution taken',
    'اسم الشارع / الموقع': 'Street / location',
    'اسم الشارع': 'Street name',
    'اسم المستخدم': 'Username',
    'كلمة المرور': 'Password',
    'نسيت كلمة المرور؟': 'Forgot password?',
    'تم إرسال رابط إعادة التعيين': 'Password reset link sent',
    'إذا كان اسم المستخدم مرتبطًا بحساب نشط، فسيتم إرسال رابط إعادة تعيين كلمة المرور إلى البريد الإلكتروني المسجل للحساب. افتح الرابط واتبع التعليمات لتعيين كلمة مرور جديدة.': 'If the username belongs to an active account, a password reset link will be sent to the email registered for that account. Open the link and follow the instructions to set a new password.',
    'حسنًا': 'OK',
    'أدخل اسم المستخدم لإرسال رابط إعادة تعيين كلمة المرور.': 'Enter the username to send a password reset link.',
    'يلزم الاتصال بالإنترنت لإرسال رابط إعادة تعيين كلمة المرور.': 'An internet connection is required to send a password reset link.',
    'إرسال رابط إعادة التعيين': 'Send reset link',
    'إلغاء': 'Cancel',
    'تأكيد الحذف': 'Confirm deletion',
    'هل أنت متأكد من أنك تريد حذف هذه البيانات نهائياً؟ قد يؤثر ذلك على العمال المرتبطين بها.': 'Are you sure you want to permanently delete this data? It may affect workers linked to it.',
    'حذف': 'Delete',
    'تم الحذف بنجاح': 'Deleted successfully',
    'تعذر الحذف': 'Deletion failed',
    'أدخل اسم المستخدم. سنرسل رابط إعادة تعيين كلمة المرور إلى البريد الإلكتروني المرتبط بالحساب.': 'Enter the username. We will send a password reset link to the email associated with the account.',
    'الاسم الكامل': 'Full name',
    'المستوى': 'Level',
    'النطاق': 'Scope',
    'بحث في العمليات': 'Search operations',
    'اسم المجموعة': 'Group name',
    'رقم المجموعة': 'Group number',
    'التسجيل الصوتي': 'Voice recording',
    'فحص PPE': 'PPE check',
    'صور الشوارع': 'Street photos',
    'الكارة البديلة': 'Alternative cart',
    'سيتم حفظ اسم المستخدم والحالة فقط؛ كلمة المرور لا تُحفظ في Shared Preferences.': 'Only the username and remember state are saved; the password is never stored in Shared Preferences.',
    'اسم المستخدم أو كلمة المرور غير صحيحة.': 'Incorrect username or password.',
    'تعذر الاتصال بالإنترنت.': 'Unable to connect to the internet.',
    'أدخل اسم المستخدم وكلمة المرور.': 'Enter username and password.',
    'منظومة عمليات جمع النفايات الصلبة': 'Solid Waste Collection Operations Platform',
    'مدير المنظومة': 'System Manager',
    'منسق مؤسسة مجلس الخدمات': 'JSC Coordinator',
    'منسق البلدية': 'Municipality Coordinator',
    'مشرف المجموعة': 'Group Supervisor',
    'لوحة التشغيل': 'Operations Dashboard',
    'الحضور والغياب': 'Attendance & Absence',
    'الإجازات والأذونات': 'Leaves & Permissions',
    'النقلات والكارو': 'Trips & Carts',
    'توثيق الشوارع': 'Street Documentation',
    'الإشعارات': 'Notifications',
    'آخر النشاط': 'Recent Activity',
    'التقارير والتحليل': 'Reports & Analytics',
    'العمال والمجموعات': 'Workers & Groups',
    'استيراد/تصدير Excel': 'Excel Import/Export',
    'مركز العمليات': 'Operations Center',
    'الصلاحيات الديناميكية': 'Dynamic Permissions',
    'الإعدادات': 'Settings',
    'المزامنة والتخزين': 'Sync & Storage',
    'المناطق الحرجة': 'Critical Areas',
    'صديري': 'Safety Vest',
    'قفازات': 'Gloves',
    'أحذية أمان': 'Safety Shoes',
    'كمامة': 'Mask',
    'قبعة': 'Helmet',
    'الحضور وPPE': 'Attendance & PPE',
    'بوت': 'Safety Boots',
    'إدخال حالة الحاويات': 'Enter Container Status',
    'الإجراءات السريعة': 'Quick Actions',
    'مساحة العمل': 'Work Space',
    'واجهة العمل الخاصة بالدور الحالي': 'Workspace for the current role',
    'البحث الذكي': 'Smart Search',
    'بحث مرن حتى مع الأخطاء اللغوية': 'Flexible search with language and spelling errors',
    'متصل بـ Firebase — تسجيل الدخول والمزامنة متاحان.': 'Connected to Firebase — login and synchronization are available.',
    'تسجيل الدخول عبر الإنترنت': 'Sign in online',
    'الدخول أوفلاين': 'Offline mode',
    'وضع أوفلاين متاح للجلسة المحفوظة.': 'Offline mode is available for the saved session.',
    'يحفظ الحساب المحلي فقط؛ لا يتم حفظ كلمة المرور.': 'Only the local account is saved; the password is never stored.',
    'لا توجد جلسة محفوظة محليًا. سجّل الدخول مرة واحدة أثناء الاتصال ثم جرّب الدخول أوفلاين.': 'No saved local session is available. Sign in once while online, then try Offline mode.',
    'فعّل «حفظ بيانات الدخول» بعد تسجيل دخول ناجح لاستخدام الدخول أوفلاين.': 'Enable Remember Me after a successful sign-in to use Offline mode.',
    'لا يوجد اتصال. استخدم زر «الدخول أوفلاين» للجلسة المحفوظة.': 'No connection. Use Offline mode for the saved session.',
    'خدمات Firebase غير متاحة حاليًا. يمكنك استخدام الدخول أوفلاين إذا كانت لديك جلسة محفوظة.': 'Firebase services are currently unavailable. You can use Offline mode if a saved session exists.',
    'هذا الحساب غير نشط أو مجمد حاليًا.': 'This account is inactive or frozen.',
    'تسجيل الدخول بواسطة Email/Password غير مفعّل في Firebase.': 'Email/Password sign-in is not enabled in Firebase.',
    'حفظ بيانات الدخول': 'Remember me',
    'مركز إدارة العمليات': 'Operations Management Center',
    'دورة النظافة': 'Work Cycle',
    'العمال': 'Workforce',
    'المكبات': 'Dumpsites',
    'دورات العمل': 'Work Cycles',
    'إنشاء دورة جديدة': 'Create New Work Cycle',
    'أرشفة الدورة': 'Archive Cycle',
    'تجميد دورة المستخدمين': 'Freeze Cycle Users',
    'إضافة مكب جديد': 'Add New Dumpsite',
    'اسم المكب': 'Dumpsite name',
    'الرمز': 'Code',
    'الموقع / الوصف': 'Location / description',
    'إضافة المكب': 'Add Dumpsite',
    'نشط': 'Active',
    'مخفي': 'Hidden',
    'مجمد': 'Frozen',
    'معطل': 'Deactivated',
    'عامل': 'Worker',
    'مشرف مجموعة': 'Group Supervisor',
    'الدور': 'Role',
    'دورة العمل': 'Work Cycle',
    'معرّف المجموعة': 'Group ID',
    'إدارة العمليات': 'Operations Management',
    'معالج إعداد المنظومة': 'System Setup Wizard',
    'السابق': 'Back',
    'التالي': 'Next',
    'تشغيل المنظومة': 'Activate System',
    'إجراء سريع': 'Quick Action',
    'تسجيل الخروج': 'Sign out',
    'مرحبًا بك': 'Welcome',
    'لا توجد إشعارات جديدة': 'No new notifications',
    'فتح الوحدة': 'Open module',
    'لا توجد إشعارات': 'No notifications',
    'إنشاء': 'Create',
    'تعديل': 'Edit',
    'نقل/تبديل': 'Transfer / Switch',
    'حذف منطقي': 'Soft Delete',
    'سجل التدقيق': 'Audit Log',
    'حجم الصورة عند الرفع': 'Upload image size',
    'مدة الاحتفاظ المحلي': 'Local retention period',
    'يومًا': 'days',
    'حالة الاتصال': 'Connection status',
    'تجميد المرحلة': 'Freeze stage',
    'تجميد': 'Freeze',
    'يلزم السماح باستخدام الميكروفون.': 'Microphone permission is required.',
    'لا يمكن إرسال البلاغ قبل الحصول على إحداثيات GPS.': 'The incident cannot be sent before GPS coordinates are available.',
    'تحذير عاجل': 'Urgent Warning',
    'تراجع 100 متر فوراً': 'Move back 100 meters immediately',
    'تم': 'Done',
    'التقرير الذكي': 'Smart Report',
    'إغلاق': 'Close',
    'مشرف المجموعة — التقرير الميداني': 'Group Supervisor — Field Report',
    'التاريخ': 'Date',
    'الوقت': 'Time',
    'حفظ كشف الحضور وPPE': 'Save Attendance & PPE',
    'إنشاء التقرير الذكي': 'Create Smart Report',
    'حضور': 'Present',
    'غياب': 'Absent',
    'إجازة': 'Leave',
    'إذن خاص': 'Special Permission',
    'غياب بعذر': 'Excused Absence',
    'غياب بدون عذر': 'Unexcused Absence',
    'مهمة خارج المجموعة': 'External Task',
    'المكب المركزي': 'Central Landfill',
    'مكب بديل معتمد': 'Approved Alternative Landfill',
    'نقلة أساسية': 'Primary Trip',
    'نقلة بديلة': 'Alternative Trip',
    'توثيق الشوارع معطّل من إعدادات المنظومة.': 'Street documentation is disabled in system settings.',
    'قبل': 'Before',
    'بعد': 'After',
    'بروتوكول مخلفات حربية': 'UXO Protocol',
    'إرسال إنذار عاجل': 'Send Urgent Alert',
    'تم قفل النقلات والإدخال. تراجع 100 متر فوراً وانتظر غرفة العمليات.': 'Trips and input are locked. Move back 100 meters immediately and wait for the operations room.',
    'مركز التقارير والتحليلات': 'Reports & Analytics Center',
    'مركز قرار تشغيلي': 'Operational Decision Center',
    'النقلات اليومية مقابل التزام PPE — آخر 7 أيام': 'Daily Trips vs PPE Compliance — Last 7 Days',
    'ساعات تشغيل الآليات الثقيلة': 'Heavy Machinery Operating Hours',
    'سعة المكب المركزي': 'Central Landfill Capacity',
    'تصدير PDF': 'Export PDF',
    'اعتماد التقرير': 'Approve Report',
    'المستوى 3 — منسق مجلس الخدمات': 'Level 3 — JSC Coordinator',
    'إرسال تحذير للمستويات المعنية': 'Send Warning to Relevant Levels',
    'طلبات الآليات': 'Machinery Requests',
    'توجيه الكباش': 'Dispatch Bulldozer',
    'إحالة': 'Refer',
    'إعادة فتح': 'Reopen',
    'المستوى 4 — مدير المنظومة': 'Level 4 — System Manager',
    'المرحلة التشغيلية': 'Operational Stage',
    'إصدارات الإعدادات': 'Configuration Versions',
    'التحكم التشغيلي الديناميكي': 'Dynamic Operational Controls',
    'سجل النشاط المحلي': 'Local Activity Log',
    'إضافة مستخدم إداري': 'Add Administrative User',
    'المستوى 2 — منسق البلدية': 'Level 2 — Municipality Coordinator',
    'الكارة 01': 'Cart 01',
    'من مجموعة 01 → مجموعة 02': 'From Group 01 → Group 02',
    'تنفيذ إعادة التوجيه': 'Execute Redirection',
    'ركود': 'Stagnation',
    'عن التطبيق والمطور': 'About App & Developer',
    'المطور': 'Developer',
    'البريد الإلكتروني': 'Email',
    'واتساب': 'WhatsApp',
    'حالة النظام': 'System status',
    'آخر مزامنة': 'Last sync',
    'صور الرفع': 'Upload images',
    'حسب آخر تسجيل': 'Based on latest entry',
    'نقلة مسجلة': 'Recorded trips',
    'قيد التشغيل/الإنجاز': 'In progress / completed',
    'تحتاج متابعة': 'Needs follow-up',
    'المرحلة مجمّدة — التعديلات التشغيلية مقفلة': 'Stage frozen — operational changes are locked',
    'مركز عمليات AI': 'AI Operations Center',
    'الموارد': 'Workforce',
    'الدورات': 'Cycles',
    'إدارة القوى العاملة': 'Workforce Management',
    'إضافة مشرف أو عامل': 'Add Supervisor or Worker',
    'إصدار الحساب': 'Provision Account',
    'مستخدمو الدورة': 'Cycle Users',
    'أوامر الدورة': 'Cycle Commands',
    'إدارة المكبات': 'Dumpsite Management',
    'إضافة مكب': 'Add Dumpsite',
    'اسم المكب بالعربية': 'Dumpsite name (Arabic)',
    'اسم المكب بالإنجليزية': 'Dumpsite name (English)',
    'Dumpsite Name (EN)': 'Dumpsite Name (EN)',
    'السعة': 'Capacity',
    'نسبة الامتلاء %': 'Fill percentage %',
    'الامتلاء %': 'Fill %',
    'حالة المكب': 'Dumpsite status',
    'تعديل بيانات المكب': 'Edit Dumpsite',
    'حفظ': 'Save',
    'وضع التركيز': 'Focus Mode',
    'عرض المؤشرات الحرجة فقط وإخفاء القوائم الثانوية': 'Show critical KPIs only and hide secondary menus',
    'وضع التركيز — ': 'Focus Mode — ',
    'المؤشرات التشغيلية الحرجة فقط': 'Critical operational KPIs only',
    'الدورة الحالية': 'Current Cycle',
    'العمال النشطون': 'Active Workers',
    'المجموعات النشطة': 'Active Groups',
    'التنبيهات الحرجة': 'Critical Alerts',
    'المكبات المسجلة': 'Registered Dumpsites',
    'دورات النظافة': 'Work Cycles',
    'إنشاء دورة وتشغيلها': 'Create & Activate Cycle',
    'سجل الدورات': 'Cycle History',
    'نقل عامل': 'Transfer Worker',
    'تبديل عاملين': 'Swap Workers',
    'تجميد مستخدمي الدورة': 'Freeze Cycle Users',
    'نوع الحساب': 'Account Type',
    'المجموعة الجديدة': 'New Group',
    'معرّف العامل': 'Worker ID',
    'المجموعة': 'Group',
    'الجوال': 'Phone',
    'الموقع': 'Location',
    'مركز القيادة': 'Command Center',
    'المساعد الذكي': 'AI Assistant',
    'المساعد التشغيلي الذكي': 'AI Operations Assistant',
    'مساعد عمليات الذكاء الاصطناعي': 'AI Operations Assistant',
    'مركز القرار التشغيلي': 'Operational Decision Center',
    'نبض النظام': 'System Pulse',
    'دورة نشطة': 'Active cycle',
    'إجراءات سريعة': 'Quick Actions',
    'إضافة مستخدم': 'Add User',
    'إدارة مكب': 'Manage Dumpsite',
    'دورة جديدة': 'New Cycle',
    'التنبيهات والمخاطر': 'Alerts & Risks',
    'الخط الزمني التشغيلي': 'Operational Timeline',
    'تنبيهات حرجة': 'Critical Alerts',
    'مسار العمليات': 'Operations Route',
    'القوى العاملة': 'Workforce',
    'الحضور': 'Attendance',
    'النقلات': 'Trips',
    'الشوارع': 'Streets',
    'الحرج': 'Critical',
    'مساحة المستوى': 'Role Workspace',
    'واجهة العمليات الخاصة بالدور الحالي': 'Operational workspace for the current role',
    'استيراد كشف Excel': 'Import Excel Roster',
    'إعادة توجيه الكارات': 'Cart Redirection',
    'تنبيهات الركود — أكثر من 90 دقيقة': 'Stagnation Alerts — More Than 90 Minutes',
    'الإعدادات العامة': 'General Settings',
    'مصفوفة الخصائص': 'Feature Matrix',
    'إدارة المستخدمين': 'User Management',
    'العامل': 'Worker',
    'تنفيذ': 'Execute',
    'الأول': 'First',
    'الثاني': 'Second',
    'تبديل': 'Switch',
    'مركز الرسائل': 'Messages Center',
    'رسالة جديدة': 'New Message',
    'تواصل تشغيلي مباشر': 'Direct Operational Communication',
    'رسائل داخلية لحظية تعمل مع التخزين المحلي ولا تعتمد على FCM.': 'Real-time internal messages with local storage; no FCM required.',
    'لا توجد رسائل بعد': 'No messages yet',
    'ستظهر الرسائل الموجهة إليك أو إلى مجموعتك هنا تلقائيًا.': 'Messages sent to you or your group will appear here automatically.',
    'إرسال رسالة': 'Send Message',
    'إرسال رسالة داخلية': 'Send Internal Message',
    'نوع الرسالة': 'Message Type',
    'معلومة': 'Info',
    'تحذير': 'Warning',
    'طوارئ / SOS': 'Emergency / SOS',
    'تقرير ميداني': 'Field Report',
    'المجموعة المستهدفة': 'Target Group',
    'رسالة إلى منسق البلدية': 'Message to Municipality Coordinator',
    'محتوى الرسالة': 'Message Content',
    'اكتب الرسالة هنا...': 'Write the message here...',
    'إرسال': 'Send',
    'جارٍ الحفظ...': 'Saving...',
    'بث للبلديات': 'Municipality Broadcast',
    'رسالة مباشرة': 'Direct Message',
    'مركز الإدارة والتشغيل': 'Operations Management Hub',
    'مركز التنبيهات': 'Alerts Center',
    'التنبيهات الحرجة والبلاغات': 'Critical alerts and incidents',
    'مركز المزامنة': 'Sync Center',
    'Offline / Online والطوابير': 'Offline / Online and queues',
    'صحة النظام': 'System Health',
    'Firebase والخدمات المحلية': 'Firebase and local services',
    'البحث الشامل': 'Global Search',
    'المستخدمون والعمليات والمكبات': 'Users, operations and dumpsites',
    'مركز المجموعات': 'Groups Command Center',
    'المشرفون والعمال والحالة': 'Supervisors, workers and status',
    'سجل الترحيلات': 'Trips Log',
    'سجلات النقل الفعلية': 'Actual transport records',
    'التقرير التنفيذي': 'Executive Report',
    'مؤشرات تشغيلية من البيانات': 'Operational metrics from live data',
    'من فعل ماذا ومتى': 'Who did what and when',
    'مركز الملفات': 'Files Center',
    'صور ومرفقات العمليات': 'Operation photos and attachments',
    'لقطة تشغيلية حقيقية': 'Live operational snapshot',
    'تُقرأ من Firestore ولا تستخدم أرقامًا تجريبية': 'Read from Firestore; no demo numbers are used',
    'نشطون': 'Active',
    'المشرفون': 'Supervisors',
    'المجموعات': 'Groups',
    'الترحيلات': 'Trips',
    'الطوارئ': 'Emergencies',
    'التقارير': 'Reports',
    'مكبات حرجة': 'Critical dumpsites',
    'مركز التشغيل': 'Operations Center',
    'قراءة تشغيلية حقيقية': 'Live operational data',
    'مؤشرات تشغيلية حية': 'Live operational metrics',
    'من بيانات المستخدمين': 'From user data',
    'سجلات تشغيلية': 'Operational records',
    'مجموعات مرتبطة': 'Linked groups',
    'سجلات حرجة': 'Critical records',
    'جاري قراءة البيانات': 'Reading live data',
    'الرسائل المحلية': 'Local messaging',
    'الرسائل Online': 'Online messaging',
    'مزامنة الآن': 'Sync now',
    'طابور البيانات المحلي': 'Local data queue',
    'عمليات بانتظار المزامنة': 'Operations waiting to sync',
    'مزامنة تلقائية': 'Automatic sync',
    'الرسائل غير المقروءة': 'Unread messages',
    'سلوك Offline': 'Offline behavior',
    'البيانات التي تسمح بها الصلاحيات تُحفظ محليًا وتنتظر المزامنة عند عودة الاتصال. لا يتم استخدام FCM.': 'Permitted data is stored locally and waits for sync when connectivity returns. FCM is not used.',
    'فحص فعلي للخدمات المتاحة': 'Live check of available services',
    'جلسة نشطة': 'Active session',
    'لا توجد جلسة': 'No session',
    'غير مهيأ': 'Not initialized',
    'غير متاح': 'Unavailable',
    'مفعّل بلا عنوان': 'Enabled without a URL',
    'لا توجد مجموعات مسجلة.': 'No groups are registered.',
    'الأرقام الحالية مأخوذة من Firestore وقت إنشاء التقرير.': 'Current figures are read from Firestore when the report is created.',
    'المؤشرات التشغيلية': 'Operational metrics',
    'قراءة فقط • Level 4': 'Read only • Level 4',
    'لا توجد عمليات مسجلة بعد.': 'No operations have been recorded yet.',
    'الملفات المرفوعة': 'Uploaded files',
    'تُقرأ من Firebase Storage • الصور والتسجيلات الميدانية': 'Read from Firebase Storage • field photos and recordings',
    'لا توجد ملفات مرفوعة بعد.': 'No files have been uploaded yet.',
    'رابط الملف': 'File link',
    'مركز الأمان': 'Security Center',
    'الحساب والجلسة وإعادة كلمة المرور': 'Account, session and password reset',
    'الحساب الحالي': 'Current account',
    'الحالة': 'Status',
    'لا تُحفظ داخل Firestore أو LocalStore': 'Not stored in Firestore or LocalStore',
    'إعادة كلمة المرور': 'Password reset',
    'يُرسل رابط إعادة التعيين إلى البريد المرتبط بالحساب': 'The reset link is sent to the email linked to the account',
    'تم إرسال رابط إعادة التعيين.': 'Password reset link sent.',
    'تعذر إرسال الرابط.': 'Unable to send the reset link.',
    'سياسة الأمان': 'Security Policy',
    'كلمات المرور': 'Passwords',
    'تُدار عبر Firebase Authentication ولا تُكتب في Firestore.': 'Managed by Firebase Authentication and never written to Firestore.',
    'لا يتم تخزين كلمة المرور في التخزين المحلي.': 'The password is never stored locally.',
    'FCM': 'FCM',
    'المشرف الميداني': 'Field Supervisor',
    'تشغيل ميداني سريع': 'Fast Field Operations',
    'تسجيل نقلة': 'Log Load',
    'حالة الحاويات': 'Container Status',
    'SOS / طوارئ': 'SOS / Emergency',
    'إدارة الحاويات': 'Container Management',
    'فارغة': 'Empty',
    'نصف ممتلئة': 'Partial',
    'ممتلئة': 'Full',
    'مشكلة مسجلة': 'Issue Reported',
    'إجراء تصحيحي - قيد المعالجة': 'Corrective Action - In Progress',
    'توكيد حل المشكلة': 'Confirm Issue Resolved',
    'لا توجد مشكلة': 'No Issue',
    'لوحة القيادة': 'Dashboard',
    'الإدارة': 'Management',
    'التقارير والرسائل': 'Reports & Messaging',
    'إدارة العمال': 'Worker Management',
    'إدارة العمال والمجموعات': 'Manage Workers & Groups',
    'فتح إدارة الحاويات': 'Open Container Management',
    'فتح التقارير': 'Open Reports',
    'فتح الرسائل': 'Open Messages',
    'حالة التشغيل': 'Operational Status',
    'متصل بالسحابة': 'Connected to cloud',
    'تشغيل طبيعي': 'Normal Operation',
    'بروتوكول طوارئ': 'Emergency Protocol',
    'حاوية ممتلئة': 'Full container',
    'مشكلة حاوية مسجلة': 'Container issue reported',
    'إجراء تصحيحي قيد المعالجة للحاوية': 'Corrective action in progress for container',
    'تم تأكيد حل مشكلة الحاوية': 'Container issue resolution confirmed',
    'اسم الموقع': 'Location name',
    'Latitude': 'Latitude',
    'Longitude': 'Longitude',
    'معرّف البلدية / منسق البلدية': 'Municipality / coordinator ID',
    'معرّف المجموعة (اختياري)': 'Group ID (optional)',
    'إضافة حاوية جديدة': 'Add New Container',
    'تعديل الحاوية': 'Edit Container',
    'حفظ الحاوية': 'Save Container',
    'الحالة اليومية': 'Daily status',
    'ملاحظة مشكلة / عطل / عدم إمكانية الوصول': 'Issue / fault / access note',
    'تفاصيل الإجراء التصحيحي': 'Corrective action details',    'أربع مهام فقط. اختر الإجراء المطلوب مباشرة دون قوائم مزدحمة.': 'Four actions only. Choose the required task directly without clutter.',
    'تسجيل الترحيل والكميات': 'Log load and quantities',
    'فارغة • نصف ممتلئة • ممتلئة': 'Empty • Partial • Full',
    'إبلاغ فوري مع الموقع': 'Immediate report with location',
    'متصل — البيانات تتزامن تلقائيًا.': 'Online — data syncs automatically.',
    'Offline — التحديثات محفوظة محليًا وستتزامن عند عودة الاتصال.': 'Offline — updates are saved locally and sync when connected.',
    'مركز القيادة والتنسيق': 'Command & Coordination Center',
    'سعة المكب': 'Dumpsite Capacity',
    'منسق JSC': 'JSC Coordinator',
    'تنبيه مرتفع': 'High Alert',
    'ضمن النطاق': 'Within Range',
    'بلاغات مرصودة': 'Reported Cases',
    'اتركه فارغًا إذا لا توجد مشكلة': 'Leave empty if there is no issue.',
    'Active': 'نشط',
    'Hidden': 'مخفي',
    'غير معرفة': 'Undefined',
    'البلدية المرتبطة تلقائيًا': 'Automatically linked municipality',
    'رقم المجموعة — باسم المنسق المختار': 'Group number — by selected coordinator',
    'جارٍ تحميل مجموعات المنسق...': 'Loading coordinator groups...',
    'استيراد العمال الذكي': 'Smart Worker Import',
    'فحص ذكي واستيراد': 'Smart Scan & Import',
    'اختيار ملف Excel': 'Choose Excel File',
    'تغيير ملف Excel': 'Change Excel File',
    'جارٍ اختيار الملف...': 'Selecting file...',
    'جارٍ الفحص والاستيراد...': 'Scanning & importing...',
    'سيتم توجيه الرسالة وفق نطاق الدور والصلاحيات.': 'The message will be routed according to role scope and permissions.',
    'ستصل الرسالة إلى المجموعة المختارة.': 'The message will be delivered to the selected group.',
    'ستصل الرسالة إلى جميع منسقي البلديات.': 'The message will be delivered to all municipality coordinators.',
    'الحساب جاهز للدخول الآن، وتم تحديث القائمة تلقائيًا. لم يتم حفظ كلمة المرور داخل Firestore.': 'The account is ready to sign in and the list was updated automatically. The password was not stored in Firestore.',
    'تم إنشاء العامل': 'Worker created',
    'تم إنشاء مشرف المجموعة': 'Group Supervisor created',
    'اكتب سؤالك التشغيلي...': 'Type your operational question...',
    'مثال: بلدية نابلس': 'Example: Nablus Municipality',
    'ابحث في المستخدمين والعمليات والمكبات والدورات': 'Search users, operations, dumpsites and cycles',
    'اسم الدورة': 'Cycle name',
    'اسم البلدية المرتبطة بالمنسق': 'Municipality linked to coordinator',
    'الرقم الوظيفي': 'Employee ID',
    'المسمى الوظيفي': 'Job title',

  };
}

class AppText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextScaler? textScaler;
  final Color? selectionColor;

  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.locale,
    this.strutStyle,
    this.textScaler,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleController>().locale.languageCode;
    final width = MediaQuery.sizeOf(context).width;
    final factor = (width / 390).clamp(.88, 1.10).toDouble();
    final responsiveStyle = style?.fontSize == null
        ? style
        : style!.copyWith(fontSize: style!.fontSize! * factor);
    return Text(
      I18n.tr(data, language),
      style: responsiveStyle,
      textAlign: textAlign,
      textDirection: textDirection ?? (language == 'ar' ? TextDirection.rtl : TextDirection.ltr),
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale,
      strutStyle: strutStyle,
      textScaler: textScaler,
      selectionColor: selectionColor,
    );
  }
}

String tr(String source) => I18n.tr(source, _LocaleBridge.current.languageCode);

class _LocaleBridge {
  static Locale current = LocaleController.arabic;
}
