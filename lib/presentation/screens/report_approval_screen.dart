import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../widgets/app_design.dart';
import '../../core/localization.dart';

class ReportApprovalScreen extends StatelessWidget {
  const ReportApprovalScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final data = context.watch<DataService>();
    final canApprove = user != null && (user.role == 'jsc_coordinator');
    final reports = data.operations.where((e) {
      if ((e['_entity'] != 'work_report' && e['_entity'] != 'report_approval') || e['isDeleted'] == true || user == null) return false;
      if (user.role == 'municipality_coordinator') return '${e['municipalityName'] ?? ''}' == user.scope || user.scope == 'all';
      if (user.role == 'group_supervisor' || user.role == 'worker') return '${e['groupId'] ?? e['groupName'] ?? ''}' == '${user.groupId ?? ''}';
      if (user.role == 'donor_manager') return '${e['status'] ?? 'draft'}' == 'approved' || '${e['status'] ?? 'draft'}' == 'closed';
      return true;
    }).toList()
      ..sort((a,b) => '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    return Scaffold(
      appBar: AppBar(title: const AppText('دورة اعتماد التقارير')),
      body: reports.isEmpty
        ? const Center(child: AppText('لا توجد تقارير في دورة الاعتماد حتى الآن.'))
        : ListView(padding: const EdgeInsets.all(12), children: [
          const Card(child: Padding(padding: EdgeInsets.all(12), child: AppText('المراحل: مسودة ← مرسل للمراجعة ← معتمد أو بحاجة إلى تعديل ← مغلق. تُسجل الإجراءات في سجل التدقيق.'))),
          for (final r in reports) Card(child: ListTile(
            leading: Icon(_icon((r['status'] ?? 'draft').toString())),
            title: Text((r['groupName'] ?? r['title'] ?? r['reportType'] ?? 'تقرير').toString()),
            subtitle: Text('الحالة: ${_label((r['status'] ?? 'draft').toString())}\nالتاريخ: ${r['createdAt'] ?? '—'}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              enabled: canApprove,
              tooltip: 'تغيير حالة التقرير',
              onSelected: (status) => _change(context, r, status),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'submitted', child: Text('إرسال للمراجعة')),
                PopupMenuItem(value: 'needs_edits', child: Text('إعادة للتعديل')),
                PopupMenuItem(value: 'approved', child: Text('اعتماد')),
                PopupMenuItem(value: 'closed', child: Text('إغلاق')),
              ],
            ),
          )),
        ]),
    );
  }

  static Future<void> _change(BuildContext context, Map<String, dynamic> r, String status) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    final entity = '${r['_entity'] ?? 'report_approval'}';
    final updated = <String, dynamic>{...r, 'status': status, 'statusChangedAt': DateTime.now().toIso8601String(), 'statusChangedBy': user.id};
    await context.read<DataService>().enqueue(entity, 'update', updated);
    await context.read<DataService>().writeAudit(actorId: user.id, operation: 'REPORT_STATUS_CHANGED', targetId: '${r['id']}', before: {'status': r['status'] ?? 'draft'}, after: {'status': status, 'entity': entity});
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تم تحديث الحالة إلى ${_label(status)}.')));
  }
  static IconData _icon(String s) => switch(s) {'approved' => Icons.verified_outlined, 'submitted' => Icons.hourglass_top, 'needs_edits' => Icons.edit_note, 'closed' => Icons.lock_outline, _ => Icons.drafts_outlined};
  static String _label(String s) => switch(s) {'approved' => 'معتمد', 'submitted' => 'مرسل للمراجعة', 'needs_edits' => 'بحاجة إلى تعديل', 'closed' => 'مغلق', _ => 'مسودة'};
}
