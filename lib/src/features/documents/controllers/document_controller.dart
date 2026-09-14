import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/utils/utils.dart';
import '../../../models/document_model.dart';
import '../../../providers/type_defs.dart';
import '../../../providers/utils_providers.dart';
import '../repository/document_repository.dart';

part 'document_controller.g.dart';

@riverpod
Future<void> documentFuture(DocumentFutureRef ref, {bool isRefreshed = false}) {
  // Depende do perfil do aluno: e ele que define a raiz do mural. Sem este
  // watch, a busca rodava antes do login terminar e o resultado vazio ficava
  // em cache.
  ref.watch(myUserProvider);
  return ref
      .watch(documentControllerProvider.notifier)
      .getAllDocuments(isRefreshed: isRefreshed);
}

@Riverpod(keepAlive: true)
class DocumentController extends _$DocumentController {
  /// Raiz compartilhada do mural. Abaixo dela existe uma subpasta por uid, e e
  /// esse segmento que define o dono de cada arquivo.
  ///
  /// Devolve null enquanto o perfil do aluno nao chegou do Firestore. Antes
  /// caia para `'/Documents'`, o app listava uma pasta inexistente e o mural
  /// ficava vazio ate alguem puxar para atualizar.
  String? _documentsRoot() {
    final dept = ref.read(myUserProvider)?.dept;
    if (dept == null || dept.isEmpty) return null;
    return '$dept/Documents';
  }

  String? get _myUid => ref.read(myUserProvider)?.uid;

  String? _myDocumentFolder() {
    final uid = _myUid;
    final root = _documentsRoot();
    if (uid == null || uid.isEmpty || root == null) return null;
    return '$root/$uid';
  }

  bool get _isAdmin => ref.read(myUserProvider)?.isAdmin ?? false;

  DocumentRepository get _repository => ref.read(documentRepositoryProvider);

  /// O dono gerencia o proprio documento; o admin gerencia o de qualquer um.
  bool canManage(Document document) {
    if (_isAdmin) return true;
    final uid = _myUid;
    return uid != null && uid.isNotEmpty && document.ownerUid == uid;
  }

  int get myDocumentCount =>
      state.where((document) => document.ownerUid == _myUid).length;

  String? _safeDocumentName(Document document, String newName) {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty ||
        trimmedName.length > 120 ||
        trimmedName.contains('/') ||
        trimmedName.contains('\\')) {
      return null;
    }

    if (trimmedName.contains('.')) return trimmedName;

    final originalExtension = document.name.split('.').last;
    return '$trimmedName.$originalExtension';
  }

  @override
  List<Document> build() {
    return [];
  }

  Future<void> getAllDocuments({bool isRefreshed = false}) async {
    final root = _documentsRoot();
    if (root == null) {
      state = [];
      return;
    }
    if (!isRefreshed && state.isNotEmpty) return;
    state = await _repository.getAllDocuments(root);
  }

  FutureEither<String> saveDocumentFile(Document document) async {
    final appDocDir = (await getTemporaryDirectory()).path;
    final filePath =
        '$appDocDir/${document.name}'; // Path : /data/user/0/com.example.jgec_notice/cache/
    final file = File(filePath);
    try {
      await _repository.writeToFile(document, file);
    } catch (e) {
      return left(e.toString());
    }
    return right(filePath);
  }

  FutureEither<String> downloadDocument(Document doc) async {
    String filePath = (await getDownloadPath())!;
    final file = File('$filePath/${doc.name}');
    try {
      if (await Permission.manageExternalStorage.request().isGranted) {
        await _repository.writeToFile(doc, file);
        return right(filePath);
      }
    } catch (e) {
      return left(e.toString());
    }
    return left('Permita o acesso aos arquivos para baixar o documento');
  }

  FutureVoid deleteDocument(Document document) async {
    if (!canManage(document)) {
      return left('Você só pode apagar documentos que você enviou');
    }

    try {
      await _repository.deleteDocument(document);
      await getAllDocuments(isRefreshed: true);
      return right(null);
    } catch (e) {
      return left('Não foi possível apagar o documento ${document.name}');
    }
  }

  FutureVoid renameDocument(Document document,
      {required String newName}) async {
    if (!canManage(document)) {
      return left('Você só pode renomear documentos que você enviou');
    }

    try {
      final safeName = _safeDocumentName(document, newName);
      if (safeName == null) {
        return left('Informe um nome de documento válido');
      }

      await _repository.renameDocument(document, safeName);
      await getAllDocuments(isRefreshed: true);
      return right(null);
    } catch (e) {
      return left('Não foi possível renomear o documento ${document.name}');
    }
  }

  FutureVoid uploadFiles() async {
    final folder = _myDocumentFolder();
    if (folder == null) return left('Faça login para enviar documentos');

    String? message;
    List<PlatformFile> result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['jpg', 'pdf', 'doc', 'docx', 'png'],
    );
    if (result.isEmpty) return right(null);
    final files = <PlatformFile>[];
    for (final file in result) {
      if (await file.length() > 2048 * 1024) {
        message = 'O tamanho máximo do arquivo é 2 MB';
        continue;
      }
      files.add(file);
    }
    if (files.isEmpty) return left(message ?? '');

    try {
      for (var file in files) {
        await _repository.uploadFile(folder, file);
      }
      await getAllDocuments(isRefreshed: true);
      return right(null);
    } catch (e) {
      return left('Não foi possível enviar o(s) documento(s)');
    }
  }
}
