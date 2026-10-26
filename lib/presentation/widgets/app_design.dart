import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization.dart';
import '../../core/models/core_models.dart';

const aiBlue = Color(0xFF087F6B);
const aiCyan = Color(0xFF39C6A5);
const aiGreen = Color(0xFF8EDB65);
const aiDark = Color(0xFF073C35);
const aiDark2 = Color(0xFF0B6657);
const aiGlow = Color(0x3339C6A5);

class AiFeatureIcon extends StatelessWidget {
  final String feature;
  final double size;
  final bool filled;
  const AiFeatureIcon(this.feature, {super.key, this.size = 30, this.filled = true});

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(feature);
    final accent = switch (feature) {
      'emergency' || 'notifications' => const Color(0xFFFF9D45),
      'messages' => const Color(0xFF259E91),
      'reports' => const Color(0xFF45A9A0),
      'trips' => const Color(0xFF35B9A2),
      'workers' || 'users' => const Color(0xFF72C96A),
      'ai' || 'dashboard' => const Color(0xFF0B8D76),
      'containers' => const Color(0xFF39C6A5),
      _ => aiCyan,
    };
    return Container(
      width: size * 1.65,
      height: size * 1.65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .52),
        gradient: filled
            ? LinearGradient(colors: [accent.withOpacity(.96), aiBlue.withOpacity(.88)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : LinearGradient(colors: [accent.withOpacity(.14), aiBlue.withOpacity(.08)]),
        border: Border.all(color: accent.withOpacity(filled ? .42 : .25)),
        boxShadow: filled ? [BoxShadow(color: accent.withOpacity(.20), blurRadius: 18, spreadRadius: 1)] : null,
      ),
      child: Icon(icon, size: size, color: filled ? Colors.white : accent),
    );
  }

  IconData _iconFor(String f) => switch (f) {
    'ai' => Icons.auto_awesome_rounded,
    'dashboard' => Icons.space_dashboard_rounded,
    'operations' => Icons.hub_rounded,
    'workers' => Icons.groups_rounded,
    'attendance' => Icons.fact_check_rounded,
    'trips' => Icons.local_shipping_rounded,
    'streets' => Icons.route_rounded,
    'emergency' => Icons.warning_amber_rounded,
    'notifications' => Icons.notifications_rounded,
    'reports' => Icons.insights_rounded,
    'excel' => Icons.table_chart_rounded,
    'permissions' => Icons.shield_rounded,
    'settings' => Icons.tune_rounded,
    'sync' => Icons.sync_rounded,
    'critical_areas' => Icons.location_searching_rounded,
    'map' => Icons.map_rounded,
    'activity' => Icons.timeline_rounded,
    'cycle' => Icons.autorenew_rounded,
    'dumpsite' => Icons.location_on_rounded,
    'users' => Icons.manage_accounts_rounded,
    'messages' => Icons.forum_rounded,
    'containers' => Icons.delete_sweep_rounded,
    _ => Icons.eco_rounded,
  };
}


class DirectionalChevron extends StatelessWidget {
  const DirectionalChevron({super.key});
  @override
  Widget build(BuildContext context) => Icon(
    context.watch<LocaleController>().isArabic ? Icons.chevron_left : Icons.chevron_right,
    color: cleanOpsMuted,
  );
}

class AiGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final VoidCallback? onTap;
  const AiGlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.gradient, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (color ?? cleanOpsSurface) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cleanOpsBorder),
        boxShadow: [
          BoxShadow(color: aiCyan.withOpacity(.08), blurRadius: 26, offset: const Offset(0, 8)),
          BoxShadow(color: aiGreen.withOpacity(.025), blurRadius: 40, offset: const Offset(0, 16))
        ],
      ),
      child: child,
    );
    final interactive = onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              splashColor: aiCyan.withOpacity(.10),
              highlightColor: aiGreen.withOpacity(.045),
              child: card,
            ),
          );
    // Short entrance motion gives shared cards a lively feel without delaying
    // navigation or changing their underlying actions/data.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: .985, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: interactive,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class AiSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String feature;
  final Widget child;
  final Widget? trailing;
  const AiSectionCard({super.key, required this.title, this.subtitle, required this.feature, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => AiGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AiFeatureIcon(feature, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cleanOpsText)),
                  if (subtitle != null) AppText(subtitle!, style: const TextStyle(fontSize: 11, color: cleanOpsMuted)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: aiBlue.withOpacity(.10)),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class AiHero extends StatelessWidget {
  final AppUser user;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const AiHero({super.key, required this.user, required this.eyebrow, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [aiDark, aiDark2, Color(0xFF006A72)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [BoxShadow(color: aiBlue.withOpacity(.18), blurRadius: 28, offset: const Offset(0, 12))],
    ),
    child: Row(
      children: [
        SizedBox(width: 64, height: 64, child: Image.asset('assets/brand/cleanops_icon_new.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: aiCyan, size: 48))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(eyebrow, style: const TextStyle(color: aiCyan, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              AppText(title, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              AppText(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Wrap(spacing: 7, runSpacing: 7, children: [AiRoleChip(role: user.role), const _StatusChip(text: 'AI Operations', icon: Icons.auto_awesome)]),
            ],
          ),
        ),
        if (trailing != null) const SizedBox(width: 10),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class AiRoleChip extends StatelessWidget {
  final String role;
  const AiRoleChip({super.key, required this.role});
  @override
  Widget build(BuildContext context) => _StatusChip(text: roleNames[role] ?? role, icon: Icons.shield_rounded, color: aiGreen);
}

class _StatusChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _StatusChip({required this.text, required this.icon, this.color = aiCyan});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withOpacity(.28))),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Flexible(child: AppText(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
      ],
    ),
  );
}

class AiStatTile extends StatelessWidget {
  final String title, value, subtitle, feature;
  const AiStatTile({super.key, required this.title, required this.value, required this.subtitle, required this.feature});
  @override
  Widget build(BuildContext context) => AiGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiFeatureIcon(feature, size: 18),
        const SizedBox(height: 12),
        AppText(title, style: const TextStyle(fontSize: 11, color: cleanOpsMuted)),
        const SizedBox(height: 3),
        AppText(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: cleanOpsText)),
        AppText(subtitle, style: const TextStyle(fontSize: 10, color: cleanOpsMuted)),
      ],
    ),
  );
}

class AiActionTile extends StatelessWidget {
  final String title, feature;
  final VoidCallback? onTap;
  const AiActionTile({super.key, required this.title, required this.feature, this.onTap});
  @override
  Widget build(BuildContext context) => AiGlassCard(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        AiFeatureIcon(feature, size: 28),
        const SizedBox(height: 10),
        AppText(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: cleanOpsText)),
      ],
    ),
  );
}
