import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../widgets/app_design.dart';
import '../../main.dart';

class EnterpriseLoginScreen extends StatefulWidget {
  const EnterpriseLoginScreen({super.key});
  @override
  State<EnterpriseLoginScreen> createState() => _EnterpriseLoginScreenState();
}

class _EnterpriseLoginScreenState extends State<EnterpriseLoginScreen> with SingleTickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  late final AnimationController logoController;
  late final Animation<double> fade;
  late final Animation<double> scale;
  bool obscure = true;
  bool remember = false;

  @override
  void initState() {
    super.initState();
    logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    fade = CurvedAnimation(parent: logoController, curve: Curves.easeOut);
    scale = Tween<double>(begin: .82, end: 1).animate(
      CurvedAnimation(parent: logoController, curve: Curves.easeOutBack),
    );
    final auth = context.read<AuthService>();
    usernameController.text = auth.rememberedUsername ?? '';
    remember = auth.rememberMe;
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    logoController.dispose();
    super.dispose();
  }

  Future<void> _saveLanguage() async {
    final controller = context.read<LocaleController>();
    final next = controller.isArabic ? LocaleController.english : LocaleController.arabic;
    controller.setLocale(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', next.languageCode);
  }

  Future<void> _onlineLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final auth = context.read<AuthService>();
    final ok = await auth.login(
      usernameController.text,
      passwordController.text,
    );
    if (!mounted || !ok) return;
    await auth.setRememberMe(remember, usernameController.text);
    _openApp(auth);
  }

  Future<void> _forgotPassword() async {
    final username = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _ForgotPasswordSheet(),
    );
    if (!mounted || username == null || username.trim().isEmpty) return;
    final auth = context.read<AuthService>();
    final ok = await auth.requestPasswordReset(username);
    if (!mounted) return;
    if (ok) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF00B87A), size: 42),
          title: const AppText('تم إرسال رابط إعادة التعيين'),
          content: const AppText(
            'إذا كان اسم المستخدم مرتبطًا بحساب نشط، فسيتم إرسال رابط إعادة تعيين كلمة المرور إلى البريد الإلكتروني المسجل للحساب. افتح الرابط واتبع التعليمات لتعيين كلمة مرور جديدة.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('حسنًا'),
            ),
          ],
        ),
      );
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  Future<void> _offlineLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final auth = context.read<AuthService>();
    final ok = await auth.enterOffline();
    if (!mounted || !ok) return;
    _openApp(auth);
  }

  void _openApp(AuthService auth) {
    final prefs = context.read<SetupState>();
    final managerNeedsSetup = auth.currentUser?.role == 'donor_manager' && !prefs.complete;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => managerNeedsSetup ? const SetupWizardPage() : const AppShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<DataService>();
    final locale = context.watch<LocaleController>();
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720 || size.width < 370;
    final titleSize = (size.width * .055).clamp(21.0, 28.0);
    final horizontal = (size.width * .055).clamp(16.0, 28.0);
    final firebaseReady = Firebase.apps.isNotEmpty;
    final onlineReady = data.online && firebaseReady;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(top: -100, right: -90, child: _LoginOrb(size: 240, color: Color(0x2200B4DB))),
            const Positioned(bottom: -130, left: -90, child: _LoginOrb(size: 260, color: Color(0x1A00E676))),
            PositionedDirectional(
              top: 10,
              end: 14,
              child: Material(
                color: Colors.white.withOpacity(.96),
                borderRadius: BorderRadius.circular(24),
                elevation: 2,
                shadowColor: aiBlue.withOpacity(.18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _saveLanguage,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
                      child: Row(
                        key: ValueKey(locale.locale.languageCode),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 18, color: aiDark),
                          const SizedBox(width: 6),
                          Text(
                            locale.isArabic ? 'English' : 'العربية',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: aiDark, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, compact ? 48 : 64, horizontal, 120),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(horizontal, compact ? 20 : 26, horizontal, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE2EEF3)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A061A2A), blurRadius: 30, offset: Offset(0, 14)),
                      ],
                    ),
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: fade,
                          child: ScaleTransition(
                            scale: scale,
                            child: const _AnimatedLogo(),
                          ),
                        ),
                        SizedBox(height: compact ? 12 : 16),
                        AppText(
                          'منظومة عمليات جمع النفايات الصلبة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: aiDark,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const AppText(
                          'AI Operations Command Center',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF009AC2),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ConnectionPill(online: onlineReady),
                        const SizedBox(height: 16),
                        _Field(
                          controller: usernameController,
                          label: 'اسم المستخدم',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: passwordController,
                          label: 'كلمة المرور',
                          icon: Icons.lock_outline_rounded,
                          obscureText: obscure,
                          suffix: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          ),
                          onSubmitted: (_) => _onlineLogin(),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: auth.loading ? null : _forgotPassword,
                            icon: const Icon(Icons.lock_reset_rounded, size: 17),
                            label: const AppText('نسيت كلمة المرور؟', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: remember,
                          onChanged: (value) => setState(() => remember = value),
                          title: const AppText('حفظ بيانات الدخول', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          subtitle: const AppText('يحفظ الحساب المحلي فقط؛ لا يتم حفظ كلمة المرور.', style: TextStyle(fontSize: 10)),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: auth.loading ? null : _onlineLogin,
                            icon: auth.loading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.cloud_done_rounded),
                            label: const AppText('تسجيل الدخول عبر الإنترنت', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: auth.loading ? null : _offlineLogin,
                            icon: const Icon(Icons.cloud_off_rounded),
                            label: const AppText('الدخول أوفلاين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          ),
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F1),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: const Color(0xFFFFD0D0)),
                            ),
                            child: AppText(
                              auth.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.w700, fontSize: 11),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        const Text('Developed by @Eman Al-Qahwaji', style: TextStyle(color: Color(0xFF7B8794), fontSize: 9, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        const Text('emanabd@gmail.com • 00970567953487', style: TextStyle(color: Color(0xFF9AA5B1), fontSize: 8)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();
  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFD7E2E8), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8FFF5),
                boxShadow: [BoxShadow(color: const Color(0xFF00B87A).withOpacity(.16), blurRadius: 20)],
              ),
              child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF00A96B), size: 30),
            ),
            const SizedBox(height: 12),
            const AppText('نسيت كلمة المرور؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: aiDark)),
            const SizedBox(height: 6),
            const AppText(
              'أدخل اسم المستخدم. سنرسل رابط إعادة تعيين كلمة المرور إلى البريد الإلكتروني المرتبط بالحساب.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF607080), height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('اسم المستخدم'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                icon: const Icon(Icons.send_rounded),
                label: const AppText('إرسال رابط إعادة التعيين', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(context), child: const AppText('إلغاء')),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF102A43)),
      cursorColor: const Color(0xFF00B87A),
      textDirection: TextDirection.ltr,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF607080)),
        floatingLabelStyle: const TextStyle(color: Color(0xFF009AC2)),
        labelText: tr(label),
        prefixIconColor: const Color(0xFF607080),
        suffixIconColor: const Color(0xFF607080),
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 118,
    height: 118,
    child: Image.asset(
      'assets/brand/cleanops_icon_new.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: aiCyan, size: 60),
      filterQuality: FilterQuality.high,
    ),
  );
}

class _ConnectionPill extends StatelessWidget {
  final bool online;
  const _ConnectionPill({required this.online});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: online ? const Color(0xFFE8FFF4) : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: online ? const Color(0xFFBCEFD4) : const Color(0xFFFFE0A3)),
      ),
      child: Row(
        children: [
          Icon(online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: online ? const Color(0xFF168C5B) : const Color(0xFFC47B00), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              online ? 'متصل بـ Firebase — تسجيل الدخول والمزامنة متاحان.' : 'وضع أوفلاين متاح للجلسة المحفوظة.',
              style: TextStyle(color: online ? const Color(0xFF168C5B) : const Color(0xFFC47B00), fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _LoginOrb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
