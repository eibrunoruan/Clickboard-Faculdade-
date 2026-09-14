@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:clickboard/src/features/documents/controllers/document_controller.dart';
import 'package:clickboard/src/features/documents/repository/document_repository.dart';
import 'package:clickboard/src/models/document_model.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Este arquivo fala com o bucket de verdade, entao nao roda junto com os
/// testes normais. Para executar:
///
///   SUPABASE_INTEGRATION=1 flutter test test/storage_integration_test.dart
final String? _pulado = Platform.environment['SUPABASE_INTEGRATION'] == '1'
    ? null
    : 'Toca o Supabase de verdade. Rode com SUPABASE_INTEGRATION=1.';

/// O que o file_picker entrega no celular e um [PlatformFile] apontando para um
/// arquivo no disco. Aqui reproduzimos exatamente isso a partir de um arquivo
/// temporario, para exercitar o mesmo caminho de upload que o app usa.
base class _ArquivoLocal extends PlatformFile {
  _ArquivoLocal(this._file);

  final File _file;

  @override
  String get name => _file.uri.pathSegments.last;

  @override
  Uri get uri => _file.uri;

  // Sem anotacao de tipo de proposito: o tipo vem da superclasse e evita
  // depender do pacote cross_file so por causa desta linha. O upload nunca
  // chama este getter.
  @override
  get xFile => throw UnsupportedError('nao usado no teste');

  @override
  Future<int> length() => _file.length();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      _file.openRead().map(Uint8List.fromList);
}

