import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/tasks_repository.dart';
import 'models/task.dart';

/// Provides TasksRepository and a stream of tasks
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final repo = TasksRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.tasksStream();
});
