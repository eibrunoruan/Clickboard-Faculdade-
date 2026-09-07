import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
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
  return ref
      .watch(documentControllerProvider.notifier)
      .getAllDocuments(isRefreshed: isRefreshed);
}

@Riverpod(keepAlive: true)
class DocumentController extends _$DocumentController {
  Reference _documentRef() => FirebaseStorage.instance.ref(
      '${ref.read(myUserProvider)?.dept ?? ''}/${ref.read(myUserProvider)?.session ?? ''}/${ref.read(myUserProvider)?.roll ?? ''}/Documents/');

  bool get _isAdmin => ref.read(myUserProvider)?.isAdmin ?? false;

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
    if (!isRefreshed && state.isNotEmpty) return;
    state = await DocumentRepository.getAllDocuments(_documentRef());
  }

  FutureEither<String> saveDocumentFile(Document document) async {
    final appDocDir = (await getTemporaryDirectory()).path;
    final filePath =
        '$appDocDir/${document.ref.name}'; // Path : /data/user/0/com.example.jgec_notice/cache/
    final file = File(filePath);
    try {
      await document.ref.writeToFile(file);
    } catch (e) {
      return left(e.toString());
    }
    return right(filePath);
  }

  FutureEither<String> downloadDocument(Document doc) async {
    String filePath = (await getDownloadPath())!;
    final file = File('$filePath/${doc.ref.name}');
    try {
      if (await Permission.manageExternalStorage.request().isGranted) {
        await doc.ref.writeToFile(file);
        return right(filePath);
      }
    } catch (e) {
      return left(e.toString());
    }
    return left('Permita o acesso aos arquivos para baixar o documento');
  }

  FutureVoid deleteDocument(Document document) async {
    if (!_isAdmin) return left('Somente a coordenação pode apagar documentos');

    try {
      await DocumentRepository.deleteDocument(document);
      await getAllDocuments(isRefreshed: true);
      return right(null);
    } catch (e) {
      return left('Não foi possível apagar o documento ${document.name}');
    }
  }

  FutureVoid renameDocument(Document document,
      {required String newName}) async {
    if (!_isAdmin) {
      return left('Somente a coordenação pode renomear documentos');
    }

    try {
      final safeName = _safeDocumentName(document, newName);
      if (safeName == null) {
        return left('Informe um nome de documento válido');
      }

      await DocumentRepository.renameDocument(document, safeName);
      await getAllDocuments(isRefreshed: true);
      return right(null);
    } catch (e) {
      return left('Não foi possível renomear o documento ${document.name}');
    }
  }

  FutureVoid uploadFiles() async {
    if (!_isAdmin) return left('Somente a coordenação pode enviar documentos');

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
        await DocumentRepository.uploadFile(_documentRef(), file);
      }
      await getAllDocuments(isRefreshed: true);
      return right(null);
    } catch (e) {
      return left('Não foi possível enviar o(s) documento(s)');
    }
  }
}
