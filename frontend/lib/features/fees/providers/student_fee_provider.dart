import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';
import '../models/student_fee_model.dart';

// --- HELPER ---
List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map<String, dynamic> && data.containsKey('results')) {
    return data['results'] as List;
  }
  return [];
}

// 1. FETCH FEES (For Fee List Screen - Protected)
final studentFeeListProvider = FutureProvider.autoDispose<List<StudentFee>>((
  ref,
) async {
  final dio = ApiClient().dio;
  try {
    final response = await dio.get('/fees/student-fees/my-fees/');
    final list = _extractList(response.data);
    return list.map((e) => StudentFee.fromJson(e)).toList();
  } catch (e) {
    throw Exception("Failed to load fees: $e");
  }
});

// 2. PAYMENT UPLOAD NOTIFIER
class PaymentUploadState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  PaymentUploadState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });
}

class PaymentUploadNotifier extends StateNotifier<PaymentUploadState> {
  PaymentUploadNotifier() : super(PaymentUploadState());

  // ✅ Uses the Public Endpoint defined in urls.py
  Future<bool> submitPayment({
    required int studentId,
    required int feeStructureId,
    required String mode, // 'bank' or 'upi'
    required String txnId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    state = PaymentUploadState(isLoading: true);
    final dio = ApiClient().dio;

    try {
      // Matches backend: views.py -> submit_student_payment
      final formData = FormData.fromMap({
        "student_id": studentId,
        "fee_structure_id": feeStructureId,
        "payment_method": mode,
        "upi_transaction_id":
            txnId, // Backend uses this field key for UPI logic
        "fee_receipt": MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await dio.post(
        '/fees/payments/',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = PaymentUploadState(isLoading: false, isSuccess: true);
        return true;
      } else {
        state = PaymentUploadState(
          isLoading: false,
          error: "Failed: ${response.statusCode} - ${response.data}",
        );
        return false;
      }
    } catch (e) {
      state = PaymentUploadState(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final paymentUploadProvider =
    StateNotifierProvider<PaymentUploadNotifier, PaymentUploadState>((ref) {
      return PaymentUploadNotifier();
    });
