import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/operations_admin_service.dart';
import '../widgets/app_design.dart';
import '../widgets/location_picker.dart';

class OperationsManagementScreen extends StatefulWidget {
  final int initialTab;
  const OperationsManagementScreen({super.key, this.initialTab = 0});
  @override
  State<OperationsManagementScreen> createState() => _OperationsManagementScreenState();
}

class _OperationsManagementScreenState extends State<OperationsManagementScreen> {
  late int tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final tabs = <Widget>[];
    final labels = <Tab>[];
    if (user.role == 'municipality_coordinator') {
      tabs.add(const _WorkforceTab());
      labels.add(Tab(text: tr('الموارد')));
    }
    if (user.role == 'municipality_coordinator' || user.role == 'jsc_coordinator') {
      tabs.add(const _DumpsitesTab());
      labels.add(Tab(text: tr('المكبات')));
    }
    if (user.role == 'donor_manager') {
      tabs.add(const _CyclesTab());
      labels.add(Tab(text: tr('الدورات')));
    }
    if (tabs.isEmpty) {
      return const Scaffold(body: Center(child: AppText('لا توجد صلاحيات لهذه الوحدة.')));
    }
    final safe = tab.clamp(0, tabs.length - 1);
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: cleanOpsBg,
        appBar: AppBar(
          title: const AppText('مركز عمليات AI'),
          actions: const [Padding(padding: EdgeInsetsDirectional.only(end: 12), child: AiFeatureIcon('operations', size: 16))],
          bottom: TabBar(isScrollable: true, onTap: (i) => setState(() => tab = i), tabs: labels),
        ),
        body: IndexedStack(index: safe, children: tabs),
      ),
    );
  }
}

class _CyclesTab extends StatefulWidget {
  const _CyclesTab();
  @override
  State<_CyclesTab> createState() => _CyclesTabState();
}

