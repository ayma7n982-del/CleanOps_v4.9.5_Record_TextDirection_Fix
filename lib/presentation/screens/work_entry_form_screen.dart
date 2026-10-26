import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/data_service.dart';
import '../widgets/app_design.dart';
import '../../core/localization.dart';

class WorkEntryFormScreen extends StatefulWidget {
  const WorkEntryFormScreen({super.key});
  @override
  State<WorkEntryFormScreen> createState() => _WorkEntryFormScreenState();
}

class _WorkEntryFormScreenState extends State<WorkEntryFormScreen> {
  final _group = TextEditingController();
  final _trips = TextEditingController(text: '0');
  final _present = TextEditingController(text: '0');
  final _absent = TextEditingController(text: '0');
  final _specialLeave = TextEditingController(text: '0');
  final _sickLeave = TextEditingController(text: '0');
  final _otherAbsence = TextEditingController(text: '0');
  final _tasks = TextEditingController();
  final _landfill = TextEditingController();
  final _containers = TextEditingController();
  final _locations = TextEditingController();
  final _completed = TextEditingController();
  final _problems = TextEditingController();
  final _suggestions = TextEditingController();
  bool _saving = false;
  String _cycleId = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cycles = [];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _group.text = user?.groupId ?? '';
    _loadCycles();
  }
  Future<void> _loadCycles() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('work_cycles').where('status', isEqualTo: 'active').limit(100).get();
      if (!mounted) return;
      setState(() { _cycles = snap.docs; if (_cycleId.isEmpty && _cycles.isNotEmpty) _cycleId = _cycles.first.id; });
    } catch (_) {}
  }

  @override
  void dispose() { for (final c in [_group,_trips,_present,_absent,_specialLeave,_sickLeave,_otherAbsence,_tasks,_landfill,_containers,_locations,_completed,_problems,_suggestions]) { c.dispose(); } super.dispose(); }

  int _number(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  String get _selectedCycleName { for (final c in _cycles) { if (c.id == _cycleId) return '${c.data()['name'] ?? c.id}'; } return ''; }
  Future<void> _save() async {
    final auth = context.read<AuthService>();
    final AppUser? user = auth.currentUser;
    if (user == null) return;
    if (user.role != 'group_supervisor' && user.role != 'municipality_coordinator') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('ليس لديك صلاحية تسجيل تقرير العمل.')));
      return;
    }
    if (_group.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('أدخل اسم المجموعة.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final record = <String, dynamic>{
        'id': const Uuid().v4(), 'recordType': 'daily_work', 'status': 'draft',
        'groupName': _group.text.trim(), 'groupId': user.groupId ?? _group.text.trim(),
        'municipalityName': user.scope == 'all' ? '' : user.scope,
        'cycleId': _cycleId, 'cycleName': _selectedCycleName, 'reportedBy': user.id, 'reporterName': user.name,
        'trips': _number(_trips), 'attendance': _number(_present), 'absence': _number(_absent),
        'specialLeave': _number(_specialLeave), 'sickLeave': _number(_sickLeave), 'otherAbsence': _number(_otherAbsence),
        'workTasks': _tasks.text.trim(), 'landfillStatus': _landfill.text.trim(),
        'containerStatus': _containers.text.trim(), 'workLocations': _locations.text.trim(),
        'completedWork': _completed.text.trim(), 'problems': _problems.text.trim(),
        'suggestions': _suggestions.text.trim(), 'createdAt': now.toIso8601String(),
        'workDate': DateTime(now.year, now.month, now.day).toIso8601String(), 'isDeleted': false,
      };
      await context.read<DataService>().enqueue('work_report', 'create', record);
      await context.read<DataService>().addActivity('تقرير العمل اليومي', 'حُفظ تقرير مجموعة ${_group.text.trim()} للمراجعة.', level: 'success');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم حفظ تقرير العمل في قائمة المزامنة بحالة مسودة.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر حفظ تقرير العمل: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('تسجيل تقرير العمل اليومي')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const AppText('أدخل بيانات العمل الفعلية التي يسجلها المشرف. يبدأ التقرير كمسودة ولا يعتبر معتمدًا حتى يمر بدورة المراجعة.', style: TextStyle(height: 1.45)),
      const SizedBox(height: 12),
      _field(_group, 'اسم المجموعة *'),
      DropdownButtonFormField<String>(value: _cycles.any((c) => c.id == _cycleId) ? _cycleId : null, items: _cycles.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.data()['name'] ?? c.id}'))).toList(), onChanged: (v) => setState(() => _cycleId = v ?? ''), decoration: const InputDecoration(labelText: 'دورة العمل', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _field(_trips, 'عدد النقلات', numeric: true)), const SizedBox(width: 8), Expanded(child: _field(_present, 'الحضور', numeric: true)), const SizedBox(width: 8), Expanded(child: _field(_absent, 'الغياب', numeric: true))]),
      Row(children: [Expanded(child: _field(_specialLeave, 'إجازة خاصة', numeric: true)), const SizedBox(width: 8), Expanded(child: _field(_sickLeave, 'إجازة مرضية', numeric: true)), const SizedBox(width: 8), Expanded(child: _field(_otherAbsence, 'أسباب أخرى', numeric: true))]),
      _field(_tasks, 'المهام المنفذة / المخطط لها', lines: 3),
      _field(_landfill, 'حالة المكب'), _field(_containers, 'حالة الحاويات'), _field(_locations, 'مواقع العمل'),
      _field(_completed, 'الأعمال المكتملة', lines: 3), _field(_problems, 'المشكلات أو العوائق', lines: 3), _field(_suggestions, 'المقترحات', lines: 3),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18,height: 18,child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: const AppText('حفظ المسودة')),
    ]),
  );
  Widget _field(TextEditingController c, String label, {bool numeric = false, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: numeric ? TextInputType.number : TextInputType.multiline, maxLines: lines, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
}
