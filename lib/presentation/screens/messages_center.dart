import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/messaging_service.dart';
import '../widgets/app_design.dart';

class MessagesCenterScreen extends StatefulWidget {
  const MessagesCenterScreen({super.key});

  @override
  State<MessagesCenterScreen> createState() => _MessagesCenterScreenState();
}

class _MessagesCenterScreenState extends State<MessagesCenterScreen> {
  final composer = TextEditingController();
  String type = 'info';
  String? selectedGroup;
  bool sending = false;

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messaging = context.watch<MessagingService>();
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('مركز الرسائل'),
          actions: [
            if (messaging.syncing) const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            Badge(
              isLabelVisible: messaging.unreadCount > 0,
              label: Text('${messaging.unreadCount}'),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.mark_email_unread_outlined)),
            ),
          ],
        ),
        body: messaging.messages.isEmpty
            ? _emptyState(user, messaging)
            : RefreshIndicator(
                onRefresh: messaging.retryPendingWrites,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  children: [
                    _statusBanner(messaging),
                    const SizedBox(height: 12),
                    AiHero(
                      user: user,
                      eyebrow: 'SECURE • FIRESTORE MESSAGING',
                      title: 'تواصل تشغيلي مباشر',
                      subtitle: 'رسائل داخلية لحظية تعمل مع التخزين المحلي ولا تعتمد على FCM.',
                      trailing: IconButton(onPressed: messaging.retryPendingWrites, icon: const Icon(Icons.sync_rounded, color: Colors.white)),
                    ),
                    const SizedBox(height: 14),
                    ...messaging.messages.map((message) => _messageCard(message, user.id, messaging)),
                  ],
                ),
              ),
        floatingActionButton: messaging.canSend(type) ? FloatingActionButton.extended(
          onPressed: sending ? null : () => _openComposer(user, messaging),
          icon: const Icon(Icons.edit_rounded),
          label: const AppText('رسالة جديدة'),
        ) : null,
      ),
    );
  }

  Widget _emptyState(AppUser user, MessagingService messaging) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          _statusBanner(messaging),
          const SizedBox(height: 28),
          const Icon(Icons.mark_email_unread_outlined, size: 78, color: aiCyan),
          const SizedBox(height: 16),
          const AppText('لا توجد رسائل بعد', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const AppText('ستظهر الرسائل الموجهة إليك أو إلى مجموعتك هنا تلقائيًا.', textAlign: TextAlign.center, style: TextStyle(color: cleanOpsMuted)),
          const SizedBox(height: 18),
          if (messaging.canSend(type))
            FilledButton.icon(onPressed: sending ? null : () => _openComposer(user, messaging), icon: const Icon(Icons.send_rounded), label: const AppText('إرسال رسالة')),
        ],
      );

  Widget _statusBanner(MessagingService service) {
    final error = service.lastError;
    return Card(
      color: error == null ? aiDark2.withOpacity(.75) : red.withOpacity(.10),
      child: ListTile(
        dense: true,
        leading: Icon(error == null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: error == null ? aiGreen : red),
        title: AppText(error == null ? 'الرسائل تعمل عبر Firestore Offline-First' : 'الرسالة محفوظة محليًا وسيعاد إرسالها عند عودة الاتصال.'),
        subtitle: error == null ? const AppText('لا توجد خدمة FCM مطلوبة للتراسل الداخلي.') : AppText(error),
      ),
    );
  }

  Widget _messageCard(MessageItem message, String uid, MessagingService messaging) {
    final isMine = message.senderId == uid;
    final style = switch (message.type) {
      'emergency' => (red, Icons.warning_amber_rounded, 'طوارئ / SOS'),
      'warning' => (orange, Icons.priority_high_rounded, 'تحذير'),
      _ => (aiCyan, Icons.info_outline_rounded, 'معلومة'),
    };
    final unread = !message.isRead && !isMine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AiGlassCard(
        color: unread ? style.$1.withOpacity(.08) : null,
        onTap: unread ? () => messaging.markRead(message.messageId) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: style.$1.withOpacity(.12), borderRadius: BorderRadius.circular(15), border: Border.all(color: style.$1.withOpacity(.35))),
              child: Icon(style.$2, color: style.$1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: AppText(style.$3, style: TextStyle(color: style.$1, fontWeight: FontWeight.w900))),
                    if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: aiGreen, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 5),
                  AppText(message.content, style: const TextStyle(fontSize: 15, height: 1.45)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 5, children: [
                    AppText(isMine ? 'أنت' : (message.senderName.isEmpty ? message.senderId : message.senderName), style: const TextStyle(color: cleanOpsMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                    AppText(DateFormat('yyyy/MM/dd • HH:mm').format(message.timestamp), style: const TextStyle(color: cleanOpsMuted, fontSize: 10)),
                    if (message.targetGroupId != null && message.targetGroupId!.startsWith('__USER__:')) const AppText('رسالة مباشرة', style: TextStyle(color: aiCyan, fontSize: 10)),
                    if (message.targetGroupId != null && !message.targetGroupId!.startsWith('__USER__:')) AppText(message.targetGroupId == MessagingService.allMunicipalitiesGroup ? 'بث للبلديات' : 'مجموعة ${message.targetGroupId}', style: const TextStyle(color: aiCyan, fontSize: 10)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openComposer(AppUser user, MessagingService messaging) async {
    composer.clear();
    type = user.role == 'group_supervisor' ? 'emergency' : 'info';
    selectedGroup = null;
    final data = context.read<DataService>();
    try { await data.refreshOperations(); } catch (_) {}
    final groups = <String>{};
    for (final item in data.operations) {
      if ('${item['_entity'] ?? ''}' == 'group' && item['isDeleted'] != true) {
        final id = '${item['id'] ?? item['number'] ?? ''}'.trim();
        if (id.isNotEmpty) groups.add(id);
      }
      final gid = '${item['groupId'] ?? ''}'.trim();
      if (gid.isNotEmpty && ('${item['_entity'] ?? ''}' == 'worker' || '${item['_entity'] ?? ''}' == 'group_supervisor')) groups.add(gid);
    }
    if ((user.groupId ?? '').isNotEmpty) groups.add(user.groupId!);
    if (groups.isNotEmpty) selectedGroup = groups.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cleanOpsSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        final isL1 = user.role == 'group_supervisor';
        final isManagement = user.role == 'municipality_coordinator' || user.role == 'jsc_coordinator' || user.role == 'donor_manager';
        final canChooseGroup = user.role == 'municipality_coordinator';
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).viewInsets.bottom + 18),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(children: [const Icon(Icons.forum_rounded, color: aiCyan), const SizedBox(width: 10), const Expanded(child: AppText('إرسال رسالة داخلية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(labelText: tr('نوع الرسالة')),
                items: [
                  if (!isL1) const DropdownMenuItem(value: 'info', child: AppText('معلومة')),
                  if (isL1) const DropdownMenuItem(value: 'info', child: AppText('تقرير ميداني')),
                  if (!isL1) const DropdownMenuItem(value: 'warning', child: AppText('تحذير')),
                  const DropdownMenuItem(value: 'emergency', child: AppText('طوارئ / SOS')),
                  if (isL1) const DropdownMenuItem(value: 'info', child: AppText('تقرير ميداني')),
                ],
                onChanged: (value) { if (value != null) setSheetState(() => type = value); },
              ),
              const SizedBox(height: 10),
              if (isManagement) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppText(type == 'emergency' ? 'سيتم توجيه الرسالة وفق نطاق الدور والصلاحيات.' : user.role == 'municipality_coordinator' ? 'ستصل الرسالة إلى المجموعة المختارة.' : 'ستصل الرسالة إلى جميع منسقي البلديات.'),
              ),
              if (canChooseGroup && groups.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: groups.contains(selectedGroup) ? selectedGroup : groups.first,
                  decoration: InputDecoration(labelText: tr('المجموعة المستهدفة')),
                  items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (value) => setSheetState(() => selectedGroup = value),
                ),
              if (isL1) const Card(color: Color(0x16EF4444), child: ListTile(leading: Icon(Icons.shield_outlined, color: red), title: AppText('رسالة إلى منسق البلدية'), subtitle: AppText('يجب أن يكون حساب المشرف مرتبطًا بالمجموعة والمنسق.'))),
              const SizedBox(height: 10),
              TextField(controller: composer, minLines: 4, maxLines: 8, textInputAction: TextInputAction.newline, decoration: InputDecoration(labelText: tr('محتوى الرسالة'), hintText: tr('اكتب الرسالة هنا...'))),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: type == 'emergency' ? red : null, minimumSize: const Size.fromHeight(54)),
                onPressed: sending ? null : () async {
                  setSheetState(() => sending = true);
                  try {
                    if (isL1) {
                      final target = await _resolveCoordinator(user, data);
                      if (target == null || target.isEmpty) throw StateError('لم يتم العثور على منسق البلدية المرتبط بهذه المجموعة.');
                      await messaging.sendToUser(targetUserId: target, content: composer.text, type: type);
                    } else if (user.role == 'municipality_coordinator') {
                      await messaging.sendBroadcast(content: composer.text, type: type, groupId: selectedGroup);
                    } else {
                      await messaging.sendBroadcast(content: composer.text, type: type);
                    }
                    if (mounted) Navigator.pop(context);
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: AppText('تم حفظ الرسالة وإرسالها. إذا لم يتوفر الإنترنت ستتم مزامنتها تلقائيًا.')));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: AppText('تعذر إرسال الرسالة: $e')));
                  } finally {
                    if (mounted) setSheetState(() => sending = false);
                  }
                },
                icon: const Icon(Icons.send_rounded),
                label: AppText(sending ? 'جارٍ الحفظ...' : 'إرسال'),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<String?> _resolveCoordinator(AppUser user, DataService data) async {
    if ((user.municipalityCoordinatorId ?? '').isNotEmpty) return user.municipalityCoordinatorId;
    final groupId = user.groupId ?? '';
    for (final item in data.operations) {
      if ('${item['_entity'] ?? ''}' != 'group') continue;
      if ('${item['id'] ?? ''}' == groupId || '${item['number'] ?? ''}' == groupId || '${item['groupId'] ?? ''}' == groupId) {
        final id = '${item['municipalityCoordinatorId'] ?? ''}'.trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }
}
