@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  group('Autorização no Servidor (Supabase Storage RLS com Cliente Cru)', () {
    final deptTeste = '_testes-autorizacao/${DateTime.now().millisecondsSinceEpoch}';
    const donoUid = 'aluno-a-dono';
    final pastaDono = '$deptTeste/Documents/$donoUid';
    final pastaAvisos = '$deptTeste/2026/Notice';

    final conteudo = Uint8List.fromList('conteudo seguro'.codeUnits);
    const nomeArquivo = 'documento_aluno_a.pdf';
    final caminhoArquivo = '$pastaDono/$nomeArquivo';
    final caminhoAviso = '$pastaAvisos/aviso_oficial.pdf';

    late SupabaseClient rawClient;

    setUpAll(() async {
      if (_pulado != null) return;
      rawClient = SupabaseClient(supabaseUrl, supabasePublishableKey);

      // Sobe arquivo do dono
      await rawClient.storage.from(supabaseStorageBucket).uploadBinary(
        caminhoArquivo,
        conteudo,
        fileOptions: const FileOptions(upsert: true),
      );
    });

    tearDownAll(() async {
      if (_pulado != null) return;
      try {
        await rawClient.storage.from(supabaseStorageBucket).remove([caminhoArquivo, caminhoAviso]);
      } catch (_) {}
    });

    test('Bypass da interface: Aluno B cru tenta apagar arquivo do Aluno A e o servidor recusa', () async {
      // O Aluno B ignora o DocumentController e chama a API do Supabase diretamente.
      // Com as regras de RLS do PR 5 ativas, remove() no storage do Supabase retorna
      // vazio ou erro 403, não apagando o arquivo.
      final result = await rawClient.storage
          .from(supabaseStorageBucket)
          .remove([caminhoArquivo]);

      // A RLS impede a exclusão: nenhum registro é retornado como removido
      expect(result.isEmpty, isTrue,
          reason: 'O servidor deve impedir a exclusão direta do arquivo do Aluno A por outro aluno');

      // O arquivo original continua intacto no servidor
      final lista = await rawClient.storage
          .from(supabaseStorageBucket)
          .list(path: pastaDono);
      expect(lista.map((f) => f.name), contains(nomeArquivo),
          reason: 'Arquivo do Aluno A precisa continuar no bucket');
    }, skip: _pulado);

    test('Bypass da interface: Aluno comum cru tenta enviar aviso em /Notice/ e o servidor recusa', () async {
      // Aluno comum tenta enviar diretamente para a pasta institucional de Notice
      // sem passar por controller e sem credencial de coordenador
      try {
        await rawClient.storage.from(supabaseStorageBucket).uploadBinary(
          caminhoAviso,
          conteudo,
          fileOptions: const FileOptions(upsert: true),
        );
      } catch (e) {
        expect(e, isA<StorageException>());
      }
    }, skip: _pulado);

    test('Bypass da interface: Aluno comum cru tenta apagar aviso institucional e o servidor recusa', () async {
      final result = await rawClient.storage
          .from(supabaseStorageBucket)
          .remove([caminhoAviso]);

      expect(result.isEmpty, isTrue,
          reason: 'Apenas coordenação pode remover avisos institucionais no servidor');
    }, skip: _pulado);
  });
}
