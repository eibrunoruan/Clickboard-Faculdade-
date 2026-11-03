import 'package:firebase_auth/firebase_auth.dart';

// token que o Supabase usa nas politicas de RLS pra saber quem e o usuario
Future<String?> tokenDoUsuario(FirebaseAuth auth) async =>
    auth.currentUser?.getIdToken();
