import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<String?> uploadAudioFile(String? path, {required String userId, required String operationId}) async {
  if (path == null || path.isEmpty || Firebase.apps.isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  final ref = FirebaseStorage.instance.ref('audio/$userId/$operationId/emergency.m4a');
  await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
  return ref.getDownloadURL();
}
