import '../providers/supabase_storage_service.dart';

class Document {
  final String name;
  final DateTime? timeCreated;
  final SupabaseStorageObject file;
  final int? size;
  final String? contentType;

  /// uid do usuario que enviou o arquivo. Vem do segmento de pasta em
  /// `<dept>/Documents/<uid>/<arquivo>`, ja que o Supabase nao registra dono
  /// proprio: o app autentica no Firebase, entao storage.objects.owner e nulo.
  final String ownerUid;

  Document({
    required this.file,
    required this.ownerUid,
    this.timeCreated,
    this.size,
    this.contentType,
  }) : name = file.name;
}
