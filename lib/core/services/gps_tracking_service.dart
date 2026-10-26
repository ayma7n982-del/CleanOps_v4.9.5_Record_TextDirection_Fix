import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/core_models.dart';
import 'auth_service.dart';
import 'config_service.dart';

class GpsTrackingService extends ChangeNotifier {
  StreamSubscription<Position>? _positionSub;
  AuthService? _auth;
  ConfigService? _config;
  bool tracking = false;
  bool permissionDenied = false;
  String? status;
  Position? lastPosition;
  String? _boundUserId;

  void bind(AuthService auth, ConfigService config) {
    _auth = auth;
    _config = config;
    auth.addListener(_reconcile);
    config.addListener(_reconcile);
    _reconcile();
  }

  void _reconcile() {
    final user = _auth?.currentUser;
    final config = _config;
    if (user == null || config == null) {
      unawaited(stop());
      return;
    }
    final eligibleRole = user.role == 'worker' || user.role == 'group_supervisor';
    if (!eligibleRole || !user.isActive || !config.workerLocationTrackingEnabled) {
      unawaited(stop());
      return;
    }
    if (_boundUserId != user.id || !tracking) {
      _boundUserId = user.id;
      unawaited(start(user));
    }
  }

  Future<void> start(AppUser user) async {
    if (tracking || _config?.workerLocationTrackingEnabled != true) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status = 'خدمة الموقع غير مفعلة';
        notifyListeners();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permissionDenied = true;
        status = 'تم رفض إذن الموقع';
        notifyListeners();
        return;
      }
      permissionDenied = false;
      tracking = true;
      status = 'تتبع الموقع مفعل';
      notifyListeners();
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) await _publish(user, last);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen((position) => unawaited(_publish(user, position)));
    } catch (e) {
      tracking = false;
      status = 'تعذر تشغيل تتبع الموقع';
      debugPrint('GPS tracking start failed: $e');
      notifyListeners();
    }
  }

  Future<void> _publish(AppUser user, Position position) async {
    if (_config?.workerLocationTrackingEnabled != true || _auth?.currentUser?.id != user.id) return;
    lastPosition = position;
    final now = Timestamp.fromDate(DateTime.now());
    final point = GeoPoint(position.latitude, position.longitude);
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(user.id).set({
        'lastLocation': point,
        'lastLocationAt': now,
      }, SetOptions(merge: true));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      await prefs.setString('last_location_at', DateTime.now().toIso8601String());
      status = 'آخر موقع: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      notifyListeners();
    } catch (e) {
      // Firestore persistence queues the write locally when offline. Keep the local marker too.
      debugPrint('GPS publish queued/failed: $e');
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    if (tracking) {
      tracking = false;
      status = 'تتبع الموقع متوقف';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_reconcile);
    _config?.removeListener(_reconcile);
    _positionSub?.cancel();
    super.dispose();
  }
}
