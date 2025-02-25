class CourseInfo {
  final String id;
  final String timeAdd;
  final String courseId;
  final String courseName;
  final String teacherNumber;
  final String teacherName;
  final String place;
  final String school;
  final String room;
  final String week;
  final String time;
  final String jie;
  final String xq;
  final String cursProperty;  // 添加考核方式
  final String cursForm;     // 添加考试形式

  static String currentTerm = ''; // 添加静态学期信息字段

  CourseInfo.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        timeAdd = json['timeAdd'] ?? '',
        courseId = json['courseId'] ?? '',
        courseName = json['courseName'] ?? '',
        teacherNumber = json['teacherNumber'] ?? '',
        teacherName = json['teacherName'] ?? '',
        place = json['place'] ?? '',
        school = json['school'] ?? '',
        room = json['room'] ?? '',
        week = json['week'] ?? '',
        time = json['time'] ?? '',
        jie = json['jie'] ?? '',
        xq = json['xq'] ?? '',
        cursProperty = json['cursProperty'] ?? '',
        // 如果考核方式为"考查"，考试形式也设置为"考查"
        cursForm = (json['cursProperty'] == '考查') ? '考查' : (json['cursForm'] ?? '');

  static CourseInfo? fromClassInfo(Map<String, dynamic> json) {
    if (json['ClassInfo'] != null) {
      return CourseInfo.fromJson(json['ClassInfo']);
    }
    return null;
  }

  static void setCurrentTerm(Map<String, dynamic> semesterInfo) {
    if (semesterInfo['data'] != null) {
      final remarks = semesterInfo['data']['remarks'] as String? ?? '';
      currentTerm = remarks;
    }
  }
}
