import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/core_models.dart';
import 'config_service.dart';

class AIService {
  final FirebaseFirestore firestore;
  final ConfigService config;

  AIService({FirebaseFirestore? firestore, required this.config})
      : firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> answer({required AppUser user, required String question}) async {
    if (user.role != 'donor_manager' && user.role != 'jsc_coordinator') {
      throw StateError('المساعد الذكي متاح للمستوى 3 والمستوى 4 فقط.');
    }
    if (!config.aiEnabled) {
      throw StateError('المساعد الذكي غير مفعّل. يمكن للمستوى 3 أو 4 تفعيله وإضافة مفتاح API من الإعدادات.');
    }
    final apiKey = config.aiApiKey.trim();
    if (apiKey.isEmpty) {
      throw StateError('مفتاح OpenAI غير مضبوط. افتح إعدادات الذكاء الاصطناعي وأدخل المفتاح بأمان.');
    }
    final prompt = await _buildPrompt(user, question);
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': config.aiModel.trim().isEmpty ? 'gpt-5.6-luna' : config.aiModel.trim(),
        'instructions': 'أنت CleanOps AI، مساعد تشغيلي لمنظومة إدارة النفايات الصلبة. استخدم فقط البيانات التشغيلية الموجودة في السياق المرفق. لا تخترع أرقامًا أو مستخدمين أو ترحيلات أو تنبيهات. إذا كانت المعلومة غير موجودة فقل بوضوح إنها غير متاحة. لا تنفذ أي إجراء تشغيلي أو تغيّر بيانات؛ أنت مساعد تحليلي فقط. احترم مستوى المستخدم وصلاحياته. أجب بالعربية إذا كان السؤال عربيًا وبالإنجليزية إذا كان السؤال إنجليزيًا. اجعل الإجابة مختصرة ومفيدة للإدارة.',
        'input': prompt,
        'store': false,
        'max_output_tokens': 900,
      }),
    ).timeout(Duration(seconds: config.apiTimeoutSeconds.clamp(10, 120)));

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map
          ? '${error['message'] ?? 'تعذر الاتصال بخدمة الذكاء الاصطناعي.'}'
          : 'تعذر الاتصال بخدمة الذكاء الاصطناعي (${response.statusCode}).';
      throw StateError(message);
    }
    final outputText = body['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) return outputText.trim();
    final output = body['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map && item['content'] is List) {
          for (final content in item['content']) {
            if (content is Map && content['text'] is String && '${content['text']}'.trim().isNotEmpty) {
              return '${content['text']}'.trim();
            }
          }
        }
      }
    }
    throw StateError('لم تُرجع خدمة الذكاء الاصطناعي نصًا صالحًا.');
  }

  Future<String> _buildPrompt(AppUser user, String question) async {
    final context = await _fetchOperationalContext(user);
    return 'السؤال من المستخدم: $question\n\nالسياق التشغيلي الحقيقي من Firestore (تم جلبه الآن):\n${_pretty(context)}\n\nأجب اعتمادًا على هذا السياق فقط. عند السؤال عن اليوم استخدم تاريخ اليوم المذكور في السياق.';
  }

  Future<Map<String, dynamic>> _fetchOperationalContext(AppUser user) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final usersSnap = await firestore.collection('users').where('isActive', isEqualTo: true).limit(1000).get();
    var activeWorkers = 0;
    var activeSupervisors = 0;
    final groups = <String>{};
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final role = '${data['role'] ?? ''}';
      if (role == 'worker') activeWorkers++;
      if (role == 'group_supervisor') activeSupervisors++;
      final groupId = '${data['groupId'] ?? ''}'.trim();
      if (groupId.isNotEmpty) groups.add(groupId);
    }

    final dumpsitesSnap = await firestore.collection('dumpsites').where('isActive', isEqualTo: true).limit(500).get();
    final dumpsites = <Map<String, dynamic>>[];
    for (final doc in dumpsitesSnap.docs) {
      final d = doc.data();
      final capacity = _number(d['capacity']);
      final fill = _number(d['fillPercentage']);
      dumpsites.add({
        'name': '${d['nameAr'] ?? d['name'] ?? doc.id}',
        'capacity': capacity,
        'fillPercentage': fill,
        'availableCapacity': capacity > 0 ? capacity * (1 - fill / 100) : null,
      });
    }

    final opsSnap = await firestore.collection('operations').limit(1500).get();
    var loadsToday = 0;
    var activeEmergencies = 0;
    for (final doc in opsSnap.docs) {
      final d = doc.data();
      final created = _parseDate(d['createdAt']);
      final entity = '${d['_entity'] ?? ''}';
      if (entity == 'trip' && created != null && !created.isBefore(start) && created.isBefore(end) && d['isDeleted'] != true) {
        loadsToday++;
      }
      if (entity == 'emergency' && d['isDeleted'] != true) {
        final status = '${d['status'] ?? ''}'.toLowerCase();
        final level = '${d['statusLevel'] ?? ''}'.toLowerCase();
        if (!['resolved', 'closed', 'secured', 'referred_to_eod'].contains(status) || level == 'critical') {
          activeEmergencies++;
        }
      }
    }

    return {
      'date': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      'managementLevel': user.role == 'donor_manager' ? 4 : 3,
      'activeWorkers': activeWorkers,
      'activeGroupSupervisors': activeSupervisors,
      'activeGroups': groups.length,
      'loadsTransferredToday': loadsToday,
      'activeSOSorEmergencies': activeEmergencies,
      'activeDumpsites': dumpsites.length,
      'dumpsites': dumpsites,
      'source': 'Firestore live operational collections',
    };
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse('$value');
  }

  String _pretty(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    data.forEach((key, value) {
      if (key == 'dumpsites' && value is List) {
        buffer.writeln('dumpsites:');
        for (final site in value) {
          buffer.writeln('- ${site['name']}: capacity=${site['capacity']}, fill=${site['fillPercentage']}%, available=${site['availableCapacity']}');
        }
      } else {
        buffer.writeln('$key: $value');
      }
    });
    return buffer.toString();
  }
}
