class QuizQuestion {
  final String id;
  final String contestId;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final int points;
  final int timeLimit;

  const QuizQuestion({
    required this.id,
    required this.contestId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.points,
    required this.timeLimit,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      contestId: json['contest_id'] as String,
      questionText: json['question_text'] as String? ?? '',
      options: [
        json['option_a'] as String? ?? '',
        json['option_b'] as String? ?? '',
        json['option_c'] as String? ?? '',
        json['option_d'] as String? ?? '',
      ],
      correctAnswer: (json['correct_answer'] as String? ?? 'A').toUpperCase(),
      points: (json['points'] as num?)?.toInt() ?? 1,
      timeLimit: (json['time_limit'] as num?)?.toInt() ?? 30,
    );
  }

  int get correctIndex {
    return switch (correctAnswer) {
      'A' => 0,
      'B' => 1,
      'C' => 2,
      'D' => 3,
      _ => 0,
    };
  }
}

class QuizAnswer {
  final String questionId;
  final int? selectedIndex;
  final int correctIndex;
  final bool isCorrect;
  final int points;

  const QuizAnswer({
    required this.questionId,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
    required this.points,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'selected_index': selectedIndex,
      'correct_index': correctIndex,
      'is_correct': isCorrect,
      'points': points,
    };
  }
}
