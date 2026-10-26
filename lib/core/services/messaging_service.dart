import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/core_models.dart';
import 'local_store.dart';
import 'config_service.dart';

class MessageItem {
  final String messageId;
  final String senderId;
  final String? targetUserId;
  final String? targetGroupId;
  final String content;
  final DateTime timestamp;
  final String type;
  final bool isRead;
  final String senderName;
  final String senderRole;

  const MessageItem({
    required this.messageId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    required this.isRead,
    this.targetUserId,
    this.targetGroupId,
    this.senderName = '',
    this.senderRole = '',
  });

  bool isForUser(String uid, String? groupId) =>
      senderId == uid || targetUserId == uid ||
      (targetGroupId != null && targetGroupId!.isNotEmpty && targetGroupId == groupId) ||
      targetGroupId == MessagingService.allMunicipalitiesGroup;

  Map<String, dynamic> toLocalJson() => {
        'messageId': messageId,
        'senderId': senderId,
        'targetUserId': targetUserId,
        'targetGroupId': targetGroupId,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        'isRead': isRead,
        'senderName': senderName,
        'senderRole': senderRole,
      };

  factory MessageItem.fromLocal(Map<String, dynamic> json) => MessageItem(
        messageId: '${json['messageId'] ?? json['id'] ?? ''}',
        senderId: '${json['senderId'] ?? ''}',
        targetUserId: json['targetUserId']?.toString(),
        targetGroupId: json['targetGroupId']?.toString(),
        content: '${json['content'] ?? ''}',
        timestamp: DateTime.tryParse('${json['timestamp'] ?? ''}') ?? DateTime.now(),
        type: '${json['type'] ?? 'info'}',
        isRead: json['isRead'] == true,
        senderName: '${json['senderName'] ?? ''}',
        senderRole: '${json['senderRole'] ?? ''}',
      );

  factory MessageItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawTs = data['timestamp'];
    final timestamp = rawTs is Timestamp ? rawTs.toDate() : (DateTime.tryParse('${rawTs ?? ''}') ?? DateTime.now());
    return MessageItem(
      messageId: '${data['messageId'] ?? doc.id}',
      senderId: '${data['senderId'] ?? ''}',
      targetUserId: data['targetUserId']?.toString(),
      targetGroupId: data['targetGroupId']?.toString(),
      content: '${data['content'] ?? ''}',
      timestamp: timestamp,
      type: '${data['type'] ?? 'info'}',
      isRead: data['isRead'] == true,
      senderName: '${data['senderName'] ?? ''}',
      senderRole: '${data['senderRole'] ?? ''}',
    );
  }
}

class MessagingService extends ChangeNotifier {
  static const allMunicipalitiesGroup = '__ALL_MUNICIPALITIES__';
  final LocalStore store;
  final ConfigService config;
  final Uuid _uuid = const Uuid();
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subscriptions = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  AppUser? _user;
  String? _uid;
  String? _groupId;
  List<MessageItem> messages = [];
  bool syncing = false;
  String? lastError;

  MessagingService(this.store, this.config);

