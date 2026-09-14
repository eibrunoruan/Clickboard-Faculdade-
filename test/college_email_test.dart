import 'package:clickboard/src/core/utils/validators/validators.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Student.isCollegeEmail', () {
    test('aceita e-mail institucional', () {
      expect(Student.isCollegeEmail('aluno@catolicasc.edu.br'), isTrue);
      expect(Student.isCollegeEmail('bruno.ruan@catolicasc.edu.br'), isTrue);
      expect(Student.isCollegeEmail('ALUNO@CATOLICASC.EDU.BR'), isTrue);
      expect(Student.isCollegeEmail('  aluno@catolicasc.edu.br  '), isTrue);
    });

    test('recusa outros dominios', () {
      expect(Student.isCollegeEmail('aluno@gmail.com'), isFalse);
      expect(Student.isCollegeEmail('aluno@catolicasc.edu.br.evil.com'), isFalse);
      expect(Student.isCollegeEmail('aluno@sub.catolicasc.edu.br'), isFalse);
      expect(Student.isCollegeEmail('catolicasc.edu.br'), isFalse);
      expect(Student.isCollegeEmail(''), isFalse);
    });
  });

  group('emailValidate (formulario)', () {
    test('deixa passar o dominio da faculdade', () {
      expect(emailValidate('aluno@catolicasc.edu.br'), isNull);
    });

    test('bloqueia dominio de fora', () {
      expect(emailValidate('aluno@gmail.com'), 'Use um e-mail @catolicasc.edu.br');
    });

    test('campo vazio e obrigatorio', () {
      expect(emailValidate(''), 'Campo obrigatório');
    });
  });

  group('Student.fromEmail', () {
    test('nunca cria admin pelo cadastro', () {
      final student = Student.fromEmail(
        name: 'Aluno',
        email: 'aluno@catolicasc.edu.br',
        pass: '123456',
        reg: '',
        uid: 'uid-1',
      );
      expect(student.isAdmin, isFalse);
      expect(student.dept, 'CATOLICASC');
      expect(student.toJSON()['isAdmin'], false);
    });

    test('e-mail de fora cai em dept Others', () {
      final student = Student.fromEmail(
        name: 'Estranho',
        email: 'x@gmail.com',
        pass: '123456',
        reg: '',
        uid: 'uid-2',
      );
      expect(student.dept, 'Others');
    });
  });
}
