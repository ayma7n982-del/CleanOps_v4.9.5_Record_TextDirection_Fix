import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/operations_admin_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_design.dart';
import 'ai_bot_screen.dart';
import 'operations_management.dart';
import 'messages_center.dart';
import 'live_operations_map.dart';
import 'reports_center.dart';
import 'enterprise_operations_hub.dart';
import 'user_management_settings.dart';

class AICommandCenter extends StatefulWidget {
  const AICommandCenter({super.key});

  @override
  State<AICommandCenter> createState() => _AICommandCenterState();
}

class _AICommandCenterState extends State<AICommandCenter> {
  bool focusMode = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser!;
    final data = context.watch<DataService>();
    final config = context.watch<ConfigService>();
    final size = MediaQuery.sizeOf(context);
    final horizontal = size.width >= 900;
    final padding = EdgeInsets.symmetric(horizontal: size.width >= 600 ? 24 : 14, vertical: 16);

    return Container(
      color: cleanOpsBg,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: focusMode
            ? ListView(
                key: const ValueKey('focus'),
                padding: padding,
                children: [
                  _FocusHeader(
                    user: user,
                    onExit: () => setState(() => focusMode = false),
                  ),
                  const SizedBox(height: 14),
                  _FocusModeKpis(user: user, data: data),
                ],
              )
            : ListView(
                key: const ValueKey('normal'),
                padding: padding,
                children: [
                  _Hero(user: user, online: data.online, queue: data.queue.length),
                  const SizedBox(height: 10),
                  _FocusToggle(value: focusMode, onChanged: (v) => setState(() => focusMode = v)),
                  const SizedBox(height: 14),
                  _SectionTitle(title: 'مركز القرار التشغيلي', subtitle: 'مؤشرات حية مختصرة للعمليات والقوى العاملة والمخاطر.'),
                  const SizedBox(height: 10),
                  FutureBuilder<Map<String, dynamic>>(
                    future: context.read<OperationsAdminService>().liveOperationalSnapshot(user),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox(height: 96, child: Center(child: CircularProgressIndicator()));
                      final x = snap.data!;
                      final maxUsers = ((x['activeUsers'] as num?)?.toDouble() ?? 1).clamp(1.0, 1000.0).toDouble();
                      final trips = ((x['trips'] as num?)?.toDouble() ?? 0.0);
                      final critical = ((x['emergencies'] as num?)?.toDouble() ?? 0.0);
                      return GridView.count(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: horizontal ? 4 : 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: horizontal ? 1.25 : 1.15,
                        children: [
                          _MetricCard(icon: Icons.groups_rounded, title: 'العاملون النشطون', value: '${x['activeUsers']}', subtitle: 'من بيانات المستخدمين', progress: ((x['activeUsers'] as num?)?.toDouble() ?? 0) / maxUsers, color: const Color(0xFF00B87A)),
                          _MetricCard(icon: Icons.local_shipping_rounded, title: 'الترحيلات', value: '${x['trips']}', subtitle: 'سجلات تشغيلية', progress: (trips / (trips + 10.0)).clamp(0.0, 1.0).toDouble(), color: const Color(0xFF00B4DB)),
                          _MetricCard(icon: Icons.groups_rounded, title: 'المجموعات', value: '${x['groups']}', subtitle: 'مجموعات مرتبطة', progress: 1.0, color: const Color(0xFF1464A5)),
                          _MetricCard(icon: Icons.warning_amber_rounded, title: 'الطوارئ', value: '${x['emergencies']}', subtitle: 'سجلات حرجة', progress: (critical / (critical + 10.0)).clamp(0.0, 1.0).toDouble(), color: const Color(0xFFF59E0B)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  if (horizontal)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _OperationsPulse(online: data.online)),
                        const SizedBox(width: 12),
                        const Expanded(child: _CycleCard()),
                      ],
                    )
                  else ...[
                    _OperationsPulse(online: data.online),
                    const SizedBox(height: 12),
                    const _CycleCard(),
                  ],
                  const SizedBox(height: 14),
                  const _AIUserState(),
                  const SizedBox(height: 14),
                  _QuickActions(user: user),
                  const SizedBox(height: 14),
                  _RiskPanel(data: data),
                  const SizedBox(height: 14),
                  _RecentActivity(data: data),
                  const SizedBox(height: 14),
                  const Center(child: Text('Developed by @Eman Al-Qahwaji', style: TextStyle(color: Color(0xFF9AA5B1), fontSize: 9, fontWeight: FontWeight.w700))),
                ],
              ),
      ),
    );
  }
}

