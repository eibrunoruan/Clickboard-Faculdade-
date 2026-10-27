import 'package:clickboard/src/features/profile_screen/controllers/profile_controller.dart';
import 'package:clickboard/src/features/profile_screen/repositories/profile_repository.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_profile_repository.dart';

void main() {
  ({ProfileController controller, ProviderContainer container}) montar(
      FakeProfileRepository repositorio) {
    final container = ProviderContainer(overrides: [
      userProfileRepositoryProvider.overrideWithValue(repositorio),
    ]);
    addTearDown(container.dispose);
    return (
      controller: container.read(profileControllerProvider.notifier),
      container: container,
    );
  }

  group('deletePhoto', () {
    test('sucesso limpa a foto da sessao', () async {
      final repositorio = FakeProfileRepository();
      final (controller: controller, container: container) =
          montar(repositorio);
      container
          .read(myPhotoProvider.notifier)
          .update('https://exemplo.invalido/foto.png');

      await controller.deletePhoto();

      expect(repositorio.chamadas, ['deletePhoto']);
      expect(container.read(myPhotoProvider), isNull);
    });

    test('falha no storage nao pode limpar a foto da sessao', () async {
      final repositorio = FakeProfileRepository();
      repositorio.falhas['deletePhoto'] = StateError('bucket fora do ar');
      final (controller: controller, container: container) =
          montar(repositorio);
      container
          .read(myPhotoProvider.notifier)
          .update('https://exemplo.invalido/foto.png');

      await controller.deletePhoto();

      expect(container.read(myPhotoProvider), isNotNull,
          reason: 'a exclusao falhou, entao a foto continua la; limpar o '
              'estado faz a tela mentir que a foto foi removida');
    });

    test('o indicador de carregando volta a falso mesmo com falha', () async {
      final repositorio = FakeProfileRepository();
      repositorio.falhas['deletePhoto'] = StateError('bucket fora do ar');
      final (controller: controller, container: container) =
          montar(repositorio);

      await controller.deletePhoto();

      expect(container.read(profileControllerProvider), isFalse);
    });
  });
}