class _CyclesTabState extends State<_CyclesTab> {
  final name = TextEditingController();
  DateTime start = DateTime.now();
  DateTime end = DateTime.now().add(const Duration(days: 1));
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _newCycle() async {
    final u = context.read<AuthService>().currentUser!;
    if (!end.isAfter(start)) return;
    setState(() => busy = true);
    try {
      await context.read<OperationsAdminService>().createWorkCycle(
        name: name.text.trim().isEmpty ? 'Cycle ${start.year}-${start.month.toString().padLeft(2, '0')}' : name.text.trim(),
        startDate: start,
        endDate: end,
        createdBy: u.id,
      );
      name.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم إنشاء دورة جديدة.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pick(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isStart ? start : end,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (isStart) {
        start = d;
        if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
      } else {
        end = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<OperationsAdminService>();
    final days = end.difference(start).inDays;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        AiHero(
          user: context.read<AuthService>().currentUser!,
          eyebrow: 'LEVEL 4 • AI GOVERNANCE',
          title: 'دورات النظافة',
          subtitle: 'إدارة دورة العمل بمدة يحددها المدير يدويًا من تاريخ البداية إلى تاريخ النهاية دون حد ثابت.',
        ),
        const SizedBox(height: 14),
        AiSectionCard(
          title: 'إنشاء دورة جديدة',
          subtitle: 'المدة الحالية: $days يوم',
          feature: 'cycle',
          child: Column(
            children: [
              TextField(controller: name, decoration: InputDecoration(labelText: tr('اسم الدورة'))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.event), label: Text(_fmt(start)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.event_available), label: Text(_fmt(end)))),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy || days <= 0 ? null : _newCycle,
                  icon: const Icon(Icons.auto_awesome),
                  label: const AppText('إنشاء دورة وتشغيلها'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: svc.activeCycles(),
          builder: (_, snap) {
            if (snap.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 34),
                    const SizedBox(height: 8),
                    const AppText('خطأ في بيانات الدورات', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh), label: const AppText('إعادة المحاولة')),
                  ]),
                ),
              );
            }
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
            if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Center(child: AppText('تعذر تحميل الدورات. تحقق من الاتصال ثم أعد المحاولة.'))));
            final docs = [...snap.data!.docs]..sort((a, b) =>
                '${a.data()['nameAr'] ?? a.data()['name'] ?? a.id}'.compareTo('${b.data()['nameAr'] ?? b.data()['name'] ?? b.id}'));
            if (docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Center(child: AppText('لا توجد دورات مسجلة بعد.'))));
            return AiSectionCard(
              title: 'سجل الدورات',
              subtitle: 'الدورة النشطة والدورات المؤرشفة',
              feature: 'reports',
              child: Column(
                children: docs.map((d) {
                  final x = d.data();
                  final active = x['status'] == 'active';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: active ? aiGreen.withOpacity(.06) : Colors.white.withOpacity(.025),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        AiFeatureIcon('cycle', size: 16, filled: active),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText('${x['nameAr'] ?? x['name'] ?? x['title'] ?? 'دورة بدون اسم'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              AppText('${_date(x['startDate'] ?? x['startAt'] ?? x['start'])} → ${_date(x['endDate'] ?? x['endAt'] ?? x['end'])}', style: const TextStyle(fontSize: 11, color: cleanOpsMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? aiGreen.withOpacity(.12) : Colors.grey.withOpacity(.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AppText(active ? 'ACTIVE' : 'ARCHIVED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: active ? Colors.green : Colors.grey)),
                        ),
                        if (active)
                          IconButton(
                            tooltip: 'Archive',
                            onPressed: () => svc.archiveCycle(d.id, archivedBy: context.read<AuthService>().currentUser!.id),
                            icon: const Icon(Icons.archive_outlined),
                          ),
                        if (context.read<AuthService>().currentUser!.can('cycle', 'delete'))
                          IconButton(
                            tooltip: tr('حذف'),
                            color: Colors.red,
                            onPressed: () => _confirmDeleteCycle(context, d.id),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmDeleteCycle(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(tr('تأكيد الحذف')),
        content: AppText(tr('هل أنت متأكد من أنك تريد حذف هذه البيانات نهائياً؟ قد يؤثر ذلك على العمال المرتبطين بها.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: AppText(tr('إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: AppText(tr('حذف'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<OperationsAdminService>().deleteWorkCycle(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(tr('تم الحذف بنجاح'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('${tr('تعذر الحذف')}: $e')));
      }
    }
  }
}

class _DumpsitesTab extends StatefulWidget {
  const _DumpsitesTab();
  @override
  State<_DumpsitesTab> createState() => _DumpsitesTabState();
}

class _DumpsitesTabState extends State<_DumpsitesTab> {
  final nameAr = TextEditingController();
  final nameEn = TextEditingController();
  final capacity = TextEditingController();
  final fillPercentage = TextEditingController(text: '0');
  final code = TextEditingController();
  final location = TextEditingController();
  LatLng? selectedLocation;
  bool busy = false;

  @override
  void dispose() {
    nameAr.dispose();
    nameEn.dispose();
    capacity.dispose();
    fillPercentage.dispose();
    code.dispose();
    location.dispose();
    super.dispose();
  }

  double? _number(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

  @override void initState() { super.initState(); _loadPhoneLocation(); }
  Future<void> _loadPhoneLocation() async { try { if(!await Geolocator.isLocationServiceEnabled()) return; var p=await Geolocator.checkPermission(); if(p==LocationPermission.denied)p=await Geolocator.requestPermission(); if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return; final x=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:8))); if(mounted)setState(()=>selectedLocation=LatLng(x.latitude,x.longitude)); } catch(_) {} }

  Future<void> _saveNew() async {
    final u = context.read<AuthService>().currentUser!;
    final cap = _number(capacity.text);
    final fill = _number(fillPercentage.text);
    if (nameAr.text.trim().isEmpty || nameEn.text.trim().isEmpty || cap == null || fill == null || cap < 0 || fill < 0 || fill > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('أدخل الاسم بالعربية والإنجليزية والسعة ونسبة الامتلاء بشكل صحيح.')));
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<OperationsAdminService>().addDumpsite(
        nameAr: nameAr.text,
        nameEn: nameEn.text,
        capacity: cap,
        fillPercentage: fill,
        code: code.text,
        location: location.text,
        latitude: selectedLocation?.latitude,
        longitude: selectedLocation?.longitude,
        actorId: u.id,
      );
      nameAr.clear();
      nameEn.clear();
      capacity.clear();
      fillPercentage.text = '0';
      code.clear();
      location.clear();
      selectedLocation = null;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تمت إضافة المكب بنجاح.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> data, String id) async {
    final u = context.read<AuthService>().currentUser!;
    final ar = TextEditingController(text: '${data['nameAr'] ?? data['name'] ?? ''}');
    final en = TextEditingController(text: '${data['nameEn'] ?? data['name'] ?? ''}');
    final cap = TextEditingController(text: '${data['capacity'] ?? 0}');
    final fill = TextEditingController(text: '${data['fillPercentage'] ?? 0}');
    final c = TextEditingController(text: '${data['code'] ?? ''}');
    final loc = TextEditingController(text: '${data['location'] ?? ''}');
    final geo = data['locationGeo'];
    final LatLng? initialPoint = geo is GeoPoint ? LatLng(geo.latitude, geo.longitude) : geo is Map && geo['latitude'] != null && geo['longitude'] != null ? LatLng(double.tryParse('${geo['latitude']}') ?? 0, double.tryParse('${geo['longitude']}') ?? 0) : null;
    LatLng? editPoint = initialPoint;
    bool active = data['isActive'] == true;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const AppText('تعديل بيانات المكب'),
            content: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: ar, decoration: InputDecoration(labelText: tr('اسم المكب بالعربية'))),
                  const SizedBox(height: 8),
                  TextField(controller: en, decoration: InputDecoration(labelText: tr('اسم المكب بالإنجليزية'))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: cap, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('السعة')))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: fill, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('الامتلاء %')))),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: c, decoration: InputDecoration(labelText: tr('الرمز'))),
                  const SizedBox(height: 8),
                  TextField(controller: loc, decoration: InputDecoration(labelText: tr('الموقع'))),
                  const SizedBox(height: 8),
                  StatefulBuilder(builder: (ctx, setLoc) => LocationField(value: editPoint, onChanged: (v) { editPoint=v; setLoc((){}); })),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                    title: const AppText('حالة المكب'),
                    subtitle: AppText(active ? 'نشط' : 'مخفي'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')),
              FilledButton(
                onPressed: () async {
                  final capacityValue = _number(cap.text);
                  final fillValue = _number(fill.text);
                  if (ar.text.trim().isEmpty || en.text.trim().isEmpty || capacityValue == null || fillValue == null || capacityValue < 0 || fillValue < 0 || fillValue > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('بيانات المكب غير صحيحة.')));
                    return;
                  }
                  await context.read<OperationsAdminService>().updateDumpsite(
                    dumpsiteId: id,
                    nameAr: ar.text,
                    nameEn: en.text,
                    capacity: capacityValue,
                    fillPercentage: fillValue,
                    code: c.text,
                    location: loc.text,
                    latitude: editPoint?.latitude,
                    longitude: editPoint?.longitude,
                    isActive: active,
                    actorId: u.id,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                },
                child: const AppText('حفظ'),
              ),
            ],
          ),
        ),
      );
      if (saved == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم تحديث بيانات المكب.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      ar.dispose(); en.dispose(); cap.dispose(); fill.dispose(); c.dispose(); loc.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<OperationsAdminService>();
    final u = context.read<AuthService>().currentUser!;
    final can = u.role == 'municipality_coordinator' || u.role == 'jsc_coordinator';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        AiHero(
          user: u,
          eyebrow: 'DUMPSITE INTELLIGENCE',
          title: 'إدارة المكبات',
          subtitle: 'إضافة وتعديل المكبات ومتابعة السعة ونسبة الامتلاء وحالة الظهور.',
        ),
        const SizedBox(height: 14),
        if (can)
          AiSectionCard(
            title: 'إضافة مكب',
            subtitle: 'يُحفظ محليًا مع دعم مزامنة Firestore عند توفر الاتصال',
            feature: 'dumpsite',
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: TextField(controller: nameAr, decoration: InputDecoration(labelText: tr('اسم المكب بالعربية')))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: nameEn, decoration: InputDecoration(labelText: 'Dumpsite Name (EN)'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: capacity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('السعة')))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: fillPercentage, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('نسبة الامتلاء %')))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: code, decoration: InputDecoration(labelText: tr('الرمز')))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: location, decoration: InputDecoration(labelText: tr('الموقع')))),
                ]),
                const SizedBox(height: 8),
                LocationField(value: selectedLocation, onChanged: (v) => setState(() => selectedLocation = v)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : _saveNew, icon: const Icon(Icons.add_location_alt_rounded), label: AppText(busy ? 'جارٍ الحفظ...' : 'إضافة مكب جديد'))),
              ],
            ),
          ),
        if (can) const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: svc.dumpsites(includeInactive: true),
          builder: (_, snap) {
            if (snap.hasError) return AppText('تعذر تحميل المكبات: ${snap.error}');
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
            if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Center(child: AppText('تعذر تحميل المكبات. تحقق من الاتصال ثم أعد المحاولة.'))));
            final docs = [...snap.data!.docs]..sort((a, b) =>
                '${a.data()['nameAr'] ?? a.data()['name'] ?? ''}'.compareTo('${b.data()['nameAr'] ?? b.data()['name'] ?? ''}'));
            return AiSectionCard(
              title: 'المكبات المسجلة',
              subtitle: 'Active / Hidden • السعة • نسبة الامتلاء',
              feature: 'dumpsite',
              child: docs.isEmpty
                  ? const ListTile(title: AppText('لا توجد مكبات مسجلة بعد.'))
                  : Column(children: docs.map((d) {
                      final x = d.data();
                      final active = x['isActive'] == true;
                      final rawFill = x['fillPercentage'];
                      final fill = (rawFill is num ? rawFill.toDouble() : double.tryParse(rawFill?.toString() ?? '') ?? 0.0).clamp(0.0, 100.0);
                      final capacityValue = x['capacity'];
                      final fillColor = fill >= 85 ? Colors.redAccent : fill >= 70 ? Colors.amber : aiGreen;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: active ? aiGreen.withOpacity(.05) : Colors.white.withOpacity(.025), borderRadius: BorderRadius.circular(18), border: Border.all(color: cleanOpsBorder)),
                        child: Column(children: [
                          Row(children: [
                            AiFeatureIcon('dumpsite', size: 16, filled: active),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              AppText('${x['nameAr'] ?? x['name'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              AppText('${x['nameEn'] ?? ''}', style: const TextStyle(fontSize: 11, color: cleanOpsMuted)),
                            ])),
                            if (can) ...[
                              IconButton(tooltip: 'تعديل', onPressed: () => _edit(x, d.id), icon: const Icon(Icons.edit_outlined)),
                              Switch(value: active, onChanged: (v) => svc.setDumpsiteActive(d.id, v, actorId: u.id)),
                            ] else Chip(label: AppText(active ? 'نشط' : 'مخفي')),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: AppText('السعة: ${capacityValue ?? '—'}', style: const TextStyle(fontSize: 11, color: cleanOpsMuted))),
                            AppText('${fill.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fillColor)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: fill / 100, minHeight: 7, color: fillColor, backgroundColor: fillColor.withOpacity(.10))),
                        ]),
                      );
                    }).toList()),
            );
          },
        ),
      ],
    );
  }
}

