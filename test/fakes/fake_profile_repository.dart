import 'dart:io';

import 'package:clickboard/src/features/profile_screen/repositories/profile_repository.dart';
import 'package:clickboard/src/models/student_model.dart';

/// Repositorio de perfil de mentira.
///
/// `implements` em vez de `extends`: os campos do repositorio real sao
/// privados, e so os tres metodos publicos precisam existir aqui.
class FakeProfileRepository implements ProfileRepository {
  final List<String> chamadas = [];

  /// Quando preenchido, a chamada ao metodo correspondente lanca.
  final Map<String, Object> falhas = {};

  void _registrar(String metodo) {
    chamadas.add(metodo);
    final falha = falhas[metodo];
    if (falha != null) throw falha;
  }

  @override
  Future<void> deletePhoto() async => _registrar('deletePhoto');

  @override
  Future<void> uploadPhoto(File file) async => _registrar('uploadPhoto');

  @override
  Future<void> editProfile(Student user) async => _registrar('editProfile');
}
