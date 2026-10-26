import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/core_models.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'local_store.dart';
import 'messaging_service.dart';

class ContainerItem {
  final String id;
  final String locationName;
  final double latitude;
  final double longitude;
  final String status;
  final String issueStatus;
  final String municipalityId;
  final String groupId;
  final String feedbackNotes;
  final String updatedAt;
  final String updatedBy;
  final String? createdAt;

  const ContainerItem({
    required this.id,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.issueStatus,
    required this.municipalityId,
    required this.groupId,
    required this.feedbackNotes,
    required this.updatedAt,
    required this.updatedBy,
    this.createdAt,
  });

  factory ContainerItem.fromMap(Map<String, dynamic> x) {
    final gps = x['gpsCoordinates'];
    double number(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return ContainerItem(
      id: '${x['id'] ?? ''}',
      locationName: '${x['locationName'] ?? ''}',
      latitude: gps is Map ? number(gps['lat'] ?? gps['latitude']) : number(x['latitude']),
      longitude: gps is Map ? number(gps['lng'] ?? gps['longitude']) : number(x['longitude']),
      status: '${x['status'] ?? 'empty'}',
      issueStatus: '${x['issueStatus'] ?? 'none'}',
      municipalityId: '${x['municipalityId'] ?? ''}',
      groupId: '${x['groupId'] ?? ''}',
      feedbackNotes: '${x['feedbackNotes'] ?? ''}',
      updatedAt: '${x['updatedAt'] ?? x['createdAt'] ?? ''}',
      updatedBy: '${x['updatedBy'] ?? x['createdBy'] ?? ''}',
      createdAt: x['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'locationName': locationName,
    'gpsCoordinates': {'lat': latitude, 'lng': longitude},
    'status': status,
    'issueStatus': issueStatus,
    'municipalityId': municipalityId,
    'groupId': groupId,
    'feedbackNotes': feedbackNotes,
    'updatedAt': updatedAt,
    'updatedBy': updatedBy,
    if (createdAt != null) 'createdAt': createdAt,
  };

  ContainerItem copyWith({
    String? locationName,
    double? latitude,
    double? longitude,
    String? status,
    String? issueStatus,
    String? municipalityId,
    String? groupId,
    String? feedbackNotes,
    String? updatedAt,
    String? updatedBy,
  }) => ContainerItem(
    id: id,
    locationName: locationName ?? this.locationName,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    status: status ?? this.status,
    issueStatus: issueStatus ?? this.issueStatus,
    municipalityId: municipalityId ?? this.municipalityId,
    groupId: groupId ?? this.groupId,
    feedbackNotes: feedbackNotes ?? this.feedbackNotes,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy ?? this.updatedBy,
    createdAt: createdAt,
  );
}

class ContainerService extends ChangeNotifier {
  final LocalStore store;
  final DataService data;
  final MessagingService messaging;
  final Uuid _uuid = const Uuid();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  AppUser? _user;
  List<ContainerItem> containers = [];
  bool loading = false;
  String? error;

  ContainerService(this.store, this.data, this.messaging);

  Future<void> attachUser(AppUser? user) async {
    await _subscription?.cancel();
    _subscription = null;
    _user = user;
    containers = store.cachedContainers().map(ContainerItem.fromMap).toList();
    _filterLocal();
    notifyListeners();
    if (user == null || Firebase.apps.isEmpty) return;
    loading = true;
    notifyListeners();
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('containers');
      if (user.role == 'group_supervisor' || user.role == 'worker') {
        query = query.where('groupId', isEqualTo: user.groupId ?? '');
      } else if (user.role == 'municipality_coordinator') {
        query = query.where('municipalityId', isEqualTo: user.id);
      }
      _subscription = query.snapshots(includeMetadataChanges: true).listen((snap) {
        final remote = snap.docs.map((d) => ContainerItem.fromMap({'id': d.id, ...d.data()})).toList();
        _mergeRemote(remote);
      }, onError: (e) {
        error = '$e';
        loading = false;
        notifyListeners();
      });
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _filterLocal() {
    final u = _user;
    if (u == null) return;
    if (u.role == 'group_supervisor' || u.role == 'worker') {
      containers = containers.where((c) => c.groupId == (u.groupId ?? '')).toList();
    } else if (u.role == 'municipality_coordinator') {
      containers = containers.where((c) => c.municipalityId == u.id).toList();
    }
  }

  void _mergeRemote(List<ContainerItem> remote) {
    final map = <String, ContainerItem>{for (final c in containers) c.id: c};
    for (final c in remote) map[c.id] = c;
    containers = map.values.toList()..sort((a, b) => a.locationName.compareTo(b.locationName));
    unawaited(store.saveCachedContainers(containers.map((e) => e.toMap()).toList()));
    loading = false;
    notifyListeners();
  }

  ContainerItem? byId(String id) { for (final c in containers) { if (c.id == id) return c; } return null; }

  Future<void> createContainer({required String locationName, required double latitude, required double longitude, required String municipalityId, String groupId = ''}) async {
    final u = _user;
    if (u == null || u.role != 'jsc_coordinator') throw StateError('ليس لديك صلاحية إنشاء الحاويات.');
    if (locationName.trim().isEmpty) throw ArgumentError('اسم موقع الحاوية مطلوب.');
    if (latitude.abs() > 90 || longitude.abs() > 180) throw ArgumentError('إحداثيات GPS غير صحيحة.');
    final now = DateTime.now().toIso8601String();
    final item = ContainerItem(id: _uuid.v4(), locationName: locationName.trim(), latitude: latitude, longitude: longitude, status: 'empty', issueStatus: 'none', municipalityId: municipalityId.trim(), groupId: groupId.trim(), feedbackNotes: '', updatedAt: now, updatedBy: u.id, createdAt: now);
    containers = [...containers, item];
    await store.saveCachedContainers(containers.map((e) => e.toMap()).toList());
    await data.enqueue('container', 'create', item.toMap());
    notifyListeners();
  }

  Future<void> updateContainer(ContainerItem item, {String? locationName, double? latitude, double? longitude, String? groupId}) async {
    final u = _user;
    if (u == null || u.role != 'jsc_coordinator') throw StateError('ليس لديك صلاحية تعديل الحاويات.');
    final next = item.copyWith(locationName: locationName, latitude: latitude, longitude: longitude, groupId: groupId, updatedAt: DateTime.now().toIso8601String(), updatedBy: u.id);
    await _saveLocal(next);
    await data.enqueue('container', 'update', next.toMap());
  }

  Future<void> updateDailyStatus(ContainerItem item, String status) async {
    final u = _user;
    if (u == null || (u.role != 'group_supervisor' && u.role != 'worker')) throw StateError('تحديث حالة الحاوية متاح للمشرف الميداني.');
    if (!const ['empty', 'partial', 'full'].contains(status)) throw ArgumentError('حالة الحاوية غير صالحة.');
    final previous = item.status;
    final next = item.copyWith(status: status, updatedAt: DateTime.now().toIso8601String(), updatedBy: u.id);
    await _saveLocal(next);
    await data.enqueue('container', 'update', next.toMap());
    if (status == 'full') {
      try { await messaging.sendContainerAlert(next, 'full'); } catch (e) { debugPrint('Container full alert deferred: $e'); }
    } else if (status == 'empty' && previous == 'full') {
      try { await messaging.sendContainerAlert(next, 'emptied'); } catch (e) { debugPrint('Container emptied alert deferred: $e'); }
    }
  }

  Future<void> reportIssue(ContainerItem item, String notes) async {
    final u = _user;
    if (u == null || (u.role != 'group_supervisor' && u.role != 'worker')) throw StateError('ليس لديك صلاحية تسجيل مشكلة الحاوية.');
    final next = item.copyWith(issueStatus: 'reported', feedbackNotes: notes.trim(), updatedAt: DateTime.now().toIso8601String(), updatedBy: u.id);
    await _saveLocal(next);
    await data.enqueue('container', 'update', next.toMap());
    try { await messaging.sendContainerAlert(next, 'issue'); } catch (e) { debugPrint('Container issue alert deferred: $e'); }
  }

  Future<void> startCorrectiveAction(ContainerItem item, String notes) async {
    final u = _user;
    if (u == null || u.role != 'municipality_coordinator') throw StateError('إجراء التصحيح متاح لمنسق البلدية.');
    if (item.issueStatus != 'reported') throw StateError('يبدأ الإجراء التصحيحي بعد تسجيل مشكلة.');
    final next = item.copyWith(issueStatus: 'resolving', feedbackNotes: notes.trim(), updatedAt: DateTime.now().toIso8601String(), updatedBy: u.id);
    await _saveLocal(next);
    await data.enqueue('container', 'update', next.toMap());
    try { await messaging.sendContainerAlert(next, 'resolving'); } catch (e) { debugPrint('Container corrective alert deferred: $e'); }
  }

  Future<void> confirmResolved(ContainerItem item, String notes) async {
    final u = _user;
    if (u == null || (u.role != 'municipality_coordinator' && u.role != 'group_supervisor')) throw StateError('تأكيد الحل متاح للبلدية والمشرف.');
    if (item.issueStatus != 'resolving') throw StateError('لا يمكن تأكيد الحل قبل بدء الإجراء التصحيحي.');
    final next = item.copyWith(issueStatus: 'verified_resolved', feedbackNotes: notes.trim(), updatedAt: DateTime.now().toIso8601String(), updatedBy: u.id);
    await _saveLocal(next);
    await data.enqueue('container', 'update', next.toMap());
    try { await messaging.sendContainerAlert(next, 'resolved'); } catch (e) { debugPrint('Container resolved alert deferred: $e'); }
  }

  Future<void> _saveLocal(ContainerItem next) async {
    final i = containers.indexWhere((c) => c.id == next.id);
    containers = [...containers];
    if (i >= 0) containers[i] = next; else containers.add(next);
    await store.saveCachedContainers(containers.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
