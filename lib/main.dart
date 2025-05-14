import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/task_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // TODO: Configure Firebase options if needed
  await Hive.initFlutter();
  await Hive.openBox('commandsQueue');
  await Hive.openBox('tasks');
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice To-Do',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TaskListScreen(),
    );
  }
}
