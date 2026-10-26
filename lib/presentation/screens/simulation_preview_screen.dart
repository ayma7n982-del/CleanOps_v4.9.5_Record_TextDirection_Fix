import 'package:flutter/material.dart';
import '../../core/services/simulation_seeder_service.dart';
import '../widgets/app_design.dart';
import '../../core/localization.dart';

/// A dedicated viewer for local-only demo data. It never reads or writes Firebase.
class SimulationPreviewScreen extends StatefulWidget {
  const SimulationPreviewScreen({super.key});

  @override
  State<SimulationPreviewScreen> createState() => _SimulationPreviewScreenState();
}

class _SimulationPreviewScreenState extends State<SimulationPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final counts = SimulationSeederService.counts;
    final groups = SimulationSeederService.groups;
    final workers = SimulationSeederService.workers;
    final trips = SimulationSeederService.trips;
    return Scaffold(
      appBar: AppBar(
        title: const AppText('معاينة المحاكاة — الدورة 11'),
        actions: [
          IconButton(
            tooltip: 'تحديث العرض',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !SimulationSeederService.hasSimulation
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: AppText('لا توجد بيانات محاكاة في الذاكرة. ارجع إلى لوحة الإدارة واضغط «تشغيل المحاكاة».', textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const AppText('بلدية بني سهيلا', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const AppText('الدورة 11 • أكتوبر 2026 • بيانات محلية وهمية فقط', style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _Metric(label: 'المجموعات', value: '${counts['groups'] ?? 0}', icon: Icons.groups_rounded),
                        _Metric(label: 'العمال والمشرفون', value: '${counts['workers'] ?? 0}', icon: Icons.badge_rounded),
                        _Metric(label: 'الحاويات', value: '${counts['containers'] ?? 0}', icon: Icons.delete_outline_rounded),
                        _Metric(label: 'النقلات', value: '${counts['trips'] ?? 0}', icon: Icons.local_shipping_rounded),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                const AppText('المجموعات والطاقم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...groups.map((group) {
                  final groupId = group['id']?.toString() ?? '';
                  final members = workers.where((w) => w['groupId']?.toString() == groupId).toList();
                  final supervisors = members.where((w) => w['role'] == 'field_supervisor').length;
                  final carts = members.where((w) => w['role'] == 'animal_cart_worker').length;
                  final primary = members.where((w) => w['role'] == 'primary_collection_worker').length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ExpansionTile(
                      leading: const CircleAvatar(child: Icon(Icons.groups_rounded)),
                      title: Text(group['name']?.toString() ?? 'مجموعة بدون اسم', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('مشرفون: $supervisors • عمال جمع: $primary • عمال كارة: $carts'),
                      children: members.map((worker) => ListTile(
                        dense: true,
                        leading: Icon(_workerIcon(worker['role']?.toString()), color: Theme.of(context).colorScheme.primary),
                        title: Text(worker['name']?.toString() ?? 'عامل تجريبي'),
                        subtitle: Text(_workerRole(worker['role']?.toString())),
                        trailing: const Icon(Icons.science_outlined, size: 18),
                      )).toList(),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const AppText('ملخص النقلات التجريبية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Card(child: Column(children: [
                  ListTile(leading: const Icon(Icons.local_shipping_rounded), title: const Text('إجمالي النقلات'), trailing: Text('${trips.length}')),
                  ListTile(leading: const Icon(Icons.scale_rounded), title: const Text('الحمولة لكل نقلة'), trailing: const Text('10 طن')),
                  ListTile(leading: const Icon(Icons.monitor_weight_rounded), title: const Text('إجمالي الحمولة'), trailing: Text('${counts['volumeTons'] ?? 0} طن')),
                ])),
                const SizedBox(height: 12),
                const Text('هذه البيانات محفوظة في ذاكرة التطبيق فقط، ولا تظهر في شاشات التشغيل الحقيقية أو Firestore. تختفي عند إغلاق التطبيق.', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
    );
  }

  IconData _workerIcon(String? role) => switch (role) {
    'field_supervisor' => Icons.supervisor_account_rounded,
    'animal_cart_worker' => Icons.pedal_bike_rounded,
    _ => Icons.person_rounded,
  };

  String _workerRole(String? role) => switch (role) {
    'field_supervisor' => 'مشرف ميداني',
    'animal_cart_worker' => 'عامل كارة',
    _ => 'عامل جمع أساسي',
  };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 145,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [Icon(icon, size: 23), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text(label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)]))]),
  );
}
