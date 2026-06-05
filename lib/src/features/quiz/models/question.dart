class QuizQuestion {
  final String id;
  final String contestId;
  final String questionType;
  final String? predictionType;
  final Map<String, dynamic> predictionPayload;
  final String questionText;
  final String? questionImageUrl;
  final List<String> options;
  final List<String?> optionImageUrls;
  final String correctAnswer;
  final int points;
  final int timeLimit;

  const QuizQuestion({
    required this.id,
    required this.contestId,
    required this.questionType,
    required this.predictionType,
    required this.predictionPayload,
    required this.questionText,
    required this.questionImageUrl,
    required this.options,
    required this.optionImageUrls,
    required this.correctAnswer,
    required this.points,
    required this.timeLimit,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      contestId: json['contest_id'] as String? ?? '',
      questionType: (json['question_type'] as String? ?? 'quiz')
          .trim()
          .toLowerCase(),
      predictionType: _cleanUrl(json['prediction_type'] as String?),
      predictionPayload: _jsonMap(json['prediction_payload']),
      questionText: json['question_text'] as String? ?? '',
      questionImageUrl: _cleanUrl(json['question_image_url'] as String?),
      options: [
        json['option_a'] as String? ?? '',
        json['option_b'] as String? ?? '',
        json['option_c'] as String? ?? '',
        json['option_d'] as String? ?? '',
      ],
      optionImageUrls: [
        _cleanUrl(json['option_a_image_url'] as String?),
        _cleanUrl(json['option_b_image_url'] as String?),
        _cleanUrl(json['option_c_image_url'] as String?),
        _cleanUrl(json['option_d_image_url'] as String?),
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

  bool get hasQuestionImage => questionImageUrl?.isNotEmpty == true;

  bool get isPronostic => questionType == 'pronostic';

  bool get hasImageOptions =>
      optionImageUrls.length == 4 &&
      optionImageUrls.every((url) => url?.isNotEmpty == true);

  String optionLabel(int index) {
    if (index < 0 || index >= options.length) return '';
    final text = options[index].trim();
    if (text.isNotEmpty) return text;
    if (hasImageOptions) return 'Image ${String.fromCharCode(65 + index)}';
    return '';
  }
}

String? _cleanUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

class QuizAnswer {
  final String questionId;
  final int? selectedIndex;
  final int correctIndex;
  final bool isCorrect;
  final bool isPronostic;
  final int points;
  final int elapsedMs;

  const QuizAnswer({
    required this.questionId,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
    this.isPronostic = false,
    required this.points,
    required this.elapsedMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'selected_index': selectedIndex,
      'correct_index': correctIndex,
      'is_correct': isCorrect,
      'is_pronostic': isPronostic,
      'resolution_status': isPronostic ? 'pending' : 'not_required',
      'points': points,
      'elapsed_ms': elapsedMs,
    };
  }
}
