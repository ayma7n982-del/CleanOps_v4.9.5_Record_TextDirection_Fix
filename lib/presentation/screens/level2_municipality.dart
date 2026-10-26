import '../../core/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/container_service.dart';
import 'reports_center.dart';
import 'operations_management.dart';
import '../widgets/app_design.dart';
import '../widgets/creative_shortcuts.dart';
import '../widgets/operations_overview.dart';
import '../widgets/smart_excel_import.dart';
import 'container_management.dart';
import 'messages_center.dart';
import 'global_search.dart';

class Level2MunicipalityScreen extends StatefulWidget {
  const Level2MunicipalityScreen({super.key});
  @override
  State<Level2MunicipalityScreen> createState() => _Level2MunicipalityScreenState();
}

class _Level2MunicipalityScreenState extends State<Level2MunicipalityScreen> {
  int tab = 0;
  List<Map<String, String>> rows = [];
  List<Map<String, dynamic>> stagnantGroups = [];
  bool loadingStagnation = false;

  @override
  void initState() {
    super.initState();
    _loadStagnation();
  }

  Future<void> _saveImportedRows(List<Map<String, String>> importedRows) async {
    final user = context.read<AuthService>().currentUser;
    final data = context.read<DataService>();
    if (user == null) return;
    for (final row in importedRows) {
      await data.enqueue('worker', 'upsert', {
        'id': row['id'],
        'name': row['name'],
        'job': row['job'],
        'phone': row['phone'],
        'municipality': row['municipality'],
        'group': row['group'],
        'groupNumber': row['group'],
        'municipalityCoordinatorId': row['municipalityCoordinatorId']?.isEmpty == true ? user.id : row['municipalityCoordinatorId'],
        'importedBy': user.id,
        'createdAt': DateTime.now().toIso8601String(),
        'isDeleted': false,
      });
    }
    if (importedRows.isNotEmpty) {
      await data.writeAudit(
        actorId: user.id,
        operation: 'IMPORT_WORKERS_SMART',
        targetId: DateTime.now().millisecondsSinceEpoch.toString(),
        after: {'count': importedRows.length, 'municipality': importedRows.first['municipality'], 'group': importedRows.first['group']},
      );
    }
    if (mounted) setState(() => rows = importedRows);
  }

  Future<void> _loadStagnation() async {
    if (!mounted) return;
    setState(() => loadingStagnation = true);
    final latest = <String, DateTime>{};
    try {
      final data = context.read<DataService>();
      await data.refreshOperations();
      for (final m in data.operations.where((e) => '${e['_entity'] ?? ''}' == 'trip')) {
        if (m['isDeleted'] == true) continue;
        final group = '${m['groupName'] ?? m['groupId'] ?? ''}'.trim();
        final created = DateTime.tryParse('${m['createdAt'] ?? ''}');
        if (group.isEmpty || created == null || latest.containsKey(group)) continue;
        latest[group] = created;
      }
    } catch (_) {}
    final now = DateTime.now();
    final computed = latest.entries
        .map((e) => {'group': e.key, 'minutes': now.difference(e.value).inMinutes})
        .where((e) => (e['minutes'] as int) >= 90)
        .toList()
      ..sort((a, b) => (b['minutes'] as int).compareTo(a['minutes'] as int));
    if (mounted) {
      setState(() {
        stagnantGroups = computed;
        loadingStagnation = false;
      });
    }
  }