class _FocusToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _FocusToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => AiGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.center_focus_strong_rounded, color: aiCyan),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('وضع التركيز', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  AppText('عرض المؤشرات الحرجة فقط وإخفاء القوائم الثانوية', style: TextStyle(color: cleanOpsMuted, fontSize: 10)),
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      );
}

class _FocusHeader extends StatelessWidget {
  final AppUser user;
  final VoidCallback onExit;
  const _FocusHeader({required this.user, required this.onExit});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF03111F), Color(0xFF0A2A43), Color(0xFF006A72)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Color(0x2200B4DB), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Row(
          children: [
            SizedBox(width: 48, height: 48, child: Image.asset('assets/brand/cleanops_icon_new.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: aiCyan, size: 48))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const AppText('FOCUS MODE', style: TextStyle(color: aiCyan, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                AppText('وضع التركيز — ${user.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                const AppText('المؤشرات التشغيلية الحرجة فقط', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
            IconButton(onPressed: onExit, tooltip: 'إيقاف وضع التركيز', icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white)),
          ],
        ),
      );
}

class _FocusModeKpis extends StatelessWidget {
  final AppUser user;
  final DataService data;
  const _FocusModeKpis({required this.user, required this.data});

  @override
  Widget build(BuildContext context) {
    final isManagement = user.role == 'municipality_coordinator' || user.role == 'jsc_coordinator' || user.role == 'donor_manager';
    final localWorkers = data.operations.where((e) => '${e['_entity'] ?? ''}' == 'worker' && e['isDeleted'] != true && e['isActive'] != false).length;
    final localGroups = data.operations
        .where((e) => '${e['_entity'] ?? ''}' == 'worker' && e['isDeleted'] != true && e['isActive'] != false)
        .map((e) => '${e['groupId'] ?? e['groupName'] ?? ''}'.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;
    final criticalAlerts = data.notifications.where((n) => n.level == 'critical' && !n.read).length;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: isManagement ? context.read<OperationsAdminService>().activeWorkforce() : null,
      builder: (context, workforceSnap) {
        var workers = localWorkers;
        var groups = localGroups;
        if (isManagement && workforceSnap.hasData) {
          final active = workforceSnap.data!.docs.where((d) => d.data()['isActive'] != false);
          workers = active.where((d) => '${d.data()['role'] ?? ''}' == 'worker').length;
          groups = active
              .where((d) => '${d.data()['role'] ?? ''}' == 'worker' || '${d.data()['role'] ?? ''}' == 'group_supervisor')
              .map((d) => '${d.data()['groupId'] ?? ''}'.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .length;
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: context.read<OperationsAdminService>().activeCycles(),
          builder: (context, cycleSnap) {
            String cycle = 'لا توجد دورة نشطة';
            if (cycleSnap.hasData) {
              for (final d in cycleSnap.data!.docs) {
                final x = d.data();
                if (x['status'] == 'active') {
                  cycle = '${x['name'] ?? 'دورة نشطة'}';
                  final endValue = x['endDate'];
                  final end = endValue is Timestamp ? endValue.toDate() : DateTime.tryParse('${endValue ?? ''}');
                  if (end != null && DateTime.now().isAfter(end)) {
                    cycle = '⚠️ دورة منتهية — ${DateTime.now().difference(end).inDays} يوم متأخر';
                  }
                  break;
                }
              }
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 2.4 : 1.35,
                  children: [
                    _FocusKpi(icon: Icons.autorenew_rounded, title: 'الدورة الحالية', value: cycle, color: aiCyan),
                    _FocusKpi(icon: Icons.groups_rounded, title: 'العمال النشطون', value: '$workers', color: aiGreen),
                    _FocusKpi(icon: Icons.hub_rounded, title: 'المجموعات النشطة', value: '$groups', color: const Color(0xFF1464A5)),
                    _FocusKpi(icon: Icons.warning_amber_rounded, title: 'التنبيهات الحرجة', value: '$criticalAlerts', color: criticalAlerts > 0 ? Colors.redAccent : aiGreen),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FocusKpi extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _FocusKpi({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(.16), cleanOpsSurface], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(.25)),
          boxShadow: [BoxShadow(color: color.withOpacity(.10), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 25)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              AppText(title, style: const TextStyle(color: cleanOpsMuted, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              AppText(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: cleanOpsText, fontSize: 22, fontWeight: FontWeight.w900)),
            ])),
          ],
        ),
      );
}

class _AIUserState extends StatelessWidget {
  const _AIUserState();
  @override
  Widget build(BuildContext context) {
    final service = context.read<OperationsAdminService>();
    final me = context.read<AuthService>().currentUser;
    if (me == null || (me.role != 'municipality_coordinator' && me.role != 'jsc_coordinator' && me.role != 'donor_manager')) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<Map<String, dynamic>>(
      stream: service.userStats(actorId: me.id, actorRole: me.role),
      builder: (_, snap) {
        final data = snap.data ?? const <String, dynamic>{};
        final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? const {});
        return _Panel(
          title: 'تحديث AI المباشر',
          feature: 'operations',
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _AIChip('المستخدمون', '${data['totalUsers'] ?? 0}', const Color(0xFF18D7FF)),
              _AIChip('النشطون', '${data['activeUsers'] ?? 0}', const Color(0xFF00E676)),
              _AIChip('L2', '${roles['municipality_coordinator'] ?? 0}', const Color(0xFF1464A5)),
              _AIChip('L3', '${roles['jsc_coordinator'] ?? 0}', const Color(0xFF7C3AED)),
              _AIChip('L4', '${roles['donor_manager'] ?? 0}', const Color(0xFFF59E0B)),
            ],
          ),
        );
      },
    );
  }
}

class _AIChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AIChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(.20))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
        AppText(label, style: const TextStyle(fontSize: 9, color: cleanOpsMuted, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  final AppUser user;
  final bool online;
  final int queue;
  const _Hero({required this.user, required this.online, required this.queue});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final title = (width * .058).clamp(22.0, 30.0);
    return Container(
      padding: EdgeInsets.all(width < 500 ? 17 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF03111F), Color(0xFF0A2A43), Color(0xFF006A72)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x2200B4DB), blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: Row(
        children: [
          SizedBox(width: width < 500 ? 58 : 72, height: width < 500 ? 58 : 72, child: Image.asset('assets/brand/cleanops_icon_new.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: aiCyan, size: 48))),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('AI OPERATIONS COMMAND CENTER', style: TextStyle(color: Color(0xFF18D7FF), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                AppText('مرحبًا، ${user.name}', style: TextStyle(color: Colors.white, fontSize: title, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                AppText(roleNames[user.role] ?? '', style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Status(text: online ? 'متصل بالسحابة' : 'غير متصل', icon: online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: online ? const Color(0xFF00E676) : const Color(0xFFFFC107)),
                    _Status(text: queue == 0 ? 'لا توجد عمليات معلقة' : '$queue معلقة', icon: Icons.sync_rounded, color: const Color(0xFF18D7FF)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _Status({required this.text, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withOpacity(.28))),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        AppText(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const AiFeatureIcon('dashboard', size: 17),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(title, style: const TextStyle(color: cleanOpsText, fontSize: 18, fontWeight: FontWeight.w900)),
            AppText(subtitle, style: const TextStyle(color: cleanOpsMuted, fontSize: 10)),
          ],
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title, value, subtitle;
  final double progress;
  final Color color;
  const _MetricCard({required this.icon, required this.title, required this.value, required this.subtitle, required this.progress, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cleanOpsSurface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: cleanOpsBorder),
      boxShadow: const [BoxShadow(color: Color(0x09061A2A), blurRadius: 18, offset: Offset(0, 7))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 20),
        ),
        const Spacer(),
        Text(value, style: TextStyle(color: cleanOpsText, fontSize: 25, fontWeight: FontWeight.w900)),
        AppText(title, style: const TextStyle(color: cleanOpsMuted, fontSize: 10, fontWeight: FontWeight.w800)),
        AppText(subtitle, style: const TextStyle(color: cleanOpsMuted, fontSize: 9)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(minHeight: 5, value: progress, backgroundColor: color.withOpacity(.10), color: color),
        ),
      ],
    ),
  );
}

class _OperationsPulse extends StatelessWidget {
  final bool online;
  const _OperationsPulse({required this.online});
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'نبض النظام',
    feature: 'operations',
    child: Column(
      children: [
        _RowValue(label: 'حالة الاتصال', value: online ? 'متصل' : 'Offline', color: online ? const Color(0xFF00A86B) : const Color(0xFFF59E0B)),
        const _RowValue(label: 'وضع الأمان', value: 'RBAC 2.0', color: Color(0xFF7C3AED)),
      ],
    ),
  );
}

class _CycleCard extends StatelessWidget {
  const _CycleCard();
  @override
  Widget build(BuildContext context) {
    final svc = context.read<OperationsAdminService>();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: svc.activeCycles(),
      builder: (context, snap) {
        final active = snap.data?.docs.where((d) => d.data()['status'] == 'active').isNotEmpty == true
            ? snap.data!.docs.firstWhere((d) => d.data()['status'] == 'active')
            : null;
        final x = active?.data();
        final endValue = x?['endDate'];
        final end = endValue is Timestamp ? endValue.toDate() : DateTime.tryParse('${endValue ?? ''}');
        final startValue = x?['startDate'];
        final start = startValue is Timestamp ? startValue.toDate() : DateTime.tryParse('${startValue ?? ''}');
        final now = DateTime.now();
        final expired = end != null && now.isAfter(end);
        final overdue = expired ? now.difference(end).inDays : 0;
        final total = (start != null && end != null) ? math.max(1, end.difference(start).inDays) : 1;
        final elapsed = (start != null && now.isAfter(start)) ? now.difference(start).inDays.clamp(0, total) : 0;
        final progress = end == null ? .0 : (expired ? 1.0 : elapsed / total);
        return _Panel(
          title: 'دورة النظافة',
          feature: 'cycle',
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 106,
                    height: 106,
                    child: CustomPaint(
                      painter: _CyclePainter(progress.toDouble()),
                      child: Center(child: Text('${(progress * 100).round()}%', style: const TextStyle(color: cleanOpsText, fontWeight: FontWeight.w900, fontSize: 22))),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(x?['name']?.toString() ?? 'لا توجد دورة نشطة', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 5),
                        AppText(end == null ? 'تاريخ النهاية غير محدد.' : 'النهاية: ${DateFormat('yyyy/MM/dd').format(end)}', style: const TextStyle(color: cleanOpsMuted, fontSize: 10)),
                        const SizedBox(height: 8),
                        if (expired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.redAccent.withOpacity(.35))),
                            child: AppText('⚠️ دورة منتهية — $overdue يوم متأخر', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11)),
                          )
                        else
                          AppText(
                            end == null
                                ? 'المتابعة: الحضور • النقلات • المكبات'
                                : 'المضى: $elapsed يوم • المتبقي: ${end.difference(now).inDays.clamp(0, 100000)} يوم',
                            style: const TextStyle(color: Color(0xFF009AC2), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CyclePainter extends CustomPainter {
  final double value;
  _CyclePainter(this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 9..color = const Color(0xFF00B4DB).withOpacity(.10);
    final active = Paint()..style = PaintingStyle.stroke..strokeWidth = 9..strokeCap = StrokeCap.round..shader = const LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF00E676)]).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, math.pi * 2 * value, false, active);
  }
  @override
  bool shouldRepaint(covariant _CyclePainter oldDelegate) => oldDelegate.value != value;
}

class _QuickActions extends StatelessWidget {
  final AppUser user;
  const _QuickActions({required this.user});

  void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final actions = <_Quick>[];

    // Every shortcut below points to an existing, real module in the application.
    actions.add(_Quick(
      feature: 'ai',
      title: 'المساعد الذكي',
      subtitle: 'تحليل البيانات الحية',
      badge: 'AI',
      onTap: () => _push(context, const AIBotScreen()),
    ));

    if (user.can('workers', 'view')) {
      actions.add(_Quick(
        feature: 'workers',
        title: 'المجموعات والعمال',
        subtitle: 'الفرق والمشرفون والحالة',
        onTap: () => _push(context, const GroupsCommandCenterPage()),
      ));
    }

    if (user.can('trips', 'view')) {
      actions.add(_Quick(
        feature: 'trips',
        title: 'سجل الترحيلات',
        subtitle: 'سجلات النقل الفعلية',
        onTap: () => _push(context, const TripsLogPage()),
      ));
    }

    if (user.can('reports', 'view')) {
      actions.add(_Quick(
        feature: 'reports',
        title: 'التقارير',
        subtitle: 'تحليلات ومؤشرات تشغيلية',
        onTap: () => _push(context, const ReportsCenterScreen()),
      ));
    }

    actions.add(_Quick(
      feature: 'emergency',
      title: 'التنبيهات والبلاغات',
      subtitle: 'الطوارئ والتنبيهات الحرجة',
      onTap: () => _push(context, const AlertsCenterPage()),
    ));

    actions.add(_Quick(
      feature: 'messages',
      title: 'مركز الرسائل',
      subtitle: 'تواصل ميداني آمن',
      onTap: () => _push(context, const MessagesCenterScreen()),
    ));

    actions.add(_Quick(
      feature: 'sync',
      title: 'المزامنة',
      subtitle: 'Online / Offline والطوابير',
      onTap: () => _push(context, const SyncCenterPage()),
    ));

    actions.add(_Quick(
      feature: 'operations',
      title: 'مركز التشغيل',
      subtitle: 'الصحة والبحث والملفات',
      onTap: () => _push(context, const EnterpriseOperationsHubPage()),
    ));

    // Management shortcuts open the correct tab for the current role.
    if (user.role == 'municipality_coordinator') {
      actions.add(_Quick(
        feature: 'workers',
        title: 'إدارة الموارد',
        subtitle: 'العمال والمشرفون',
        onTap: () => _push(context, const OperationsManagementScreen(initialTab: 0)),
      ));
      actions.add(_Quick(
        feature: 'dumpsite',
        title: 'إدارة المكبات',
        subtitle: 'السعة والامتلاء والمواقع',
        onTap: () => _push(context, const OperationsManagementScreen(initialTab: 1)),
      ));
      actions.add(_Quick(
        feature: 'users',
        title: 'إدارة المستخدمين',
        subtitle: 'حسابات وصلاحيات التشغيل',
        onTap: () => _push(context, const UserManagementSettingsPage()),
      ));
    } else if (user.role == 'jsc_coordinator') {
      actions.add(_Quick(
        feature: 'dumpsite',
        title: 'إدارة المكبات',
        subtitle: 'السعة والامتلاء والمواقع',
        onTap: () => _push(context, const OperationsManagementScreen(initialTab: 0)),
      ));
    } else if (user.role == 'donor_manager') {
      actions.add(_Quick(
        feature: 'cycle',
        title: 'دورات العمل',
        subtitle: 'إنشاء وأرشفة الدورات',
        onTap: () => _push(context, const OperationsManagementScreen(initialTab: 0)),
      ));
      actions.add(_Quick(
        feature: 'users',
        title: 'إدارة المستخدمين',
        subtitle: 'حسابات وصلاحيات التشغيل',
        onTap: () => _push(context, const UserManagementSettingsPage()),
      ));
    }

    return _Panel(
      title: 'اختصارات تشغيلية ذكية',
      feature: 'operations',
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth >= 900 ? 4 : box.maxWidth >= 620 ? 3 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: cols == 2 ? 1.05 : 1.10,
            ),
            itemBuilder: (_, i) => actions[i],
          );
        },
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  final String feature, title, subtitle;
  final String? badge;
  final VoidCallback? onTap;
  const _Quick({required this.feature, required this.title, required this.subtitle, this.badge, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAi = feature == 'ai';
    final accent = switch (feature) {
      'emergency' => const Color(0xFFFF9D45),
      'messages' => const Color(0xFF9B7CFF),
      'reports' => const Color(0xFF5CA9FF),
      'trips' => const Color(0xFF20D8FF),
      'workers' || 'users' => const Color(0xFF5CFF9A),
      'dumpsite' => const Color(0xFF22D3EE),
      'cycle' || 'sync' => const Color(0xFF67E8F9),
      'ai' => const Color(0xFFB56CFF),
      _ => aiCyan,
    };
    return AiGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      gradient: LinearGradient(
        colors: isAi ? [const Color(0xFF291050), const Color(0xFF0B2940)] : [const Color(0xFF071D30), const Color(0xFF092A39)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Stack(
        children: [
          PositionedDirectional(top: -16, end: -14, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(.09)))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AiFeatureIcon(feature, size: 30),
                const Spacer(),
                if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: accent.withOpacity(.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withOpacity(.30))), child: Text(badge!, style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.w900))),
              ]),
              const Spacer(),
              AppText(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              AppText(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Container(height: 2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(colors: [accent.withOpacity(.8), accent.withOpacity(.05)])))),
                const SizedBox(width: 7),
                Icon(context.watch<LocaleController>().isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 17, color: accent),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  final DataService data;
  const _RiskPanel({required this.data});
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'التنبيهات والمخاطر',
    feature: 'emergency',
    child: data.notifications.isEmpty
        ? const Row(children: [Icon(Icons.check_circle_outline, color: Color(0xFF00A86B)), SizedBox(width: 8), AppText('لا توجد تنبيهات محلية جديدة.', style: TextStyle(fontWeight: FontWeight.w700))])
        : Column(
            children: data.notifications.take(3).map((n) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(n.level == 'critical' ? Icons.priority_high_rounded : Icons.notifications_active_outlined, color: n.level == 'critical' ? const Color(0xFFC0392B) : const Color(0xFFF59E0B)),
              title: AppText(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: AppText(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            )).toList(),
          ),
  );
}

class _RecentActivity extends StatelessWidget {
  final DataService data;
  const _RecentActivity({required this.data});
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'الخط الزمني التشغيلي',
    feature: 'activity',
    child: data.activities.isEmpty
        ? const AppText('لا توجد أنشطة محلية بعد.')
        : Column(
            children: data.activities.take(5).map((a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timeline_rounded, color: Color(0xFF009AC2)),
              title: AppText(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: AppText(a.detail, maxLines: 1, overflow: TextOverflow.ellipsis),
            )).toList(),
          ),
  );
}

class _Panel extends StatelessWidget {
  final String title, feature;
  final Widget child;
  const _Panel({required this.title, required this.feature, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: cleanOpsSurface, borderRadius: BorderRadius.circular(24), border: Border.all(color: cleanOpsBorder), boxShadow: const [BoxShadow(color: Color(0x09061A2A), blurRadius: 18, offset: Offset(0, 7))]),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [AiFeatureIcon(feature, size: 16), const SizedBox(width: 9), AppText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cleanOpsText))]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: cleanOpsBorder),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _RowValue extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RowValue({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [Expanded(child: AppText(label, style: const TextStyle(color: cleanOpsMuted, fontSize: 11))), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11))]),
  );
}
