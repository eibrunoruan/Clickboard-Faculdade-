import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clickboard/src/features/dashboard/controllers/notice_controller.dart';
import 'package:clickboard/src/features/dashboard/controllers/publish_notice_controller.dart';
import 'package:clickboard/src/features/dashboard/repository/notice_repository.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import 'fakes/fake_storage_service.dart';

/// Publicacao de aviso pela coordenacao, sem rede.
///
/// Caminho de sucesso: o PDF cai na pasta da turma e o aviso entra no topo do
/// mural na hora. Caminho de falha: a queda de conexao vira mensagem
/// explicita, nunca sucesso silencioso nem estado preso em "enviando".
void main() {
  const dept = 'CATOLICASC';
  const session = 'N/A';
  const pastaDeAvisos = '$dept/$session/Notice';
  final pdf = Uint8List.fromList('%PDF-1.4 aviso'.codeUnits);

  Student usuario({bool isAdmin = true}) => Student(
        name: isAdmin ? 'Coordenação' : 'Aluno',
        roll: 'N/A',
        reg: '',
        email: 'pessoa@catolicasc.edu.br',
        dept: dept,
        session: session,
        isAdmin: isAdmin,
        uid: isAdmin ? 'coordenacao' : 'aluno-1',
      );

  /// O site da faculdade de origem fica sempre fora do ar nos testes.
  final semSiteDaFaculdade = MockClient((_) async => http.Response('', 404));

  ({ProviderContainer container, FakeStorageService storage}) montar({
    Student? quem,
    FakeStorageService? storage,
  }) {
    final fake = storage ?? FakeStorageService();
    final container = ProviderContainer(overrides: [
      noticeRepositoryProvider.overrideWithValue(NoticeRepository(
        storageService: fake,
        httpClient: semSiteDaFaculdade,
        department: dept,
        session: session,
      )),
    ]);
    addTearDown(container.dispose);
    container.read(myUserProvider.notifier).update(quem ?? usuario());
    // Mantem o provider autoDispose vivo durante o teste.
    container.listen(publishNoticeControllerProvider, (_, __) {});
    return (container: container, storage: fake);
  }

  PublishNoticeController controllerDe(ProviderContainer c) =>
      c.read(publishNoticeControllerProvider.notifier);

  group('caminho de sucesso', () {
    test('o PDF vai para a pasta da turma e o estado termina em sucesso',
        () async {
      final (container: c, storage: storage) = montar();

      await controllerDe(c).publish(title: '  Prova de Calculo  ', pdf: pdf);

      expect(storage.chamadas,
          contains('uploadBytes($pastaDeAvisos/Prova de Calculo.pdf)'),
          reason: 'o titulo e aparado e vira o nome do arquivo');
      final estado = c.read(publishNoticeControllerProvider);
      expect(estado, isA<PublishNoticeSuccess>());
      expect((estado as PublishNoticeSuccess).notice.name, 'Prova de Calculo');
    });

    test('o aviso entra no topo do mural sem recarregar', () async {
      final storage = FakeStorageService(arquivos: {
        pastaDeAvisos: [
          SupabaseStorageObject(
            path: '$pastaDeAvisos/Antigo.pdf',
            name: 'Antigo.pdf',
            timeCreated: DateTime(2026, 10, 1),
          ),
        ],
      });
      final (container: c, storage: _) = montar(storage: storage);
      await c.read(noticeControllerProvider.notifier).getAllNotices();
      storage.chamadas.clear();

      await controllerDe(c).publish(title: 'Novo', pdf: pdf);

      expect(c.read(noticeControllerProvider).map((n) => n.name),
          ['Novo', 'Antigo']);
      expect(storage.chamadas.where((ch) => ch.startsWith('list(')), isEmpty,
          reason: 'aparece na hora, sem esperar outra leitura do bucket');
    });

    test('republicar com o mesmo titulo nao duplica a linha do mural',
        () async {
      final (container: c, storage: _) = montar();

      await controllerDe(c).publish(title: 'Aviso', pdf: pdf);
      await controllerDe(c).publish(title: 'Aviso', pdf: pdf);

      expect(c.read(noticeControllerProvider), hasLength(1));
    });
  });

  group('caminho de falha', () {
    test('queda de conexao vira mensagem explicita e nao entra no mural',
        () async {
      final storage = FakeStorageService()
        ..falhas['uploadBytes'] = const SocketException('Network is down');
      final (container: c, storage: _) = montar(storage: storage);

      await controllerDe(c).publish(title: 'Aviso', pdf: pdf);

      final estado = c.read(publishNoticeControllerProvider);
      expect(estado, isA<PublishNoticeError>(),
          reason: 'o erro nao pode ser engolido nem ficar em "enviando"');
      expect((estado as PublishNoticeError).message, erroDeConexaoAoPublicar);
      expect(c.read(noticeControllerProvider), isEmpty);
    });

    test('depois da falha da para tentar de novo e publicar', () async {
      final storage = FakeStorageService()
        ..falhas['uploadBytes'] = http.ClientException('Connection reset');
      final (container: c, storage: _) = montar(storage: storage);

      await controllerDe(c).publish(title: 'Aviso', pdf: pdf);
      storage.falhas.clear();
      await controllerDe(c).publish(title: 'Aviso', pdf: pdf);

      expect(c.read(publishNoticeControllerProvider),
          isA<PublishNoticeSuccess>());
    });

    test('aluno comum e recusado sem nenhuma chamada ao storage', () async {
      final (container: c, storage: storage) =
          montar(quem: usuario(isAdmin: false));

      await controllerDe(c).publish(title: 'Aviso', pdf: pdf);

      expect(c.read(publishNoticeControllerProvider), isA<PublishNoticeError>());
      expect(storage.chamadas, isEmpty);
    });

    test('titulo vazio, titulo com barra ou sem PDF nao chegam ao storage',
        () async {
      final (container: c, storage: storage) = montar();

      for (final (titulo, arquivo) in [
        ('   ', pdf),
        ('../Documents/x', pdf),
        ('Aviso', null),
      ]) {
        await controllerDe(c).publish(title: titulo, pdf: arquivo);
        expect(c.read(publishNoticeControllerProvider), isA<PublishNoticeError>(),
            reason: 'titulo: "$titulo"');
      }
      expect(storage.chamadas, isEmpty);
    });
  });

  group('mensagemDeFalhaAoPublicar', () {
    test('rede e tempo esgotado viram erro de conexao', () {
      for (final erro in [
        const SocketException('offline'),
        http.ClientException('reset'),
        TimeoutException('sem resposta'),
      ]) {
        expect(mensagemDeFalhaAoPublicar(erro), erroDeConexaoAoPublicar,
            reason: '$erro');
      }
    });

    test('negacao do servidor vira erro de permissao, nao de rede', () {
      expect(
          mensagemDeFalhaAoPublicar(
              const StorageException('denied', statusCode: '403')),
          erroDePermissaoAoPublicar);
      expect(
          mensagemDeFalhaAoPublicar(const StorageException(
              'new row violates row-level security policy',
              statusCode: '400')),
          erroDePermissaoAoPublicar);
    });

    test('erro desconhecido tem mensagem propria', () {
      expect(mensagemDeFalhaAoPublicar(StateError('?')),
          erroInesperadoAoPublicar);
    });
  });

  group('leitura do mural sem catch vazio', () {
    test('falha do storage sobe em vez de virar mural vazio', () async {
      final storage = FakeStorageService()
        ..falhas['list'] = const SocketException('offline');
      final (container: c, storage: _) = montar(storage: storage);

      expect(
        c.read(noticeControllerProvider.notifier).getAllNotices(),
        throwsA(isA<SocketException>()),
        reason: 'antes o catch vazio devolvia [] e a tela dizia "No Notices"',
      );
    });

    test('site da faculdade fora do ar nao derruba os avisos da turma',
        () async {
      final repo = NoticeRepository(
        storageService: FakeStorageService(arquivos: {
          pastaDeAvisos: [
            const SupabaseStorageObject(
                path: '$pastaDeAvisos/Aviso.pdf', name: 'Aviso.pdf'),
          ],
        }),
        httpClient: MockClient((_) => throw http.ClientException('offline')),
        department: dept,
        session: session,
      );

      final avisos = await repo.getAllNotices();

      expect(avisos.map((n) => n.name), ['Aviso']);
    });
  });
}
