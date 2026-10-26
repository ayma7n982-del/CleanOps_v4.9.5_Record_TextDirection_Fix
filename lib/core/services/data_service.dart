import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/core_models.dart';
import 'config_service.dart';
import 'local_store.dart';

class DataService extends ChangeNotifier {
  final LocalStore store;
  final ConfigService config;
  final Uuid uuid = const Uuid();
  List<NotificationItem> notifications = [];
  List<ActivityItem> activities = [];
  List<SyncItem> queue = [];
  List<Map<String, dynamic>> operations = [];
  bool online = false, syncing = false;
  String lastSync = 'لم تتم المزامنة بعد';
  StreamSubscription<List<ConnectivityResult>>? connectivitySub;

  DataService(this.store, this.config);

  Future<void> init() async {
    notifications = store.notifications();
    activities = store.activities();
    queue = store.queue();
    operations = store.cachedOperations();
    lastSync = store.lastSync();
    final c = await Connectivity().checkConnectivity();
    online = !c.contains(ConnectivityResult.none);
    connectivitySub = Connectivity().onConnectivityChanged.listen((v) {
      online = !v.contains(ConnectivityResult.none);
      notifyListeners();
      if (online) {
        unawaited(sync());
        unawaited(refreshOperations());
      }
    });
    notifyListeners();
    if (online) {
      unawaited(sync());
      unawaited(refreshOperations());
    }
  }

  @override
  void dispose() {
    connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> addActivity(String title, String detail, {String level = 'info'}) async {
    final a = ActivityItem(
      id: uuid.v4(),
      title: title,
      detail: detail,
      createdAt: DateTime.now().toIso8601String(),
      level: level,
    );
    activities = [a, ...activities].take(100).toList();
    await store.saveActivities(activities);
    notifyListeners();
  }

  Future<void> writeAudit({
    required String actorId,
    required String operation,
    required String targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    final payload = {
      'id': uuid.v4(),
      'actorId': actorId,
      'operation': operation,
      'targetId': targetId,
      'before': before ?? {},
      'after': after ?? {},
      'createdAt': DateTime.now().toIso8601String(),
      'immutable': true,
    };
    await enqueue('audit', 'create', payload);
  }

  Future<void> notifyUser(String title, String body, {String level = 'info'}) async {
    final n = NotificationItem(
      id: uuid.v4(),
      title: title,
      body: body,
      level: level,
      createdAt: DateTime.now().toIso8601String(),
    );
    notifications = [n, ...notifications].take(100).toList();
    await store.saveNotifications(notifications);
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    notifications = notifications.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
    await store.saveNotifications(notifications);
    notifyListeners();
  }

  /// Converts Firestore and Dart values to JSON-safe primitives before placing
  /// operations in the offline queue. Firestore Timestamp/GeoPoint values can be
  /// present in imported or edited records and jsonEncode cannot encode them by default.
  dynamic _toJsonSafe(dynamic value) {
    if (value == null || value is String || value is bool || value is num) return value;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is GeoPoint) return <String, dynamic>{'latitude': value.latitude, 'longitude': value.longitude};
    if (value is DocumentReference) return value.path;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', _toJsonSafe(item)));
    }
    if (value is Iterable) return value.map(_toJsonSafe).toList();
    // Preserve useful diagnostics without allowing an unsupported object to abort
    // an otherwise valid offline-first operation.
    return value.toString();
  }

  Future<void> enqueue(String entity, String operation, Map<String, dynamic> payload) async {
    final safePayload = Map<String, dynamic>.from(_toJsonSafe(payload) as Map);
    final item = SyncItem(
      id: uuid.v4(),
      entity: entity,
      operation: operation,
      payload: jsonEncode(safePayload),
      createdAt: DateTime.now().toIso8601String(),
    );
    queue = [...queue, item];
    await store.saveQueue(queue);
    _applyLocalOperation(entity, operation, safePayload);
    notifyListeners();
    if (online) unawaited(sync());
  }

