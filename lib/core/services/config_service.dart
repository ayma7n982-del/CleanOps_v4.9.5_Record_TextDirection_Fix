import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/core_models.dart';
import '../constants/app_constants.dart';
import 'local_store.dart';

class ConfigService extends ChangeNotifier {
  final LocalStore store;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? configSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? globalConfigSub;
  String? attachedRole;
  Map<String, FeaturePolicy> policies = {};
  int configVersion = 1, permissionVersion = 1, workflowVersion = 1;
  int imageTargetKb = 300;
  int localImageRetentionDays = 7;
  bool autoImageCompression = true;
  bool voiceEnabled = true, ppeEnabled = true, streetPhotosEnabled = true, alternativeCartEnabled = true;
  bool liveOperationsMapEnabled = false, workerLocationTrackingEnabled = false;
  bool stageFrozen = false;
  String shift = '08:00 - 16:00';
  String apiBaseUrl = '';
  String apiVersion = 'v1';
  int apiTimeoutSeconds = 30;
  bool apiEnabled = false;
  bool localMessagingEnabled = true;
  bool onlineMessagingEnabled = true;
  bool autoMessageSync = true;
  bool readReceiptsEnabled = true;
  bool saveSentMessagesLocally = true;
  int messageRetentionDays = 30;
  String _apiKey = '';
  bool aiEnabled = false;
  String _aiApiKey = '';
  String aiModel = 'gpt-5.6-luna';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ConfigService(this.store);

  Future<void> loadLocal() async {
    final p = await SharedPreferences.getInstance();
    configVersion = p.getInt('config_version') ?? configVersion;
    permissionVersion = p.getInt('permission_version') ?? permissionVersion;
    workflowVersion = p.getInt('workflow_version') ?? workflowVersion;
    imageTargetKb = [300, 400, 500, 600, 1024].contains(p.getInt('image_target_kb'))
        ? p.getInt('image_target_kb')!
        : imageTargetKb;
    localImageRetentionDays = p.getInt('local_image_retention_days') ?? localImageRetentionDays;
    autoImageCompression = p.getBool('auto_image_compression') ?? autoImageCompression;
    voiceEnabled = p.getBool('voice_enabled') ?? voiceEnabled;
    ppeEnabled = p.getBool('ppe_enabled') ?? ppeEnabled;
    streetPhotosEnabled = p.getBool('street_photos_enabled') ?? streetPhotosEnabled;
    alternativeCartEnabled = p.getBool('alternative_cart_enabled') ?? alternativeCartEnabled;
    liveOperationsMapEnabled = p.getBool('live_operations_map_enabled') ?? liveOperationsMapEnabled;
    workerLocationTrackingEnabled = p.getBool('worker_location_tracking_enabled') ?? workerLocationTrackingEnabled;
    stageFrozen = p.getBool('stage_frozen') ?? stageFrozen;
    shift = p.getString('shift') ?? shift;
    apiBaseUrl = p.getString('api_base_url') ?? apiBaseUrl;
    apiVersion = p.getString('api_version') ?? apiVersion;
    apiTimeoutSeconds = p.getInt('api_timeout_seconds') ?? apiTimeoutSeconds;
    apiEnabled = p.getBool('api_enabled') ?? apiEnabled;
    localMessagingEnabled = p.getBool('local_messaging_enabled') ?? localMessagingEnabled;
    onlineMessagingEnabled = p.getBool('online_messaging_enabled') ?? onlineMessagingEnabled;
    autoMessageSync = p.getBool('auto_message_sync') ?? autoMessageSync;
    readReceiptsEnabled = p.getBool('read_receipts_enabled') ?? readReceiptsEnabled;
    saveSentMessagesLocally = p.getBool('save_sent_messages_locally') ?? saveSentMessagesLocally;
    messageRetentionDays = p.getInt('message_retention_days') ?? messageRetentionDays;
    _apiKey = await _secureStorage.read(key: 'cleanops_api_key') ?? _apiKey;
    aiEnabled = p.getBool('ai_enabled') ?? aiEnabled;
    final primaryAiKey = await _secureStorage.read(key: 'cleanops_ai_api_key');
    final legacyAiKey = (primaryAiKey == null || primaryAiKey.isEmpty)
        ? await _secureStorage.read(key: 'cleanops_gemini_api_key')
        : null;
    _aiApiKey = (primaryAiKey != null && primaryAiKey.isNotEmpty ? primaryAiKey : legacyAiKey) ?? _aiApiKey;
    aiModel = p.getString('ai_model') ?? aiModel;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('config_version', configVersion);
    await p.setInt('permission_version', permissionVersion);
    await p.setInt('workflow_version', workflowVersion);
    await p.setInt('image_target_kb', imageTargetKb);
    await p.setInt('local_image_retention_days', localImageRetentionDays);
    await p.setBool('auto_image_compression', autoImageCompression);
    await p.setBool('voice_enabled', voiceEnabled);
    await p.setBool('ppe_enabled', ppeEnabled);
    await p.setBool('street_photos_enabled', streetPhotosEnabled);
    await p.setBool('alternative_cart_enabled', alternativeCartEnabled);
    await p.setBool('live_operations_map_enabled', liveOperationsMapEnabled);
    await p.setBool('worker_location_tracking_enabled', workerLocationTrackingEnabled);
    await p.setBool('stage_frozen', stageFrozen);
    await p.setString('shift', shift);
    await p.setString('api_base_url', apiBaseUrl);
    await p.setString('api_version', apiVersion);
    await p.setInt('api_timeout_seconds', apiTimeoutSeconds);
    await p.setBool('api_enabled', apiEnabled);
    await p.setBool('local_messaging_enabled', localMessagingEnabled);
    await p.setBool('online_messaging_enabled', onlineMessagingEnabled);
    await p.setBool('auto_message_sync', autoMessageSync);
    await p.setBool('read_receipts_enabled', readReceiptsEnabled);
    await p.setBool('save_sent_messages_locally', saveSentMessagesLocally);
    await p.setInt('message_retention_days', messageRetentionDays);
    await _secureStorage.write(key: 'cleanops_api_key', value: _apiKey);
    await p.setBool('ai_enabled', aiEnabled);
    await _secureStorage.write(key: 'cleanops_ai_api_key', value: _aiApiKey);
    await p.setString('ai_model', aiModel);
  }

