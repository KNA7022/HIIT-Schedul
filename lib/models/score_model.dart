import 'dart:convert';  // 添加此导入

class TeacherInfo {
  final String name;
  final String number;

  TeacherInfo.fromJson(Map<String, dynamic> json)
    : name = json['tchrName'] ?? '',
      number = json['teacherNumber'] ?? '';
}

class ScoreInfo {
  final String courseName;
  final List<TeacherInfo> scoreSetters;
  final String classEvaValue; // 平时分
  final String evaValue;     // 期末分
  final String finEvaValue;  // 最终分
  final String credit;       // 学分
  final String point;        // 绩点
  final String createBy;     // 创建者编号

  ScoreInfo.fromJson(Map<String, dynamic> json)
    : courseName = json['courseName'] ?? '',
      scoreSetters = (json['scoreSetters'] != null 
          ? (jsonDecode(json['scoreSetters']) as List)
              .map((item) => TeacherInfo.fromJson(item))
              .toList()
          : <TeacherInfo>[]),
      classEvaValue = json['classEvaValue'] ?? '0',
      evaValue = json['evaValue'] ?? '0',
      finEvaValue = json['finEvaValue'] ?? '0',
      credit = json['credit'] ?? '0',
      point = json['point'] ?? '0',
      createBy = json['createBy'] ?? '';

  String get teacherName {
    final teacher = scoreSetters.firstWhere(
      (t) => t.number == createBy,
      orElse: () => scoreSetters.isEmpty ? TeacherInfo.fromJson({}) : scoreSetters.first
    );
    return teacher.name;
  }

  // 计算GPA
  double get gpa => double.tryParse(point) ?? 0.0;
  
  // 获取学分数
  double get creditValue => double.tryParse(credit) ?? 0.0;
}

class TermScores {
  final String term;
  final List<ScoreInfo> scores;
  
  TermScores(this.term, this.scores);

  // 计算学期GPA
  double get averageGPA {
    if (scores.isEmpty) return 0.0;
    double totalPoints = 0.0;
    double totalCredits = 0.0;
    
    for (var score in scores) {
      totalPoints += score.gpa * score.creditValue;
      totalCredits += score.creditValue;
    }
    
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  // 获取总学分
  double get totalCredits {
    return scores.fold(0.0, (sum, score) => sum + score.creditValue);
  }
}
