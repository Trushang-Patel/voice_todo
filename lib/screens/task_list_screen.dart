import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/voice_service.dart';
import '../models/task.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final voiceService = ref.read(voiceServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Voice To-Do')),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks yet'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                leading: Checkbox(
                  value: task.isCompleted,
                  onChanged: (_) {
                    ref.read(tasksRepositoryProvider).handleCommand('complete ${task.title}');
                  },
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    ref.read(tasksRepositoryProvider).handleCommand('delete ${task.title}');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => voiceService.startListening(),
        child: const Icon(Icons.mic),
      ),
    );
  }
}