  Future<void> _redirect() async {
    final u = context.read<AuthService>().currentUser;
    if (u == null || u.role != 'municipality_coordinator' || !u.can('workers', 'edit')) return;
    final d = context.read<DataService>();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await d.enqueue('cart_redirect', 'create', {
      'id': id,
      'fromGroup': 'مجموعة 01',
      'toGroup': 'مجموعة 02',
      'cart': 'الكارة 01',
      'requestedBy': u.id,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await d.writeAudit(actorId: u.id, operation: 'REDIRECT_CART', targetId: id, after: {'from': 'مجموعة 01', 'to': 'مجموعة 02'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم تسجيل إعادة توجيه الكارة في قائمة المزامنة.')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('المستوى 2 — منسق البلدية'),
          actions: [
            IconButton(tooltip: tr('البحث الذكي'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchPage())), icon: const Icon(Icons.search_rounded)),
            IconButton(onPressed: _loadStagnation, icon: const Icon(Icons.refresh)),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsCenterScreen())), icon: const Icon(Icons.analytics_outlined)),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsManagementScreen(initialTab: 1))), icon: const Icon(Icons.hub_outlined)),
          ],
          bottom: TabBar(isScrollable: true, onTap: (i) => setState(() => tab = i), tabs: [Tab(text: tr('لوحة القيادة')), Tab(text: tr('الإدارة')), Tab(text: tr('التقارير والرسائل'))]),
        ),
        body: _tabBody(),
      ),
    );
  }

  Widget _dashboardBody() => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            AiHero(
              user: context.read<AuthService>().currentUser!,
              eyebrow: 'LEVEL 2 • MUNICIPAL COMMAND',
              title: 'لوحة تشغيل البلدية',
              subtitle: 'مراقبة الركود، القوى العاملة، الكارات والبيانات الميدانية من مركز واحد.',
            ),
            const SizedBox(height: 10),
            const OperationsOverviewStrip(),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final cs = context.watch<ContainerService>();
              final critical = cs.containers.where((c) => c.status == 'full' || c.issueStatus == 'reported' || c.issueStatus == 'resolving').toList();
              return AiSectionCard(
                title: 'تنبيهات الحاويات',
                subtitle: critical.isEmpty ? 'لا توجد تنبيهات حرجة للحاويات.' : '${critical.length} تنبيه يحتاج متابعة.',
                feature: 'containers',
                child: critical.isEmpty
                    ? const AppText('لا توجد حاويات ممتلئة أو مشكلات مفتوحة.')
                    : Column(children: critical.take(6).map((c) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(c.status == 'full' ? Icons.warning_amber_rounded : Icons.report_problem_outlined, color: c.status == 'full' ? red : orange), title: AppText(c.locationName), subtitle: AppText(c.status == 'full' ? 'ممتلئة — يلزم التفريغ' : c.issueStatus == 'reported' ? 'مشكلة مسجلة' : 'إجراء تصحيحي قيد المعالجة'))).toList()),
              );
            }),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                const SizedBox(width: 165, child: AiStatTile(title: 'الركود', value: '90+ min', subtitle: 'عتبة التنبيه', feature: 'emergency')),
                SizedBox(width: 165, child: AiStatTile(title: 'السجلات', value: '${rows.length}', subtitle: 'سجلات مستوردة', feature: 'excel')),
                const SizedBox(width: 165, child: AiStatTile(title: 'الدور', value: 'L2', subtitle: 'منسق البلدية', feature: 'permissions')),
              ],
            ),
            const SizedBox(height: 14),
            CardSection2(
              title: 'تنبيهات الركود — أكثر من 90 دقيقة',
              icon: const Icon(Icons.timer_outlined),
              child: loadingStagnation
                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  : stagnantGroups.isEmpty
                      ? const ListTile(title: AppText('لا توجد مجموعة متوقفة لأكثر من 90 دقيقة ضمن البيانات المتاحة.'))
                      : Column(children: stagnantGroups.map((e) => _stagnation('${e['group']}', '${e['minutes']} دقيقة')).toList()),
            ),
          ],
        );

  Widget _tabBody() => switch (tab) {
    0 => _dashboardBody(),
    1 => ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 120), children: [
      CreativeShortcutGrid(items: [
        CreativeShortcut(title: 'المجموعات والعمال', subtitle: 'القوى العاملة والتوزيع', feature: 'workers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsManagementScreen(initialTab: 0)))),
        CreativeShortcut(title: 'إدخال الحاويات', subtitle: 'الحالة والمشكلات اليومية', feature: 'containers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContainerManagementScreen()))),
        CreativeShortcut(title: 'المكبات', subtitle: 'السعة والامتلاء والمواقع', feature: 'dumpsite', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsManagementScreen(initialTab: 1)))),
        CreativeShortcut(title: 'التقارير', subtitle: 'تشغيل البلدية ومؤشراتها', feature: 'reports', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsCenterScreen()))),
      ]),
      const SizedBox(height: 14),
      AiSectionCard(title: 'إدارة العمال', subtitle: 'استيراد كشف العمال بذكاء من Excel أو CSV.', feature: 'workers', child: SmartExcelImportCard(onImport: _saveImportedRows)),
      const SizedBox(height: 12),
      CardSection2(title: 'إعادة توجيه الكارات', icon: const Icon(Icons.swap_horiz), child: Column(children: [
        const ListTile(title: AppText('الكارة 01'), subtitle: AppText('من مجموعة 01 → مجموعة 02')),
        FilledButton.icon(onPressed: _redirect, icon: const Icon(Icons.double_arrow), label: const AppText('تنفيذ إعادة التوجيه')),
      ])),
    ]),
    2 => _reportsBody(),
    _ => _dashboardBody(),
  };

  Widget _reportsBody() => ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 120), children: [
    AiSectionCard(title: 'التقارير والرسائل', subtitle: 'الوصول إلى التقارير التشغيلية ومركز الرسائل.', feature: 'reports', child: Column(children: [
      FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsCenterScreen())), icon: const Icon(Icons.analytics_outlined), label: const AppText('فتح التقارير')),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesCenterScreen())), icon: const Icon(Icons.forum_outlined), label: const AppText('فتح الرسائل')),
    ])),
  ]);

  Widget _stagnation(String group, String time) => ListTile(
    leading: const Icon(Icons.warning_amber_rounded, color: orange),
    title: AppText(group, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: AppText('لا يوجد نشاط منذ $time'),
    trailing: const Chip(label: AppText('ركود')),
  );
}

class CardSection2 extends StatelessWidget {
  final String title;
  final Widget icon;
  final Widget child;
  const CardSection2({super.key, required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) => AiSectionCard(title: title, feature: title.contains('Excel') ? 'excel' : title.contains('ركود') ? 'emergency' : 'trips', child: child);
}
