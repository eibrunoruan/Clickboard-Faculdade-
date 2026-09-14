import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Cliente offline: nenhum teste aqui faz chamada de rede, so exercita os
  // helpers de caminho que decidem em qual pasta o arquivo cai.
  final service = SupabaseStorageService(
    client: SupabaseClient('https://exemplo.supabase.co', 'chave-de-teste'),
  );

  test('childPath monta o caminho dentro da pasta do dono', () {
    expect(
      service.childPath('CATOLICASC/Documents/aluno-1', 'prova.pdf'),
      'CATOLICASC/Documents/aluno-1/prova.pdf',
    );
  });

  test('normalizeFolder remove barras e segmentos vazios', () {
    expect(service.normalizeFolder('/CATOLICASC//Documents/'),
        'CATOLICASC/Documents');
    expect(service.normalizeFolder('   '), '');
  });

  test('parentFolder devolve a pasta do dono', () {
    expect(
      service.parentFolder('CATOLICASC/Documents/aluno-1/prova.pdf'),
      'CATOLICASC/Documents/aluno-1',
    );
    expect(service.parentFolder('prova.pdf'), '');
  });

  test('rename mantem o arquivo na pasta de origem', () {
    const atual = 'CATOLICASC/Documents/aluno-1/prova.pdf';
    expect(
      service.childPath(service.parentFolder(atual), 'prova-final.pdf'),
      'CATOLICASC/Documents/aluno-1/prova-final.pdf',
    );
  });
}
