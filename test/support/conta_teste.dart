import 'dart:convert';
import 'dart:io';

import 'package:clickboard/firebase_options.dart';
import 'package:clickboard/src/providers/supabase_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conta real do Firebase usada nos testes de integracao.
class ContaTeste {
  ContaTeste(this.uid, this.token);

  final String uid;
  final String token;

  SupabaseClient get cliente => SupabaseClient(
        supabaseUrl,
        supabasePublishableKey,
        accessToken: () async => token,
      );
}

String? _env(String nome) {
  final valor = Platform.environment[nome];
  // secret que nao existe chega vazio no CI
  return (valor == null || valor.isEmpty) ? null : valor;
}

/// Le <PREFIXO>_EMAIL e <PREFIXO>_SENHA do ambiente (ex: ALUNO_A_EMAIL).
bool temConta(String prefixo) =>
    _env('${prefixo}_EMAIL') != null && _env('${prefixo}_SENHA') != null;

Future<ContaTeste> entrar(String prefixo) async {
  final email = _env('${prefixo}_EMAIL');
  final senha = _env('${prefixo}_SENHA');
  if (email == null || senha == null) {
    throw StateError('Faltou ${prefixo}_EMAIL / ${prefixo}_SENHA no ambiente');
  }

  final http = HttpClient();
  try {
    final req = await http.postUrl(Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
        '?key=${DefaultFirebaseOptions.web.apiKey}'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(
        {'email': email, 'password': senha, 'returnSecureToken': true}));
    final res = await req.close();
    final corpo = jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw StateError('Login de $prefixo falhou: ${corpo['error']}');
    }
    return ContaTeste(corpo['localId'] as String, corpo['idToken'] as String);
  } finally {
    http.close();
  }
}
