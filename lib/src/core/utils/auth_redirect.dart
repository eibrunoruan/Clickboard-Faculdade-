/// Rotas que o redirect do GoRouter usa como destino.
const String loginLocation = '/auth/login';
const String verifyEmailLocation = '/app/verify-email';
const String homeLocation = '/';

/// Decide para onde mandar o usuario a cada navegacao.
///
/// Fica separada do [GoRouter] de proposito: sem importar o Firebase aqui, a
/// regra pode ser testada sem subir o app. Devolver `null` significa "pode
/// seguir para onde pediu".
String? resolveRedirect({
  required bool useFirebase,
  required bool isSignedIn,
  required bool isEmailVerified,
  required String location,
}) {
  final isAuthRoute = location.startsWith('/auth');
  final isVerifyRoute = location.startsWith(verifyEmailLocation);

  // Modo simulador: nao ha autenticacao, tudo cai no login.
  if (!useFirebase) return isAuthRoute ? null : loginLocation;

  if (!isSignedIn) return isAuthRoute ? null : loginLocation;

  // Logado, mas sem confirmar o e-mail: a unica tela liberada e a de
  // verificacao, que reenvia o e-mail e libera sozinha quando o usuario
  // confirma. Quem entra pelo Google ja chega verificado e nem passa por aqui.
  if (!isEmailVerified) return isVerifyRoute ? null : verifyEmailLocation;

  // Verificado: login e tela de verificacao nao fazem mais sentido.
  if (isAuthRoute || isVerifyRoute) return homeLocation;

  return null;
}
