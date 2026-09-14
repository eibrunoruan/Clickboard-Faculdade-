import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://czlevkffqqnzrtcnyiev.supabase.co',
);

const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_mB4fEsJCStu00rsJOYUomg_Eb5FVbwY',
);

const supabaseStorageBucket = String.fromEnvironment(
  'SUPABASE_STORAGE_BUCKET',
  defaultValue: 'clickboard',
);

class SupabaseStorageObject {
  final String path;
  final String name;
  final DateTime? timeCreated;
  final int? size;
  final String? contentType;

  const SupabaseStorageObject({
    required this.path,
    required this.name,
    this.timeCreated,
    this.size,
    this.contentType,
  });
}

class SupabaseStorageService {
  SupabaseStorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  StorageFileApi get _bucket => _client.storage.from(supabaseStorageBucket);

  String normalizeFolder(String folder) {
    return folder
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .join('/');
  }

  String childPath(String folder, String fileName) {
    final cleanFolder = normalizeFolder(folder);
    return cleanFolder.isEmpty ? fileName : '$cleanFolder/$fileName';
  }

  String parentFolder(String path) {
    final index = path.lastIndexOf('/');
    return index == -1 ? '' : path.substring(0, index);
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  SupabaseStorageObject _fromFileObject(String folder, FileObject file) {
    final metadata = file.metadata ?? <String, dynamic>{};
    final path = childPath(folder, file.name);
    return SupabaseStorageObject(
      path: path,
      name: file.name,
      timeCreated: _parseDate(file.createdAt),
      size: int.tryParse('${metadata['size'] ?? ''}'),
      contentType: metadata['mimetype']?.toString(),
    );
  }

  // Subpastas voltam do list() como entradas sem id, junto de um marcador
  // .emptyFolderPlaceholder criado pelo proprio Supabase. Nenhum dos dois e
  // arquivo de verdade.
  static bool _isFile(FileObject entry) =>
      entry.id != null && entry.name != '.emptyFolderPlaceholder';

  Future<List<SupabaseStorageObject>> list(String folder) async {
    final cleanFolder = normalizeFolder(folder);
    final files = await _bucket.list(path: cleanFolder);
    return files
        .where(_isFile)
        .map((file) => _fromFileObject(cleanFolder, file))
        .toList();
  }

  Future<List<String>> listFolders(String folder) async {
    final entries = await _bucket.list(path: normalizeFolder(folder));
    return entries
        .where((entry) => !_isFile(entry))
        .map((entry) => entry.name)
        .where((name) => name != '.emptyFolderPlaceholder')
        .toList();
  }

  Future<String> signedUrl(String path) {
    return _bucket.createSignedUrl(path, 60 * 60);
  }

  Future<Uint8List> download(String path) {
    return _bucket.download(path);
  }

  Future<void> uploadPlatformFile(String folder, PlatformFile file) async {
    final path = childPath(folder, file.name);
    final contentType = file.path == null ? null : lookupMimeType(file.path!);
    final options = FileOptions(contentType: contentType, upsert: true);

    if (file.path != null) {
      await _bucket.upload(path, File(file.path!), fileOptions: options);
      return;
    }

    await _bucket.uploadBinary(
      path,
      await file.readAsBytes(),
      fileOptions: options,
    );
  }

  Future<String> uploadFile(String folder, String fileName, File file) async {
    final path = childPath(folder, fileName);
    await _bucket.upload(
      path,
      file,
      fileOptions: FileOptions(
        contentType: lookupMimeType(file.path),
        upsert: true,
      ),
    );
    return signedUrl(path);
  }

  Future<String> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final path = childPath(folder, fileName);
    await _bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return signedUrl(path);
  }

  Future<void> delete(String path) async {
    // remove() responde 200 com lista vazia quando a RLS nega a operacao ou o
    // objeto nao existe, entao sem esta checagem a falha passa silenciosa e a
    // tela mostra sucesso com o arquivo ainda no bucket.
    final removed = await _bucket.remove([path]);
    if (removed.isEmpty) {
      throw StorageException(
        'Nenhum arquivo foi apagado em $path',
        error: 'NotDeleted',
      );
    }
  }

  Future<void> rename(String currentPath, String newName) async {
    await _bucket.move(
        currentPath, childPath(parentFolder(currentPath), newName));
  }
}
