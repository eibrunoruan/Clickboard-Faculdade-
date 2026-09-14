import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../models/document_model.dart';
import '../../../providers/supabase_storage_service.dart';

/// Ponto unico de criacao do repositorio. Existe para que o teste possa
/// substituir o storage por um cliente proprio e exercitar o controller
/// inteiro: sem isso o `SupabaseStorageService()` padrao depende do singleton
/// `Supabase.instance`, que nao sobe dentro do `flutter test`.
final documentRepositoryProvider = Provider((ref) => DocumentRepository());

class DocumentRepository {
  DocumentRepository({SupabaseStorageService? storageService})
      : _storage = storageService ?? SupabaseStorageService();

  final SupabaseStorageService _storage;

  /// Le todos os documentos abaixo de [root], que guarda uma subpasta por
  /// usuario. A lista e compartilhada: todo mundo enxerga tudo, mas o uid da
  /// subpasta diz quem pode apagar ou renomear cada arquivo.
  Future<List<Document>> getAllDocuments(String root) async {
    final ownerUids = await _storage.listFolders(root);
    final documents = <Document>[];

    for (final ownerUid in ownerUids) {
      final files = await _storage.list('$root/$ownerUid');
      documents.addAll(files.map((file) => Document(
            file: file,
            ownerUid: ownerUid,
            timeCreated: file.timeCreated,
            contentType: file.contentType,
            size: file.size,
          )));
    }

    documents.sort((a, b) {
      final aDate = a.timeCreated;
      final bDate = b.timeCreated;
      if (aDate == null || bDate == null) return a.name.compareTo(b.name);
      return bDate.compareTo(aDate);
    });
    return documents;
  }

  Future<void> deleteDocument(Document document) async {
    await _storage.delete(document.file.path);
  }

  Future<void> renameDocument(Document document, String newName) async {
    final appDocDir = (await getTemporaryDirectory()).path;
    final filePath = '$appDocDir/$newName';
    final file = File(filePath);
    await file.writeAsBytes(await _storage.download(document.file.path));
    await _storage.rename(document.file.path, newName);
  }

  Future<void> uploadFile(String folder, PlatformFile file) async {
    await _storage.uploadPlatformFile(folder, file);
  }

  Future<void> writeToFile(Document document, File file) async {
    await file.writeAsBytes(await _storage.download(document.file.path));
  }
}
