class StudentProgress {
  final String studentId;
  final String studentName;
  final String lessonId;
  final double completionPercentage; // 0.0 to 1.0
  final double confidenceScore; // AI graded confidence 0.0 to 1.0
  final DateTime lastUpdated;

  StudentProgress({
    required this.studentId,
    required this.studentName,
    required this.lessonId,
    required this.completionPercentage,
    required this.confidenceScore,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentName': studentName,
    'lessonId': lessonId,
    'completionPercentage': completionPercentage,
    'confidenceScore': confidenceScore,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory StudentProgress.fromJson(Map<String, dynamic> json) =>
      StudentProgress(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        lessonId: json['lessonId'] as String,
        completionPercentage: (json['completionPercentage'] as num).toDouble(),
        confidenceScore: (json['confidenceScore'] as num).toDouble(),
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      );
}
