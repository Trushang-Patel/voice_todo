import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

/// Repository managing tasks locally (Hive) and remotely (Firestore) with offline queueing.
class TasksRepository {
  final Box _tasksBox = Hive.box('tasks');
  final Box _queueBox = Hive.box('commandsQueue');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  final StreamController<List<Task>> _tasksController = StreamController.broadcast();

  late final StreamSubscription _hiveSub;
  late final StreamSubscription _firestoreSub;
  late final StreamSubscription _connectivitySub;

  TasksRepository() {
    _init();
  }

  Future<void> _init() async {
    // initial emit
    _tasksController.add(_getLocalTasks());

    // listen to local changes
    _hiveSub = _tasksBox.watch().listen((_) {
      _tasksController.add(_getLocalTasks());
    });

    // listen to remote changes
    _firestoreSub = _firestore.collection('tasks').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        _tasksBox.put(doc.id, doc.data());
      }
      _tasksController.add(_getLocalTasks());
    });

    // listen to connectivity
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _flushQueue();
      }
    });

    // initial flush if online
    final status = await _connectivity.checkConnectivity();
    if (status != ConnectivityResult.none) {
      _flushQueue();
    }
  }

  List<Task> _getLocalTasks() {
    return _tasksBox.values
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Stream of current tasks
  Stream<List<Task>> tasksStream() => _tasksController.stream;

  /// Handle raw voice command
  Future<void> handleCommand(String text) async {
    final cmd = _parseCommand(text);
    if (cmd == null) return;
    final status = await _connectivity.checkConnectivity();
    final offline = status == ConnectivityResult.none;
    if (offline) {
      await _queueBox.add(text);
      await _processCommand(cmd, localOnly: true);
    } else {
      await _processCommand(cmd, localOnly: false);
    }
  }

  Future<void> _flushQueue() async {
    final commands = _queueBox.values.cast<String>().toList();
    for (var text in commands) {
      final cmd = _parseCommand(text);
      if (cmd != null) {
        await _processCommand(cmd, localOnly: false);
      }
    }
    await _queueBox.clear();
  }

  ParsedCommand? _parseCommand(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('add ') || lower.startsWith('create ')) {
      final parts = text.split(' ');
      final title = parts.skip(1).join(' ');
      return ParsedCommand(type: CommandType.add, payload: title);
    } else if (lower.startsWith('complete ') || lower.startsWith('finish ')) {
      final parts = text.split(' ');
      final title = parts.skip(1).join(' ');
      return ParsedCommand(type: CommandType.complete, payload: title);
    } else if (lower.startsWith('delete ')) {
      final parts = text.split(' ');
      final title = parts.skip(1).join(' ');
      return ParsedCommand(type: CommandType.delete, payload: title);
    }
    return null;
  }

  Future<void> _processCommand(ParsedCommand cmd, {required bool localOnly}) async {
    switch (cmd.type) {
      case CommandType.add:
        final id = Uuid().v4();
        final task = Task(id: id, title: cmd.payload);
        await _tasksBox.put(id, task.toJson());
        if (!localOnly) {
          await _firestore.collection('tasks').doc(id).set(task.toJson());
        }
        break;
      case CommandType.complete:
        final match = _getLocalTasks().firstWhere(
            (t) => t.title.toLowerCase() == cmd.payload.toLowerCase(),
            orElse: () => Task(id: '', title: ''));
        if (match.id.isNotEmpty) {
          final updated = match.copyWith(isCompleted: true);
          await _tasksBox.put(updated.id, updated.toJson());
          if (!localOnly) {
            await _firestore
                .collection('tasks')
                .doc(updated.id)
                .update({'isCompleted': true});
          }
        }
        break;
      case CommandType.delete:
        final match = _getLocalTasks().firstWhere(
            (t) => t.title.toLowerCase() == cmd.payload.toLowerCase(),
            orElse: () => Task(id: '', title: ''));
        if (match.id.isNotEmpty) {
          await _tasksBox.delete(match.id);
          if (!localOnly) {
            await _firestore.collection('tasks').doc(match.id).delete();
          }
        }
        break;
    }
  }

  void dispose() {
    _hiveSub.cancel();
    _firestoreSub.cancel();
    _connectivitySub.cancel();
    _tasksController.close();
  }
}

enum CommandType { add, complete, delete }

class ParsedCommand {
  final CommandType type;
  final String payload;
  ParsedCommand({required this.type, required this.payload});
}
