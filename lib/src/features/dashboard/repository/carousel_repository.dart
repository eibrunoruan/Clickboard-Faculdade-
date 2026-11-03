import 'package:flutter/material.dart';

import '../../../providers/supabase_storage_service.dart';

class CarouselRepository {
  final SupabaseStorageService _storageService;

  CarouselRepository({SupabaseStorageService? storageService})
      : _storageService = storageService ?? SupabaseStorageService();
  Future<List<Image>> getAllImages() async {
    List<Image> images = [];
    try {
      final imageFiles = await _storageService.list('Carousel');
      for (var file in imageFiles) {
        final url = await _storageService.signedUrl(file.path);
        images.add(Image.network(url, fit: BoxFit.cover));
      }
    } catch (e) {
      debugPrint('Falha ao buscar os carrosseis: $e');
    }
    return images;
  }
}
