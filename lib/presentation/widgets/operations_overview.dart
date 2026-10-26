import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/container_service.dart';
import '../../core/services/operations_admin_service.dart';
import 'app_design.dart';
import '../screens/container_management.dart';
import '../../core/localization.dart';
import '../../core/constants/app_constants.dart';

/// Compact, role-safe home overview. It deliberately exposes only the two
/// operational assets that field users need to see immediately.
class OperationsOverviewStrip extends StatelessWidget {
  const OperationsOverviewStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(child: _ContainersCard(user: user)),
        const SizedBox(width: 10),
        Expanded(child: _DumpsitesCard(user: user)),
      ],
    );
  }
}

class _ContainersCard extends StatelessWidget {
  final dynamic user;
  const _ContainersCard({required this.user});
  @override
  Widget build(BuildContext context) {
    final service = context.watch<ContainerService>();
    final total = service.containers.length;
    final critical = service.containers.where((c) => c.status == 'full' || c.issueStatus == 'reported' || c.issueStatus == 'resolving').length;
    return AiGlassCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContainerManagementScreen())),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
      child: Row(children: [
        const AiFeatureIcon('containers', size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppText('الحاويات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          AppText('$total حاوية', style: const TextStyle(fontSize: 10, color: cleanOpsMuted)),
          if (critical > 0) AppText('$critical تحتاج متابعة', style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w800)),
        ])),
        const Icon(Icons.chevron_left_rounded, color: aiCyan, size: 20),
      ]),
    );
  }
}

class _DumpsitesCard extends StatelessWidget {
  final dynamic user;
  const _DumpsitesCard({required this.user});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: context.read<OperationsAdminService>().dumpsites(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final critical = docs.where((d) => ((d.data()['fillPercentage'] as num?)?.toDouble() ?? 0) >= 85).length;
        return AiGlassCard(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DumpsitesOverviewScreen())),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const AiFeatureIcon('dumpsite', size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AppText('المكبات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              AppText('${docs.length} مكب نشط', style: const TextStyle(fontSize: 10, color: cleanOpsMuted)),
              if (critical > 0) AppText('$critical سعة حرجة', style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w800)),
            ])),
            const Icon(Icons.chevron_left_rounded, color: aiCyan, size: 20),
          ]),
        );
      },
    );
  }
}


class DumpsitesOverviewScreen extends StatelessWidget {
  const DumpsitesOverviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cleanOpsBg,
      appBar: AppBar(title: const AppText('المكبات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<OperationsAdminService>().dumpsites(includeInactive: true),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: AppText('تعذر تحميل المكبات: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.toList();
          if (docs.isEmpty) return const Center(child: AppText('لا توجد مكبات مسجلة.'));
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final fill = ((d['fillPercentage'] as num?)?.toDouble() ?? 0).clamp(0, 100).toDouble();
              final active = d['isActive'] != false;
              final color = fill >= 85 ? Colors.red : fill >= 70 ? Colors.orange : aiGreen;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AiGlassCard(padding: const EdgeInsets.all(13), child: Column(children: [
                  Row(children: [
                    const AiFeatureIcon('dumpsite', size: 19),
                    const SizedBox(width: 10),
                    Expanded(child: AppText('${d['nameAr'] ?? d['name'] ?? 'مكب'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                    AppText(active ? 'نشط' : 'مخفي', style: TextStyle(color: active ? aiGreen : cleanOpsMuted, fontSize: 9, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 9),
                  Row(children: [Expanded(child: LinearProgressIndicator(value: fill / 100, minHeight: 8, color: color)), const SizedBox(width: 10), AppText('${fill.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w900))]),
                ])),
              );
            },
          );
        },
      ),
    );
  }
}