class _WorkforceTab extends StatefulWidget {
  const _WorkforceTab();
  @override
  State<_WorkforceTab> createState() => _WorkforceTabState();
}

class _WorkforceTabState extends State<_WorkforceTab> {
  final name = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  final group = TextEditingController();
  String role = 'worker';
  String cycleId = '';
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    phone.dispose();
    group.dispose();
    super.dispose();
  }

  Future<void> provision() async {
    if (cycleId.isEmpty) return;
    setState(() => busy = true);
    try {
      final result = await context.read<OperationsAdminService>().provisionUser(
        name: name.text,
        username: username.text,
        role: role,
        cycleId: cycleId,
        groupId: group.text,
        phone: phone.text,
      );
      if (mounted) {
        name.clear();
        username.clear();
        phone.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تم إنشاء ${role == 'worker' ? 'العامل' : 'مشرف المجموعة'} • ${result['username'] ?? ''}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<OperationsAdminService>();
    final u = context.read<AuthService>().currentUser!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: svc.activeCycles(),
      builder: (_, cs) {
        final cycles = cs.data?.docs ?? [];
        if (cycles.isNotEmpty && cycleId.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => cycleId = cycles.first.id);
          });
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            AiHero(
              user: u,
              eyebrow: 'LEVEL 2 • WORKFORCE COMMAND',
              title: 'إدارة القوى العاملة',
              subtitle: 'إنشاء الحسابات، نقل العمال، التبديل والتجميد — كلها تحت صلاحية منسق البلدية.',
            ),
            const SizedBox(height: 14),
            AiSectionCard(
              title: 'إضافة مشرف أو عامل',
              subtitle: 'الحسابات مرتبطة بدورة عمل محددة',
              feature: 'users',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: cycles.any((x) => x.id == cycleId) ? cycleId : null,
                    items: cycles.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.data()['name']}'))).toList(),
                    onChanged: (v) => setState(() => cycleId = v ?? ''),
                    decoration: InputDecoration(labelText: tr('دورة العمل')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(value: 'worker', child: AppText('عامل')),
                      DropdownMenuItem(value: 'group_supervisor', child: AppText('مشرف مجموعة')),
                    ],
                    onChanged: (v) => setState(() => role = v ?? role),
                    decoration: InputDecoration(labelText: tr('نوع الحساب')),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: name, decoration: InputDecoration(labelText: tr('الاسم الكامل'))),
                  const SizedBox(height: 8),
                  TextField(controller: username, decoration: InputDecoration(labelText: tr('اسم المستخدم')), textDirection: TextDirection.ltr),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: phone, decoration: InputDecoration(labelText: tr('الجوال')))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: group, decoration: InputDecoration(labelText: tr('المجموعة')))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : provision,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const AppText('إصدار الحساب'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (cycleId.isNotEmpty)
              AiSectionCard(
                title: 'أوامر الدورة',
                feature: 'cycle',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Builder(builder: (context) {
                      QueryDocumentSnapshot<Map<String, dynamic>>? selected;
                      for (final cycle in cycles) { if (cycle.id == cycleId) { selected = cycle; break; } }
                      final endValue = selected?.data()['endDate'];
                      final endDate = endValue is Timestamp ? endValue.toDate() : DateTime.tryParse('${endValue ?? ''}');
                      final ended = endDate != null && !DateTime.now().isBefore(endDate);
                      return SizedBox(width: 170, child: AiActionTile(title: 'تجميد الكل', feature: 'permissions', onTap: ended ? () async {
                        try {
                          await svc.freezeCycleUsers(cycleId, actorId: u.id);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم تجميد عمال ومشرفي الدورة المنتهية.')));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      } : null));
                    }),
                    SizedBox(width: 170, child: AiActionTile(title: 'نقل عامل', feature: 'trips', onTap: () => _transferDialog(context, svc, u.id, cycleId))),
                    SizedBox(width: 170, child: AiActionTile(title: 'تبديل عاملين', feature: 'workers', onTap: () => _swapDialog(context, svc, u.id))),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            if (cycleId.isNotEmpty)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: svc.cycleUsers(cycleId, actorId: u.id),
                builder: (_, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  return AiSectionCard(
                    title: 'مستخدمو الدورة',
                    subtitle: 'Active / Frozen / Deactivated',
                    feature: 'users',
                    child: Column(
                      children: docs.map((d) {
                        final x = d.data();
                        final active = x['isActive'] != false;
                        final frozen = x['status'] == 'frozen';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: active ? aiGreen.withOpacity(.04) : Colors.red.withOpacity(.035),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              AiFeatureIcon(x['role'] == 'worker' ? 'workers' : 'users', size: 15, filled: active),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                    AppText('${x['role']} • ${x['username'] ?? ''} • ${x['groupId'] ?? ''}', style: const TextStyle(fontSize: 10, color: cleanOpsMuted)),
                                  ],
                                ),
                              ),
                              if (active)
                                IconButton(tooltip: 'Deactivate', onPressed: () => svc.deactivateUser(d.id, actorId: u.id), icon: const Icon(Icons.person_off_rounded, color: Colors.red))
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.grey.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
                                  child: Text(frozen ? 'FROZEN' : 'INACTIVE', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _transferDialog(BuildContext context, OperationsAdminService svc, String actor, String cycle) async {
    final worker = TextEditingController();
    final group = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const AppText('نقل عامل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: worker, decoration: InputDecoration(labelText: tr('معرّف العامل'))),
            const SizedBox(height: 8),
            TextField(controller: group, decoration: InputDecoration(labelText: tr('المجموعة الجديدة'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AppText('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (worker.text.trim().isEmpty || group.text.trim().isEmpty) return;
              await svc.transferWorker(userId: worker.text.trim(), toGroupId: group.text.trim(), toCycleId: cycle, actorId: actor);
              if (context.mounted) Navigator.pop(context);
            },
            child: const AppText('تنفيذ'),
          ),
        ],
      ),
    );
    worker.dispose();
    group.dispose();
  }

  Future<void> _swapDialog(BuildContext context, OperationsAdminService svc, String actor) async {
    final a = TextEditingController();
    final b = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const AppText('تبديل عاملين'),
        content: Row(
          children: [
            Expanded(child: TextField(controller: a, decoration: InputDecoration(labelText: tr('الأول')))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: b, decoration: InputDecoration(labelText: tr('الثاني')))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AppText('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (a.text.trim().isEmpty || b.text.trim().isEmpty) return;
              await svc.swapWorkers(firstUserId: a.text.trim(), secondUserId: b.text.trim(), actorId: actor);
              if (context.mounted) Navigator.pop(context);
            },
            child: const AppText('تبديل'),
          ),
        ],
      ),
    );
    a.dispose();
    b.dispose();
  }
}

String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _date(dynamic v) { if (v is Timestamp) return _fmt(v.toDate()); if (v is DateTime) return _fmt(v); if (v == null) return 'غير محدد'; if (v is String) { final parsed = DateTime.tryParse(v); return parsed == null ? v : _fmt(parsed); } if (v is int) { try { return _fmt(DateTime.fromMillisecondsSinceEpoch(v)); } catch (_) { return 'غير محدد'; } } return 'غير محدد'; }
