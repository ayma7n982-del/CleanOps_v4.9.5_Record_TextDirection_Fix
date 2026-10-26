# إصلاح أخطاء الترجمة — CleanOps

تمت معالجة الأخطاء المبلغ عنها في هذه الحزمة:
- إضافة الاستيرادات المباشرة اللازمة لـ `AppText` و`cleanOpsText` و`cleanOpsMuted` و`roleNames` في الملفات التي تستخدمها.
- تسمية استيراد حزمة Excel باسم `excel` لتجنب تعارض الاسم `Border` مع `Border` الخاص بـ Flutter، وتحديث استخدام `Excel` و`TextCellValue`.
- تعديل شاشة معاينة المحاكاة لاستخدام getters الثابتة مباشرةً من `SimulationSeederService` بدل التعامل مع اسم الصنف كأنه كائن خدمة.

لم يتم تعديل ملفات قواعد Firestore أو وظائف Firebase ضمن إصلاح أخطاء Dart.

## نتيجة الفحص
- `verify_project.sh`: ALL_STATIC_CHECKS_PASSED
- فحص قواعد Firestore الساكن: FIRESTORE_RULES_STATIC_CHECK_PASSED
- لم يتوفر Flutter/Dart SDK في بيئة الإصلاح؛ لذلك لم يُنفّذ `flutter analyze` أو `flutter build apk`. لا تعتبر هذه الحزمة مختبرة ببناء Flutter الفعلي حتى يتم تشغيل تلك الأوامر في بيئة Flutter.
