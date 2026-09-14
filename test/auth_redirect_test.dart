import 'package:clickboard/src/core/utils/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

String? _redirect({
  bool useFirebase = true,
  bool isSignedIn = true,
  bool isEmailVerified = true,
  required String location,
}) =>
    resolveRedirect(
      useFirebase: useFirebase,
      isSignedIn: isSignedIn,
      isEmailVerified: isEmailVerified,
      location: location,
    );

void main() {
  group('deslogado', () {
    test('qualquer tela do app manda para o login', () {
      expect(_redirect(isSignedIn: false, location: '/'), loginLocation);
      expect(_redirect(isSignedIn: false, location: '/app/documents'),
          loginLocation);
      expect(_redirect(isSignedIn: false, location: verifyEmailLocation),
          loginLocation);
    });

    test('telas de autenticacao ficam acessiveis', () {
      expect(_redirect(isSignedIn: false, location: '/auth/login'), isNull);
      expect(_redirect(isSignedIn: false, location: '/auth/signup'), isNull);
      expect(
          _redirect(isSignedIn: false, location: '/auth/forgot-password'), isNull);
    });
  });

  group('logado com e-mail nao verificado', () {
    test('o app inteiro cai na tela de verificacao', () {
      expect(_redirect(isEmailVerified: false, location: '/'),
          verifyEmailLocation);
      expect(_redirect(isEmailVerified: false, location: '/app/documents'),
          verifyEmailLocation);
      expect(_redirect(isEmailVerified: false, location: '/app/my-account'),
          verifyEmailLocation);
    });

    test('nem volta para o login por conta propria', () {
      expect(_redirect(isEmailVerified: false, location: '/auth/login'),
          verifyEmailLocation);
    });

    test('a propria tela de verificacao e acessivel (sem loop de redirect)', () {
      expect(_redirect(isEmailVerified: false, location: verifyEmailLocation),
          isNull);
    });
  });

  group('logado e verificado', () {
    test('usa o app normalmente', () {
      expect(_redirect(location: '/'), isNull);
      expect(_redirect(location: '/app/documents'), isNull);
    });

    test('nao fica preso na tela de verificacao', () {
      expect(_redirect(location: verifyEmailLocation), homeLocation);
    });

    test('nao volta para o login', () {
      expect(_redirect(location: '/auth/login'), homeLocation);
      expect(_redirect(location: '/auth/signup'), homeLocation);
    });
  });

  group('modo simulador (USE_FIREBASE=false)', () {
    test('tudo cai no login e a verificacao nao entra no caminho', () {
      expect(_redirect(useFirebase: false, location: '/'), loginLocation);
      expect(_redirect(useFirebase: false, location: '/app/documents'),
          loginLocation);
      expect(_redirect(useFirebase: false, location: '/auth/login'), isNull);
    });
  });

  group('estabilidade do redirect', () {
    test('todo destino devolvido e um ponto final, nunca redireciona de novo',
        () {
      const estados = [
        (signed: false, verified: false),
        (signed: true, verified: false),
        (signed: true, verified: true),
      ];
      const locais = [
        '/',
        '/app/documents',
        '/app/my-account',
        '/auth/login',
        '/auth/signup',
        verifyEmailLocation,
      ];

      for (final estado in estados) {
        for (final local in locais) {
          final destino = _redirect(
            isSignedIn: estado.signed,
            isEmailVerified: estado.verified,
            location: local,
          );
          if (destino == null) continue;
          expect(
            _redirect(
              isSignedIn: estado.signed,
              isEmailVerified: estado.verified,
              location: destino,
            ),
            isNull,
            reason: 'de "$local" foi para "$destino" e seria redirecionado '
                'de novo (loop) com signed=${estado.signed} '
                'verified=${estado.verified}',
          );
        }
      }
    });
  });
}
