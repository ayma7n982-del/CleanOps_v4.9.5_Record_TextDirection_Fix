import 'package:flutter/material.dart';
import 'app_design.dart';
import '../../core/localization.dart';

class CreativeShortcut {
  final String title;
  final String subtitle;
  final String feature;
  final VoidCallback onTap;
  final Color? accent;
  const CreativeShortcut({required this.title, required this.subtitle, required this.feature, required this.onTap, this.accent});
}

class CreativeShortcutGrid extends StatelessWidget {
  final List<CreativeShortcut> items;
  final int? maxColumns;
  final bool emphasize;
  const CreativeShortcutGrid({super.key, required this.items, this.maxColumns, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = maxColumns ?? (width >= 1000 ? 4 : width >= 650 ? 3 : 2);
    final ratio = emphasize ? (width >= 650 ? 1.34 : 1.06) : (width >= 650 ? 1.20 : .98);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: ratio,
      ),
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: .94, end: 1),
        duration: Duration(milliseconds: 180 + (i % 5) * 28),
        curve: Curves.easeOutCubic,
        child: _CreativeShortcutCard(item: items[i], emphasize: emphasize),
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(offset: Offset(0, (1 - value) * 9), child: Transform.scale(scale: value, child: child)),
        ),
      ),
    );
  }
}

class _CreativeShortcutCard extends StatelessWidget {
  final CreativeShortcut item;
  final bool emphasize;
  const _CreativeShortcutCard({required this.item, this.emphasize = false});

  Color _accent() {
    if (item.accent != null) return item.accent!;
    return switch (item.feature) {
      'emergency' => const Color(0xFFFF6B5E),
      'reports' => const Color(0xFF6C8CFF),
      'trips' => const Color(0xFF20D8FF),
      'workers' || 'users' => const Color(0xFF48E68A),
      'dumpsite' => const Color(0xFF36D9C7),
      'containers' => const Color(0xFF22C7FF),
      'sync' => const Color(0xFF63D8F5),
      'cycle' => const Color(0xFFB678FF),
      _ => aiCyan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF071D30), const Color(0xFF0B3448)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: accent.withOpacity(.24)),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(.11), blurRadius: 24, offset: const Offset(0, 9)),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -28,
                end: -25,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(.075)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AiFeatureIcon(item.feature, size: emphasize ? 37 : 31),
                    const SizedBox(height: 10),
                    AppText(
                      item.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: emphasize ? 18 : 15.5, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 5),
                    AppText(
                      item.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: emphasize ? 11.5 : 10.5, height: 1.3, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 30, height: 3, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: accent.withOpacity(.55))),
                        const SizedBox(width: 7),
                        Icon(rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 18, color: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
