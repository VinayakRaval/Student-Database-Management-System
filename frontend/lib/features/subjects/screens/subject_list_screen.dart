import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

// --- Quick Model for this screen ---
class SubjectSimple {
  final int id;
  final String name;
  final String code;
  final String semester;

  SubjectSimple({required this.id, required this.name, required this.code, required this.semester});

  factory SubjectSimple.fromJson(Map<String, dynamic> json) {
    return SubjectSimple(
      // Adjust keys based on your actual API response structure for 'getAssignedSubjects'
      id: json['subject_id'] ?? 0, 
      name: json['subject_name'] ?? 'Unknown',
      code: json['subject_code'] ?? '',
      semester: json['semester'].toString(),
    );
  }
}

// --- Provider to fetch Professor's Subjects ---
final mySubjectsProvider = FutureProvider.autoDispose<List<SubjectSimple>>((ref) async {
  final dio = Dio(); // Use your configured Dio instance
  // API Endpoint from your document (7.6 Get Assigned Subjects)
  // Assuming your backend handles "my subjects" via token, or you might need to pass faculty_id
  // If your backend requires ID: queryParameters: {'faculty_id': user.id}
  final response = await dio.get('http://10.0.2.2:8000/api/subjects/professor/subjects/');
  
  return (response.data as List).map((e) => SubjectSimple.fromJson(e)).toList();
});

class SubjectListScreen extends ConsumerWidget {
  const SubjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(mySubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Select Subject for IA")),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (subjects) {
          if (subjects.isEmpty) return const Center(child: Text("No subjects assigned."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Text(subject.semester)),
                  title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subject.code),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to the IA Entry Screen we created earlier
                    context.push(
                      '/ia/create/${subject.id}', 
                      extra: subject.name
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}