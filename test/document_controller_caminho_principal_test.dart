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

import 'fakes/fake_storage_service.dart';

/// Caminho principal do mural exercitado de ponta a ponta sem rede.
///
/// Antes deste arquivo, os 29 testes do projeto cobriam funcoes puras e as
/// recusas — nenhum provava que enviar, apagar ou renomear **funciona**, nem
/// que a recusa de fato nao chega ao storage.
void main() {
  const dept = 'CATOLICASC';
  const raiz = '$dept/Documents';
  const dono = 'aluno-1';
  const outro = 'aluno-2';
  const pastaDoDono = '$raiz/$dono';
  const pastaDoOutro = '$raiz/$outro';

  Student aluno({required String uid, bool isAdmin = false}) => Student(
        name: 'Aluno $uid',
        roll: 'N/A',
        reg: '',
        email: '$uid@catolicasc.edu.br',
        dept: dept,
        session: 'N/A',
        isAdmin: isAdmin,
        uid: uid,
      );

  SupabaseStorageObject objeto(String pasta, String nome) =>
      SupabaseStorageObject(
        path: '$pasta/$nome',
        name: nome,
        timeCreated: DateTime(2026, 10, 27),
        contentType: 'application/pdf',
        size: 1024,
      );

  Document documento(String pasta, String nome, String ownerUid) => Document(
        file: objeto(pasta, nome),
        ownerUid: ownerUid,
      );

  /// Storage ja povoado: um arquivo do dono, um arquivo do outro aluno.
  FakeStorageService storagePovoado() => FakeStorageService(arquivos: {
        pastaDoDono: [objeto(pastaDoDono, 'prova.pdf')],
        pastaDoOutro: [objeto(pastaDoOutro, 'ata.pdf')],
      });

  ({DocumentController controller, FakeStorageService storage}) montar(
    Student? usuario, {
    FakeStorageService? storage,
  }) {
    final fake = storage ?? storagePovoado();
    final container = ProviderContainer(overrides: [
      documentRepositoryProvider
          .overrideWithValue(DocumentRepository(storageService: fake)),
    ]);
    addTearDown(container.dispose);
    container.read(myUserProvider.notifier).update(usuario);
    return (
      controller: container.read(documentControllerProvider.notifier),
      storage: fake,
    );
  }

  group('getAllDocuments', () {
    test('lista os dois arquivos com o dono vindo da subpasta', () async {
      final (controller: controller, storage: _) = montar(aluno(uid: dono));

      await controller.getAllDocuments(isRefreshed: true);

      expect(controller.state, hasLength(2));
      final meu = controller.state.singleWhere((d) => d.ownerUid == dono);
      expect(meu.file.path, '$pastaDoDono/prova.pdf');
      expect(meu.contentType, 'application/pdf');
      expect(meu.size, 1024);
      expect(controller.myDocumentCount, 1,
          reason: 'conta so os arquivos do proprio aluno');
    });

    test('sem perfil carregado a lista fica vazia e nao consulta o storage',
        () async {
      final (controller: controller, storage: storage) = montar(null);

      await controller.getAllDocuments(isRefreshed: true);

      expect(controller.state, isEmpty);
      expect(storage.chamadas, isEmpty,
          reason: 'sem dept nao existe raiz para consultar');
    });
  });

  group('deleteDocument', () {
    test('o dono apaga e o arquivo sai do bucket e da lista', () async {
      final (controller: controller, storage: storage) =
          montar(aluno(uid: dono));
      await controller.getAllDocuments(isRefreshed: true);

      final resultado =
          await controller.deleteDocument(documento(pastaDoDono, 'prova.pdf', dono));

      expect(resultado.isRight(), isTrue, reason: 'o dono precisa conseguir');
      expect(storage.chamadas, contains('delete($pastaDoDono/prova.pdf)'));
      expect(controller.state.map((d) => d.file.path),
          isNot(contains('$pastaDoDono/prova.pdf')),
          reason: 'o controller recarrega a lista sozinho');
    });

    test('a coordenacao apaga arquivo de qualquer aluno', () async {
      final (controller: controller, storage: storage) =
          montar(aluno(uid: 'coordenacao', isAdmin: true));

      final resultado =
          await controller.deleteDocument(documento(pastaDoOutro, 'ata.pdf', outro));

      expect(resultado.isRight(), isTrue);
      expect(storage.chamadas, contains('delete($pastaDoOutro/ata.pdf)'));
    });

    test('outro aluno leva recusa SEM nenhuma chamada ao storage', () async {
      final (controller: controller, storage: storage) =
          montar(aluno(uid: dono));

      final resultado =
          await controller.deleteDocument(documento(pastaDoOutro, 'ata.pdf', outro));

      expect(resultado.isLeft(), isTrue);
      expect(storage.chamadas, isEmpty,
          reason: 'a recusa precisa acontecer antes de tocar no storage, '
              'e agora isso e verificado em vez de presumido');
    });

    test('falha do storage vira mensagem de erro, nao sucesso silencioso',
        () async {
      final fake = storagePovoado();
      fake.falhas['delete'] = StateError('bucket fora do ar');
      final (controller: controller, storage: _) =
          montar(aluno(uid: dono), storage: fake);

      final resultado =
          await controller.deleteDocument(documento(pastaDoDono, 'prova.pdf', dono));

      expect(resultado.isLeft(), isTrue);
      resultado.fold(
        (msg) => expect(msg, 'Não foi possível apagar o documento prova.pdf'),
        (_) => fail('erro do storage nao pode virar sucesso'),
      );
    });
  });

  group('renameDocument', () {
    test('o dono renomeia e o arquivo continua na pasta dele', () async {
      final (controller: controller, storage: storage) =
          montar(aluno(uid: dono));

      final resultado = await controller.renameDocument(
        documento(pastaDoDono, 'prova.pdf', dono),
        newName: 'prova-final',
      );

      expect(resultado.isRight(), isTrue);
      expect(
        storage.chamadas,
        contains('rename($pastaDoDono/prova.pdf -> prova-final.pdf)'),
        reason: 'mantem a extensao original e nao sai da pasta do dono',
      );
    });

    test('outro aluno leva recusa SEM nenhuma chamada ao storage', () async {
      final (controller: controller, storage: storage) =
          montar(aluno(uid: dono));

      final resultado = await controller.renameDocument(
        documento(pastaDoOutro, 'ata.pdf', outro),
        newName: 'qualquer',
      );

      expect(resultado.isLeft(), isTrue);
      expect(storage.chamadas, isEmpty);
    });

    test('nome que escaparia da pasta e recusado antes do storage', () async {
      final (controller: controller, storage: storage) =
          montar(aluno(uid: dono));

      for (final invalido in ['', '   ', '../outro/aluno', r'pasta\arquivo']) {
        final resultado = await controller.renameDocument(
          documento(pastaDoDono, 'prova.pdf', dono),
          newName: invalido,
        );
        expect(resultado.isLeft(), isTrue, reason: 'nome: "$invalido"');
      }
      expect(storage.chamadas, isEmpty);
    });
  });

  group('uploadFile pelo repositorio', () {
    test('o arquivo cai dentro da pasta do dono', () async {
      final fake = storagePovoado();
      final repositorio = DocumentRepository(storageService: fake);

      await repositorio.uploadFile(pastaDoDono, _ArquivoFalso('trabalho.pdf'));

      expect(fake.chamadas,
          contains('uploadPlatformFile($pastaDoDono/trabalho.pdf)'));
      expect((await fake.list(pastaDoDono)).map((a) => a.name),
          contains('trabalho.pdf'));
    });
  });
}

/// `PlatformFile` minimo: o upload so precisa do nome, porque o fake nao le
/// bytes. O seletor de arquivos em si (`FilePicker.pickFiles`, estatico) segue
/// sem cobertura — esta anotado no PR.
base class _ArquivoFalso extends PlatformFile {
  _ArquivoFalso(this._nome);

  final String _nome;

  @override
  String get name => _nome;

  @override
  Uri get uri => Uri.file('/tmp/$_nome');

  // Sem anotacao de tipo de proposito: o tipo vem da superclasse e evita
  // depender do pacote cross_file so por causa desta linha.
  @override
  get xFile => throw UnsupportedError('nao usado neste teste');

  @override
  Future<int> length() async => _conteudo.length;

  @override
  Future<Uint8List> readAsBytes() async => _conteudo;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_conteudo);

  static final Uint8List _conteudo =
      Uint8List.fromList('documento de teste'.codeUnits);
}
