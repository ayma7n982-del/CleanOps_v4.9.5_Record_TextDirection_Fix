import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/core_models.dart';
import 'local_store.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage secure = const FlutterSecureStorage();
  final LocalStore localStore;
  AppUser? currentUser;
  User? firebaseUser;
  bool loading = false;
  String? error;
  bool rememberMe = false;
  String? rememberedUsername;
  bool offlineSession = false;

  AuthService(this.localStore);

  Future<void> loadRememberedState() async {
    final prefs = await SharedPreferences.getInstance();
    rememberMe = prefs.getBool('remember_me') ?? false;
    rememberedUsername = rememberMe ? prefs.getString('remembered_username') : null;
    notifyListeners();
  }

  Future<void> setRememberMe(bool value, String username) async {
    final prefs = await SharedPreferences.getInstance();
    rememberMe = value;
    await prefs.setBool('remember_me', value);
    if (value && username.trim().isNotEmpty) {
      rememberedUsername = username.trim();
      await prefs.setString('remembered_username', rememberedUsername!);
    } else {
      rememberedUsername = null;
      await prefs.remove('remembered_username');
    }
    notifyListeners();
  }

  Future<void> restore() async {
    try {
      final marker = await secure.read(key: 'session_marker');
      if (marker == 'authenticated') {
        currentUser = localStore.cachedUser();
        offlineSession = currentUser != null;
      }

      if (Firebase.apps.isNotEmpty) {
        firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          try {
            await _loadUser(firebaseUser!.uid);
            offlineSession = false;
          } catch (e) {
            debugPrint('Remote profile restore failed; fallback to local cache: $e');
            currentUser ??= localStore.cachedUser();
            offlineSession = currentUser != null;
          }
        }
      }
    } catch (e, stack) {
      debugPrint('Auth session restore failed: $e');
      debugPrintStack(stackTrace: stack);
    }
    notifyListeners();
  }

  Future<void> _loadUser(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 4));
    if (snap.exists && snap.data() != null) {
      final profile = AppUser.fromJson({...snap.data()!, 'id': uid});
      if (!profile.isActive) {
        throw StateError('هذا الحساب غير نشط أو مجمد حاليًا.');
      }
      currentUser = profile;
      await localStore.saveCachedUser(profile);
    } else {
      throw StateError('حساب المستخدم غير مهيأ في قاعدة البيانات.');
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<bool> enterOffline() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final cached = localStore.cachedUser();
      if (cached == null) {
        throw StateError('لا توجد جلسة مستخدم محفوظة محليًا. يجب تسجيل الدخول لمرة واحدة على الأقل أثناء توفر الإنترنت.');
      }
      if (!cached.isActive) {
        throw StateError('الحساب المحفوظ محلياً غير نشط أو مجمد حاليًا.');
      }
      currentUser = cached;
      firebaseUser = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
      offlineSession = true;
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (Firebase.apps.isEmpty) {
        throw StateError('خدمات Firebase غير متصلة. يمكنك استخدام «الدخول أوفلاين» إذا كانت لديك جلسة سابقة.');
      }
      final normalized = username.trim();
      final loginIdentity = normalized.toLowerCase();
      if (normalized.isEmpty || password.isEmpty) {
        throw StateError('يرجى إدخال اسم المستخدم وكلمة المرور.');
      }

      final online = await _hasInternet();
      if (!online) {
        throw StateError('لا يتوفر اتصال بالإنترنت. استخدم زر «الدخول أوفلاين» لمتابعة العمل.');
      }

      String email = loginIdentity.contains('@') ? loginIdentity : '$loginIdentity@solidwaste.local';
      UserCredential? credential;

      try {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (firstError) {
        bool resolvedAttempt = false;
        if (!loginIdentity.contains('@') &&
            (firstError.code == 'invalid-credential' ||
             firstError.code == 'wrong-password' ||
             firstError.code == 'user-not-found')) {
          try {
            final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
                .httpsCallable('resolveLoginEmail');
            final result = await callable.call({'username': loginIdentity});
            final resolvedEmail = ((result.data as Map?)?['email'] ?? '').toString().trim().toLowerCase();
            if (resolvedEmail.isNotEmpty && resolvedEmail != email) {
              email = resolvedEmail;
              credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              resolvedAttempt = true;
            }
          } catch (fnErr) {
            debugPrint('Cloud Function resolveLoginEmail is unavailable or un-deployed: $fnErr');
          }
        }
        if (!resolvedAttempt && credential == null) {
          rethrow;
        }
      }

      firebaseUser = credential?.user;
      if (firebaseUser == null) {
        throw StateError('تعذر إنشاء جلسة Firebase.');
      }

      await _loadUser(firebaseUser!.uid);
      await secure.write(key: 'session_marker', value: 'authenticated');
      offlineSession = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'اسم المستخدم أو كلمة المرور غير صحيحة. تأكد من صحة بياناتك وحاول ثانية.',
        'user-disabled' => 'هذا الحساب معطل من قبل إدارة المنظومة.',
        'network-request-failed' => 'تعذر الاتصال بالشبكة. يمكنك استخدام «الدخول أوفلاين» إذا سبق لك الدخول.',
        'too-many-requests' => 'تم تجاوز عدد محاولات الدخول المسموح بها. انتظر قليلاً وأعد المحاولة.',
        'operation-not-allowed' => 'تسجيل الدخول عبر البريد وكلمة المرور غير مفعّل في Firebase Authentication.',
        _ => 'تعذر تسجيل الدخول: ${e.message ?? e.code}',
      };
      return false;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordReset(String username) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (Firebase.apps.isEmpty) {
        throw StateError('خدمات Firebase غير متصلة. يرجى الاتصال بالإنترنت.');
      }
      final normalized = username.trim().toLowerCase();
      if (normalized.isEmpty) {
        throw StateError('يرجى إدخال اسم المستخدم لإرسال رابط إعادة تعيين كلمة المرور.');
      }
      final online = await _hasInternet();
      if (!online) {
        throw StateError('يلزم الاتصال بالإنترنت لإرسال رابط إعادة التعيين.');
      }

      bool functionSucceeded = false;
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('requestPasswordReset');
        await callable.call({'username': normalized});
        functionSucceeded = true;
      } catch (fnErr) {
        debugPrint('Cloud Function requestPasswordReset not available: $fnErr');
      }

      if (!functionSucceeded) {
        final email = normalized.contains('@') ? normalized : '$normalized@solidwaste.local';
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'user-not-found') {
            error = 'لم يتم العثور على حساب مرتبط بهذا الاسم.';
            return false;
          }
          rethrow;
        }
      }
      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await secure.delete(key: 'session_marker');
    await localStore.clearCachedUser();
    currentUser = null;
    firebaseUser = null;
    offlineSession = false;
    notifyListeners();
  }
}
