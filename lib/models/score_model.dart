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
  final String evaValue;     // 最终总评
  final String finEvaValue;  // 期末成绩
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

  // 简单计算每门课的绩点，不需要乘以学分
  double get gpa {
    final value = double.tryParse(point) ?? 0.0;
    return value;  // 返回原始绩点，不再在这里格式化
  }
  
  // 获取学分数
  double get creditValue => double.tryParse(credit) ?? 0.0;

  // 修改判断逻辑，处理各种汉字成绩情况
  bool get needsRetake {
    // 处理文字成绩
    switch (evaValue) {
      case '优秀':
      case '良好':
      case '中等':
      case '及格':
        return false;
      case '不及格':
        return true;
    }
    
    // 处理数字成绩
    final score = double.tryParse(evaValue) ?? 0.0;
    return score < 60;
  }
}

class TermScores {
  final String term;
  final List<ScoreInfo> scores;
  
  TermScores(this.term, this.scores);

  // 修改 GPA 计算，确保按公式计算并四舍五入到一位小数
  double get averageGPA {
    if (scores.isEmpty) return 0.0;
    double totalPoints = 0.0;
    int totalCourses = scores.length;
    
    for (var score in scores) {
      totalPoints += score.gpa;
    }
    
    // GPA = (Σ单科绩点/Σ科目数)四舍五入保留一位小数
    return double.parse((totalPoints / totalCourses).toStringAsFixed(1));
  }

  // 获取总学分，保留一位小数
  double get totalCredits {
    final total = scores.fold(0.0, (sum, score) => sum + score.creditValue);
    // 使用 double.parse(toStringAsFixed(1)) 确保保留一位小数
    return double.parse(total.toStringAsFixed(1));
  }
}
