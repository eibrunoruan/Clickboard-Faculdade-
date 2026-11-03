@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/conta_teste.dart';

/// Teste de aceite da US-01 (PR 5): autorização no servidor (Supabase Storage RLS).
///
/// Diferente de document_permissions_test.dart ou storage_integration_test.dart,
/// aqui NENHUM controller ou repository é utilizado. O teste exercita o
/// SupabaseClient CRU, simulando um invasor ou usuário comum que tenta
/// contornar as travas da interface gráfica chamando o endpoint de storage
/// diretamente.
final String? _pulado = Platform.environment['SUPABASE_INTEGRATION'] == '1'
    ? null
    : 'Toca o Supabase de verdade. Rode com SUPABASE_INTEGRATION=1.';

void main() {
  group('Regras offline de Autorização de Servidor', () {
    test('Estrutura de caminhos de Documentos e Avisos identifica o tipo de recurso', () {
      final service = SupabaseStorageService(
        client: SupabaseClient('https://exemplo.supabase.co', 'chave-de-teste'),
      );

      const pathDocumento = 'CATOLICASC/Documents/aluno-1/prova.pdf';
      const pathAviso = 'CATOLICASC/2026/Notice/edital.pdf';

      expect(service.parentFolder(pathDocumento), 'CATOLICASC/Documents/aluno-1');
      expect(pathDocumento.contains('/Documents/aluno-1/'), isTrue);

      expect(pathAviso.contains('/Notice/'), isTrue);
      // Avisos não possuem subpasta por dono
      expect(pathAviso.contains('/Documents/'), isFalse);
    });

    test('Identificação de subpasta do dono para proteção RLS no servidor', () {
      final service = SupabaseStorageService(
        client: SupabaseClient('https://exemplo.supabase.co', 'chave-de-teste'),
      );

      const pastaDonoA = 'CATOLICASC/Documents/aluno-a';
      final arquivoDonoA = service.childPath(pastaDonoA, 'trabalho.pdf');
      
      expect(arquivoDonoA, 'CATOLICASC/Documents/aluno-a/trabalho.pdf');
      expect(arquivoDonoA.contains('/Documents/aluno-a/'), isTrue);
      expect(arquivoDonoA.contains('/Documents/aluno-b/'), isFalse);
    });
  });


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
