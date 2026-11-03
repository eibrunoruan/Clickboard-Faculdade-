import 'dart:convert';
import 'dart:typed_data';

import 'package:clickboard/src/features/documents/controllers/document_controller.dart';
import 'package:clickboard/src/features/documents/repository/document_repository.dart';
import 'package:clickboard/src/models/document_model.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:clickboard/src/providers/token_supabase.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Teste de aceite da US-01 sem rede: o servidor do Supabase e simulado no
/// nivel do HTTP. O teste contra o servidor real esta em
/// storage_rls_integration_test.dart.

class _UsuarioFake implements User {
  _UsuarioFake(this._token);
  final String _token;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => _token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthFake implements FirebaseAuth {
  _AuthFake(this.currentUser);

  @override
  final User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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


  group('Autorização no Servidor (Supabase simulado)', () {
    const dono = 'aluno-a';
    const pastaDono = 'CATOLICASC/Documents/$dono';
    const caminhoArquivo = '$pastaDono/prova.pdf';

    late List<http.BaseRequest> requisicoes;

    // responde como o Supabase responde quando a RLS nega:
    // delete -> 200 com lista vazia, upload -> 403
    MockClient servidorComRls() => MockClient((req) async {
          requisicoes.add(req);
          if (req.method == 'DELETE') return http.Response('[]', 200);
          if (req.method == 'POST' && req.url.path.contains('/list/')) {
            return http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode({
              'statusCode': '403',
              'error': 'Unauthorized',
              'message': 'new row violates row-level security policy',
            }),
            403,
          );
        });

    SupabaseStorageService storageComToken(String? token) =>
        SupabaseStorageService(
          client: SupabaseClient(
            'https://exemplo.supabase.co',
            'chave-publica',
            httpClient: servidorComRls(),
            accessToken: () async => token,
          ),
        );

    setUp(() => requisicoes = []);

    test('tokenDoUsuario devolve o token do aluno logado', () async {
      expect(await tokenDoUsuario(_AuthFake(_UsuarioFake('token-aluno-b'))),
          'token-aluno-b');
    });

    test('tokenDoUsuario devolve null quando ninguem esta logado', () async {
      expect(await tokenDoUsuario(_AuthFake(null)), isNull);
    });

    test('o app manda o token do aluno em toda requisicao ao storage',
        () async {
      final auth = _AuthFake(_UsuarioFake('token-aluno-b'));
      final storage = SupabaseStorageService(
        client: SupabaseClient(
          'https://exemplo.supabase.co',
          'chave-publica',
          httpClient: servidorComRls(),
          accessToken: () => tokenDoUsuario(auth),
        ),
      );

      await storage.list(pastaDono);
      try {
        await storage.delete(caminhoArquivo);
      } on StorageException catch (_) {}

      expect(requisicoes, hasLength(2));
      for (final req in requisicoes) {
        expect(req.headers['Authorization'], 'Bearer token-aluno-b');
      }
    });

    test('delete negado pela RLS vira erro, nao sucesso falso', () async {
      await expectLater(
        storageComToken('token-aluno-b').delete(caminhoArquivo),
        throwsA(isA<StorageException>()),
      );
    });

    test('upload negado pela RLS chega no app como 403', () async {
      await expectLater(
        storageComToken('token-aluno-b').uploadBytes(
          folder: pastaDono,
          fileName: 'intruso.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<StorageException>()
            .having((e) => e.statusCode, 'statusCode', '403')),
      );
    });

    test('coordenacao: se o servidor nega, a tela mostra erro', () async {
      // o controller deixa a coordenacao tentar; quem decide e o servidor
      final container = ProviderContainer(overrides: [
        documentRepositoryProvider.overrideWithValue(DocumentRepository(
            storageService: storageComToken('token-coordenacao'))),
      ]);
      addTearDown(container.dispose);
      container.read(myUserProvider.notifier).update(Student(
            name: 'Coordenacao',
            roll: 'N/A',
            reg: '',
            email: 'coord@catolicasc.edu.br',
            dept: 'CATOLICASC',
            session: 'N/A',
            isAdmin: true,
            uid: 'coord',
          ));

      final resultado = await container
          .read(documentControllerProvider.notifier)
          .deleteDocument(Document(
            file: const SupabaseStorageObject(
                path: caminhoArquivo, name: 'prova.pdf'),
            ownerUid: dono,
          ));

      expect(resultado.isLeft(), isTrue);
      resultado.fold(
        (msg) => expect(msg, contains('Não foi possível apagar')),
        (_) => fail('mostrou sucesso com o servidor negando'),
      );
    });
  });
}
