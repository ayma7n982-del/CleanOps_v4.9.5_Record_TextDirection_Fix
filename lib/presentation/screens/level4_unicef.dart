import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../core/services/auth_service.dart';
import '../widgets/app_design.dart';
import '../widgets/creative_shortcuts.dart';
import '../widgets/operations_overview.dart';
import 'equipment_search.dart';
import 'enterprise_operations_hub.dart';
import 'reports_center.dart';
import 'global_search.dart';
import 'user_management_settings.dart';
import '../../core/services/simulation_seeder_service.dart';
import 'simulation_preview_screen.dart';

/// Level 4 home: intentionally compact. Administrative forms remain in the
/// dedicated User Management screen so the home is not overloaded.
class Level4UnicefScreen extends StatelessWidget {
  const Level4UnicefScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const Scaffold(body: Center(child: AppText('لا يوجد مستخدم نشط.')));
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const AppText('مدير المنظومة'), actions: [IconButton(tooltip: tr('البحث الذكي'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchPage())), icon: const Icon(Icons.search_rounded))]),
        body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 120), children: [
          AiHero(user: user, eyebrow: 'LEVEL 4 • SYSTEM COMMAND', title: 'لوحة المنظومة', subtitle: 'رؤية مختصرة للحاويات والمكبات والبحث التشغيلي.'),
          const SizedBox(height: 10),
          // Prominent temporary simulation shortcut: visible near the top of the dashboard.
          const _SimulationShortcutBanner(),
          const SizedBox(height: 12),
          const OperationsOverviewStrip(),
          const SizedBox(height: 14),
          CreativeShortcutGrid(
            emphasize: true,
            maxColumns: 2,
            items: [
              CreativeShortcut(title: 'بحث المعدات', subtitle: 'المعدات والآليات والمواقع', feature: 'operations', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EquipmentSearchScreen()))),
              CreativeShortcut(title: 'مركز الإدارة', subtitle: 'العمليات والتنبيهات والبحث', feature: 'dashboard', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnterpriseOperationsHubPage()))),
              CreativeShortcut(title: 'إدارة المستخدمين', subtitle: 'الحسابات والصلاحيات', feature: 'users', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementSettingsPage()))),
              CreativeShortcut(title: 'التقارير', subtitle: 'الأداء والتحليلات التشغيلية', feature: 'reports', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsCenterScreen()))),
            ],
          ),
          const SizedBox(height: 16),
          const _TemporarySimulationPanel(),
        ]),
      ),
    );
  }
}



class _SimulationShortcutBanner extends StatefulWidget {
  const _SimulationShortcutBanner();
  @override
  State<_SimulationShortcutBanner> createState() => _SimulationShortcutBannerState();
}

class _SimulationShortcutBannerState extends State<_SimulationShortcutBanner> {
  bool busy = false;

  Future<void> _run() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('تشغيل محاكاة الدورة 11'),
        content: const AppText('سيتم إنشاء بيانات وهمية داخل ذاكرة التطبيق فقط للتجربة. لن يتم الاتصال بـ Firebase أو إنشاء بيانات حقيقية، وستختفي البيانات عند إغلاق التطبيق. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const AppText('تشغيل المحاكاة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await runCycle11Simulation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تم إنشاء المحاكاة محليًا: ${result['groups'] ?? 0} مجموعات، ${result['workers'] ?? 0} عاملًا ومشرفًا، ${result['trips'] ?? 0} نقلة. اضغط «عرض المجموعات والعمال».')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر تشغيل المحاكاة: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child)),
        child: Material(
          color: const Color(0xFF0B2937),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: busy ? null : _run,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF18C8E8), Color(0xFF35D889)]), borderRadius: BorderRadius.all(Radius.circular(14))),
                  child: SizedBox(width: 48, height: 48, child: Icon(Icons.science_rounded, color: Colors.white, size: 27)),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AppText('تشغيل محاكاة الدورة 11', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  SizedBox(height: 4),
                  AppText('بلدية بني سهيلا • 5 مجموعات • 20 يوم عمل', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ])),
                if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF63E8C1))) else const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF63E8C1), size: 27),
              ]),
            ),
          ),
        ),
      );
}

class _TemporarySimulationPanel extends StatefulWidget {
  const _TemporarySimulationPanel();

  @override
  State<_TemporarySimulationPanel> createState() => _TemporarySimulationPanelState();
}

class _TemporarySimulationPanelState extends State<_TemporarySimulationPanel> {
  bool busy = false;

  Future<void> _run() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('تشغيل محاكاة الدورة 11'),
        content: const AppText(
          'سيتم إنشاء عرض تجريبي وهمي داخل ذاكرة التطبيق فقط: بلدية بني سهيلا، 5 مجموعات، 50 عاملًا ومشرفًا، حاويتان و900 نقلة. لن تُكتب أي بيانات إلى Firebase، ولن تظهر هذه البيانات في التقارير أو شاشات التشغيل الحقيقية، وتختفي عند إغلاق التطبيق.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const AppText('تشغيل المحاكاة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await runCycle11Simulation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('تم إنشاء المحاكاة محليًا: ${result['groups'] ?? 0} مجموعات، ${result['workers'] ?? 0} عاملًا ومشرفًا، ${result['trips'] ?? 0} نقلة. اضغط «عرض المجموعات والعمال».')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر تشغيل المحاكاة: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('حذف بيانات المحاكاة'),
        content: const AppText('سيتم مسح بيانات العرض التجريبي من ذاكرة التطبيق فقط. لن يتم الاتصال بـ Firebase ولن تُحذف أو تتغير أي بيانات حقيقية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('حذف بيانات المحاكاة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await deleteSimulationData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('تم مسح ${result['deleted'] ?? 0} عنصرًا تجريبيًا من ذاكرة التطبيق فقط.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر حذف بيانات المحاكاة: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetAndRun() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('إعادة بناء محاكاة الدورة 11'),
        content: const AppText('سيتم مسح العرض التجريبي المحلي ثم إنشاؤه من جديد. لن يتم الاتصال بـ Firebase أو تعديل أي بيانات تشغيلية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const AppText('إعادة البناء')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await deleteSimulationData();
      final result = await runCycle11Simulation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تمت إعادة إنشاء المحاكاة: ${result['groups'] ?? 0} مجموعات و${result['workers'] ?? 0} عاملًا ومشرفًا. اضغط «عرض المجموعات والعمال».')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر إعادة بناء المحاكاة: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.science_rounded, color: Colors.cyanAccent),
                const SizedBox(width: 8),
                const Expanded(child: AppText('محاكاة تشغيلية مؤقتة', style: TextStyle(fontWeight: FontWeight.w800))),
                if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 6),
            const AppText('عرض محلي مؤقت • لا يتصل بـ Firebase • يختفي عند إغلاق التطبيق', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : _run,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const AppText('تشغيل المحاكاة'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : _delete,
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                  label: const AppText('حذف بيانات المحاكاة'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : _resetAndRun,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const AppText('إعادة البناء'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulationPreviewScreen())),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const AppText('عرض المجموعات والعمال'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
