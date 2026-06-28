import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoUploadCard extends StatefulWidget {
  final String title;
  final Uint8List? initialBytes;
  final String? fileName;
  final Function(Uint8List?, String?) onChanged;

  const PhotoUploadCard({
    super.key,
    required this.title,
    this.initialBytes,
    this.fileName,
    required this.onChanged,
  });

  @override
  State<PhotoUploadCard> createState() => _PhotoUploadCardState();
}

class _PhotoUploadCardState extends State<PhotoUploadCard> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFile() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        widget.onChanged(bytes, picked.name);
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  void _removeFile() {
    widget.onChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    bool hasFile = widget.initialBytes != null;

    return Container(
      width: 160,
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon or Preview
          Expanded(
            child: hasFile
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      widget.initialBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : const Icon(
                    Icons.attach_file,
                    size: 40,
                    color: Color(0xFF6D2AA8),
                  ), // Purple icon
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            widget.title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Action Text
          TextButton(
            onPressed: hasFile ? _removeFile : _pickFile,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              hasFile ? "Remove" : "Upload File",
              style: TextStyle(
                fontSize: 12,
                color: hasFile ? Colors.red : const Color(0xFF6D2AA8),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
