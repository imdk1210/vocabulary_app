import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'word_model.dart';
import 'word_repository.dart';
import 'add_word_screen.dart';
import 'flashcard_screen.dart';

class WordListScreen extends StatefulWidget {
  @override
  _WordListScreenState createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final WordRepository _repository = WordRepository();
  late Future<List<Word>> _wordsFuture;
  final Set<String> _selectedWords = {};
  late Timer _timer;
  String _bishkekTime = '';
  Duration _timeOffset = Duration.zero;
  bool _isSelectionMode = false;
  String? _longPressedWord;
  int _wordsForReviewCount = 0;

  @override
  void initState() {
    super.initState();
    _wordsFuture = _repository.getWords();
    _loadTimeOffset();
    _updateBishkekTime();
    _updateWordsForReviewCount();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _updateBishkekTime();
      });
    });
  }

  Future<void> _loadTimeOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final hours = prefs.getInt('time_offset_hours') ?? 0;
    setState(() {
      _timeOffset = Duration(hours: hours);
      _updateWordsForReviewCount();
    });
  }

  Future<void> _incrementTimeOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final newOffset = _timeOffset + Duration(hours: 1);
    setState(() {
      _timeOffset = newOffset;
      _updateWordsForReviewCount();
    });
    await prefs.setInt('time_offset_hours', newOffset.inHours);
  }

  Future<void> _resetTimeOffset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('time_offset_hours');
    setState(() {
      _timeOffset = Duration.zero;
      _updateWordsForReviewCount();
    });
  }

  Future<void> _updateWordsForReviewCount() async {
    final words = await _repository.getWordsForReview();
    setState(() {
      _wordsForReviewCount = words.length;
    });
  }

  void _updateBishkekTime() {
    final now = DateTime.now().add(_timeOffset).toUtc().add(Duration(hours: 6)); // Bishkek UTC+6
    _bishkekTime = DateFormat('HH:mm:ss').format(now);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Открытие диалога для редактирования слова
  void _editWord(BuildContext context, Word word) {
    final _formKey = GlobalKey<FormState>();
    final _originalController = TextEditingController(text: word.original);
    final _translationController = TextEditingController(text: word.translation);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать слово'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _originalController,
                decoration: InputDecoration(labelText: 'Слово'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите слово';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _translationController,
                decoration: InputDecoration(labelText: 'Перевод'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите перевод';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _repository.deleteWord(word.original);
              Navigator.pop(context);
              setState(() {
                _selectedWords.remove(word.original);
                _wordsFuture = _repository.getWords();
                _isSelectionMode = _selectedWords.isNotEmpty;
                _longPressedWord = null;
                _updateWordsForReviewCount();
              });
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              final updatedWord = Word(
                original: word.original,
                translation: word.translation,
                interval: word.interval,
                reviewStage: word.reviewStage,
                reviewCount: word.reviewCount,
                nextReview: word.nextReview,
                isFamiliar: true, // Mark as familiar
              );
              print('Marking as familiar in edit: original=${word.original}, isFamiliar=${updatedWord.isFamiliar}');
              await _repository.updateWord(updatedWord);
              Navigator.pop(context);
              setState(() {
                _selectedWords.remove(word.original);
                _wordsFuture = _repository.getWords();
                _isSelectionMode = _selectedWords.isNotEmpty;
                _longPressedWord = null;
                _updateWordsForReviewCount();
              });
            },
            child: Text('Выучено', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final updatedWord = Word(
                  original: _originalController.text,
                  translation: _translationController.text,
                  interval: word.interval,
                  reviewStage: word.reviewStage,
                  reviewCount: word.reviewCount,
                  nextReview: word.nextReview,
                  isFamiliar: word.isFamiliar,
                );
                await _repository.updateWord(updatedWord);
                Navigator.pop(context);
                setState(() {
                  _wordsFuture = _repository.getWords();
                  _isSelectionMode = _selectedWords.isNotEmpty;
                  _longPressedWord = null;
                  _updateWordsForReviewCount();
                });
              }
            },
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // Вычисление статуса повторения
  String _getReviewStatus(Word word) {
    if (word.isFamiliar) {
      return 'Выучено';
    }
    final now = DateTime.now().add(_timeOffset);
    final today = DateTime(now.year, now.month, now.day);
    final nextReviewDay = DateTime(word.nextReview.year, word.nextReview.month, word.nextReview.day);
    final difference = nextReviewDay.difference(today).inDays;
    print('Word: ${word.original}, nextReview=${word.nextReview}, today=$today, difference=$difference days');
    if (difference <= 0) {
      return 'Повторить сегодня';
    }
    return 'Осталось: $difference дн.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Список слов'),
            Row(
              children: [
                Text(
                  'Бишкек: $_bishkekTime${_timeOffset.inHours > 0 ? " (+${_timeOffset.inHours}ч)" : ""}',
                  style: TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: Icon(Icons.watch_later, color: Colors.blue),
                  onPressed: _incrementTimeOffset,
                  tooltip: 'Добавить 1 час',
                ),
                if (_timeOffset.inHours > 0)
                  IconButton(
                    icon: Icon(Icons.restore, color: Colors.red),
                    onPressed: _resetTimeOffset,
                    tooltip: 'Сбросить смещение времени',
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedWords.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () async {
                  await _repository.addWordsForReview(_selectedWords.toList());
                  setState(() {
                    _selectedWords.clear();
                    _isSelectionMode = false;
                    _longPressedWord = null;
                    _wordsFuture = _repository.getWords();
                    _updateWordsForReviewCount();
                  });
                },
                child: Text('Добавить выбранные в карточки'),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Word>>(
              future: _wordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Список слов пуст'));
                }

                final words = snapshot.data!;
                return ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return ListTile(
                      leading: _isSelectionMode
                          ? Checkbox(
                        value: _selectedWords.contains(word.original),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedWords.add(word.original);
                            } else {
                              _selectedWords.remove(word.original);
                              if (_selectedWords.isEmpty) {
                                _isSelectionMode = false;
                                _longPressedWord = null;
                              }
                            }
                          });
                        },
                      )
                          : null,
                      title: Text(word.original),
                      subtitle: Text(word.translation),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getReviewStatus(word),
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          if (_isSelectionMode || _longPressedWord == word.original)
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editWord(context, word),
                            ),
                        ],
                      ),
                      onLongPress: () {
                        setState(() {
                          _isSelectionMode = true;
                          _longPressedWord = word.original;
                          _selectedWords.add(word.original);
                        });
                      },
                      onTap: _isSelectionMode
                          ? () {
                        setState(() {
                          if (_selectedWords.contains(word.original)) {
                            _selectedWords.remove(word.original);
                            if (_selectedWords.isEmpty) {
                              _isSelectionMode = false;
                              _longPressedWord = null;
                            }
                          } else {
                            _selectedWords.add(word.original);
                          }
                        });
                      }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Badge(
            isLabelVisible: _wordsForReviewCount > 0,
            label: Text(
              '$_wordsForReviewCount',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            offset: Offset(10, -10),
            child: FloatingActionButton(
              heroTag: 'flashcards',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FlashcardScreen()),
                ).then((_) {
                  setState(() {
                    _wordsFuture = _repository.getWords();
                    _updateWordsForReviewCount();
                  });
                });
              },
              child: Icon(Icons.play_arrow),
            ),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add_word',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddWordScreen()),
              );
              setState(() {
                _wordsFuture = _repository.getWords();
                _updateWordsForReviewCount();
              });
            },
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}