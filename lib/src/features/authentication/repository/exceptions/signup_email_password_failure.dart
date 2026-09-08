class SignupWithEmailAndPasswordFailure {
  final String message;
  const SignupWithEmailAndPasswordFailure(
      [this.message = "Não foi possível autenticar. Tente novamente."]);

  factory SignupWithEmailAndPasswordFailure.code(String code) {
    switch (code) {
      case 'weak-password':
        return const SignupWithEmailAndPasswordFailure(
            "A senha informada é fraca. Use pelo menos 6 caracteres.");
      case 'invalid-email':
        return const SignupWithEmailAndPasswordFailure(
            "O formato do e-mail é inválido.");
      case 'wrong-password':
        return const SignupWithEmailAndPasswordFailure(
            "A senha informada está incorreta.");
      case 'user-not-found':
        return const SignupWithEmailAndPasswordFailure(
            "Não existe usuário cadastrado com esse e-mail.");
      case 'invalid-credential':
        return const SignupWithEmailAndPasswordFailure(
            "As credenciais informadas são inválidas ou expiraram.");
      case 'email-already-in-use':
        return const SignupWithEmailAndPasswordFailure(
            "Já existe uma conta com esse e-mail.");
      case 'operation-not-allowed':
        return const SignupWithEmailAndPasswordFailure(
            "Login por e-mail e senha não está habilitado no Firebase Authentication.");
      case 'configuration-not-found':
        return const SignupWithEmailAndPasswordFailure(
            "Firebase Authentication ainda não foi configurado para este projeto.");
      case 'network-request-failed':
        return const SignupWithEmailAndPasswordFailure(
            "Falha de conexão com o Firebase. Verifique a internet e tente novamente.");
      case 'user-disabled':
        return const SignupWithEmailAndPasswordFailure(
            "Este usuário foi desativado. Entre em contato com o suporte.");
      case 'too-many-requests':
        return const SignupWithEmailAndPasswordFailure(
            "Muitas tentativas. Aguarde um momento.");
      default:
        return const SignupWithEmailAndPasswordFailure();
    }
  }
}
