import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../widgets/app_design.dart';
import '../../core/constants/app_constants.dart';

class EquipmentSearchScreen extends StatefulWidget {
  const EquipmentSearchScreen({super.key});
  @override State<EquipmentSearchScreen> createState() => _EquipmentSearchScreenState();
}

class _EquipmentSearchScreenState extends State<EquipmentSearchScreen> {
  final search = TextEditingController();
  String filter = 'all';
  Timer? _debounce;
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;

  @override void initState() { super.initState(); _load(); search.addListener(_changed); }
  @override void dispose() { _debounce?.cancel(); search.dispose(); super.dispose(); }
  void _changed() { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 250), () => setState(() {})); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final db = FirebaseFirestore.instance;
      final futures = await Future.wait([
        db.collection('operations').where('_entity', isEqualTo: 'heavy_machinery').limit(1000).get(),
        db.collection('equipment').limit(1000).get(),
      ]);
      final all = <Map<String, dynamic>>[];
      for (final result in futures) {
        if (result is QuerySnapshot<Map<String, dynamic>>) {
          for (final d in result.docs) all.add({'id': d.id, ...d.data()});
        }
      }
      final unique = <String, Map<String, dynamic>>{};
      for (final x in all) unique['${x['id']}'] = x;
      if (mounted) setState(() { rows = unique.values.toList(); loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  bool _matches(Map<String, dynamic> x) {
    final q = search.text.trim().toLowerCase();
    final status = '${x['status'] ?? x['machineStatus'] ?? ''}'.toLowerCase();
    if (filter != 'all' && status != filter) return false;
    if (q.isEmpty) return true;
    final hay = [x['name'], x['machine'], x['equipmentName'], x['type'], x['model'], x['plateNumber'], x['municipality'], x['municipalityName'], x['groupName'], x['status'], x['notes'], x['location']]
        .map((v) => '$v'.toLowerCase()).join(' ');
    return hay.contains(q);
  }

  @override Widget build(BuildContext context) {
    final visible = rows.where(_matches).toList();
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const AppText('بحث المعدات'), actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
        body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 120), children: [
          AiSectionCard(
            title: 'مركز بحث المعدات', subtitle: 'ابحث بالاسم أو النوع أو الموديل أو اللوحة أو البلدية أو المجموعة.', feature: 'operations',
            child: Column(children: [
              TextField(controller: search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('ابحث عن معدة...'), suffixIcon: search.text.isEmpty ? null : IconButton(onPressed: search.clear, icon: const Icon(Icons.clear_rounded)))),
              const SizedBox(height: 10),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _filter('all', 'الكل'), _filter('active', 'نشطة'), _filter('maintenance', 'صيانة'), _filter('inactive', 'متوقفة'),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
          else if (error != null) AiSectionCard(title: 'تعذر تحميل المعدات', feature: 'emergency', child: AppText(error!))
          else if (visible.isEmpty) const AiSectionCard(title: 'لا توجد نتائج', subtitle: 'جرّب كلمة بحث أخرى أو غيّر الفلتر.', feature: 'operations', child: SizedBox.shrink())
          else AiSectionCard(title: '${visible.length} نتيجة', subtitle: 'بيانات المعدات التشغيلية', feature: 'operations', child: Column(children: visible.map(_tile).toList())),
        ]),
      ),
    );
  }

  Widget _filter(String value, String label) => Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: ChoiceChip(label: AppText(label), selected: filter == value, onSelected: (_) => setState(() => filter = value)));

  Widget _tile(Map<String, dynamic> x) {
    final title = '${x['name'] ?? x['machine'] ?? x['equipmentName'] ?? x['type'] ?? 'معدة'}'.trim();
    final subtitle = [x['model'], x['plateNumber'], x['municipalityName'] ?? x['municipality'], x['groupName']]
        .where((v) => '$v'.trim().isNotEmpty && '$v' != 'null').join(' • ');
    final status = '${x['status'] ?? x['machineStatus'] ?? 'غير محدد'}';
    final color = status.toLowerCase() == 'active' || status == 'نشطة' ? Colors.green : status.toLowerCase() == 'maintenance' || status == 'صيانة' ? Colors.orange : cleanOpsMuted;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withOpacity(.25))), child: Icon(Icons.construction_rounded, color: color)),
      title: AppText(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: AppText(subtitle.isEmpty ? 'لا توجد تفاصيل إضافية' : subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: _status(status, color),
    );
  }
  Widget _status(String s, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: c.withOpacity(.1), borderRadius: BorderRadius.circular(15)), child: AppText(s, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800)));
}
