import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class Todo {
  String title;
  bool isDone;

  Todo({required this.title, this.isDone = false});

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isDone': isDone,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      title: json['title'],
      isDone: json['isDone'],
    );
  }
}

class TodoScreen extends StatefulWidget {
  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final List<Todo> _todos = [];
  final TextEditingController _textController = TextEditingController();
  String? _userEmail;
  
  // Speech recognition variables
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  
  // Text to speech
  late FlutterTts _flutterTts;

  void _checkPermissions() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadUserInfo();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('userEmail');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Todo List'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Welcome, ${_userEmail ?? 'User'}',
              style: TextStyle(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Add a new todo...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _isListening ? 'Listening...' : _text.isNotEmpty ? 'Command recognized: $_text' : 'Tap the mic to add or remove todos by voice',
              style: TextStyle(
                fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                color: _isListening ? Colors.blue : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? Center(child: Text('No todos yet. Add one!'))
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return ListTile(
                        leading: Checkbox(
                          value: todo.isDone,
                          onChanged: (value) {
                            setState(() {
                              todo.isDone = value!;
                            });
                          },
                        ),
                        title: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteTodo(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        tooltip: 'Voice Command',
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            setState(() {
              _isListening = false;
            });
            _processVoiceCommand(_text);
          }
        },
        onError: (errorNotification) {
          setState(() {
            _isListening = false;
            _text = "Error: $errorNotification";
          });
        },
      );
      
      if (available) {
        setState(() {
          _isListening = true;
          _text = '';
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
            });
          },
        );
      } else {
        setState(() {
          _text = "Speech recognition not available";
        });
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
    }
  }

  void _processVoiceCommand(String command) {
    command = command.toLowerCase();
    
    if (command.contains('add') || command.contains('create')) {
      // Extract the task text after "add" or "create"
      String task = '';
      if (command.contains('add')) {
        task = command.substring(command.indexOf('add') + 4).trim();
      } else if (command.contains('create')) {
        task = command.substring(command.indexOf('create') + 7).trim();
      }
      
      if (task.isNotEmpty) {
        setState(() {
          _todos.add(Todo(title: task));
        });
        _speak("Added task: $task");
      } else {
        _speak("Could not understand the task to add");
      }
    } else if (command.contains('remove') || command.contains('delete')) {
      // Try to identify task to remove
      String taskToRemove = '';
      if (command.contains('remove')) {
        taskToRemove = command.substring(command.indexOf('remove') + 7).trim();
      } else if (command.contains('delete')) {
        taskToRemove = command.substring(command.indexOf('delete') + 7).trim();
      }
      
      if (taskToRemove.isNotEmpty) {
        bool found = false;
        for (int i = 0; i < _todos.length; i++) {
          if (_todos[i].title.toLowerCase().contains(taskToRemove)) {
            _deleteTodo(i);
            _speak("Removed task containing: $taskToRemove");
            found = true;
            break;
          }
        }
        
        if (!found) {
          _speak("Could not find a task with: $taskToRemove");
        }
      } else {
        _speak("Could not understand which task to remove");
      }
    } else if (command.contains('clear all') || command.contains('remove all')) {
      setState(() {
        _todos.clear();
      });
      _speak("Cleared all tasks");
    } else if (command.contains('help')) {
      _speak("You can say commands like: Add buy milk, Remove buy milk, or Clear all tasks");
    } else {
      _speak("Command not recognized. Try saying Add, followed by your task.");
    }
  }

  void _addTodo() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _todos.add(Todo(title: _textController.text));
        _textController.clear();
      });
    }
  }

  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }
}