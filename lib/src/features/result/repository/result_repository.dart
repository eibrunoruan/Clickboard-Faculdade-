import '../../../models/result_model.dart';
import '../../../providers/supabase_storage_service.dart';

class ResultRepository {
  static final SupabaseStorageService _storage = SupabaseStorageService();

  static Future<List<Result>> getAllResults(String folder) async {
    final files = await _storage.list(folder);
    return files.map((file) {
      final match = RegExp(r'\d+').firstMatch(file.name);
      return Result(
        sem: int.tryParse(match?.group(0) ?? '') ?? 0,
        file: file,
        timeCreated: file.timeCreated,
      );
    }).toList();
  }

  static Future<List<int>> download(Result result) {
    return _storage.download(result.file.path);
  }
}
