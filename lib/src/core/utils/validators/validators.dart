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
  return "Please enter a valid registration number";
}

String? nameValidate(String? value) {
  if (value == '') return 'Cannot be empty!';
  return null;
}

String? emailValidate(String? value) {
  if (value == '') return 'Cannot be empty!';
  if (RegExp(r'^[a-zA-Z]{2}\d{4}@(cse|ece|it|ee|ce|me)\.jgec\.ac\.in$')
      .hasMatch((value ?? '').trim().toLowerCase())) {
    return null;
  }
  return 'Invalid email';
}

String? passValidate(String? value) {
  if (value == '') return 'Cannot be empty!';
  if ((value?.length ?? 0) < 6) {
    return 'Password length must be atleast 6';
  }
  return null;
}
