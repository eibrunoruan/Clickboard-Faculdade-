import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  String name, roll, reg, email, uid, session, dept;
  bool isAdmin;
  String? pass;

  Student(
      {required this.name,
      required this.roll,
      required this.reg,
      required this.email,
      this.pass,
      required this.dept,
      required this.session,
      this.isAdmin = false,
      required this.uid});

  static String buildRollFromEmailAndDept(String email, String dept) {
    email = email.trim().toLowerCase();
    if (!isCollegeEmail(email)) return 'N/A';
    return 'N/A';
  }

  static String buildDeptFromEmail(String email) {
    email = email.trim().toLowerCase();
    if (!isCollegeEmail(email)) return 'Others';
    return 'CATOLICASC';
  }

  static String buildFullSessionFromEmail(String email) {
    email = email.trim().toLowerCase();
    if (!isCollegeEmail(email)) return 'N/A';
    return 'N/A';
  }

  static bool isCollegeEmail(String email) =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@catolicasc\.edu\.br$')
          .hasMatch(email.trim().toLowerCase());

  Map<String, dynamic> toJSON() {
    return {
      "Full Name": name,
      "Email": email,
      "Roll Number": roll,
      "Registration Number": reg,
      "uid": uid,
      "Department": dept,
      "session": session,
      "isAdmin": isAdmin
    };
  }

  factory Student.fromEmail(
      {required String name,
      required String email,
      required String pass,
      required String reg,
      required String uid}) {
    String dept = buildDeptFromEmail(email);
    String session = buildFullSessionFromEmail(email);
    String roll = buildRollFromEmailAndDept(email, dept);
    return Student(
        name: name,
        roll: roll,
        reg: reg,
        email: email,
        dept: dept,
        session: session,
        isAdmin: false,
        pass: pass,
        uid: uid);
  }
  factory Student.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};
    final email = data['Email']?.toString() ?? '';
    final dept = data["Department"]?.toString() ?? buildDeptFromEmail(email);
    final session =
        data["session"]?.toString() ?? buildFullSessionFromEmail(email);
    final roll = data['Roll Number']?.toString() ??
        buildRollFromEmailAndDept(email, dept);

    return Student(
        name: data['Full Name']?.toString() ?? '',
        roll: roll,
        reg: data['Registration Number']?.toString() ?? '',
        email: email,
        uid: data["uid"]?.toString() ?? document.id,
        session: session,
        dept: dept,
        isAdmin: data["isAdmin"] == true ||
            data["isAdmin"].toString().toLowerCase() == 'true');
  }

  Student copyWith({
    String? name,
    String? reg,
  }) {
    return Student(
        name: name ?? this.name,
        roll: roll,
        reg: reg ?? this.reg,
        email: email,
        dept: dept,
        session: session,
        isAdmin: isAdmin,
        uid: uid);
  }
}
