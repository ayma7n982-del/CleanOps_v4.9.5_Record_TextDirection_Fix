import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization.dart';
import '../../core/models/core_models.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/operations_admin_service.dart';
import 'enterprise_operations_hub.dart';
import '../widgets/app_design.dart';
import 'messages_center.dart';
import 'live_operations_map.dart';
import 'operations_management.dart';
import 'reports_center.dart';
import '../../core/constants/app_constants.dart';

class AIBotScreen extends StatefulWidget {
  const AIBotScreen({super.key});
  @override State<AIBotScreen> createState() => _AIBotScreenState();
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  const _ChatMessage(this.text, {required this.fromUser});
}

class _AIBotScreenState extends State<AIBotScreen> with TickerProviderStateMixin {
  late final AnimationController orbitController;
  late final AnimationController glowController;
  late final AnimationController entranceController;
  final TextEditingController input = TextEditingController();
  final ScrollController chatScroll = ScrollController();
  final List<_ChatMessage> messages = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    orbitController = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
    glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
    messages.add(const _ChatMessage('أنا CleanOps AI. أستطيع تحليل مؤشرات التشغيل الحقيقية من Firestore للمستوى 3 و4. اطرح سؤالك وسأوضح مصدر الأرقام بدل اختلاقها.', fromUser: false));
  }

  @override
  void dispose() {
    orbitController.dispose();
    glowController.dispose();
    entranceController.dispose();
    input.dispose();
    chatScroll.dispose();
    super.dispose();
  }

  Future<void> _toggleLanguage() async {
    final locale = context.read<LocaleController>();
    locale.toggle();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale.locale.languageCode);
  }

  Future<void> _send() async {
    final question = input.text.trim();
    final user = context.read<AuthService>().currentUser;
    if (question.isEmpty || loading || user == null) return;
    if (user.role != 'donor_manager' && user.role != 'jsc_coordinator') {
      setState(() => messages.add(const _ChatMessage('المساعد الذكي متاح للمستوى 3 والمستوى 4 فقط.', fromUser: false)));
      return;
    }
    input.clear();
    setState(() {
      messages.add(_ChatMessage(question, fromUser: true));
      loading = true;
    });
    _scrollToBottom();
    try {
      final service = AIService(config: context.read<ConfigService>());
      final answer = await service.answer(user: user, question: question);
      if (!mounted) return;
      setState(() => messages.add(_ChatMessage(answer, fromUser: false)));
    } catch (e) {
      if (!mounted) return;
      final error = e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      setState(() => messages.add(_ChatMessage(error, fromUser: false)));
    } finally {
      if (mounted) {
        setState(() => loading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScroll.hasClients) chatScroll.animateTo(chatScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final locale = context.watch<LocaleController>();
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    final titleSize = (width * .055).clamp(19.0, 25.0);
    final allowed = user?.role == 'donor_manager' || user?.role == 'jsc_coordinator';
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F5),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF7FBF8), Color(0xFFEAF6F0), Color(0xFFDDF3EC)])),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(compact ? 14 : 18, 14, compact ? 14 : 18, 120),
            children: [
              Row(children: [
                const AiFeatureIcon('operations', size: 18), const SizedBox(width: 10),
                Expanded(child: AppText('المساعد التشغيلي الذكي', style: TextStyle(color: cleanOpsText, fontSize: titleSize, fontWeight: FontWeight.w900))),
                _LanguagePill(onTap: _toggleLanguage, isArabic: locale.isArabic),
              ]),
              const SizedBox(height: 8),
              _BotCoreAnimation(orbitController: orbitController, glowController: glowController, entranceController: entranceController, width: width),
              const AppText('CleanOps AI', textAlign: TextAlign.center, style: TextStyle(color: aiBlue, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 13)),
              const SizedBox(height: 10),
              if (!allowed)
                const _AccessNotice()
              else ...[
                FutureBuilder<Map<String, dynamic>>(
                  future: context.read<OperationsAdminService>().liveOperationalSnapshot(user!),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final x = snap.data!;
                    return AiGlassCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [AiFeatureIcon('dashboard', size: 16), SizedBox(width: 8), AppText('بيانات تشغيلية حقيقية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)), Spacer(), AppText('Firestore', style: TextStyle(fontSize: 9, color: aiGreen))]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [_LiveChip('العمال', '${x['workers']}'), _LiveChip('المجموعات', '${x['groups']}'), _LiveChip('الترحيلات', '${x['trips']}'), _LiveChip('الطوارئ', '${x['emergencies']}'), _LiveChip('المكبات الحرجة', '${x['criticalDumpsites']}')]),
                    ]));
                  },
                ),
                const SizedBox(height: 10),
                _ChatPanel(messages: messages, loading: loading, input: input, controller: chatScroll, onSend: _send),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _BotAction(icon: Icons.analytics_rounded, title: 'ملخص اليوم', onTap: () { input.text = 'أعطني ملخصًا لعمليات اليوم بالأرقام الحقيقية.'; _send(); }),
                  _BotAction(icon: Icons.warning_amber_rounded, title: 'التنبيهات', onTap: () { input.text = 'ما حالات SOS والطوارئ النشطة الآن؟'; _send(); }),
                  _BotAction(icon: Icons.delete_sweep_rounded, title: 'المكبات', onTap: () { input.text = 'اعرض حالة المكبات ونسب الامتلاء الحالية.'; _send(); }),
                  _BotAction(icon: Icons.local_shipping_rounded, title: 'الترحيلات', onTap: () { input.text = 'كم عدد الترحيلات المسجلة اليوم؟'; _send(); }),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _BotAction(icon: Icons.forum_rounded, title: 'الرسائل', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesCenterScreen())))),
                  const SizedBox(width: 8),
                  Expanded(child: _BotAction(icon: Icons.hub_rounded, title: 'مركز التشغيل', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnterpriseOperationsHubPage())))),
                  if (user.role == 'jsc_coordinator') ...[
                    const SizedBox(width: 8),
                    Expanded(child: _BotAction(icon: Icons.location_on_rounded, title: 'المكبات', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsManagementScreen(initialTab: 0))))),
                  ],
                  if (user.role == 'donor_manager' || user.role == 'jsc_coordinator') ...[
                    const SizedBox(width: 8),
                    Expanded(child: _BotAction(icon: Icons.map_rounded, title: 'العمليات الحية', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveOperationsMapScreen())))),
                  ],
                ]),
              ],
              const SizedBox(height: 16),
              const AppText('Developed by @Eman Al-Qahwaji', textAlign: TextAlign.center, style: TextStyle(color: aiDark2, fontSize: 10, letterSpacing: .45, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  final List<_ChatMessage> messages;
  final bool loading;
  final TextEditingController input;
  final ScrollController controller;
  final VoidCallback onSend;
  const _ChatPanel({required this.messages, required this.loading, required this.input, required this.controller, required this.onSend});
  @override Widget build(BuildContext context) => AiGlassCard(padding: const EdgeInsets.all(10), child: Column(children: [
    SizedBox(height: MediaQuery.sizeOf(context).height < 760 ? 250 : 300, child: ListView.builder(controller: controller, padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4), itemCount: messages.length + (loading ? 1 : 0), itemBuilder: (_, i) {
      if (loading && i == messages.length) return const _TypingBubble();
      final m = messages[i];
      return Align(alignment: m.fromUser ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), constraints: const BoxConstraints(maxWidth: 520), decoration: BoxDecoration(color: m.fromUser ? const Color(0xFFDDF4ED) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: (m.fromUser ? aiCyan : aiGreen).withOpacity(.20))), child: AppText(m.text, style: const TextStyle(color: cleanOpsText, fontSize: 14, height: 1.55))));
    })),
    const SizedBox(height: 8),
    Row(children: [Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, onSubmitted: (_) => onSend(), textInputAction: TextInputAction.send, decoration: InputDecoration(hintText: tr('اكتب سؤالك التشغيلي...'), prefixIcon: Icon(Icons.auto_awesome_rounded, color: aiCyan)))), const SizedBox(width: 8), IconButton(onPressed: loading ? null : onSend, icon: const Icon(Icons.send_rounded, color: aiCyan))]),
  ]));
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override Widget build(BuildContext context) => Align(alignment: AlignmentDirectional.centerEnd, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: aiCyan))));
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice();
  @override Widget build(BuildContext context) => const AiGlassCard(padding: EdgeInsets.all(16), child: Row(children: [Icon(Icons.lock_outline_rounded, color: Colors.orange), SizedBox(width: 10), Expanded(child: AppText('CleanOps AI التحليلي متاح للمستوى 3 والمستوى 4 فقط، حفاظًا على بيانات الإدارة.', style: TextStyle(color: cleanOpsMuted, fontSize: 14, height: 1.55)))]));
}

