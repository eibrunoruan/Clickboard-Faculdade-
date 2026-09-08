import '../providers/supabase_storage_service.dart';

class Result {
  final String name;
  final int sem;
  final DateTime? timeCreated;
  final SupabaseStorageObject file;

  Result({required this.sem, required this.file, this.timeCreated})
      : name = 'Semester $sem';
}
