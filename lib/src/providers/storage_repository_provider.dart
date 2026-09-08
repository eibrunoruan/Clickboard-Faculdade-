import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'supabase_storage_service.dart';
import 'type_defs.dart';

final storageRepositoryProvider = Provider(
  (ref) => StorageRepository(
    storageService: SupabaseStorageService(),
  ),
);

class StorageRepository {
  final SupabaseStorageService _storageService;

  StorageRepository({required SupabaseStorageService storageService})
      : _storageService = storageService;

  FutureEither<String> storeFile({
    required String path,
    required String id,
    required File? file,
    required Uint8List? webFile,
  }) async {
    try {
      if (kIsWeb) {
        return right(await _storageService.uploadBytes(
          folder: path,
          fileName: id,
          bytes: webFile!,
        ));
      } else {
        return right(await _storageService.uploadFile(path, id, file!));
      }
    } catch (e) {
      return left(e.toString());
    }
  }
}
