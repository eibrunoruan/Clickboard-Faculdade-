import 'package:clickboard/src/core/utils/validators/validators.dart';
import 'package:clickboard/src/features/profile_screen/controllers/profile_controller.dart';
import 'package:clickboard/src/features/profile_screen/repositories/profile_repository.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_profile_repository.dart';

/// US-02: o aluno altera o nome no perfil e o nome fica salvo.
void main() {
  Student aluno(String nome) => Student(
        name: nome,
        roll: 'N/A',
        reg: '',
        email: 'ana@catolicasc.edu.br',
        dept: 'CATOLICASC',
        session: 'N/A',
        uid: 'aluno-1',
      );

  ({ProfileController controller, ProviderContainer container}) montar(
      FakeProfileRepository repositorio, {String nomeAtual = 'Ana'}) {
    final container = ProviderContainer(overrides: [
      userProfileRepositoryProvider.overrideWithValue(repositorio),
    ]);
    addTearDown(container.dispose);
    container.read(myUserProvider.notifier).update(aluno(nomeAtual));
    return (
      controller: container.read(profileControllerProvider.notifier),
      container: container,
    );
  }

  group('validacao do nome', () {
    test('nome so com espacos e recusado', () {
      expect(nameValidate('   '), 'Campo obrigatório');
    });

    test('nome nulo e recusado', () {
      expect(nameValidate(null), 'Campo obrigatório');
    });

    test('nome normal passa', () {
      expect(nameValidate('Ana Souza'), isNull);
    });
  });

  group('changeUserData', () {
    test('salva o nome novo no repositorio e na sessao', () async {
      final repositorio = FakeProfileRepository();
      final (controller: controller, container: container) =
          montar(repositorio);

      final resultado = await controller.changeUserData(name: 'Ana Souza');

      expect(resultado.isRight(), isTrue);
      expect(repositorio.perfilSalvo?.name, 'Ana Souza');
      expect(container.read(myUserProvider)!.name, 'Ana Souza');
    });

    test('espacos sobrando nao vao para o banco', () async {
      final repositorio = FakeProfileRepository();
      final (controller: controller, container: _) = montar(repositorio);

      await controller.changeUserData(name: '  Ana Souza  ');

      expect(repositorio.perfilSalvo?.name, 'Ana Souza');
    });

    test('nome so com espacos nao chega no repositorio', () async {
      final repositorio = FakeProfileRepository();
      final (controller: controller, container: container) =
          montar(repositorio);

      final resultado = await controller.changeUserData(name: '   ');

      expect(resultado.isLeft(), isTrue);
      expect(repositorio.chamadas, isEmpty);
      expect(container.read(myUserProvider)!.name, 'Ana');
    });

    test('falha no servidor mantem o nome antigo e explica em portugues',
        () async {
      final repositorio = FakeProfileRepository();
      repositorio.falhas['editProfile'] = StateError('permission-denied');
      final (controller: controller, container: container) =
          montar(repositorio);

      final resultado = await controller.changeUserData(name: 'Ana Souza');

      expect(resultado.getLeft().toNullable(),
          'Não foi possível atualizar o perfil');
      expect(container.read(myUserProvider)!.name, 'Ana');
      expect(container.read(profileControllerProvider), isFalse);
    });
  });

  group('saudacao do perfil', () {
    test('primeiro nome ignora espaco no comeco', () {
      expect(aluno(' Ana Souza').primeiroNome, 'Ana');
    });

    test('nome vazio nao quebra a saudacao', () {
      expect(aluno('').primeiroNome, '');
    });
  });
}
