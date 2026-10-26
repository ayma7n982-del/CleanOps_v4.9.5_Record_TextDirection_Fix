import '../../core/localization.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/image_service.dart';
import '../../core/services/report_service.dart';
import 'reports_center.dart';
import '../widgets/app_design.dart';
import '../widgets/operations_overview.dart';
import 'container_management.dart';
import 'global_search.dart';

class Level1SupervisorScreen extends StatefulWidget {
  const Level1SupervisorScreen({super.key});
  @override
  State<Level1SupervisorScreen> createState() => _Level1SupervisorState();
}

class _Level1SupervisorState extends State<Level1SupervisorScreen> {
  int tab = 0, trips = 0, alternativeTrips = 0, remaining = 0;
  bool emergencyLock = false, recording = false, loadingWorkers = true;
  String landfill = 'المكب المركزي';
  Position? reportPosition;
  String? audioPath;
  Timer? timer;
  final street = TextEditingController();
  final issue = TextEditingController();
  final solution = TextEditingController();
  final quantity = TextEditingController();
  final recorder = AudioRecorder();
  final imageService = ImageService();
  final Map<String, Map<String, bool>> ppe = {};
  final Map<String, String> attendanceStatus = {};
  final Map<String, bool> tripPpe = {'بوت': false, 'قفازات': false, 'كمامة': false, 'قبعة': false, 'صديري': false};
  final List<String> tripPhotoPaths = [];
  List<Map<String, String>> workers = [];

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    timer?.cancel();
    street.dispose();
    issue.dispose();
    solution.dispose();
    quantity.dispose();
    recorder.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    final loaded = <String, Map<String, String>>{};
    try {
      final data = context.read<DataService>();
      await data.refreshOperations();
      for (final m in data.operations.where((e) => '${e['_entity'] ?? ''}' == 'worker')) {
        if (m['isDeleted'] == true) continue;
        final id = '${m['id'] ?? ''}';
        if (id.isEmpty) continue;
        loaded[id] = {
          'id': id,
          'name': '${m['name'] ?? ''}',
          'phone': '${m['phone'] ?? ''}',
          'job': '${m['job'] ?? ''}',
          'group': '${m['group'] ?? ''}'
        };
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        workers = loaded.values.where((w) => (w['name'] ?? '').isNotEmpty).toList();
        loadingWorkers = false;
      });
    }
  }

  Future<void> _call(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: normalized);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<Position?> _gps() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _captureGps() async {
    final p = await _gps();
    if (!mounted) return;
    setState(() => reportPosition = p);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تعذر التقاط GPS. تأكد من تفعيل الموقع ومنح الإذن.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تم التقاط GPS: ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)} • الدقة ${p.accuracy.round()} م')));
  }

  Future<void> _addTripPhoto() async {
    final config = context.read<ConfigService>();
    if (emergencyLock || tripPhotoPaths.length >= 3) return;
    try {
      final path = await imageService.pickCompressLocal(targetKb: config.imageTargetKb, context: context);
      if (path == null || !mounted) return;
      setState(() => tripPhotoPaths.add(path));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تمت إضافة صورة للنقلة.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر إضافة الصورة: $e')));
    }
  }

  void _removeTripPhoto(String path) {
    setState(() => tripPhotoPaths.remove(path));
    try { File(path).delete(); } catch (_) {}
  }

  Future<void> _takePhoto(String phase) async {
    final u = context.read<AuthService>().currentUser;
    final c = context.read<ConfigService>();
    if (c.stageFrozen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('المرحلة مجمّدة — التعديلات التشغيلية مقفلة')));
      return;
    }
    if (u == null || !c.streetPhotosEnabled || !u.can('streets', 'create') || emergencyLock) return;
    final id = '${DateTime.now().millisecondsSinceEpoch}_${phase}_${u.id}';
    try {
      final localPath = await imageService.pickCompressLocal(targetKb: c.imageTargetKb, context: context);
      final p = await _gps();
      if (localPath != null) {
        final d = context.read<DataService>();
        await d.enqueue('street_photo', 'create', {
          'id': id,
          'street': street.text.trim(),
          'phase': phase,
          'localAttachmentPath': localPath,
          'attachmentType': 'image',
          'userId': u.id,
          'latitude': p?.latitude,
          'longitude': p?.longitude,
          'caption': ReportService(d).autoCaption(phase: phase == 'قبل' ? 'before' : 'after', streetName: street.text.trim()),
          'createdAt': DateTime.now().toIso8601String(),
          'isDeleted': false,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AppText(localPath == null ? 'لم يتم التقاط الصورة.' : 'تم حفظ صورة $phase محليًا وستتم مزامنتها تلقائيًا عند توفر الاتصال.'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر حفظ الصورة: $e')));
    }
  }

  Future<void> _registerTrip(bool alternative) async {
    final u = context.read<AuthService>().currentUser;
    final config = context.read<ConfigService>();
    if (config.stageFrozen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('المرحلة مجمّدة — التعديلات التشغيلية مقفلة')));
      return;
    }
    if (u == null || emergencyLock || !u.can('trips', 'create')) return;
    if (landfill.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('اختر المكب أو نقطة التجميع قبل تسجيل النقلة.')));
      return;
    }
    if (config.ppeEnabled && !tripPpe.values.every((v) => v)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('لا يمكن اعتماد النقلة قبل تأكيد البوت والقفازات والكمامة والقبعة والصديري.')));
      return;
    }
    final d = context.read<DataService>();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    try {
      await d.enqueue('trip', 'create', {
        'id': id,
        'groupId': u.id,
        'groupName': 'مجموعة المشرف',
        'municipality': u.scope == 'all' ? '' : u.scope,
        'supervisorId': u.id,
        'cartType': alternative ? 'alternative' : 'primary',
        'alternative': alternative,
        'landfill': landfill,
        'estimatedQuantity': quantity.text.trim(),
        'issue': issue.text.trim(),
        'solution': solution.text.trim(),
        'shift': config.shift,
        'street': street.text.trim(),
        'latitude': reportPosition?.latitude,
        'longitude': reportPosition?.longitude,
        'ppeComplete': tripPpe.values.every((v) => v),
        'ppe': Map<String, bool>.from(tripPpe),
        'photoCount': tripPhotoPaths.length,
        'createdAt': DateTime.now().toIso8601String(),
        'isDeleted': false,
      });
      for (var i = 0; i < tripPhotoPaths.length; i++) {
        await d.enqueue('trip_photo', 'create', {
          'id': '${id}_photo_$i',
          'parentTripId': id,
          'localAttachmentPath': tripPhotoPaths[i],
          'attachmentType': 'image',
          'userId': u.id,
          'createdAt': DateTime.now().toIso8601String(),
          'isDeleted': false,
        });
      }
      await d.addActivity('تسجيل نقلة', 'تم تسجيل ${alternative ? 'نقلة كارة بديلة' : 'نقلة كارة أساسية'} إلى $landfill مع ${tripPhotoPaths.length} صورة.', level: 'success');
      if (mounted) {
        setState(() {
          if (alternative) { alternativeTrips++; } else { trips++; }
          tripPhotoPaths.clear();
          tripPpe.updateAll((key, value) => false);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم تسجيل النقلة بنجاح وإضافتها إلى المزامنة.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر تسجيل النقلة. تم الاحتفاظ بالبيانات محليًا إن أمكن. التفاصيل: $e')));
    }
  }

  Future<void> _startAudio() async {
    final c = context.read<ConfigService>();
    if (!c.voiceEnabled || recording || emergencyLock) return;
    if (!await recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('يلزم السماح باستخدام الميكروفون.')));
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/emergency_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (mounted) {
      setState(() {
        recording = true;
        remaining = 10;
        audioPath = path;
      });
    }
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (remaining <= 1) {
        t.cancel();
        await _stopAudio();
      } else {
        setState(() => remaining--);
      }
    });
  }

  Future<void> _stopAudio() async {
    if (!recording) return;
    final path = await recorder.stop();
    if (mounted) {
      setState(() {
        recording = false;
        remaining = 0;
        audioPath = path ?? audioPath;
      });
    }
  }

  Future<void> _sendEmergency() async {
    final u = context.read<AuthService>().currentUser;
    final d = context.read<DataService>();
    if (u == null || emergencyLock || !u.can('emergency', 'create')) return;
    final p = await _gps();
    if (p == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('لا يمكن إرسال البلاغ قبل الحصول على إحداثيات GPS.')));
      return;
    }
    if (recording) await _stopAudio();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await d.enqueue('emergency', 'create', {
      'id': id,
      'type': 'war_remnants',
      'street': street.text.trim(),
      'latitude': p.latitude,
      'longitude': p.longitude,
      'localAttachmentPath': audioPath,
      'attachmentType': 'audio',
      'userId': u.id,
      'reportedBy': u.id,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'urgent',
      'statusLevel': 'critical',
      'isDeleted': false,
    });
    await d.enqueue('notification', 'urgent', {
      'id': '${id}_L2',
      'targetLayer': 'L2',
      'title': 'بلاغ مخلفات حربية عاجل',
      'body': 'بلاغ $id — إيقاف الحركة والتنسيق الفوري.',
      'sourceId': id,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await d.enqueue('notification', 'urgent', {
      'id': '${id}_L3',
      'targetLayer': 'L3',
      'title': 'بلاغ مخلفات حربية عاجل',
      'body': 'بلاغ $id صادر من المشرف الميداني.',
      'sourceId': id,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await d.writeAudit(actorId: u.id, operation: 'CREATE_EMERGENCY', targetId: id, after: {
      'type': 'war_remnants',
      'street': street.text.trim(),
      'latitude': p.latitude,
      'longitude': p.longitude,
      'audioQueued': audioPath != null,
    });
    if (mounted) {
      setState(() {
        emergencyLock = true;
        tab = 3;
      });
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const AppText('تحذير عاجل'),
          content: const AppText('تراجع 100 متر فوراً', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: red)),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const AppText('تم'))],
        ),
      );
    }
  }

  Future<void> _smartReport() async {
    final u = context.read<AuthService>().currentUser;
    if (u == null) return;
    final d = context.read<DataService>();
    final s = await ReportService(d).load(user: u);
    final summary = await ReportService(d).createSmartReport(user: u, snapshot: s, group: 'مجموعة المشرف');
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const AppText('التقرير الذكي'),
          content: AppText(summary),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const AppText('إغلاق'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final config = context.watch<ConfigService>();
    final online = data.online;
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('المشرف الميداني'),
          actions: [
            if (data.queue.isNotEmpty)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Center(child: AppText('${data.queue.length} بانتظار المزامنة', style: const TextStyle(fontSize: 10, color: cleanOpsMuted)))),
            IconButton(tooltip: tr('البحث الذكي'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchPage())), icon: const Icon(Icons.search_rounded)),
            IconButton(onPressed: data.syncing ? null : data.sync, icon: Icon(data.syncing ? Icons.sync : (online ? Icons.cloud_done : Icons.cloud_off), color: online ? aiGreen : orange)),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 120),
            children: [
              AiHero(
                user: context.read<AuthService>().currentUser!,
                eyebrow: 'LEVEL 1 • FIELD MODE',
                title: 'تشغيل ميداني سريع',
                subtitle: 'أربع مهام فقط. اختر الإجراء المطلوب مباشرة دون قوائم مزدحمة.',
              ),
              const SizedBox(height: 12),
              const OperationsOverviewStrip(),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: MediaQuery.sizeOf(context).width >= 700 ? 1.08 : .96,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SupervisorActionCard(icon: Icons.fact_check_rounded, title: 'الحضور', subtitle: 'الحضور وPPE', color: aiGreen, onTap: () => _openAction(context, 'الحضور', _attendance(config))),
                  _SupervisorActionCard(icon: Icons.local_shipping_rounded, title: 'تسجيل نقلة', subtitle: 'تسجيل الترحيل والكميات', color: aiCyan, onTap: () => _openAction(context, 'تسجيل نقلة', _trips(config))),
                  _SupervisorActionCard(icon: Icons.delete_sweep_rounded, title: 'إدخال حالة الحاويات', subtitle: 'تحديث حالة حاويات المجموعة', color: const Color(0xFF8B7CFF), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContainerManagementScreen()))),
                  _SupervisorActionCard(icon: Icons.warning_amber_rounded, title: 'SOS / طوارئ', subtitle: 'إبلاغ فوري مع الموقع', color: red, emergency: true, onTap: () => _openAction(context, 'SOS / طوارئ', _emergency(config))),
                ],
              ),
              const SizedBox(height: 16),
              AiSectionCard(
                title: 'حالة التشغيل',
                subtitle: online ? 'متصل — البيانات تتزامن تلقائيًا.' : 'Offline — التحديثات محفوظة محليًا وستتزامن عند عودة الاتصال.',
                feature: 'sync',
                child: Row(children: [Icon(online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: online ? aiGreen : orange, size: 28), const SizedBox(width: 10), Expanded(child: AppText(online ? 'متصل بالسحابة' : 'وضع Offline', style: TextStyle(color: online ? aiGreen : orange, fontWeight: FontWeight.w900))), if (data.queue.isNotEmpty) AppText('${data.queue.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAction(BuildContext context, String title, Widget child) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: AppText(title)), body: child)));
  }

  Widget _attendance(ConfigService config) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        AiHero(
          user: context.read<AuthService>().currentUser!,
          eyebrow: 'LEVEL 1 • FIELD OPERATIONS',
          title: 'لوحة المشرف الميداني',
          subtitle: 'الحضور، النقلات، توثيق الشوارع والطوارئ ضمن واجهة تشغيل سريعة.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(width: 160, child: AiStatTile(title: 'النقلات', value: '$trips', subtitle: 'كارات أساسية', feature: 'trips')),
            SizedBox(width: 160, child: AiStatTile(title: 'البديلة', value: '$alternativeTrips', subtitle: 'كارات بديلة', feature: 'operations')),
            SizedBox(width: 160, child: AiStatTile(title: 'الحالة', value: emergencyLock ? 'LOCK' : 'READY', subtitle: emergencyLock ? 'بروتوكول طوارئ' : 'تشغيل طبيعي', feature: emergencyLock ? 'emergency' : 'attendance')),
          ],
        ),
        const SizedBox(height: 14),
        SupervisorCardSection(
          title: 'الإعدادات والبيانات الأساسية',
          icon: const Icon(Icons.assignment_outlined),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: ListTile(title: const AppText('التاريخ'), subtitle: AppText(DateTime.now().toString().substring(0, 10)))),
                  Expanded(child: ListTile(title: const AppText('الوقت'), subtitle: AppText(TimeOfDay.now().format(context)))),
                ],
              ),
              DropdownButtonFormField<String>(
                value: config.shift,
                items: const [
                  DropdownMenuItem(value: '08:00 - 16:00', child: AppText('08:00 - 16:00')),
                  DropdownMenuItem(value: '07:00 - 15:00', child: AppText('07:00 - 15:00')),
                  DropdownMenuItem(value: '16:00 - 00:00', child: AppText('16:00 - 00:00')),
                ],
                onChanged: null,
                decoration: InputDecoration(labelText: tr('الوردية المعتمدة')),
              ),
              const SizedBox(height: 8),
              TextField(controller: street, enabled: !emergencyLock, decoration: InputDecoration(labelText: tr('اسم الشارع / المربع'))),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: emergencyLock ? null : _captureGps,
                icon: const Icon(Icons.gps_fixed),
                label: AppText(reportPosition == null ? 'التقاط GPS' : '${reportPosition!.latitude.toStringAsFixed(5)}, ${reportPosition!.longitude.toStringAsFixed(5)}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SupervisorCardSection(
          title: 'الحضور وPPE',
          icon: const Icon(Icons.health_and_safety_outlined),
          child: loadingWorkers
              ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              : workers.isEmpty
                  ? const AppText('لا توجد سجلات عمال مخصصة للمجموعة ضمن البيانات المتاحة. استورد كشف العمال من مستوى البلدية أولاً.')
                  : Column(children: workers.map((w) => _worker(w, config)).toList()),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: emergencyLock || workers.isEmpty ? null : _saveAttendance,
          icon: const Icon(Icons.fact_check_outlined),
          label: const AppText('حفظ كشف الحضور وPPE'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: emergencyLock ? null : _smartReport,
          icon: const Icon(Icons.auto_awesome),
          label: const AppText('إنشاء التقرير الذكي'),
        ),
      ],
    );
  }

  Future<void> _saveAttendance() async {
    final u = context.read<AuthService>().currentUser;
    final config = context.read<ConfigService>();
    if (config.stageFrozen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('المرحلة مجمّدة — التعديلات التشغيلية مقفلة')));
      return;
    }
    if (u == null || !u.can('attendance', 'create')) return;
    if (config.ppeEnabled) {
      final incomplete = workers.where((w) => (attendanceStatus[w['name'] ?? ''] ?? 'present') == 'present').where((w) {
        final state = ppe[w['name'] ?? ''] ?? const <String, bool>{};
        return state.length != 5 || !state.values.every((v) => v);
      }).toList();
      if (incomplete.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('اعتمد البوت والقفازات والكمامة والقبعة والصديري لكل عامل حاضر قبل حفظ الكشف.')));
        return;
      }
    }
    final d = context.read<DataService>();
    for (final w in workers) {
      final name = w['name'] ?? '';
      final state = ppe[name] ?? {};
      final id = '${DateTime.now().microsecondsSinceEpoch}_${name.hashCode}';
      await d.enqueue('attendance', 'create', {
        'id': id,
        'workerId': w['id'],
        'workerName': name,
        'workerRole': w['role'] ?? 'worker',
        'groupId': u.groupId ?? w['groupId'] ?? '',
        'groupName': w['groupName'] ?? u.groupId ?? '',
        'municipalityName': u.scope == 'assigned_only' ? '' : u.scope,
        'status': attendanceStatus[name] ?? 'present',
        'ppeComplete': state.length == 5 && state.values.every((v) => v),
        'ppe': state,
        'reportedBy': u.id,
        'shift': config.shift,
        'createdAt': DateTime.now().toIso8601String(),
        'isDeleted': false,
      });
    }
    await d.addActivity('الحضور وPPE', 'تم حفظ كشف الحضور وفحص معدات الوقاية للمجموعة.', level: 'success');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم حفظ الحضور وفحص PPE في قائمة المزامنة.')));
  }

  Widget _worker(Map<String, String> w, ConfigService config) {
    final name = w['name'] ?? '';
    final state = ppe.putIfAbsent(name, () => {'صديري': false, 'قفازات': false, 'بوت': false, 'كمامة': false, 'قبعة': false});
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: emergencyLock ? null : () => _openSafetyApproval(w, config),
        child: Padding(
          padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(backgroundColor: aiBlue, child: Icon(Icons.person_rounded, color: Colors.white)),
                const SizedBox(width: 8),
                Expanded(child: AppText('${w['name']} — ${w['job']} • المجموعة ${w['group']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                if ((w['phone'] ?? '').isNotEmpty)
                  IconButton(onPressed: emergencyLock ? null : () => _call(w['phone']!), icon: const Icon(Icons.phone, color: green)),
              ],
            ),
            DropdownButtonFormField<String>(
              value: attendanceStatus[name] ?? 'present',
              decoration: InputDecoration(labelText: tr('حالة العامل')),
              items: const [
                DropdownMenuItem(value: 'present', child: AppText('حضور')),
                DropdownMenuItem(value: 'absent', child: AppText('غياب')),
                DropdownMenuItem(value: 'leave', child: AppText('إجازة')),
                DropdownMenuItem(value: 'permission', child: AppText('إذن خاص')),
                DropdownMenuItem(value: 'excused_absence', child: AppText('غياب بعذر')),
                DropdownMenuItem(value: 'unexcused_absence', child: AppText('غياب بدون عذر')),
                DropdownMenuItem(value: 'external_task', child: AppText('مهمة خارج المجموعة')),
              ],
              onChanged: emergencyLock ? null : (v) => setState(() => attendanceStatus[name] = v ?? 'present'),
            ),
            const SizedBox(height: 8),
            if (config.ppeEnabled && (attendanceStatus[name] ?? 'present') == 'present')
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: state.keys.map((k) => FilterChip(
                  label: AppText(k),
                  selected: state[k]!,
                  onSelected: emergencyLock ? null : (v) => setState(() => state[k] = v),
                )).toList(),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _openSafetyApproval(Map<String, String> worker, ConfigService config) async {
    final name = worker['name'] ?? 'العامل';
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cleanOpsSurface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.health_and_safety_rounded, color: aiGreen, size: 42),
            const SizedBox(height: 8),
            const AppText('اعتماد السلامة قبل العمل', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            AppText(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const AppText('تأكد من البوت والقفازات والكمامة والقبعة والصديري قبل اعتماد العامل.', textAlign: TextAlign.center, style: TextStyle(color: cleanOpsMuted)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: aiGreen, foregroundColor: Colors.black), onPressed: () => Navigator.pop(sheetContext, true), icon: const Icon(Icons.check_circle_rounded), label: const AppText('مطابق'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: red, side: const BorderSide(color: red)), onPressed: () => Navigator.pop(sheetContext, false), icon: const Icon(Icons.cancel_rounded, color: red), label: const AppText('غير مطابق', style: TextStyle(color: red)))),
            ]),
          ]),
        ),
      ),
    );
    if (!mounted || result == null) return;
    final state = ppe.putIfAbsent(name, () => {'صديري': false, 'قفازات': false, 'بوت': false, 'كمامة': false, 'قبعة': false});
    setState(() { for (final key in state.keys) { state[key] = result; } });
    if (result && config.ppeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تم اعتماد السلامة للعامل: $name')));
    } else if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('العامل غير مطابق لمتطلبات السلامة: $name')));
    }
  }

  Widget _trips(ConfigService config) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
    children: [
      SupervisorCardSection(
        title: 'النقلات والتوثيق',
        icon: const Icon(Icons.local_shipping_outlined),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _counter('$trips', 'كارة أساسية', navy)),
              Expanded(child: _counter('$alternativeTrips', 'كارة بديلة', orange)),
            ]),
            DropdownButtonFormField<String>(
              value: landfill,
              items: const [
                DropdownMenuItem(value: 'المكب المركزي', child: AppText('المكب المركزي')),
                DropdownMenuItem(value: 'مكب بديل معتمد', child: AppText('مكب بديل معتمد')),
              ],
              onChanged: emergencyLock ? null : (v) => setState(() => landfill = v!),
              decoration: InputDecoration(labelText: tr('المكب / نقطة التجميع')),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: emergencyLock ? null : () => _registerTrip(false), icon: const Icon(Icons.add), label: const AppText('نقلة أساسية'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: emergencyLock || !config.alternativeCartEnabled ? null : () => _registerTrip(true), icon: const Icon(Icons.swap_horiz), label: const AppText('نقلة بديلة'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: quantity, enabled: !emergencyLock, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('الكمية التقديرية (طن/حاويات)'))),
            const SizedBox(height: 8),
            TextField(controller: issue, enabled: !emergencyLock, decoration: InputDecoration(labelText: tr('مشكلة/عطل/إغلاق طريق'))),
            const SizedBox(height: 8),
            TextField(controller: solution, enabled: !emergencyLock, decoration: InputDecoration(labelText: tr('الحل الفوري المتخذ'))),
            if (config.ppeEnabled) ...[
              const SizedBox(height: 14),
              AiSectionCard(title: 'اعتماد السلامة قبل النقلة', subtitle: 'يجب تأكيد جميع معدات الوقاية قبل تسجيل النقلة.', feature: 'permissions', child: Wrap(spacing: 6, runSpacing: 6, children: tripPpe.keys.map((k) => FilterChip(avatar: Icon(k == 'بوت' ? Icons.hiking_rounded : k == 'قفازات' ? Icons.back_hand_rounded : k == 'كمامة' ? Icons.masks_rounded : k == 'قبعة' ? Icons.sports_baseball_rounded : Icons.health_and_safety_rounded, size: 16), label: AppText(k), selected: tripPpe[k]!, onSelected: emergencyLock ? null : (v) => setState(() => tripPpe[k] = v))).toList())),
            ],
            const SizedBox(height: 12),
            AiSectionCard(title: 'صور النقلة', subtitle: 'أضف حتى 3 صور لتوثيق النقلة.', feature: 'streets', child: Column(children: [
              Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.tonalIcon(onPressed: emergencyLock || tripPhotoPaths.length >= 3 ? null : _addTripPhoto, icon: const Icon(Icons.add_a_photo_rounded), label: AppText('إضافة صورة (${tripPhotoPaths.length}/3)'))),
              if (tripPhotoPaths.isNotEmpty) const SizedBox(height: 8),
              if (tripPhotoPaths.isNotEmpty) SizedBox(height: 92, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: tripPhotoPaths.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) { final path = tripPhotoPaths[i]; return Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(path), width: 92, height: 92, fit: BoxFit.cover)), PositionedDirectional(top: 2, end: 2, child: InkWell(onTap: () => _removeTripPhoto(path), child: Container(decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, size: 14, color: Colors.white))))]); })),
            ])),
          ],
        ),
      ),
    ],
  );

  Widget _counter(String v, String label, Color color) => Column(children: [
    AppText(v, style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: color)),
    AppText(label),
  ]);

  Widget _streets(ConfigService config) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
    children: [
      if (!config.streetPhotosEnabled)
        const Card(child: Padding(padding: EdgeInsets.all(16), child: AppText('توثيق الشوارع معطّل من إعدادات المنظومة.')))
      else
        SupervisorCardSection(
          title: 'قبل / بعد + وصف تلقائي',
          icon: const Icon(Icons.camera_alt_outlined),
          child: Column(
            children: [
              TextField(controller: street, enabled: !emergencyLock, decoration: InputDecoration(labelText: tr('اسم الشارع'))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: emergencyLock ? null : () => _takePhoto('قبل'), icon: const Icon(Icons.camera_alt), label: const AppText('قبل'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(onPressed: emergencyLock ? null : () => _takePhoto('بعد'), icon: const Icon(Icons.camera_alt_outlined), label: const AppText('بعد'))),
              ]),
            ],
          ),
        ),
    ],
  );

  Widget _emergency(ConfigService config) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Card(
          color: red.withOpacity(.08),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 72, color: red),
                const AppText('بروتوكول مخلفات حربية', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: red)),
                const SizedBox(height: 8),
                const AppText('لا تقترب. احصل على GPS وأرسل البلاغ ثم تراجع 100 متر فوراً.', textAlign: TextAlign.center),
                const SizedBox(height: 14),
                TextField(controller: street, enabled: !emergencyLock, decoration: InputDecoration(labelText: tr('اسم الشارع / الموقع'))),
                const SizedBox(height: 12),
                if (config.voiceEnabled)
                  FilledButton.icon(
                    onPressed: recording ? _stopAudio : (emergencyLock ? null : _startAudio),
                    icon: Icon(recording ? Icons.stop : Icons.mic),
                    label: AppText(recording ? 'تسجيل جارٍ $remaining ثوانٍ' : 'تسجيل صوتي 10 ثوانٍ'),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: red, minimumSize: const Size.fromHeight(58)),
                  onPressed: emergencyLock ? null : _sendEmergency,
                  icon: const Icon(Icons.gps_fixed),
                  label: const AppText('إرسال إنذار عاجل'),
                ),
                if (emergencyLock)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: AppText('تم قفل النقلات والإدخال. تراجع 100 متر فوراً وانتظر غرفة العمليات.', style: TextStyle(color: red, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(onPressed: _smartReport, icon: const Icon(Icons.auto_awesome), label: const AppText('إنشاء التقرير الذكي')),
      ],
    );
  }
}

class SupervisorCardSection extends StatelessWidget {
  final String title;
  final Widget icon;
  final Widget child;
  const SupervisorCardSection({super.key, required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) => AiSectionCard(
    title: title,
    feature: title.contains('طوارئ')
        ? 'emergency'
        : title.contains('الحضور')
            ? 'attendance'
            : title.contains('النقل')
                ? 'trips'
                : title.contains('الشوارع')
                    ? 'streets'
                    : 'operations',
    child: child,
  );
}


class _SupervisorActionCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Color color; final VoidCallback onTap; final bool emergency;
  const _SupervisorActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap, this.emergency = false});
  @override Widget build(BuildContext context) => Material(
    color: emergency ? red.withOpacity(.12) : cleanOpsSurface,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24), onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(.35)), boxShadow: [BoxShadow(color: color.withOpacity(.07), blurRadius: 20)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 62, height: 62, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [color.withOpacity(.95), aiBlue.withOpacity(.85)]), boxShadow: [BoxShadow(color: color.withOpacity(.22), blurRadius: 20)]), child: Icon(icon, color: Colors.white, size: 31)),
          const SizedBox(height: 12), AppText(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5), AppText(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: cleanOpsMuted)),
        ]),
      ),
    ),
  );
}