  void seedFor(String role) {
    for (final f in allFeatures.keys) {
      policies[f] = defaultPolicy(role, f);
    }
    notifyListeners();
  }

  bool visible(String role, String feature) => (policies[feature] ?? defaultPolicy(role, feature)).visible;

  Future<void> loadRemote() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 5),
      ));
      await rc.fetchAndActivate();
      configVersion = rc.getInt('config_version') == 0 ? configVersion : rc.getInt('config_version');
      permissionVersion = rc.getInt('permission_version') == 0 ? permissionVersion : rc.getInt('permission_version');
      workflowVersion = rc.getInt('workflow_version') == 0 ? workflowVersion : rc.getInt('workflow_version');
      imageTargetKb = [300, 400, 500, 600, 1024].contains(rc.getInt('image_target_kb'))
          ? rc.getInt('image_target_kb')
          : imageTargetKb;
      localImageRetentionDays = rc.getInt('local_image_retention_days') == 0
          ? localImageRetentionDays
          : rc.getInt('local_image_retention_days');
      final values = rc.getAll();
      if (values.containsKey('auto_image_compression')) autoImageCompression = rc.getBool('auto_image_compression');
      if (values.containsKey('voice_enabled')) voiceEnabled = rc.getBool('voice_enabled');
      if (values.containsKey('ppe_enabled')) ppeEnabled = rc.getBool('ppe_enabled');
      if (values.containsKey('street_photos_enabled')) streetPhotosEnabled = rc.getBool('street_photos_enabled');
      if (values.containsKey('alternative_cart_enabled')) alternativeCartEnabled = rc.getBool('alternative_cart_enabled');
      if (values.containsKey('live_operations_map_enabled')) liveOperationsMapEnabled = rc.getBool('live_operations_map_enabled');
      if (values.containsKey('worker_location_tracking_enabled')) workerLocationTrackingEnabled = rc.getBool('worker_location_tracking_enabled');
      if (values.containsKey('stage_frozen')) stageFrozen = rc.getBool('stage_frozen');
      if (values.containsKey('shift') && rc.getString('shift').trim().isNotEmpty) shift = rc.getString('shift');
    } catch (_) {}
    await _persistLocal();
    notifyListeners();
  }

  Future<void> attachRole(String role) async {
    attachedRole = role;
    seedFor(role);
    if (Firebase.apps.isEmpty) return;
    await configSub?.cancel();
    configSub = FirebaseFirestore.instance
        .collection('config')
        .doc('roles')
        .collection('items')
        .doc(role)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final raw = Map<String, dynamic>.from(data['features'] as Map? ?? {});
      for (final e in raw.entries) {
        policies[e.key] = FeaturePolicy.fromJson(Map<String, dynamic>.from(e.value));
      }
      configVersion = (data['configVersion'] ?? configVersion) as int;
      permissionVersion = (data['permissionVersion'] ?? permissionVersion) as int;
      workflowVersion = (data['workflowVersion'] ?? workflowVersion) as int;
      imageTargetKb = (data['imageTargetKb'] ?? imageTargetKb) as int;
      localImageRetentionDays = (data['localImageRetentionDays'] ?? localImageRetentionDays) as int;
      voiceEnabled = data['voiceEnabled'] ?? voiceEnabled;
      ppeEnabled = data['ppeEnabled'] ?? ppeEnabled;
      streetPhotosEnabled = data['streetPhotosEnabled'] ?? streetPhotosEnabled;
      alternativeCartEnabled = data['alternativeCartEnabled'] ?? alternativeCartEnabled;
      liveOperationsMapEnabled = data['liveOperationsMapEnabled'] ?? liveOperationsMapEnabled;
      workerLocationTrackingEnabled = data['workerLocationTrackingEnabled'] ?? workerLocationTrackingEnabled;
      shift = '${data['shift'] ?? shift}';
      stageFrozen = data['stageFrozen'] ?? stageFrozen;
      _persistLocal();
      notifyListeners();
    });
    await _listenGlobalConfig();
  }

  Future<void> _listenGlobalConfig() async {
    await globalConfigSub?.cancel();
    globalConfigSub = FirebaseFirestore.instance
        .collection('config')
        .doc('global')
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      voiceEnabled = data['voiceEnabled'] ?? voiceEnabled;
      ppeEnabled = data['ppeEnabled'] ?? ppeEnabled;
      streetPhotosEnabled = data['streetPhotosEnabled'] ?? streetPhotosEnabled;
      alternativeCartEnabled = data['alternativeCartEnabled'] ?? alternativeCartEnabled;
      liveOperationsMapEnabled = data['liveOperationsMapEnabled'] ?? liveOperationsMapEnabled;
      workerLocationTrackingEnabled = data['workerLocationTrackingEnabled'] ?? workerLocationTrackingEnabled;
      shift = '${data['shift'] ?? shift}';
      stageFrozen = data['stageFrozen'] ?? stageFrozen;
      apiEnabled = data['apiEnabled'] ?? apiEnabled;
      apiBaseUrl = '${data['apiBaseUrl'] ?? apiBaseUrl}';
      apiVersion = '${data['apiVersion'] ?? apiVersion}';
      apiTimeoutSeconds = (data['apiTimeoutSeconds'] ?? apiTimeoutSeconds) as int;
      localMessagingEnabled = data['localMessagingEnabled'] ?? localMessagingEnabled;
      onlineMessagingEnabled = data['onlineMessagingEnabled'] ?? onlineMessagingEnabled;
      autoMessageSync = data['autoMessageSync'] ?? autoMessageSync;
      readReceiptsEnabled = data['readReceiptsEnabled'] ?? readReceiptsEnabled;
      saveSentMessagesLocally = data['saveSentMessagesLocally'] ?? saveSentMessagesLocally;
      messageRetentionDays = (data['messageRetentionDays'] ?? messageRetentionDays) as int;
      configVersion = (data['configVersion'] ?? configVersion) as int;
      workflowVersion = (data['workflowVersion'] ?? workflowVersion) as int;
      notifyListeners();
    });
  }


  String get maskedApiKey => _apiKey.isEmpty ? '' : '••••••••${_apiKey.length > 4 ? _apiKey.substring(_apiKey.length - 4) : _apiKey}';
  String get aiApiKey => _aiApiKey;
  String get maskedAiApiKey => _aiApiKey.isEmpty ? '' : '••••••••${_aiApiKey.length > 4 ? _aiApiKey.substring(_aiApiKey.length - 4) : _aiApiKey}';

  Future<void> updateAISettings({required bool enabled, required String apiKey, required String model}) async {
    if (attachedRole != 'donor_manager' && attachedRole != 'jsc_coordinator') return;
    aiEnabled = enabled;
    if (apiKey.trim().isNotEmpty) _aiApiKey = apiKey.trim();
    aiModel = model.trim().isEmpty ? 'gpt-5.6-luna' : model.trim();
    await _persistLocal();
    notifyListeners();
  }

  Future<void> updateApiSettings({required bool enabled, required String baseUrl, required String version, required int timeoutSeconds, String? apiKey}) async {
    if (attachedRole != 'donor_manager' && attachedRole != 'jsc_coordinator') return;
    apiEnabled = enabled;
    apiBaseUrl = baseUrl.trim();
    apiVersion = version.trim().isEmpty ? 'v1' : version.trim();
    apiTimeoutSeconds = timeoutSeconds.clamp(5, 120);
    if (apiKey != null && apiKey.trim().isNotEmpty) _apiKey = apiKey.trim();
    configVersion++;
    await _persistLocal();
    notifyListeners();
    if (Firebase.apps.isNotEmpty) {
      await FirebaseFirestore.instance.collection('config').doc('global').set({
        'apiEnabled': apiEnabled,
        'apiBaseUrl': apiBaseUrl,
        'apiVersion': apiVersion,
        'apiTimeoutSeconds': apiTimeoutSeconds,
        'configVersion': configVersion,
      }, SetOptions(merge: true));
    }
  }

  Future<void> updateMessagingSettings({required bool localEnabled, required bool onlineEnabled, required bool autoSync, required bool readReceipts, required bool saveSentLocally, required int retentionDays}) async {
    localMessagingEnabled = localEnabled;
    onlineMessagingEnabled = onlineEnabled;
    autoMessageSync = autoSync;
    readReceiptsEnabled = readReceipts;
    saveSentMessagesLocally = saveSentLocally;
    messageRetentionDays = retentionDays.clamp(1, 3650);
    configVersion++;
    await _persistLocal();
    notifyListeners();
    if (Firebase.apps.isNotEmpty && (attachedRole == 'donor_manager' || attachedRole == 'jsc_coordinator')) {
      await FirebaseFirestore.instance.collection('config').doc('global').set({
        'localMessagingEnabled': localMessagingEnabled,
        'onlineMessagingEnabled': onlineMessagingEnabled,
        'autoMessageSync': autoMessageSync,
        'readReceiptsEnabled': readReceiptsEnabled,
        'saveSentMessagesLocally': saveSentMessagesLocally,
        'messageRetentionDays': messageRetentionDays,
        'configVersion': configVersion,
      }, SetOptions(merge: true));
    }
  }

  Future<void> setPolicy(String role, String feature, FeaturePolicy policy) async {
    policies[feature] = policy;
    permissionVersion++;
    await _persistLocal();
    notifyListeners();
    if (Firebase.apps.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection('config').doc('roles').collection('items').doc(role);
    await ref.set({
      'permissionVersion': permissionVersion,
      'configVersion': configVersion,
      'workflowVersion': workflowVersion,
      'imageTargetKb': imageTargetKb,
      'localImageRetentionDays': localImageRetentionDays,
    }, SetOptions(merge: true));
    await ref.update({'features.$feature': policy.toJson()});
  }

  Future<void> setOperationalFeature(String feature, bool enabled) async {
    final isL4 = attachedRole == 'donor_manager';
    final isL3 = attachedRole == 'jsc_coordinator';
    if (!isL4 && !isL3) return;
    if (!isL4 && feature != 'liveOperationsMap' && feature != 'workerLocationTracking') return;
    switch (feature) {
      case 'voice': voiceEnabled = enabled; break;
      case 'ppe': ppeEnabled = enabled; break;
      case 'streetPhotos': streetPhotosEnabled = enabled; break;
      case 'alternativeCart': alternativeCartEnabled = enabled; break;
      case 'liveOperationsMap': liveOperationsMapEnabled = enabled; break;
      case 'workerLocationTracking': workerLocationTrackingEnabled = enabled; break;
      default: return;
    }
    configVersion++;
    await _persistLocal();
    notifyListeners();
    if (Firebase.apps.isNotEmpty) {
      final payload = <String, dynamic>{
        'configVersion': configVersion,
        'liveOperationsMapEnabled': liveOperationsMapEnabled,
        'workerLocationTrackingEnabled': workerLocationTrackingEnabled,
      };
      if (isL4) {
        payload.addAll({
          'voiceEnabled': voiceEnabled,
          'ppeEnabled': ppeEnabled,
          'streetPhotosEnabled': streetPhotosEnabled,
          'alternativeCartEnabled': alternativeCartEnabled,
        });
      }
      await FirebaseFirestore.instance.collection('config').doc('global').set(payload, SetOptions(merge: true));
    }
  }

  Future<void> freezeStage() async {
    if (attachedRole != 'donor_manager') return;
    stageFrozen = true;
    workflowVersion++;
    await _persistLocal();
    notifyListeners();
    if (Firebase.apps.isNotEmpty) {
      await FirebaseFirestore.instance.collection('config').doc('global').set({
        'stageFrozen': true,
        'workflowVersion': workflowVersion
      }, SetOptions(merge: true));
    }
  }

  Future<void> updateShift(String value) async {
    if (attachedRole != 'donor_manager' || value.trim().isEmpty) return;
    shift = value.trim();
    configVersion++;
    await _persistLocal();
    notifyListeners();
    if (Firebase.apps.isNotEmpty) {
      await FirebaseFirestore.instance.collection('config').doc('global').set({
        'shift': shift,
        'configVersion': configVersion
      }, SetOptions(merge: true));
    }
  }

  Future<void> updateImageTarget(int kb) async {
    if (![300, 400, 500, 600, 1024].contains(kb)) return;
    imageTargetKb = kb;
    configVersion++;
    await _persistLocal();
    notifyListeners();
    if (Firebase.apps.isNotEmpty && attachedRole != null) {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('roles')
          .collection('items')
          .doc(attachedRole)
          .set({'imageTargetKb': kb, 'configVersion': configVersion}, SetOptions(merge: true));
    }
  }

  @override
  void dispose() {
    configSub?.cancel();
    globalConfigSub?.cancel();
    super.dispose();
  }
}
