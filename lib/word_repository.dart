import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'word_model.dart';

class WordRepository {
  static const String _wordsKey = 'words';

  // Получение списка слов, отсортированного по алфавиту
  Future<List<Word>> getWords() async {
    final prefs = await SharedPreferences.getInstance();
    final wordsJson = prefs.getStringList(_wordsKey) ?? [];
    final words = wordsJson.map((json) => Word.fromJson(jsonDecode(json))).toList();
    words.sort((a, b) => a.original.compareTo(b.original)); // Сортировка по original
    return words;
  }

  // Добавление нового слова
  Future<void> addWord(Word word) async {
    final prefs = await SharedPreferences.getInstance();
    final words = await getWords();
    final now = DateTime.now();
    words.add(Word(
      original: word.original,
      translation: word.translation,
      interval: 1,
      reviewStage: 0,
      reviewCount: 0,
      nextReview: DateTime(now.year, now.month, now.day), // Начало текущего дня
      isFamiliar: false,
    ));
    final wordsJson = words.map((word) => jsonEncode(word.toJson())).toList();
    await prefs.setStringList(_wordsKey, wordsJson);
  }

  // Обновление слова (например, после повторения или редактирования)
  Future<void> updateWord(Word updatedWord) async {
    final prefs = await SharedPreferences.getInstance();
    final words = await getWords();
    final index = words.indexWhere((word) => word.original == updatedWord.original);
    if (index != -1) {
      words[index] = updatedWord;
      final wordsJson = words.map((word) => jsonEncode(word.toJson())).toList();
      await prefs.setStringList(_wordsKey, wordsJson);
    }
  }

  // Удаление слова
  Future<void> deleteWord(String original) async {
    final prefs = await SharedPreferences.getInstance();
    final words = await getWords();
    words.removeWhere((word) => word.original == original);
    final wordsJson = words.map((word) => jsonEncode(word.toJson())).toList();
    await prefs.setStringList(_wordsKey, wordsJson);
  }

  // Получение слов для повторения (дата повторения <= текущей даты с учетом смещения)
  Future<List<Word>> getWordsForReview() async {
    final prefs = await SharedPreferences.getInstance();
    final offsetHours = prefs.getInt('time_offset_hours') ?? 0;
    final offset = Duration(hours: offsetHours);
    final words = await getWords();
    final now = DateTime.now().add(offset);
    // Нормализуем текущую дату к началу дня
    final today = DateTime(now.year, now.month, now.day);
    return words.where((word) => !word.isFamiliar && word.nextReview.isBefore(today) || word.nextReview.isAtSameMomentAs(today)).toList();
  }

  // Принудительное добавление слова для повторения
  Future<void> addWordForReview(String original) async {
    final prefs = await SharedPreferences.getInstance();
    final offsetHours = prefs.getInt('time_offset_hours') ?? 0;
    final offset = Duration(hours: offsetHours);
    final words = await getWords();
    final index = words.indexWhere((word) => word.original == original);
    if (index != -1) {
      final now = DateTime.now().add(offset);
      final updatedWord = Word(
        original: words[index].original,
        translation: words[index].translation,
        interval: words[index].interval,
        reviewStage: words[index].reviewStage,
        reviewCount: words[index].reviewCount,
        nextReview: DateTime(now.year, now.month, now.day),
        isFamiliar: words[index].isFamiliar,
      );
      await updateWord(updatedWord);
    }
  }

  // Принудительное добавление нескольких слов для повторения
  Future<void> addWordsForReview(List<String> originals) async {
    for (final original in originals) {
      await addWordForReview(original);
    }
  }
}