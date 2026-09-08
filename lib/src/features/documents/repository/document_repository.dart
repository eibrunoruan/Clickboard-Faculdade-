import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../models/document_model.dart';
import '../../../providers/supabase_storage_service.dart';

class DocumentRepository {
  static final SupabaseStorageService _storage = SupabaseStorageService();

  static Future<List<Document>> getAllDocuments(String folder) async {
    final files = await _storage.list(folder);
    return files
        .map((file) => Document(
              file: file,
              timeCreated: file.timeCreated,
              contentType: file.contentType,
              size: file.size,
            ))
        .toList();
  }

  static Future<void> deleteDocument(Document document) async {
    await _storage.delete(document.file.path);
  }

  static Future<void> renameDocument(Document document, String newName) async {
    final appDocDir = (await getTemporaryDirectory()).path;
    final filePath = '$appDocDir/$newName';
    final file = File(filePath);
    await file.writeAsBytes(await _storage.download(document.file.path));
    await _storage.rename(document.file.path, newName);
  }

  static Future<void> uploadFile(String folder, PlatformFile file) async {
    await _storage.uploadPlatformFile(folder, file);
  }

  static Future<void> writeToFile(Document document, File file) async {
    await file.writeAsBytes(await _storage.download(document.file.path));
  }
}