class _LiveChip extends StatelessWidget {
  final String title, value;
  const _LiveChip(this.title, this.value);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: aiCyan.withOpacity(.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: aiCyan.withOpacity(.16))), child: Row(mainAxisSize: MainAxisSize.min, children: [AppText(title, style: const TextStyle(fontSize: 11, color: cleanOpsMuted)), const SizedBox(width: 6), AppText(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: aiCyan))]));
}

class _LanguagePill extends StatelessWidget {
  final VoidCallback onTap;
  final bool isArabic;
  const _LanguagePill({required this.onTap, required this.isArabic});
  @override Widget build(BuildContext context) => Material(color: aiBlue.withOpacity(.08), borderRadius: BorderRadius.circular(22), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.language_rounded, color: Color(0xFF6FE8FF), size: 17), const SizedBox(width: 5), AppText(isArabic ? 'English' : 'العربية', style: const TextStyle(color: cleanOpsText, fontSize: 13, fontWeight: FontWeight.w800))]))));
}

class _BotCoreAnimation extends StatelessWidget {
  final AnimationController orbitController;
  final AnimationController glowController;
  final AnimationController entranceController;
  final double width;
  const _BotCoreAnimation({required this.orbitController, required this.glowController, required this.entranceController, required this.width});

  @override
  Widget build(BuildContext context) {
    final size = math.min(width * .55, 250.0);
    return AnimatedBuilder(
      animation: Listenable.merge([orbitController, glowController, entranceController]),
      builder: (context, child) {
        final t = orbitController.value * math.pi * 2;
        final glow = 0.72 + (math.sin(glowController.value * math.pi * 2) + 1) * .14;
        final entrance = Curves.easeOutBack.transform(entranceController.value);
        final rings = <Widget>[
          for (final factor in [0.82, 0.68, 0.54])
            Container(
              width: size * factor,
              height: size * factor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF18D7FF).withOpacity(.10 * glow), width: 1.2),
              ),
            ),
        ];
        return Opacity(
          opacity: entranceController.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: .82 + .18 * entrance,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size * .72,
                    height: size * .72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF18D7FF).withOpacity(.20 * glow), blurRadius: 70, spreadRadius: 18),
                        BoxShadow(color: const Color(0xFF00E676).withOpacity(.12 * glow), blurRadius: 45, spreadRadius: 6),
                      ],
                    ),
                  ),
                  ...rings,
                  Transform.rotate(
                    angle: t,
                    child: Container(
                      width: size * .76,
                      height: size * .76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF18D7FF).withOpacity(.48), width: 2),
                      ),
                    ),
                  ),
                  Container(
                    width: size * .48,
                    height: size * .48,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEAF6F0),
                      border: Border.all(color: const Color(0xFF18D7FF).withOpacity(.82), width: 2),
                      boxShadow: [BoxShadow(color: const Color(0xFF18D7FF).withOpacity(.34 * glow), blurRadius: 32, spreadRadius: 4)],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/brand/cleanops_icon_new.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: aiCyan, size: 70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BotAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _BotAction({required this.icon, required this.title, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white, const Color(0xFFF0FAF5)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: aiCyan.withOpacity(.24))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: aiBlue, size: 20), const SizedBox(width: 7), Flexible(child: AppText(title, textAlign: TextAlign.center, style: const TextStyle(color: cleanOpsText, fontSize: 13, fontWeight: FontWeight.w800)))])));
}
