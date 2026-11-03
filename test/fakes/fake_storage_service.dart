import 'dart:io';
import 'dart:typed_data';

import 'package:clickboard/src/providers/storage_paths.dart';
import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:file_picker/file_picker.dart';

/// Storage de mentira que **registra cada chamada** em [chamadas].
///
/// O log e o ponto central: sem ele, um teste de recusa apenas confia que o
/// codigo retornou antes de tocar na rede. Com ele, da para afirmar
/// `expect(fake.chamadas, isEmpty)` e provar.
///
/// Escrito a mao de proposito, sem mocktail: a lista de chamadas e mais
/// legivel para quem revisa que um `verifyNever`, e o projeto nao ganha
/// dependencia nova por causa de teste.
class FakeStorageService implements StorageService {
  FakeStorageService({Map<String, List<SupabaseStorageObject>>? arquivos})
      : _arquivos = arquivos ?? {};

  /// Pastas e seus arquivos, como se estivessem no bucket.
  final Map<String, List<SupabaseStorageObject>> _arquivos;

  /// Toda chamada que chegou, na ordem, no formato `metodo(argumentos)`.
  final List<String> chamadas = [];

  /// Quando preenchido, a proxima chamada a este metodo lanca.
  final Map<String, Object> falhas = {};

  void _registrar(String chamada) {
    chamadas.add(chamada);
    final metodo = chamada.split('(').first;
    final falha = falhas[metodo];
    if (falha != null) throw falha;
  }

  @override
  Future<List<SupabaseStorageObject>> list(String folder) async {
    final pasta = StoragePaths.normalizeFolder(folder);
    _registrar('list($pasta)');
    return List.of(_arquivos[pasta] ?? const []);
  }

  @override
  Future<List<String>> listFolders(String folder) async {
    final raiz = StoragePaths.normalizeFolder(folder);
    _registrar('listFolders($raiz)');
    return _arquivos.keys
        .where((pasta) => pasta.startsWith('$raiz/'))
        .map((pasta) => pasta.substring(raiz.length + 1).split('/').first)
        .toSet()
        .toList();
  }

  @override
  Future<String> signedUrl(String path) async {
    _registrar('signedUrl($path)');
    return 'https://exemplo.invalido/$path';
  }

  @override
  Future<Uint8List> download(String path) async {
    _registrar('download($path)');
    return Uint8List.fromList('conteudo de $path'.codeUnits);
  }

  @override
  Future<void> uploadPlatformFile(String folder, PlatformFile file) async {
    final destino = StoragePaths.childPath(folder, file.name);
    _registrar('uploadPlatformFile($destino)');
    _inserir(folder, file.name);
  }

  @override
  Future<String> uploadFile(String folder, String fileName, File file) async {
    _registrar('uploadFile(${StoragePaths.childPath(folder, fileName)})');
    _inserir(folder, fileName);
    return 'https://exemplo.invalido/$folder/$fileName';
  }

  @override
  Future<String> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    _registrar('uploadBytes(${StoragePaths.childPath(folder, fileName)})');
    _inserir(folder, fileName, contentType: contentType, size: bytes.length);
    return 'https://exemplo.invalido/$folder/$fileName';
  }

  @override
  Future<void> delete(String path) async {
    _registrar('delete($path)');
    final pasta = StoragePaths.parentFolder(path);
    _arquivos[pasta]?.removeWhere((arquivo) => arquivo.path == path);
  }

  @override
  Future<void> rename(String currentPath, String newName) async {
    _registrar('rename($currentPath -> $newName)');
    final pasta = StoragePaths.parentFolder(currentPath);
    _arquivos[pasta]?.removeWhere((arquivo) => arquivo.path == currentPath);
    _inserir(pasta, newName);
  }

  void _inserir(String folder, String fileName,
      {String? contentType, int? size}) {
    final pasta = StoragePaths.normalizeFolder(folder);
    _arquivos.putIfAbsent(pasta, () => []).add(SupabaseStorageObject(
          path: StoragePaths.childPath(pasta, fileName),
          name: fileName,
          timeCreated: DateTime(2026, 10, 27),
          contentType: contentType,
          size: size,
        ));
  }
}