  Future<List<Map<String, dynamic>>> refreshOperations({int limit = 1000}) async {
    if (!online || Firebase.apps.isEmpty) return operations;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('operations')
          .limit(limit)
          .get();
      final loaded = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        loaded.add({'id': doc.id, ...doc.data()});
      }
      operations = _mergeOperations(loaded, operations);
      await store.saveCachedOperations(operations.take(limit).toList());
      notifyListeners();
    } catch (e) {
      debugPrint('Operations refresh failed; keeping local cache: $e');
    }
    return operations;
  }

  List<Map<String, dynamic>> _mergeOperations(
    List<Map<String, dynamic>> remote,
    List<Map<String, dynamic>> local,
  ) {
    final map = <String, Map<String, dynamic>>{};
    for (final item in remote) {
      final id = '${item['id'] ?? ''}';
      if (id.isNotEmpty) map[id] = Map.from(item);
    }
    for (final item in local) {
      final id = '${item['id'] ?? ''}';
      if (id.isNotEmpty) map[id] = {...?map[id], ...item};
    }
    final values = map.values.toList();
    values.sort((a, b) => '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    return values;
  }

  void _applyLocalOperation(String entity, String operation, Map<String, dynamic> payload) {
    if (entity == 'audit' || entity == 'notification') return;
    final id = '${payload['id'] ?? ''}';
    if (id.isEmpty) return;
    if (operation == 'delete' || operation == 'soft_delete') {
      operations = operations.map((e) => '${e['id']}' == id
          ? {...e, ...payload, '_entity': entity, 'isDeleted': true}
          : e).toList();
      return;
    }
    final next = {...payload, '_entity': entity};
    final index = operations.indexWhere((e) => '${e['id']}' == id);
    if (index >= 0) {
      operations = [...operations]..[index] = {...operations[index], ...next};
    } else {
      operations = _mergeOperations([next], operations);
    }
    unawaited(store.saveCachedOperations(operations.take(1000).toList()));
  }

  Future<void> _uploadAttachment(Map<String, dynamic> payload) async {
    final localPath = '${payload['localAttachmentPath'] ?? ''}';
    if (localPath.isEmpty) return;
    final file = File(localPath);
    if (!await file.exists()) {
      payload['attachmentWarning'] = 'ملف المرفق المحلي مفقود';
      payload.remove('localAttachmentPath');
      return;
    }
    final kind = '${payload['attachmentType'] ?? ''}';
    final userId = '${payload['userId'] ?? payload['reportedBy'] ?? 'unknown'}';
    final operationId = '${payload['id'] ?? uuid.v4()}';
    late final String url;
    if (kind == 'audio') {
      final ref = FirebaseStorage.instance.ref('audio/$userId/$operationId/emergency.m4a');
      await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
      url = await ref.getDownloadURL();
    } else {
      final ref = FirebaseStorage.instance.ref('photos/$userId/$operationId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      url = await ref.getDownloadURL();
    }
    payload['attachmentUrl'] = url;
    payload.remove('localAttachmentPath');
    payload.remove('attachmentType');
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> sync() async {
    if (!online || syncing || queue.isEmpty || Firebase.apps.isEmpty) return;
    syncing = true;
    notifyListeners();
    var completed = 0;

    try {
      for (final item in List.from(queue)) {
        try {
          final payload = Map<String, dynamic>.from(jsonDecode(item.payload));
          if (payload['localAttachmentPath'] != null && '${payload['localAttachmentPath']}'.isNotEmpty) {
            try {
              await _uploadAttachment(payload);
            } catch (attErr) {
              debugPrint('تعذر رفع المرفق للعنصر ${item.id}: $attErr');
            }
          }

          final collection = item.entity == 'audit' ? 'audit' : (item.entity == 'container' ? 'containers' : 'operations');
          final docId = payload['id']?.toString() ?? item.id;
          final ref = FirebaseFirestore.instance.collection(collection).doc(docId);

          if (item.entity == 'audit') {
            await ref.set({
              ...payload,
              'timestamp': FieldValue.serverTimestamp(),
              'immutable': true,
              '_entity': item.entity
            });
          } else if (item.entity == 'container') {
            // Containers have their own Firestore collection and strict field-level rules.
            // Do not inject the generic _entity marker into this collection.
            await ref.set({
              ...payload,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else if (item.operation == 'delete') {
            await ref.set({
              ...payload,
              'isDeleted': true,
              'updatedAt': FieldValue.serverTimestamp(),
              '_entity': item.entity
            }, SetOptions(merge: true));
          } else {
            await ref.set({
              ...payload,
              'updatedAt': FieldValue.serverTimestamp(),
              '_entity': item.entity
            }, SetOptions(merge: true));
          }

          completed++;
          _applyLocalOperation(item.entity, item.operation, payload);
          queue = queue.where((e) => e.id != item.id).toList();
          await store.saveQueue(queue);
        } catch (itemError) {
          debugPrint('تعذر مزامنة العنصر ${item.id}: $itemError');
        }
      }

      if (completed > 0) {
        lastSync = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        await store.saveLastSync(lastSync);
        await refreshOperations();
        await notifyUser('المزامنة مكتملة', 'تمت مزامنة $completed عملية بنجاح.', level: 'success');
        await addActivity('مزامنة البيانات', 'تم رفع $completed عملية إلى السحابة.', level: 'success');
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
