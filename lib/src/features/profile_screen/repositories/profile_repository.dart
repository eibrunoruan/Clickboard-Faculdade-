import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../../models/student_model.dart';
import '../../../providers/supabase_storage_service.dart';

final userProfileRepositoryProvider = Provider((ref) {
  return ProfileRepository(firestore: FirebaseFirestore.instance);
});

class ProfileRepository {
  final FirebaseFirestore _firestore;
  final SupabaseStorageService _storageService;
  ProfileRepository({required FirebaseFirestore firestore})
      : _firestore = firestore,
        _storageService = SupabaseStorageService();
  CollectionReference get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);

  Future<void> uploadPhoto(File file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final extension = file.path.split('.').last;
    final url = await _storageService.uploadFile(
      'Profile',
      '$uid.$extension',
      file,
    );
    await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
  }

  Future<void> deletePhoto() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final files = await _storageService.list('Profile');
    final userFiles = files.where((file) => file.name.split('.').first == uid);
    for (final file in userFiles) {
      await _storageService.delete(file.path);
    }
    await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
  }

  Future<void> editProfile(Student user) async {
    await _users.doc(user.uid).update(user.toJSON());
  }
}
