@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/conta_teste.dart';

/// Bate no Supabase de verdade com contas reais. Para rodar:
///
///   SUPABASE_INTEGRATION=1 ALUNO_A_EMAIL=... ALUNO_A_SENHA=... \
///   ALUNO_B_EMAIL=... ALUNO_B_SENHA=... flutter test test/storage_rls_integration_test.dart
final String? _pulado = Platform.environment['SUPABASE_INTEGRATION'] != '1'
    ? 'Toca o Supabase de verdade. Rode com SUPABASE_INTEGRATION=1.'
    : !(temConta('ALUNO_A') && temConta('ALUNO_B'))
        ? 'Sem as contas ALUNO_A_* e ALUNO_B_* no ambiente.'
        : null;

void main() {
  // Precisa de contas reais: ALUNO_A_*, ALUNO_B_* e (opcional) COORD_*.
  // Nada aqui passa por controller: e o cliente cru batendo direto no storage.
  group('Autorização no Servidor (Supabase Storage RLS com Cliente Cru)', () {
    final deptTeste =
        '_testes-autorizacao/${DateTime.now().millisecondsSinceEpoch}';
    final pastaAvisos = '$deptTeste/2026/Notice';
    final caminhoAviso = '$pastaAvisos/aviso_oficial.pdf';
    final conteudo = Uint8List.fromList('conteudo seguro'.codeUnits);
    const nomeArquivo = 'documento_aluno_a.pdf';

    final semCoordenacao =
        temConta('COORD') ? null : 'Sem COORD_EMAIL/COORD_SENHA no ambiente.';

    late ContaTeste alunoA;
    late ContaTeste alunoB;
    ContaTeste? coordenacao;
    late String pastaDono;
    late String caminhoArquivo;

    // so a chave publica, sem login nenhum
    final semLogin = SupabaseClient(supabaseUrl, supabasePublishableKey);

    StorageFileApi bucket(SupabaseClient c) =>
        c.storage.from(supabaseStorageBucket);

    Future<bool> arquivoAindaExiste() async =>
        (await bucket(semLogin).list(path: pastaDono))
            .any((f) => f.name == nomeArquivo);

    setUpAll(() async {
      if (_pulado != null) return;
      alunoA = await entrar('ALUNO_A');
      alunoB = await entrar('ALUNO_B');
      if (semCoordenacao == null) coordenacao = await entrar('COORD');

      pastaDono = '$deptTeste/Documents/${alunoA.uid}';
      caminhoArquivo = '$pastaDono/$nomeArquivo';
    });

    setUp(() async {
      if (_pulado != null) return;
      await bucket(alunoA.cliente).uploadBinary(caminhoArquivo, conteudo,
          fileOptions: const FileOptions(upsert: true));
    });

    tearDownAll(() async {
      if (_pulado != null) return;
      try {
        await bucket(alunoA.cliente).remove([caminhoArquivo]);
        if (coordenacao != null) {
          await bucket(coordenacao!.cliente).remove([caminhoAviso]);
        }
      } catch (_) {}
    });

    test('Sem login: so com a chave publica nao apaga o arquivo do Aluno A',
        () async {
      final apagados = await bucket(semLogin).remove([caminhoArquivo]);

      expect(apagados, isEmpty,
          reason: 'a chave publica esta no repositorio, nao pode bastar');
      expect(await arquivoAindaExiste(), isTrue);
    }, skip: _pulado);

    test('Aluno B logado nao apaga o arquivo do Aluno A', () async {
      final apagados = await bucket(alunoB.cliente).remove([caminhoArquivo]);

      expect(apagados, isEmpty);
      expect(await arquivoAindaExiste(), isTrue);
    }, skip: _pulado);

    test('Aluno B nao envia arquivo para a pasta do Aluno A', () async {
      await expectLater(
        bucket(alunoB.cliente).uploadBinary('$pastaDono/intruso.pdf', conteudo),
        throwsA(isA<StorageException>()),
      );
    }, skip: _pulado);

    test('Aluno comum nao envia aviso institucional', () async {
      await expectLater(
        bucket(alunoB.cliente).uploadBinary(caminhoAviso, conteudo),
        throwsA(isA<StorageException>()),
      );
    }, skip: _pulado);

    test('Aluno comum nao apaga aviso enviado pela coordenacao', () async {
      await bucket(coordenacao!.cliente).uploadBinary(caminhoAviso, conteudo,
          fileOptions: const FileOptions(upsert: true));

      final apagados = await bucket(alunoB.cliente).remove([caminhoAviso]);

      expect(apagados, isEmpty);
      expect(
          (await bucket(semLogin).list(path: pastaAvisos))
              .any((f) => f.name == 'aviso_oficial.pdf'),
          isTrue);
    }, skip: _pulado ?? semCoordenacao);

    test('O dono continua conseguindo apagar o proprio arquivo', () async {
      final apagados = await bucket(alunoA.cliente).remove([caminhoArquivo]);

      expect(apagados, isNotEmpty);
      expect(await arquivoAindaExiste(), isFalse);
    }, skip: _pulado);

    test('Coordenacao apaga arquivo de aluno', () async {
      final apagados =
          await bucket(coordenacao!.cliente).remove([caminhoArquivo]);

      expect(apagados, isNotEmpty);
      expect(await arquivoAindaExiste(), isFalse);
    }, skip: _pulado ?? semCoordenacao);
  });
}