  Future<void> init(AppUser? user) async {
    await attachUser(user);
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        unawaited(retryPendingWrites());
      }
    });
  }

  Future<void> attachUser(AppUser? user) async {
    await _cancelStreams();
    _user = user;
    _uid = user?.id;
    _groupId = user?.groupId;
    messages = (user == null || !config.localMessagingEnabled) ? [] : store.cachedMessages(user.id).map(MessageItem.fromLocal).toList();
    _applyLocalReadState();
    notifyListeners();
    if (user == null || !config.onlineMessagingEnabled || Firebase.apps.isEmpty) return;
    await _subscribe();
  }

  Future<void> _subscribe() async {
    final uid = _uid;
    if (uid == null) return;
    final firestore = FirebaseFirestore.instance;
    final queries = <Query<Map<String, dynamic>>>[
      firestore.collection('messages').where('targetGroupId', isEqualTo: '__USER__:$uid'),
      firestore.collection('messages').where('senderId', isEqualTo: uid),
    ];
    if ((_groupId ?? '').isNotEmpty) {
      queries.add(firestore.collection('messages').where('targetGroupId', isEqualTo: _groupId));
    }
    if (_user?.role == 'municipality_coordinator') {
      queries.add(firestore.collection('messages').where('targetGroupId', isEqualTo: allMunicipalitiesGroup));
    }
    if (_user?.role == 'jsc_coordinator') {
      queries.add(firestore.collection('messages').where('targetGroupId', isEqualTo: '__JSC__'));
    }
    for (final query in queries) {
      _subscriptions.add(query.snapshots(includeMetadataChanges: true).listen((snapshot) {
        for (final doc in snapshot.docs) {
          _mergeMessage(MessageItem.fromFirestore(doc));
        }
        _saveCache();
      }, onError: (Object error, StackTrace stack) {
        lastError = error.toString();
        debugPrint('Messaging stream error: $error');
      }));
    }
  }

  Future<void> _cancelStreams() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _mergeMessage(MessageItem message) {
    final index = messages.indexWhere((m) => m.messageId == message.messageId);
    if (index >= 0) {
      final local = messages[index];
      messages[index] = MessageItem(
        messageId: message.messageId,
        senderId: message.senderId,
        targetUserId: message.targetUserId,
        targetGroupId: message.targetGroupId,
        content: message.content,
        timestamp: message.timestamp,
        type: message.type,
        isRead: local.isRead || message.isRead,
        senderName: message.senderName,
        senderRole: message.senderRole,
      );
    } else {
      messages.add(message);
    }
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (messages.length > 500) messages = messages.take(500).toList();
    _applyLocalReadState();
    notifyListeners();
  }

  void _applyLocalReadState() {
    final uid = _uid;
    if (uid == null) return;
    final readIds = store.messageReadIds(uid).toSet();
    messages = messages.map((m) => readIds.contains(m.messageId) ? MessageItem(
      messageId: m.messageId,
      senderId: m.senderId,
      targetUserId: m.targetUserId,
      targetGroupId: m.targetGroupId,
      content: m.content,
      timestamp: m.timestamp,
      type: m.type,
      isRead: true,
      senderName: m.senderName,
      senderRole: m.senderRole,
    ) : m).toList();
  }

  Future<void> _saveCache() async {
    final uid = _uid;
    if (uid == null) return;
    await store.saveCachedMessages(uid, messages.map((m) => m.toLocalJson()).toList());
  }

  int get unreadCount => messages.where((m) => m.senderId != _uid && !m.isRead).length;

  bool canSend(String type) {
    switch (_user?.role) {
      case 'donor_manager':
      case 'jsc_coordinator':
        return true;
      case 'municipality_coordinator':
        return true;
      case 'group_supervisor':
        return type == 'info' || type == 'emergency';
      default:
        return false;
    }
  }

  Future<void> sendBroadcast({required String content, required String type, String? groupId}) async {
    final user = _user;
    if (user == null || !canSend(type)) throw StateError('ليس لديك صلاحية إرسال هذا النوع من الرسائل.');
    final targetGroup = user.role == 'donor_manager' || user.role == 'jsc_coordinator'
        ? allMunicipalitiesGroup
        : (groupId ?? _groupId ?? '');
    if (targetGroup.isEmpty) throw StateError('لم يتم تحديد المجموعة المستهدفة.');
    await _send(
      content: content,
      type: type,
      targetGroupId: targetGroup,
    );
  }

  Future<void> sendContainerAlert(dynamic container, String event) async {
    final user = _user;
    if (user == null) return;
    final municipalityId = '${container.municipalityId ?? ''}';
    final location = '${container.locationName ?? ''}';
    final groupId = '${container.groupId ?? ''}';
    final status = '${container.status ?? ''}';
    final issue = '${container.issueStatus ?? ''}';
    String text;
    String type = 'warning';
    switch (event) {
      case 'full':
        text = 'حاوية ممتلئة: $location • الحالة: ممتلئة${groupId.isEmpty ? '' : ' • المجموعة $groupId'}';
        type = 'emergency';
        break;
      case 'emptied':
        text = 'تم تفريغ الحاوية: $location • عادت إلى حالة فارغة.';
        type = 'info';
        break;
      case 'issue':
        text = 'مشكلة حاوية مسجلة: $location • ${container.feedbackNotes ?? ''}';
        type = 'warning';
        break;
      case 'resolving':
        text = 'إجراء تصحيحي قيد المعالجة للحاوية: $location.';
        type = 'warning';
        break;
      case 'resolved':
        text = 'تم تأكيد حل مشكلة الحاوية: $location.';
        type = 'info';
        break;
      default:
        text = 'تحديث حالة الحاوية: $location • $status • $issue';
    }
    // Container alerts are delivered to the municipality coordinator and JSC.
    final municipalityTarget = municipalityId.isNotEmpty ? municipalityId : (user.municipalityCoordinatorId ?? '');
    if (municipalityTarget.isNotEmpty && (user.role == 'group_supervisor' || user.role == 'worker')) {
      await _send(content: text, type: type, targetUserId: municipalityTarget);
      await _send(content: text, type: type, targetGroupId: '__JSC__');
    } else if (user.role == 'municipality_coordinator') {
      await _send(content: text, type: type, targetGroupId: '__JSC__');
    } else if (user.role == 'jsc_coordinator') {
      await _send(content: text, type: type, targetGroupId: '__ALL_MUNICIPALITIES__');
    }
  }

  Future<void> sendToUser({required String targetUserId, required String content, required String type}) async {
    final user = _user;
    if (user == null || !canSend(type)) throw StateError('ليس لديك صلاحية إرسال الرسائل.');
    if (targetUserId.trim().isEmpty) throw ArgumentError('المرسل إليه غير محدد.');
    await _send(content: content, type: type, targetUserId: targetUserId.trim());
  }

  Future<void> _send({required String content, required String type, String? targetUserId, String? targetGroupId}) async {
    final user = _user;
    if (user == null) throw StateError('لا توجد جلسة مستخدم.');
    final body = content.trim();
    if (body.isEmpty) throw ArgumentError('محتوى الرسالة مطلوب.');
    if (!const ['info', 'warning', 'emergency'].contains(type)) throw ArgumentError('نوع الرسالة غير صالح.');
    final id = _uuid.v4();
    final message = MessageItem(
      messageId: id,
      senderId: user.id,
      targetUserId: targetUserId,
      targetGroupId: targetGroupId,
      content: body,
      timestamp: DateTime.now(),
      type: type,
      isRead: true,
      senderName: user.name,
      senderRole: user.role,
    );
    _mergeMessage(message);
    if (config.localMessagingEnabled && config.saveSentMessagesLocally) await _saveCache();
    lastError = null;
    notifyListeners();

    if (!config.onlineMessagingEnabled || Firebase.apps.isEmpty) {
      throw StateError('Firebase غير متاح. تم حفظ الرسالة محليًا وستتم المحاولة عند الاتصال.');
    }
    try {
      final firestoreTarget = targetUserId != null ? '__USER__:$targetUserId' : targetGroupId;
      await FirebaseFirestore.instance.collection('messages').doc(id).set({
        'messageId': id,
        'senderId': user.id,
        'targetGroupId': firestoreTarget,
        'content': body,
        'timestamp': Timestamp.fromDate(message.timestamp),
        'type': type,
        'isRead': false,
      }, SetOptions(merge: false));
    } catch (e) {
      lastError = e.toString();
      debugPrint('Message write deferred; Firestore offline queue/cache will retry: $e');
      notifyListeners();
    }
  }

  Future<void> markRead(String messageId) async {
    final uid = _uid;
    if (uid == null) return;
    final readIds = store.messageReadIds(uid).toSet()..add(messageId);
    await store.saveMessageReadIds(uid, readIds.toList());
    final index = messages.indexWhere((m) => m.messageId == messageId);
    if (index >= 0) {
      final m = messages[index];
      messages[index] = MessageItem(
        messageId: m.messageId,
        senderId: m.senderId,
        targetUserId: m.targetUserId,
        targetGroupId: m.targetGroupId,
        content: m.content,
        timestamp: m.timestamp,
        type: m.type,
        isRead: true,
        senderName: m.senderName,
        senderRole: m.senderRole,
      );
      await _saveCache();
      notifyListeners();
    }
    if (config.onlineMessagingEnabled && config.readReceiptsEnabled && Firebase.apps.isNotEmpty) {
      final message = messages.firstWhere((m) => m.messageId == messageId, orElse: () => throw StateError('Message not found'));
      if (message.targetGroupId == '__USER__:$uid' || message.targetUserId == uid) {
        try {
          await FirebaseFirestore.instance.collection('messages').doc(messageId).update({'isRead': true});
        } catch (_) {}
      }
    }
  }

  Future<void> retryPendingWrites() async {
    if (!config.autoMessageSync || !config.onlineMessagingEnabled || syncing || Firebase.apps.isEmpty || _uid == null) return;
    syncing = true;
    notifyListeners();
    try {
      // Firestore's native offline persistence is the primary queue. The local cache
      // is intentionally kept so the center remains usable even before Firestore reconnects.
      await _subscribeRefresh();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _subscribeRefresh() async {
    if (!config.onlineMessagingEnabled || Firebase.apps.isEmpty) return;
    // Rebinding streams also refreshes any locally queued Firestore writes after reconnect.
    await _cancelStreams();
    await _subscribe();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _connectivitySub?.cancel();
    super.dispose();
  }
}