void main() {
  // O controller monta a raiz a partir do `dept` do aluno (`<dept>/Documents`).
  // Usando um dept proprio do teste, tudo cai fora de CATOLICASC e nenhuma
  // sobra aparece no mural real.
  final deptTeste = '_testes-automatizados/${DateTime.now().millisecondsSinceEpoch}';
  final raiz = '$deptTeste/Documents';
  const dono = 'aluno-dono';
  const outro = 'aluno-outro';
  final pastaDoDono = '$raiz/$dono';

  final conteudo = Uint8List.fromList(
      'documento de teste ${DateTime.now().toIso8601String()}'.codeUnits);

  late SupabaseStorageService storage;
  late DocumentRepository repository;
  late File arquivoLocal;
  late String nomeRemoto;
  late String caminhoRemoto;

  Student aluno({required String uid, bool isAdmin = false}) => Student(
        name: 'Aluno $uid',
        roll: 'N/A',
        reg: '',
        email: '$uid@catolicasc.edu.br',
        dept: deptTeste,
        session: 'N/A',
        isAdmin: isAdmin,
        uid: uid,
      );

  /// Controller ligado ao bucket de verdade: o unico override e o repositorio,
  /// para trocar o storage. Tudo o mais (permissao, tratamento de erro,
  /// recarga da lista) e o codigo que roda no app.
  DocumentController controllerDe(Student usuario) {
    final container = ProviderContainer(overrides: [
      documentRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    container.read(myUserProvider.notifier).update(usuario);
    return container.read(documentControllerProvider.notifier);
  }

  Document documentoDoDono({String? caminho}) => Document(
        file: SupabaseStorageObject(
            path: caminho ?? caminhoRemoto, name: nomeRemoto),
        ownerUid: dono,
      );

  setUpAll(() {
    storage = SupabaseStorageService(
      client: SupabaseClient(supabaseUrl, supabasePublishableKey),
    );
    repository = DocumentRepository(storageService: storage);
    arquivoLocal = File(
        '${Directory.systemTemp.path}/clickboard-teste-${DateTime.now().millisecondsSinceEpoch}.pdf')
      ..writeAsBytesSync(conteudo);
    nomeRemoto = arquivoLocal.uri.pathSegments.last;
    caminhoRemoto = '$pastaDoDono/$nomeRemoto';
  });

  tearDownAll(() async {
    if (_pulado != null) return;
    if (arquivoLocal.existsSync()) arquivoLocal.deleteSync();
    for (final pasta in await storage.listFolders(raiz)) {
      for (final obj in await storage.list('$raiz/$pasta')) {
        try {
          await storage.delete(obj.path);
        } catch (_) {
          // Ja apagado pelo proprio teste.
        }
      }
    }
  });

  // Reenvia antes de cada teste, pelo mesmo metodo que o controller chama.
  setUp(() async {
    if (_pulado != null) return;
    await repository.uploadFile(pastaDoDono, _ArquivoLocal(arquivoLocal));
  });

  test('ENVIO: o controller lista o arquivo com dono, tipo e tamanho certos',
      () async {
    final controller = controllerDe(aluno(uid: dono));
    await controller.getAllDocuments(isRefreshed: true);

    final enviado =
        controller.state.singleWhere((d) => d.file.path == caminhoRemoto);
    expect(enviado.ownerUid, dono,
        reason: 'o dono sai do nome da subpasta no bucket');
    expect(enviado.size, conteudo.length);
    expect(enviado.contentType, 'application/pdf');
    expect(enviado.timeCreated, isNotNull);
    expect(controller.myDocumentCount, 1);
  }, skip: _pulado);

  test('DOWNLOAD: o arquivo baixado e byte a byte igual ao enviado', () async {
    final destino = File('${Directory.systemTemp.path}/baixado-$nomeRemoto');
    addTearDown(() {
      if (destino.existsSync()) destino.deleteSync();
    });

    await repository.writeToFile(documentoDoDono(), destino);
    expect(destino.readAsBytesSync(), conteudo);

    final url = await storage.signedUrl(caminhoRemoto);
    expect(url, contains('token='));
  }, skip: _pulado);

  test('DELETE BARRADO: outro aluno leva erro e o arquivo continua no bucket',
      () async {
    final invasor = controllerDe(aluno(uid: outro));
    final resultado = await invasor.deleteDocument(documentoDoDono());

    expect(resultado.isLeft(), isTrue);
    resultado.fold(
      (msg) => expect(msg, 'Você só pode apagar documentos que você enviou'),
      (_) => fail('o controller deixou outro aluno apagar'),
    );

    // O que importa de verdade: o arquivo continua no bucket.
    expect((await storage.list(pastaDoDono)).map((a) => a.path),
        contains(caminhoRemoto));
  }, skip: _pulado);

  test('DELETE PERMITIDO: o dono apaga pelo controller e o arquivo some',
      () async {
    final controller = controllerDe(aluno(uid: dono));
    await controller.getAllDocuments(isRefreshed: true);
    expect(controller.state.map((d) => d.file.path), contains(caminhoRemoto));

    final resultado = await controller.deleteDocument(documentoDoDono());
    expect(resultado.isRight(), isTrue,
        reason: 'o dono precisa conseguir apagar');

    // Sumiu do bucket...
    expect((await storage.list(pastaDoDono)).map((a) => a.path),
        isNot(contains(caminhoRemoto)));
    // ...e o controller ja recarregou a lista sozinho.
    expect(controller.state.map((d) => d.file.path),
        isNot(contains(caminhoRemoto)));
  }, skip: _pulado);

  test('ADMIN: a coordenacao apaga arquivo de aluno pelo controller', () async {
    final admin = controllerDe(aluno(uid: 'coordenacao', isAdmin: true));

    final resultado = await admin.deleteDocument(documentoDoDono());
    expect(resultado.isRight(), isTrue);

    expect((await storage.list(pastaDoDono)).map((a) => a.path),
        isNot(contains(caminhoRemoto)));
  }, skip: _pulado);

  test('DELETE FALSO: apagar o que nao existe vira erro na tela, nao sucesso',
      () async {
    final controller = controllerDe(aluno(uid: dono));
    final fantasma =
        documentoDoDono(caminho: '$pastaDoDono/arquivo-que-nunca-existiu.pdf');

    final resultado = await controller.deleteDocument(fantasma);

    expect(resultado.isLeft(), isTrue,
        reason: 'o remove() do Supabase responde 200 com lista vazia nesse '
            'caso; sem a checagem no service a tela mostraria sucesso');
    resultado.fold(
      (msg) => expect(msg, contains('Não foi possível apagar o documento')),
      (_) => fail('fingiu que apagou'),
    );
  }, skip: _pulado);

  test('RENOMEAR: o arquivo continua dentro da pasta do dono', () async {
    // Direto no service: o renameDocument do repositorio passa por
    // getTemporaryDirectory(), que e plugin nativo e nao existe no teste.
    const novoNome = 'renomeado-pelo-teste.pdf';
    await storage.rename(caminhoRemoto, novoNome);

    final caminhos = (await storage.list(pastaDoDono)).map((a) => a.path);
    expect(caminhos, contains('$pastaDoDono/$novoNome'));
    expect(caminhos, isNot(contains(caminhoRemoto)));

    await storage.delete('$pastaDoDono/$novoNome');
  }, skip: _pulado);
}
