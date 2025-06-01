import 'package:flutter/material.dart';
import 'word_model.dart';
import 'word_repository.dart';

class FlashcardScreen extends StatefulWidget {
  @override
  _FlashcardScreenState createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final WordRepository _repository = WordRepository();
  List<Word> _wordsForReview = [];
  int _currentIndex = 0;
  bool _showTranslation = false;
  DateTime? _nextReviewDate;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final words = await _repository.getWordsForReview();
    setState(() {
      _wordsForReview = words;
      _currentIndex = 0;
      _showTranslation = false;
      _nextReviewDate = null;
    });
  }

  void _updateReview(Word word) {
    // Фиксированный график повторений: 1, 3, 7, 14, 30, 60 дней
    const intervals = [1, 3, 7, 14, 30, 60];
    // Используем текущую стадию повторения для выбора интервала
    int currentStage = word.reviewStage;
    // Выбираем интервал, не превышая длину массива
    int newInterval = intervals[currentStage < intervals.length ? currentStage : intervals.length - 1];
    // Увеличиваем стадию повторения после выбора интервала
    int newStage = currentStage + 1;

    // Используем текущую дату повторения как основу
    DateTime nextReview = word.nextReview.add(Duration(days: newInterval));

    print('Updating review: original=${word.original}, currentStage=$currentStage, newStage=$newStage, newInterval=$newInterval days, nextReview=$nextReview');

    final updatedWord = Word(
      original: word.original,
      translation: word.translation,
      interval: newInterval,
      reviewStage: newStage,
      reviewCount: word.reviewCount + 1,
      nextReview: nextReview,
      isFamiliar: word.isFamiliar,
    );

    setState(() {
      _nextReviewDate = updatedWord.nextReview;
    });

    _repository.updateWord(updatedWord);
  }

  void _markAsFamiliar(Word word) {
    final updatedWord = Word(
      original: word.original,
      translation: word.translation,
      interval: word.interval,
      reviewStage: word.reviewStage,
      reviewCount: word.reviewCount,
      nextReview: word.nextReview,
      isFamiliar: true,
    );
    print('Marking as familiar: original=${word.original}, isFamiliar=${updatedWord.isFamiliar}');
    _repository.updateWord(updatedWord);
    _nextCard();
  }

  void _nextCard() {
    setState(() {
      if (_currentIndex < _wordsForReview.length - 1) {
        _currentIndex++;
        _showTranslation = false;
        _nextReviewDate = null;
      } else {
        _wordsForReview = [];
        _loadWords(); // Refresh the list to exclude familiar words
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_wordsForReview.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Карточки')),
        body: Center(child: Text('Нет слов для повторения')),
      );
    }

    final currentWord = _wordsForReview[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Карточки')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showTranslation ? currentWord.translation : currentWord.original,
              style: TextStyle(fontSize: 32),
            ),
            if (_nextReviewDate != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Следующий повтор: ${_nextReviewDate!.toString().substring(0, 10)}',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showTranslation = !_showTranslation;
                  _nextReviewDate = null; // Сброс даты при переключении
                });
              },
              child: Text(_showTranslation ? 'Показать слово' : 'Показать перевод'),
            ),
          ],
        ),
      ),
      floatingActionButton: _showTranslation
          ? FloatingActionButton(
        onPressed: () {
          _updateReview(currentWord);
          _nextCard();
        },
        child: Text('Далее'),
      )
          : null,
    );
  }
}