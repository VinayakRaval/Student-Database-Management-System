import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class LibraryFeedbackScreen extends StatefulWidget {
  const LibraryFeedbackScreen({super.key});

  @override
  State<LibraryFeedbackScreen> createState() => _LibraryFeedbackScreenState();
}

class _LibraryFeedbackScreenState extends State<LibraryFeedbackScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _feedbacks = [];
  final _responseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/feedback/');
      final List list = res.data is List ? res.data : [];
      if (mounted) {
        setState(() {
          _feedbacks = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load feedback: $e";
        });
      }
    }
  }

  Future<void> _respondToFeedback(int id) async {
    final text = _responseCtrl.text.trim();
    if (text.isEmpty) return;

    try {
      final dio = ApiClient().dio;
      await dio.post('/library/feedback/$id/respond/', data: {'response': text});
      _responseCtrl.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Response sent successfully!"), backgroundColor: Color(0xFF059669)),
        );
        _fetchFeedback();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to respond: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showResponseDialog(Map<String, dynamic> item) {
    _responseCtrl.text = item['response'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.rate_review_rounded, color: Color(0xFF13246E), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text("Respond to ${item['user_name'] ?? 'Borrower'}")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Subject: ${item['subject']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text("Message: ${item['message']}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 16),
            const Text("Officer Response:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _responseCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Enter official response or resolution notes...",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
            onPressed: () => _respondToFeedback(item['id']),
            child: const Text("Send Response"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.rate_review_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Library Feedback & Suggestions Desk",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Feedback",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchFeedback,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade700),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                        onPressed: _fetchFeedback,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : _feedbacks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_chat_read_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text("No pending library feedback records.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text("Suggestions submitted by students and faculty will appear here."),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _feedbacks.length,
                      itemBuilder: (ctx, i) {
                        final fb = _feedbacks[i];
                        final hasResponse = (fb['response'] ?? '').toString().isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF13246E).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        fb['category'] ?? 'General',
                                        style: const TextStyle(color: Color(0xFF13246E), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      fb['subject'] ?? 'Feedback',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: hasResponse ? const Color(0xFFECFDF5) : Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: hasResponse ? const Color(0xFFA7F3D0) : Colors.amber.shade300),
                                      ),
                                      child: Text(
                                        hasResponse ? "RESOLVED" : "NEEDS RESPONSE",
                                        style: TextStyle(
                                          color: hasResponse ? const Color(0xFF065F46) : Colors.amber.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(fb['message'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                                const SizedBox(height: 10),
                                Text(
                                  "By: ${fb['user_name']} (${fb['user_role'] ?? 'Borrower'}) • Rating: ${'★' * (fb['rating'] ?? 5)}",
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                                if (hasResponse) ...[
                                  const Divider(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF059669)),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Librarian Response (${fb['responded_by_name'] ?? 'Officer'}):",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF059669)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(fb['response'], style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B))),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF13246E),
                                      side: const BorderSide(color: Color(0xFF13246E)),
                                    ),
                                    onPressed: () => _showResponseDialog(fb),
                                    icon: const Icon(Icons.reply_rounded, size: 16),
                                    label: Text(hasResponse ? "Update Response" : "Respond to Borrower"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
