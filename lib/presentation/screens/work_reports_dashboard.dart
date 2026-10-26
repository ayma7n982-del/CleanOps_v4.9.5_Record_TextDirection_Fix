import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../widgets/app_design.dart';
import 'work_entry_form_screen.dart';

class WorkReportsDashboard extends StatelessWidget {
  const WorkReportsDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final arabic = context.watch<LocaleController>().isArabic;
    final user = context.watch<AuthService>().currentUser;
    final all = context.watch<DataService>().operations.where((e) => e['_entity'] == 'work_report' && e['isDeleted'] != true).toList();
    final visible = all.where((e) {
      if (user == null) return false;
      if (user.role == 'group_supervisor' || user.role == 'worker') return '${e['groupId'] ?? e['groupName']}' == '${user.groupId ?? ''}';
      if (user.role == 'municipality_coordinator' && user.scope != 'all') return '${e['municipalityName'] ?? ''}' == user.scope;
      if (user.role == 'donor_manager') return (e['status'] ?? 'draft').toString() == 'approved' || (e['status'] ?? 'draft').toString() == 'closed';
      return true;
    }).toList()..sort((a,b) => '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    final today = DateTime.now();
    final todayReports = visible.where((e) { final d = DateTime.tryParse('${e['workDate'] ?? e['createdAt'] ?? ''}'); return d != null && d.year == today.year && d.month == today.month && d.day == today.day; }).toList();
    final trips = todayReports.fold<int>(0, (n,e) => n + ((e['trips'] as num?)?.toInt() ?? 0));
    final specialLeave = todayReports.fold<int>(0, (n,e) => n + ((e['specialLeave'] as num?)?.toInt() ?? 0));
    final sickLeave = todayReports.fold<int>(0, (n,e) => n + ((e['sickLeave'] as num?)?.toInt() ?? 0));
    final otherAbsence = todayReports.fold<int>(0, (n,e) => n + ((e['otherAbsence'] as num?)?.toInt() ?? 0));
    final present = todayReports.fold<int>(0, (n,e) => n + ((e['attendance'] as num?)?.toInt() ?? 0));
    final absent = todayReports.fold<int>(0, (n,e) => n + ((e['absence'] as num?)?.toInt() ?? 0));
    return Directionality(textDirection: arabic ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(title: const AppText('لوحة تقارير العمل'), actions: [if (user?.role == 'group_supervisor' || user?.role == 'municipality_coordinator') IconButton(tooltip: 'تسجيل تقرير', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkEntryFormScreen())), icon: const Icon(Icons.add_circle_outline))]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const AppText('ملخص اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [_kpi('تقارير اليوم', '${todayReports.length}'), _kpi('النقلات', '$trips'), _kpi('الحضور', '$present'), _kpi('الغياب', '$absent'), _kpi('إجازة خاصة', '$specialLeave'), _kpi('إجازة مرضية', '$sickLeave'), _kpi('أسباب أخرى', '$otherAbsence')])]))),
        const SizedBox(height: 10),
        if (user?.role == 'group_supervisor' || user?.role == 'municipality_coordinator') FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkEntryFormScreen())), icon: const Icon(Icons.edit_note), label: const AppText('تسجيل تقرير مجموعة')),
        const SizedBox(height: 14),
        const AppText('ملخص البلدية دون أسماء العمال', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ..._municipalitySummary(visible),
        const SizedBox(height: 14),
        const AppText('تقارير المجموعات الفعلية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        if (visible.isEmpty) const Padding(padding: EdgeInsets.all(18), child: AppText('لا توجد تقارير عمل مسجلة ضمن نطاق صلاحياتك.')),
        for (final e in visible) Card(child: ExpansionTile(
          leading: const Icon(Icons.assignment_outlined),
          title: Text((e['groupName'] ?? 'مجموعة غير محددة').toString()),
          subtitle: Text('${e['workDate'] ?? e['createdAt'] ?? ''} • ${_status((e['status'] ?? 'draft').toString())}'),
          trailing: ((user?.role == 'group_supervisor' || user?.role == 'municipality_coordinator') && (e['status'] ?? 'draft').toString() == 'draft') ? IconButton(tooltip: 'إرسال للمراجعة', icon: const Icon(Icons.send_outlined), onPressed: () => _submitReport(context, e)) : null,
          childrenPadding: const EdgeInsets.fromLTRB(16,0,16,16),
          children: [
            _line('النقلات', '${e['trips'] ?? 0}'), _line('الحضور / الغياب', '${e['attendance'] ?? 0} / ${e['absence'] ?? 0}'), _line('الإجازات', 'خاصة ${e['specialLeave'] ?? 0} • مرضية ${e['sickLeave'] ?? 0} • أخرى ${e['otherAbsence'] ?? 0}'),
            _line('المهام', '${e['workTasks'] ?? '—'}'), _line('حالة المكب', '${e['landfillStatus'] ?? '—'}'),
            _line('حالة الحاويات', '${e['containerStatus'] ?? '—'}'), _line('مواقع العمل', '${e['workLocations'] ?? '—'}'),
            _line('العمل المكتمل', '${e['completedWork'] ?? '—'}'), _line('المشكلات', '${e['problems'] ?? '—'}'), _line('المقترحات', '${e['suggestions'] ?? '—'}'),
          ],
        )),
      ]),
    ));
  }
  static Future<void> _submitReport(BuildContext context, Map<String, dynamic> report) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    final updated = <String, dynamic>{...report, 'status': 'submitted', 'submittedAt': DateTime.now().toIso8601String(), 'submittedBy': user.id};
    await context.read<DataService>().enqueue('work_report', 'update', updated);
    await context.read<DataService>().writeAudit(actorId: user.id, operation: 'WORK_REPORT_SUBMITTED', targetId: '${report['id']}', before: {'status': report['status'] ?? 'draft'}, after: {'status': 'submitted'});
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم إرسال تقرير العمل للمراجعة.')));
  }

  static List<Widget> _municipalitySummary(List<Map<String, dynamic>> reports) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final report in reports) {
      final municipality = '${report['municipalityName'] ?? ''}'.trim();
      final label = municipality.isEmpty || municipality == 'assigned_only' ? 'غير محددة' : municipality;
      (grouped[label] ??= []).add(report);
    }
    if (grouped.isEmpty) return [const Padding(padding: EdgeInsets.all(10), child: AppText('لا توجد بيانات كافية للملخص البلدي.'))];
    return grouped.entries.map((entry) {
      final rows = entry.value;
      int sum(String key) => rows.fold<int>(0, (n, e) => n + ((e[key] as num?)?.toInt() ?? 0));
      return Card(child: ListTile(
        leading: const Icon(Icons.location_city_outlined), title: Text(entry.key),
        subtitle: Text("تقارير: ${rows.length} • نقلات: ${sum('trips')} • حضور: ${sum('attendance')} • غياب: ${sum('absence')}\nإجازة خاصة: ${sum('specialLeave')} • مرضية: ${sum('sickLeave')} • أسباب أخرى: ${sum('otherAbsence')}"),
        isThreeLine: true,
      ));
    }).toList();
  }
  static Widget _kpi(String label, String value) => SizedBox(width: 135, child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [Text(label, style: const TextStyle(fontSize: 12)), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))]))));
  static Widget _line(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 105, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: Text(v))]));
  static String _status(String s) => switch(s) {'approved' => 'معتمد', 'submitted' => 'بانتظار المراجعة', 'needs_edits' => 'بحاجة إلى تعديل', 'closed' => 'مغلق', _ => 'مسودة'};
}
