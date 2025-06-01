import 'package:flutter/material.dart';
import 'word_model.dart';
import 'word_repository.dart';

class AddWordScreen extends StatefulWidget {
  @override
  _AddWordScreenState createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originalController = TextEditingController();
  final _translationController = TextEditingController();
  final _repository = WordRepository();

  @override
  void dispose() {
    _originalController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Добавить слово'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
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
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final word = Word(
                      original: _originalController.text,
                      translation: _translationController.text,
                      interval: 1,
                      reviewStage: 0,
                      nextReview: DateTime.now(),
                      isFamiliar: false,
                    );
                    await _repository.addWord(word);
                    Navigator.pop(context);
                  }
                },
                child: Text('Добавить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}