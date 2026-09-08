// String? rollValidate(String? value) {
//   if (RegExp(r'(^\d{2}10110[1-6]0(((0[1-9])|([1-6][0-9]))|[89][0-9])$)')
//       .hasMatch(value ?? '')) {
//     return null;
//   }
//   if (value == '') return 'Cannot be empty!';
//   return "Please enter a valid roll number";
// }

String? regValidate(String? value) {
  if (RegExp(r'(^\d{2}10101(\d{6}|\d{8})$)').hasMatch(value ?? '')) {
    return null;
  }
  if (value == '') return null;
  return "Informe um número de matrícula válido";
}

String? nameValidate(String? value) {
  if (value == '') return 'Campo obrigatório';
  return null;
}

String? emailValidate(String? value) {
  if (value == '') return 'Campo obrigatório';
  if (RegExp(r'^[a-zA-Z0-9._%+-]+@catolicasc\.edu\.br$')
      .hasMatch((value ?? '').trim().toLowerCase())) {
    return null;
  }
  return 'Use um e-mail @catolicasc.edu.br';
}

String? passValidate(String? value) {
  if (value == '') return 'Campo obrigatório';
  if ((value?.length ?? 0) < 6) {
    return 'A senha deve ter pelo menos 6 caracteres';
  }
  return null;
}
