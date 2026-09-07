class SignupWithEmailAndPasswordFailure {
  final String message;
  const SignupWithEmailAndPasswordFailure([this.message = "Ocorreu um erro"]);

  factory SignupWithEmailAndPasswordFailure.code(String code) {
    switch (code) {
      case 'weak-password':
        return const SignupWithEmailAndPasswordFailure(
            "Informe uma senha mais forte.");
      case 'invalid-email':
        return const SignupWithEmailAndPasswordFailure(
            "O e-mail é inválido ou está mal formatado.");
      case 'wrong-password' || 'user-not-found':
        return const SignupWithEmailAndPasswordFailure(
            "E-mail ou senha inválidos.");
      case 'email-already-in-use':
        return const SignupWithEmailAndPasswordFailure(
            "Já existe uma conta com esse e-mail.");
      case 'operation-not-allowed':
        return const SignupWithEmailAndPasswordFailure(
            "Operação não permitida. Entre em contato com o suporte.");
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
