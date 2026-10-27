/// Matematica de caminho dentro do bucket: decide em que pasta cada arquivo
/// cai e de qual pasta ele veio.
///
/// Vivia dentro de `SupabaseStorageService`, misturada com as chamadas de rede.
/// Sao tres funcoes puras, sem I/O: separadas, dao para exercitar sem cliente
/// nenhum. `test/storage_paths_test.dart` ja testava exatamente isto, mas
/// pagava o preco de montar um `SupabaseClient` de mentira so para alcancar
/// os metodos.
class StoragePaths {
  const StoragePaths._();

  /// Remove barras das pontas, barras duplicadas e segmentos so com espaco.
  static String normalizeFolder(String folder) => folder
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .join('/');

  /// Caminho de [fileName] dentro de [folder], com a pasta normalizada.
  /// Quando [folder] fica vazia, devolve apenas o nome do arquivo.
  static String childPath(String folder, String fileName) {
    final cleanFolder = normalizeFolder(folder);
    return cleanFolder.isEmpty ? fileName : '$cleanFolder/$fileName';
  }

  /// Pasta que contem [path]. String vazia quando [path] nao tem pasta.
  static String parentFolder(String path) {
    final index = path.lastIndexOf('/');
    return index == -1 ? '' : path.substring(0, index);
  }
}
