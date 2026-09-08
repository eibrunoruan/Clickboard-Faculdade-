import '../providers/supabase_storage_service.dart';

class Document {
  final String name;
  final DateTime? timeCreated;
  final SupabaseStorageObject file;
  final int? size;
  final String? contentType;

  Document({required this.file, this.timeCreated, this.size, this.contentType})
      : name = file.name;
}
