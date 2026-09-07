import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/utils.dart';

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
    String smallRoll = '${email[4]}${email[5]}';
    int smallRollInt = int.parse(smallRoll);
    bool lateral = smallRollInt >= 80;
    int deptCode = departments.indexOf(dept) + 1;
    int session = int.parse('${email[2]}${email[3]}');
    int startingSession = lateral ? session - 3 : session - 4;
    String roll = '${startingSession}10110${deptCode}0$smallRoll';
    return roll;
  }

  static String buildDeptFromEmail(String email) {
    email = email.trim().toLowerCase();
    if (!isCollegeEmail(email)) return 'Others';
    String dept = RegExp(r'^[a-z]{2}\d{4}@(cse|ece|it|ee|ce|me)\.jgec\.ac\.in$')
        .firstMatch(email)!
        .group(1)!
        .toUpperCase();
    return dept;
  }

  static String buildFullSessionFromEmail(String email) {
    email = email.trim().toLowerCase();
    if (!isCollegeEmail(email)) return 'N/A';
    int passYear = int.parse('20${email[2]}${email[3]}');
    int startingYear = passYear - 4;
    return '$startingYear-$passYear';
  }

  static bool isCollegeEmail(String email) =>
      RegExp(r'^[a-zA-Z]{2}\d{4}@(cse|ece|it|ee|ce|me)\.jgec\.ac\.in$')
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
