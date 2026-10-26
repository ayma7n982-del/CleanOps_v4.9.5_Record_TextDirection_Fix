import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../core/constants/gaza_municipalities.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/operations_admin_service.dart';
import '../widgets/app_design.dart';
import '../../core/constants/app_constants.dart';

class UserManagementSettingsPage extends StatefulWidget {
  const UserManagementSettingsPage({super.key});
  @override
  State<UserManagementSettingsPage> createState() => _UserManagementSettingsPageState();
}

class _UserManagementSettingsPageState extends State<UserManagementSettingsPage> {
  final name = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final employeeId = TextEditingController();
  final jobTitle = TextEditingController();
  final group = TextEditingController();
  final notes = TextEditingController();
  final municipality = TextEditingController();
  String role = 'worker';
  bool _roleInit = false;
  String cycleId = '';
  bool obscure = true;
  bool busy = false;

  @override
  void dispose() {
    for (final c in [name, username, email, phone, password, employeeId, jobTitle, group, notes, municipality]) { c.dispose(); }
    super.dispose();
  }

  bool get workforce => role == 'worker' || role == 'group_supervisor';

  Future<void> create() async {
    final actor = context.read<AuthService>().currentUser!;
    if (name.text.trim().isEmpty || username.text.trim().isEmpty || password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('أدخل الاسم واسم المستخدم وكلمة مرور من 8 أحرف على الأقل.')));
      return;
    }
    if (workforce && (cycleId.isEmpty || group.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('حسابات العاملين تحتاج دورة عمل ومجموعة.')));
      return;
    }
    setState(() => busy = true);
    try {
      final svc = context.read<OperationsAdminService>();
      final result = workforce
          ? await svc.provisionUser(name: name.text, username: username.text, role: role, cycleId: cycleId, groupId: group.text, phone: phone.text, password: password.text, email: email.text, employeeId: employeeId.text, jobTitle: jobTitle.text, notes: notes.text)
          : await svc.provisionManagementUser(name: name.text, username: username.text, role: role, phone: phone.text, password: password.text, email: email.text, employeeId: employeeId.text, jobTitle: jobTitle.text, notes: notes.text, municipalityName: municipality.text);
      if (!mounted) return;
      await showDialog(context: context, builder: (_) => AlertDialog(
        title: const AppText('تم إنشاء المستخدم'),
        content: AppText('اسم المستخدم: ${result['username']}\nكلمة المرور: ${result['temporaryPassword']}\n\nالحساب جاهز للدخول الآن، وتم تحديث القائمة تلقائيًا. لم يتم حفظ كلمة المرور داخل Firestore.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const AppText('إغلاق'))],
      ));
      for (final c in [name, username, email, phone, password, employeeId, jobTitle, group, notes, municipality]) { c.clear(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    // Keep the local form and the role-driven UI fresh after creation.
    if (actor.id.isNotEmpty && mounted) setState(() {});
  }

  Future<void> _confirmDeleteManagedUser(BuildContext context, String id, String name, AppUser actor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('تأكيد حذف المستخدم'),
        content: AppText('هل تريد حذف المستخدم "$name" نهائيًا؟ سيتم حذف ملفه التشغيلي وحساب Firebase Authentication إن وجد. لا يمكن التراجع عن العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const AppText('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<OperationsAdminService>().deleteManagedUser(id, actorId: actor.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم حذف المستخدم نهائيًا.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر حذف المستخدم: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<AuthService>().currentUser;
    if (actor == null || (actor.role != 'donor_manager' && actor.role != 'municipality_coordinator')) {
      return const Scaffold(body: Center(child: AppText('لا تملك صلاحية إدارة المستخدمين.')));
    }
    final roles = actor.role == 'donor_manager'
        ? const ['donor_manager', 'jsc_coordinator', 'municipality_coordinator']
        : const ['group_supervisor', 'worker'];
    if (!_roleInit) {
      _roleInit = true;
      role = roles.first;
    }
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const AppText('إدارة المستخدمين'), actions: const [Padding(padding: EdgeInsetsDirectional.only(end: 14), child: AiFeatureIcon('users', size: 16))]),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            AiHero(user: actor, eyebrow: 'USER MANAGEMENT', title: 'إنشاء حساب تشغيلي كامل', subtitle: 'الحساب يُنشأ في Firebase Authentication ويُسجّل ملفه التشغيلي في Firestore. كلمة المرور لا تُحفظ في ملف المستخدم.'),
            const SizedBox(height: 14),
            AiSectionCard(
              title: 'بيانات الحساب', feature: 'users', child: Column(children: [
                DropdownButtonFormField<String>(value: roles.contains(role) ? role : roles.first, items: roles.map((r) => DropdownMenuItem(value: r, child: AppText(roleNames[r] ?? r))).toList(), onChanged: busy ? null : (v) => setState(() => role = v ?? role), decoration: InputDecoration(labelText: tr('الدور / المستوى'))),
                const SizedBox(height: 10),
                TextField(controller: name, decoration: InputDecoration(labelText: tr('الاسم الكامل'))),
                const SizedBox(height: 10),
                TextField(controller: username, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('اسم المستخدم'))),
                const SizedBox(height: 10),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('البريد الإلكتروني (اختياري)'))),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('رقم الجوال'))),
                if (role == 'municipality_coordinator') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(value: municipality.text.isEmpty ? null : municipality.text, items: gazaMunicipalities.map((m) => DropdownMenuItem(value: m.nameAr, child: AppText('${m.nameAr} — ${m.governorate}'))).toList(), onChanged: busy ? null : (v) => setState(() => municipality.text = v ?? ''), decoration: InputDecoration(labelText: tr('اسم البلدية المرتبطة بالمنسق')),),
                ],
                const SizedBox(height: 10),
                TextField(controller: password, obscureText: obscure, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('كلمة المرور'), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))))
              ]),
            ),
            const SizedBox(height: 12),
            AiSectionCard(
              title: 'المعلومات التشغيلية', feature: 'operations', child: Column(children: [
                Row(children: [Expanded(child: TextField(controller: employeeId, decoration: InputDecoration(labelText: tr('الرقم الوظيفي')))), const SizedBox(width: 10), Expanded(child: TextField(controller: jobTitle, decoration: InputDecoration(labelText: tr('المسمى الوظيفي'))))]),
                if (workforce) ...[
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: context.read<OperationsAdminService>().activeCycles(),
                    builder: (_, snap) {
                      final cycles = snap.data?.docs ?? [];
                      return Column(children: [
                        DropdownButtonFormField<String>(value: cycles.any((c) => c.id == cycleId) ? cycleId : null, items: cycles.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.data()['name'] ?? c.id}'))).toList(), onChanged: (v) => setState(() => cycleId = v ?? ''), decoration: InputDecoration(labelText: tr('دورة العمل'))),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('operations').where('_entity', isEqualTo: 'group').limit(200).snapshots(),
                          builder: (context, groupSnap) {
                            final docs = groupSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                            final ids = docs.map((d) => d.id).toSet();
                            return Column(children: [
                              DropdownButtonFormField<String>(
                                value: ids.contains(group.text.trim()) ? group.text.trim() : null,
                                items: docs.map((d) {
                                  final x = d.data();
                                  return DropdownMenuItem(value: d.id, child: Text('${x['name'] ?? x['groupName'] ?? d.id}'));
                                }).toList(),
                                onChanged: busy ? null : (v) => setState(() => group.text = v ?? ''),
                                decoration: InputDecoration(labelText: tr('المجموعة / مشرف المجموعة')),
                              ),
                              const SizedBox(height: 7),
                              TextField(controller: group, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('معرّف المجموعة (بديل عند عدم وجود القائمة)'))),
                            ]);
                          },
                        ),
                      ]);
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextField(controller: notes, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: tr('ملاحظات'))),
              ]),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: busy ? null : create, icon: const Icon(Icons.person_add_alt_1_rounded), label: AppText(busy ? 'جارٍ إنشاء الحساب...' : 'إنشاء المستخدم وحفظ البيانات'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54))),
            const SizedBox(height: 8),
            const AppText('الأمان: كلمة المرور تُرسل مباشرة إلى Firebase Authentication ولا تُخزن في Firestore أو LocalStore.', style: TextStyle(color: cleanOpsMuted, fontSize: 11)),
            const SizedBox(height: 16),
            AiSectionCard(
              title: 'المستخدمون (تحديث مباشر)', feature: 'users',
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: context.read<OperationsAdminService>().managedUsers(actorId: actor.id, actorRole: actor.role),
                builder: (_, snap) {
                  if (snap.hasError) return AppText('تعذر تحميل المستخدمين: ${snap.error}');
                  if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                  final docs = snap.data!.docs.toList()
                    ..sort((a, b) => '${a.data()['name'] ?? ''}'.compareTo('${b.data()['name'] ?? ''}'));
                  if (docs.isEmpty) return const AppText('لا يوجد مستخدمون بعد.');
                  return Column(children: [
                    for (final d in docs)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(d.data()['isActive'] == false ? Icons.person_off_rounded : Icons.person_rounded,
                            color: d.data()['isActive'] == false ? Colors.red : Colors.green),
                        title: Text('${d.data()['name'] ?? d.id}'),
                        subtitle: Text('${d.data()['username'] ?? ''} • ${roleNames['${d.data()['role']}'] ?? d.data()['role'] ?? ''}'),
                        trailing: (actor.role == 'donor_manager' || actor.role == 'municipality_coordinator') && d.id != actor.id
                            ? Wrap(children: [
                                IconButton(tooltip: 'حذف المستخدم', onPressed: () => _confirmDeleteManagedUser(context, d.id, '${d.data()['name'] ?? d.id}', actor), icon: const Icon(Icons.delete_forever_rounded, color: Colors.red)),
                                Switch(
                                  value: d.data()['isActive'] != false,
                                  onChanged: (v) async {
                                    try {
                                      await context.read<OperationsAdminService>().setUserActive(d.id, v, actorId: actor.id);
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                    }
                                  })
                              ])
                            : null,
                      ),
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
