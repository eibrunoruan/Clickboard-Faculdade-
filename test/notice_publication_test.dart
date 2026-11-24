import 'dart:io';

import 'package:clickboard/src/features/dashboard/controllers/carousel_controller.dart';
import 'package:clickboard/src/features/dashboard/controllers/notice_controller.dart';
import 'package:clickboard/src/features/dashboard/repository/notice_repository.dart';
import 'package:clickboard/src/features/dashboard/screens/dashboard.dart';
import 'package:clickboard/src/features/dashboard/screens/widgets/publish_notice_dialog.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage_service.dart';

void main() {
  const dept = 'CATOLICASC';
  const session = '2026';
  const folder = '$dept/$session/Notice';

  Student coordenador() => Student(
        name: 'Prof. Coordenador',
        roll: 'N/A',
        reg: '',
        email: 'coordenador@catolicasc.edu.br',
        dept: dept,
        session: session,
        isAdmin: true,
        uid: 'coord-1',
      );

  Student aluno() => Student(
        name: 'Aluno Aluno',
        roll: 'N/A',
        reg: '',
        email: 'aluno@catolicasc.edu.br',
        dept: dept,
        session: session,
        isAdmin: false,
        uid: 'aluno-1',
      );

  group('NoticeRepository - Publicação e Tratamento de Erros', () {
    test('publishNotice envia o arquivo para a pasta correta com extensão .pdf',
        () async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      await repo.publishNotice(
        title: 'Reunião de Colegiado',
        content: 'Pauta sobre o novo semestre',
      );

      expect(
        fake.chamadas,
        contains('uploadBytes($folder/Reunião de Colegiado.pdf)'),
      );
      final list = await fake.list(folder);
      expect(list.any((f) => f.name == 'Reunião de Colegiado.pdf'), isTrue);
    });

    test('publishNotice NÃO engole erro: falha de storage propaga exceção',
        () async {
      final fake = FakeStorageService();
      fake.falhas['uploadBytes'] =
          const SocketException('Sem conexão com o Supabase');
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      expect(
        () => repo.publishNotice(title: 'Aviso Teste'),
        throwsA(isA<SocketException>()),
      );
    });

    test('publishNotice recusa título vazio lançando ArgumentError', () async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      expect(
        () => repo.publishNotice(title: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(fake.chamadas, isEmpty);
    });
  });

  group('NoticeController - Gerenciamento de Estado Reativo', () {
    test(
        'caminho de sucesso: gerencia estados (loading -> success), atualiza lista e devolve Right',
        () async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(coordenador());

      final controller = container.read(noticeControllerProvider.notifier);

      expect(
        container.read(noticePublishStateProvider).status,
        NoticePublishStatus.initial,
      );

      final result = await controller.publishNotice(
        title: 'Semana Acadêmica',
        content: 'Programação de palestras',
      );

      expect(result.isRight(), isTrue);

      final publishState = container.read(noticePublishStateProvider);
      expect(publishState.isSuccess, isTrue);
      expect(publishState.successMessage, 'Aviso publicado com sucesso!');
      expect(publishState.isLoading, isFalse);

      // Garante que o mural foi atualizado instantaneamente
      final listaAvisos = container.read(noticeControllerProvider);
      expect(listaAvisos.any((a) => a.name == 'Semana Acadêmica'), isTrue);
    });

    test(
        'caminho de falha: erro de rede NÃO é engolido, estado vira error e devolve Left',
        () async {
      final fake = FakeStorageService();
      fake.falhas['uploadBytes'] =
          const SocketException('Erro de rede simulado');
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(coordenador());

      final controller = container.read(noticeControllerProvider.notifier);

      final result = await controller.publishNotice(
        title: 'Aviso com Queda de Rede',
        content: 'Conteúdo de teste',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (erro) => expect(
          erro,
          'Erro de conexão ao enviar aviso. Verifique sua rede e tente novamente',
        ),
        (_) => fail('Erro de rede não pode virar sucesso'),
      );

      final publishState = container.read(noticePublishStateProvider);
      expect(publishState.isError, isTrue);
      expect(
        publishState.errorMessage,
        'Erro de conexão ao enviar aviso. Verifique sua rede e tente novamente',
      );
      expect(publishState.isLoading, isFalse);
    });
  });

  group('Widget Tests - Diálogo de Publicação e Feedback Visual (BDD)', () {
    testWidgets(
        'DADO que o coordenador preenche os dados do aviso E há conexão, '
        'QUANDO clica em Publicar, '
        'ENTÃO app exibe mensagem de sucesso e fecha o formulário',
        (tester) async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(coordenador());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_dialog_btn'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => const PublishNoticeDialog(),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      // Abre o diálogo
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Preenche os dados
      await tester.enterText(
        find.byKey(const Key('notice_title_field')),
        'Horários das Provas Finais',
      );
      await tester.enterText(
        find.byKey(const Key('notice_content_field')),
        'Consulte a planilha de salas',
      );
      await tester.pump();

      // Clica em Publicar
      await tester.tap(find.byKey(const Key('submit_publish_button')));
      await tester.pumpAndSettle();

      // Feedback visual de sucesso exibido
      expect(find.text('Aviso publicado com sucesso!'), findsOneWidget);

      // O diálogo foi fechado
      expect(find.byType(PublishNoticeDialog), findsNothing);

      // O arquivo foi publicado no storage
      expect(
        fake.chamadas,
        contains('uploadBytes($folder/Horários das Provas Finais.pdf)'),
      );
    });

    testWidgets(
        'DADO que ocorre queda de conexão durante o upload, '
        'QUANDO clica em Publicar, '
        'ENTÃO app NÃO engole erro, exibe alerta explícito e MANTÉM os dados digitados',
        (tester) async {
      final fake = FakeStorageService();
      fake.falhas['uploadBytes'] =
          const SocketException('Host unreachable');
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(coordenador());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_dialog_btn'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => const PublishNoticeDialog(),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      // Abre o diálogo
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Preenche os dados do aviso
      await tester.enterText(
        find.byKey(const Key('notice_title_field')),
        'Mudança de Sala',
      );
      await tester.enterText(
        find.byKey(const Key('notice_content_field')),
        'A aula será no laboratório 3',
      );
      await tester.pump();

      // Clica em Publicar com conexão simulando queda
      await tester.tap(find.byKey(const Key('submit_publish_button')));
      await tester.pumpAndSettle();

      // Exibe alerta explícito orientando a tentar novamente
      expect(
        find.text(
          'Erro de conexão ao enviar aviso. Verifique sua rede e tente novamente',
        ),
        findsAtLeastNWidgets(1),
      );

      // O formulário NÃO foi fechado e os dados digitados foram preservados
      expect(find.byType(PublishNoticeDialog), findsOneWidget);
      expect(find.byKey(const Key('notice_title_field')), findsOneWidget);
      final titleField = tester.widget<TextFormField>(
        find.byKey(const Key('notice_title_field')),
      );
      expect(titleField.controller?.text, 'Mudança de Sala');

      final contentField = tester.widget<TextFormField>(
        find.byKey(const Key('notice_content_field')),
      );
      expect(contentField.controller?.text, 'A aula será no laboratório 3');
    });

    testWidgets(
        'Publicação com título vazio exibe erro de validação sem chamar storage',
        (tester) async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(coordenador());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_dialog_btn'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => const PublishNoticeDialog(),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Clica em Publicar sem preencher o título
      await tester.tap(find.byKey(const Key('submit_publish_button')));
      await tester.pumpAndSettle();

      expect(find.text('Informe o título do aviso'), findsOneWidget);
      expect(fake.chamadas, isEmpty);
    });
  });

  group('Dashboard - Permissão e Atualização Instantânea', () {
    testWidgets('Aluno comum não vê botão de adicionar aviso', (tester) async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
          carouselFutureProvider().overrideWith((ref) => Future.value()),
          noticeFutureProvider().overrideWith((ref) => Future.value()),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(aluno());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Dashboard()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add_notice_fab')), findsNothing);
    });

    testWidgets('Coordenador vê botão de adicionar aviso', (tester) async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
          carouselFutureProvider().overrideWith((ref) => Future.value()),
          noticeFutureProvider().overrideWith((ref) => Future.value()),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(coordenador());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Dashboard()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add_notice_fab')), findsOneWidget);
    });

    testWidgets(
        'Aviso publicado aparece imediatamente na lista da Dashboard sem reiniciar o app',
        (tester) async {
      final fake = FakeStorageService();
      final repo = NoticeRepository(
        storageService: fake,
        department: dept,
        session: session,
      );

      final container = ProviderContainer(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(repo),
          carouselFutureProvider().overrideWith((ref) => Future.value()),
          noticeFutureProvider().overrideWith((ref) => Future.value()),
        ],
      );
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(coordenador());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Dashboard()),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente sem avisos
      expect(find.text('No Notices'), findsOneWidget);

      // Abre diálogo clicando no FAB
      await tester.tap(find.byKey(const Key('add_notice_fab')));
      await tester.pumpAndSettle();

      // Preenche e publica
      await tester.enterText(
        find.byKey(const Key('notice_title_field')),
        'Aviso Instantâneo na Dashboard',
      );
      await tester.tap(find.byKey(const Key('submit_publish_button')));
      await tester.pumpAndSettle();

      // O novo aviso já aparece imediatamente renderizado na Dashboard
      expect(find.text('Aviso Instantâneo na Dashboard'), findsOneWidget);
      expect(find.text('No Notices'), findsNothing);
    });
  });
}
