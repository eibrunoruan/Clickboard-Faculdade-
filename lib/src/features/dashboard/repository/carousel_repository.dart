import 'package:flutter/material.dart';

import '../../../providers/supabase_storage_service.dart';

class CarouselRepository {
  final StorageService? _storageService;

  CarouselRepository({StorageService? storageService})
      : _storageService = storageService;

  Future<List<Image>> getAllImages() async {
    List<Image> images = [];
    try {
      final storage = _storageService ?? SupabaseStorageService();
      final imageFiles = await storage.list('Carousel');
      for (var file in imageFiles) {
        final url = await storage.signedUrl(file.path);
        images.add(Image.network(url, fit: BoxFit.cover));
      }
    } catch (e) {
      debugPrint('Falha ao buscar os carrosseis: $e');
    }
    return images;
  }
}
