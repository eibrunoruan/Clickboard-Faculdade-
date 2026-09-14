import 'package:clickboard/src/features/documents/controllers/document_controller.dart';
import 'package:clickboard/src/models/document_model.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Student _student({required String uid, bool isAdmin = false}) => Student(
      name: 'Aluno $uid',
      roll: 'N/A',
      reg: '',
      email: '$uid@catolicasc.edu.br',
      dept: 'CATOLICASC',
      session: 'N/A',
      isAdmin: isAdmin,
      uid: uid,
    );

Document _document({required String ownerUid, String name = 'prova.pdf'}) =>
    Document(
      file: SupabaseStorageObject(
        path: 'CATOLICASC/Documents/$ownerUid/$name',
        name: name,
      ),
      ownerUid: ownerUid,
    );

DocumentController _controllerFor(Student? user) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(myUserProvider.notifier).update(user);
  return container.read(documentControllerProvider.notifier);
}

void main() {
  group('canManage', () {
    test('dono gerencia o proprio arquivo', () {
      final controller = _controllerFor(_student(uid: 'aluno-1'));
      expect(controller.canManage(_document(ownerUid: 'aluno-1')), isTrue);
    });

    test('aluno nao gerencia arquivo de outro aluno', () {
      final controller = _controllerFor(_student(uid: 'aluno-1'));
      expect(controller.canManage(_document(ownerUid: 'aluno-2')), isFalse);
    });

    test('admin gerencia arquivo de qualquer um', () {
      final controller = _controllerFor(_student(uid: 'coord', isAdmin: true));
      expect(controller.canManage(_document(ownerUid: 'aluno-2')), isTrue);
    });

    test('sem usuario logado nao gerencia nada', () {
      final controller = _controllerFor(null);
      expect(controller.canManage(_document(ownerUid: 'aluno-1')), isFalse);
      expect(controller.canManage(_document(ownerUid: '')), isFalse);
    });
  });

  group('deleteDocument', () {
    test('recusa apagar arquivo de outro aluno antes de tocar no storage',
        () async {
      final controller = _controllerFor(_student(uid: 'aluno-1'));
      final result = await controller.deleteDocument(_document(ownerUid: 'aluno-2'));
      expect(result.isLeft(), isTrue);
      result.fold(
        (msg) => expect(msg, 'Você só pode apagar documentos que você enviou'),
        (_) => fail('deveria ter sido negado'),
      );
    });
  });

  group('renameDocument', () {
    test('recusa renomear arquivo de outro aluno', () async {
      final controller = _controllerFor(_student(uid: 'aluno-1'));
      final result = await controller.renameDocument(
        _document(ownerUid: 'aluno-2'),
        newName: 'novo.pdf',
      );
      expect(result.isLeft(), isTrue);
      result.fold(
        (msg) => expect(msg, 'Você só pode renomear documentos que você enviou'),
        (_) => fail('deveria ter sido negado'),
      );
    });

    test('recusa nomes que escapariam da pasta do dono', () async {
      final controller = _controllerFor(_student(uid: 'aluno-1'));
      for (final invalido in ['', '   ', '../outro/aluno', r'pasta\arquivo']) {
        final result = await controller.renameDocument(
          _document(ownerUid: 'aluno-1'),
          newName: invalido,
        );
        result.fold(
          (msg) => expect(msg, 'Informe um nome de documento válido',
              reason: 'nome: "$invalido"'),
          (_) => fail('deveria recusar o nome "$invalido"'),
        );
      }
    });
  });

  group('uploadFiles', () {
    test('sem usuario logado nem abre o seletor de arquivos', () async {
      final controller = _controllerFor(null);
      final result = await controller.uploadFiles();
      result.fold(
        (msg) => expect(msg, 'Faça login para enviar documentos'),
        (_) => fail('deveria ter sido negado'),
      );
    });
  });
}
