class RankInfo {
  final double average;
  final String studentNumber;
  final String studentName;
  final bool isSelf;
  final double rank;
  final double credit;
  final String className;
  final String classId;
  
  RankInfo.fromJson(Map<String, dynamic> json)
    : average = double.tryParse(json['average']?.toString() ?? '0') ?? 0.0,
      studentNumber = json['studentNumber'] ?? '',
      studentName = json['studentName'] ?? '',
      isSelf = json['self'] == '1',
      rank = double.tryParse(json['rank']?.toString() ?? '0') ?? 0.0,
      credit = double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0,
      className = json['className'] ?? '',
      classId = json['classId'] ?? '';
}
