import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future<Uint8List> compress(Uint8List bytes, int targetKb) async {
    if (bytes.lengthInBytes <= targetKb * 1024) return bytes;
    int quality = 85;
    Uint8List result = bytes;
    for (var i = 0; i < 6; i++) {
      final scale = math.max(480, 1600 - i * 180);
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: scale,
        minHeight: scale,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      result = Uint8List.fromList(out);
      if (result.lengthInBytes <= targetKb * 1024) break;
      quality = math.max(40, quality - 10);
    }
    return result;
  }

  Future<String> compressToLocal(XFile file, {int targetKb = 500}) async {
    final raw = await file.readAsBytes();
    final compressed = await compress(raw, targetKb);
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/field_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(compressed, flush: true);
    return path;
  }

  Future<String?> pickCompressUpload({required int targetKb, required String userId, required String operationId}) async {
    final localPath = await pickCompressLocal(targetKb: targetKb, context: null);
    if (localPath == null) return null;
    if (Firebase.apps.isEmpty) return localPath;
    try {
      final ref = storage.ref('photos/$userId/$operationId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(localPath), SettableMetadata(contentType: 'image/jpeg', customMetadata: {'targetKb': '$targetKb'}));
      final url = await ref.getDownloadURL();
      try {
        await File(localPath).delete();
      } catch (_) {}
      return url;
    } catch (_) {
      return localPath;
    }
  }

  Future<ImageSource?> _chooseSource(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0A1F32),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('مصدر الصورة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ListTile(leading: const CircleAvatar(child: Icon(Icons.camera_alt_rounded)), title: const Text('التقاط من الكاميرا', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), onTap: () => Navigator.pop(sheetContext, ImageSource.camera)),
            ListTile(leading: const CircleAvatar(child: Icon(Icons.photo_library_rounded)), title: const Text('اختيار من الاستوديو', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), onTap: () => Navigator.pop(sheetContext, ImageSource.gallery)),
          ]),
        ),
      ),
    );
  }

  Future<String?> pickCompressLocal({required int targetKb, BuildContext? context}) async {
    final picker = ImagePicker();
    final source = context == null ? ImageSource.camera : await _chooseSource(context);
    if (source == null) return null;
    final image = await picker.pickImage(source: source, imageQuality: 100);
    if (image == null) return null;
    return compressToLocal(image, targetKb: targetKb);
  }
}
