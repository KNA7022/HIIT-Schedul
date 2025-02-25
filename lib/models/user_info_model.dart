class UserInfo {
  final String name;
  final String studentNumber;
  final String exaNumber;
  final String companyName;
  final String officeName;
  final String grade;
  final String classId;     // 班级学号
  final String className;   // 班级名称
  final String gender;

  UserInfo.fromJson(Map<String, dynamic> json)
      : name = json['name'] ?? '',
        studentNumber = json['studentNumber'] ?? '',
        exaNumber = json['exaNumber'] ?? '',
        companyName = json['companyName'] ?? '',
        officeName = json['officeName'] ?? '',
        grade = json['grade'] ?? '',
        classId = (json['classId']?.isNotEmpty ?? false) 
            ? json['classId'] 
            : (json['clazzId'] ?? ''),
        className = (json['classId']?.isNotEmpty ?? false) 
            ? json['className'] 
            : (json['clazzName'] ?? ''),
        gender = json['gender'] ?? '1';

  String get genderText => gender == '1' ? '男' : '女';
  String get formattedClassInfo => '$className -$classId (班级学号可能不代表点名册顺序)';
}
