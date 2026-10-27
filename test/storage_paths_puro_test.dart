import 'package:clickboard/src/providers/storage_paths.dart';
import 'package:flutter_test/flutter_test.dart';

/// Os mesmos casos de `storage_paths_test.dart`, agora sem instanciar
/// `SupabaseClient` nenhum: e esse o ganho da extracao. Cobre tambem as bordas
/// que o teste antigo nao alcancava.
void main() {
  group('normalizeFolder', () {
    test('remove barras das pontas e duplicadas', () {
      expect(StoragePaths.normalizeFolder('/CATOLICASC//Documents/'),
          'CATOLICASC/Documents');
    });

    test('descarta segmentos so com espaco', () {
      expect(StoragePaths.normalizeFolder('   '), '');
      expect(StoragePaths.normalizeFolder('a/  /b'), 'a/b');
    });

    test('pasta vazia continua vazia', () {
      expect(StoragePaths.normalizeFolder(''), '');
      expect(StoragePaths.normalizeFolder('///'), '');
    });
  });

  group('childPath', () {
    test('monta o caminho dentro da pasta do dono', () {
      expect(
        StoragePaths.childPath('CATOLICASC/Documents/aluno-1', 'prova.pdf'),
        'CATOLICASC/Documents/aluno-1/prova.pdf',
      );
    });

    test('normaliza a pasta antes de concatenar', () {
      expect(
        StoragePaths.childPath('/CATOLICASC//Documents/', 'prova.pdf'),
        'CATOLICASC/Documents/prova.pdf',
      );
    });

    test('sem pasta devolve so o nome do arquivo', () {
      expect(StoragePaths.childPath('', 'prova.pdf'), 'prova.pdf');
      expect(StoragePaths.childPath('   ', 'prova.pdf'), 'prova.pdf');
    });
  });

  group('parentFolder', () {
    test('devolve a pasta do dono', () {
      expect(
        StoragePaths.parentFolder('CATOLICASC/Documents/aluno-1/prova.pdf'),
        'CATOLICASC/Documents/aluno-1',
      );
    });

    test('caminho sem pasta devolve vazio', () {
      expect(StoragePaths.parentFolder('prova.pdf'), '');
    });
  });

  test('renomear mantem o arquivo na pasta de origem', () {
    const atual = 'CATOLICASC/Documents/aluno-1/prova.pdf';
    expect(
      StoragePaths.childPath(
          StoragePaths.parentFolder(atual), 'prova-final.pdf'),
      'CATOLICASC/Documents/aluno-1/prova-final.pdf',
    );
  });
}
