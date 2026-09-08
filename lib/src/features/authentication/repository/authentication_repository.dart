import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../../models/student_model.dart';
import '../../../providers/type_defs.dart';
import 'exceptions/signup_email_password_failure.dart';

class AuthenticationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AuthenticationRepository()
      : _auth = FirebaseAuth.instance,
        _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);

  Stream<User?> get authStateChange => _auth.authStateChanges();

  Stream<Student> getUserData(String uid) {
    return _users
        .doc(uid)
        .snapshots()
        .map((event) => Student.fromSnapshot(event));
  }

  FutureEither<Student> _getExistingStudent(String uid) async {
    final snapshot = await _users.doc(uid).get();
    if (!snapshot.exists) {
      return left(
          'Login autenticado, mas o perfil do aluno não existe no Firestore.');
    }
    return right(Student.fromSnapshot(snapshot));
  }

  String _firestoreProfileFailureMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Login autenticado, mas o Firestore negou acesso ao perfil do aluno. Verifique as regras ou habilite o Cloud Firestore no Firebase.';
      case 'unavailable':
        return 'Login autenticado, mas o Cloud Firestore está indisponível ou desativado no projeto Firebase.';
      case 'not-found':
        return 'Login autenticado, mas o banco ou perfil do aluno não foi encontrado no Firestore.';
      default:
        return 'Login autenticado, mas não foi possível carregar o perfil do aluno no Firestore: ${e.message ?? e.code}';
    }
  }

  FutureEither<Student> createUserWithEmailAndPassword(Student student) async {
    UserCredential userCredential;
    try {
      if (!Student.isCollegeEmail(student.email)) {
        return left('Use um e-mail institucional @catolicasc.edu.br');
      }

      userCredential = await _auth.createUserWithEmailAndPassword(
          email: student.email, password: student.pass!);
      student.uid = userCredential.user!.uid;
      await _users.doc(student.uid).set(student.toJSON());
      return right(student);
    } on FirebaseAuthException catch (e) {
      final ex = SignupWithEmailAndPasswordFailure.code(e.code);
      return left(ex.message);
    } catch (e) {
      return left(e.toString());
    }
  }

  FutureEither<Student> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
      AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      User user = userCredential.user!;
      if (!Student.isCollegeEmail(user.email ?? '')) {
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          await user.delete();
        }
        await GoogleSignIn().signOut();
        await _auth.signOut();
        return left('Use um e-mail institucional @catolicasc.edu.br');
      }

      Student student;
      if (userCredential.additionalUserInfo?.isNewUser ?? true) {
        student = Student.fromEmail(
            name: user.displayName ?? '',
            email: user.email!,
            pass: 'temporary-pass@123',
            reg: '',
            uid: user.uid);
        await _users.doc(student.uid).set(student.toJSON());
      } else {
        final existingStudent = await _getExistingStudent(user.uid);
        return existingStudent;
      }
      return right(student);
    } on FirebaseAuthException catch (e) {
      final ex = SignupWithEmailAndPasswordFailure.code(e.code);
      return left(ex.message);
    } on FirebaseException catch (e) {
      return left(_firestoreProfileFailureMessage(e));
    } catch (e) {
      return left('Cancelado');
    }
  }

  FutureEither<Student> loginUserWithEmailAndPassword(email, password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final existingStudent =
          await _getExistingStudent(userCredential.user!.uid);
      return existingStudent;
    } on FirebaseAuthException catch (e) {
      final ex = SignupWithEmailAndPasswordFailure.code(e.code);
      return left(ex.message);
    } on FirebaseException catch (e) {
      return left(_firestoreProfileFailureMessage(e));
    } catch (e) {
      return left('Não foi possível carregar o perfil do aluno: $e');
    }
  }

  FutureVoid forgotPassord(String email) async {
    try {
      return right(await _auth.sendPasswordResetEmail(email: email.trim()));
    } catch (e) {
      return left(e.toString());
    }
  }

  FutureVoid verifyEmail(String email) async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return right(null);
    } catch (e) {
      return left(e.toString());
    }
  }

  FutureVoid reAuth(String email, String password) async {
    try {
      await _auth.currentUser?.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password));
      return right(null);
    } catch (e) {
      return left(e.toString());
    }
  }

  Future<void> logOut() async {
    if (_auth.currentUser?.providerData[0].providerId == 'google.com') {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
  }

  Future<void> delete() async =>
      await FirebaseAuth.instance.currentUser!.delete();
}
