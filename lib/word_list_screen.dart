import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _wordsFuture = _repository.getWords();
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
              });
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final updatedWord = Word(
                  original: _originalController.text,
                  translation: _translationController.text,
                  interval: word.interval,
                  reviewStage: word.reviewStage,
                  nextReview: word.nextReview,
                  isFamiliar: word.isFamiliar,
                );
                await _repository.updateWord(updatedWord);
                Navigator.pop(context);
                setState(() {
                  _wordsFuture = _repository.getWords();
                });
              }
            },
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // Вычисление интервала до следующего повторения
  String _getReviewStatus(Word word) {
    if (word.isFamiliar) {
      return 'Выучено';
    }
    final now = DateTime.now();
    final difference = word.nextReview.difference(now).inDays;
    if (difference <= 0) {
      return 'Повторить сегодня';
    }
    return 'Через $difference дн.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Список слов'),
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
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FlashcardScreen()),
                  );
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
                      leading: Checkbox(
                        value: _selectedWords.contains(word.original),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedWords.add(word.original);
                            } else {
                              _selectedWords.remove(word.original);
                            }
                          });
                        },
                      ),
                      title: Text(word.original),
                      subtitle: Text('${word.translation} | ${_getReviewStatus(word)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editWord(context, word),
                          ),
                          IconButton(
                            icon: Icon(Icons.play_circle, color: Colors.green),
                            onPressed: () async {
                              await _repository.addWordForReview(word.original);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => FlashcardScreen()),
                              );
                            },
                          ),
                        ],
                      ),
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
          FloatingActionButton(
            heroTag: 'flashcards',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FlashcardScreen()),
              );
            },
            child: Icon(Icons.play_arrow),
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
              });
            },
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}