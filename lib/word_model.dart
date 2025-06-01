class Word {
  final String original;
  final String translation;
  int interval; // Интервал повторения в днях
  int reviewStage; // Стадия повторения (0: новый, 1: 1 день, 2: 3 дня, и т.д.)
  DateTime nextReview; // Дата следующего повторения
  bool isFamiliar; // Флаг, указывающий, что слово выучено

  Word({
    required this.original,
    required this.translation,
    this.interval = 1,
    this.reviewStage = 0,
    required this.nextReview,
    this.isFamiliar = false,
  });

  // Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'translation': translation,
      'interval': interval,
      'reviewStage': reviewStage,
      'nextReview': nextReview.toIso8601String(),
      'isFamiliar': isFamiliar,
    };
  }

  // Создание объекта из JSON
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      original: json['original'],
      translation: json['translation'],
      interval: json['interval'],
      reviewStage: json['reviewStage'] ?? 0,
      nextReview: DateTime.parse(json['nextReview']),
      isFamiliar: json['isFamiliar'] ?? false,
    );
  }
}