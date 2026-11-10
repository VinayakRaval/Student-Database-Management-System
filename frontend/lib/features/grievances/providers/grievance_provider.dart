import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/grievance_model.dart';

class GrievanceProvider with ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  static final List<GrievanceCategoryModel> defaultCategories = [
    GrievanceCategoryModel(id: 1, code: "ACADEMIC", name: "Academic and IA marks", defaultTargetRole: "HOD", slaDays: 7),
    GrievanceCategoryModel(id: 2, code: "ATTENDANCE", name: "Attendance and timetable", defaultTargetRole: "HOD", slaDays: 5),
    GrievanceCategoryModel(id: 3, code: "FACULTY", name: "Faculty-related concerns", defaultTargetRole: "HOD", slaDays: 5),
    GrievanceCategoryModel(id: 4, code: "ADMISSION", name: "Admission and student records", defaultTargetRole: "ADMISSION", slaDays: 7),
    GrievanceCategoryModel(id: 5, code: "FEES", name: "Fees and payments", defaultTargetRole: "ACCOUNTS", slaDays: 5),
    GrievanceCategoryModel(id: 6, code: "LIBRARY", name: "Library services", defaultTargetRole: "LIBRARY", slaDays: 5),
    GrievanceCategoryModel(id: 7, code: "INFRASTRUCTURE", name: "Infrastructure and laboratory facilities", defaultTargetRole: "HOD", slaDays: 7),
    GrievanceCategoryModel(id: 8, code: "TECHNICAL", name: "Technical issues", defaultTargetRole: "SYSTEM", slaDays: 3),
    GrievanceCategoryModel(id: 9, code: "HARASSMENT", name: "Harassment and safety", defaultTargetRole: "PRINCIPAL", slaDays: 2, isConfidentialByDefault: true),
    GrievanceCategoryModel(id: 10, code: "OTHER", name: "Other / Custom", defaultTargetRole: "HOD", slaDays: 7),
  ];

  List<GrievanceModel> _grievances = [];
  List<GrievanceCategoryModel> _categories = List.from(defaultCategories);
  List<OfficerModel> _officers = [];
  GrievanceStatsModel? _stats;
  GrievanceModel? _selectedGrievance;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Filters & State
  String _activeScope = "assigned"; // "assigned", "my", "department", "all", "escalated"
  String? _filterStatus;
  String? _filterCategory;
  String? _filterPriority;
  String _searchQuery = "";
  bool _filterOverdueOnly = false;

  // Getters
  List<GrievanceModel> get grievances => _grievances;
  List<GrievanceCategoryModel> get categories => _categories;
  List<OfficerModel> get officers => _officers;
  GrievanceStatsModel? get stats => _stats;
  GrievanceModel? get selectedGrievance => _selectedGrievance;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  String get activeScope => _activeScope;
  String? get filterStatus => _filterStatus;
  String? get filterCategory => _filterCategory;
  String? get filterPriority => _filterPriority;
  String get searchQuery => _searchQuery;
  bool get filterOverdueOnly => _filterOverdueOnly;

  void setScope(String scope) {
    if (_activeScope != scope) {
      _activeScope = scope;
      fetchGrievances();
    }
  }

  void setFilters({
    String? status,
    String? category,
    String? priority,
    String? search,
    bool? overdueOnly,
  }) {
    if (status != null) _filterStatus = status.isEmpty ? null : status;
    if (category != null) _filterCategory = category.isEmpty ? null : category;
    if (priority != null) _filterPriority = priority.isEmpty ? null : priority;
    if (search != null) _searchQuery = search;
    if (overdueOnly != null) _filterOverdueOnly = overdueOnly;
    fetchGrievances();
  }

  void clearFilters() {
    _filterStatus = null;
    _filterCategory = null;
    _filterPriority = null;
    _searchQuery = "";
    _filterOverdueOnly = false;
    fetchGrievances();
  }

  // 1. Fetch Grievances List
  Future<void> fetchGrievances() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (_activeScope.isNotEmpty && _activeScope != "all") {
        queryParams['scope'] = _activeScope;
      }
      if (_filterStatus != null) queryParams['status'] = _filterStatus;
      if (_filterCategory != null) queryParams['category'] = _filterCategory;
      if (_filterPriority != null) queryParams['priority'] = _filterPriority;
      if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;
      if (_filterOverdueOnly) queryParams['is_overdue'] = 'true';

      final res = await _dio.get('/grievances/', queryParameters: queryParams);
      final dynamic raw = res.data;
      final List list = raw is List ? raw : (raw is Map && raw['results'] is List ? raw['results'] : []);

      _grievances = list.map((e) => GrievanceModel.fromMap(e as Map<String, dynamic>)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Failed to load grievances: $e";
      notifyListeners();
    }
  }

  // 2. Fetch Metrics & Statistics
  Future<void> fetchStats() async {
    try {
      final res = await _dio.get('/grievances/stats/');
      if (res.data is Map) {
        _stats = GrievanceStatsModel.fromMap(res.data as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (e) {
      // stats error shouldn't crash app
    }
  }

  // 3. Fetch Categories
  Future<void> fetchCategories() async {
    try {
      final res = await _dio.get('/grievances/categories/');
      final dynamic raw = res.data;
      final List list = raw is List ? raw : (raw is Map && raw['results'] is List ? raw['results'] : []);
      if (list.isNotEmpty) {
        _categories = list.map((e) => GrievanceCategoryModel.fromMap(e as Map<String, dynamic>)).toList();
        notifyListeners();
      }
    } catch (e) {
      // keep pre-seeded default categories
    }
  }

  // Add / register custom category
  Future<GrievanceCategoryModel> addCustomCategory(String name) async {
    final trimmed = name.trim();
    final existing = _categories.firstWhere(
      (c) => c.name.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => GrievanceCategoryModel(id: 0, code: '', name: ''),
    );
    if (existing.id != 0) return existing;

    try {
      final code = trimmed.toUpperCase().replaceAll(' ', '_');
      final res = await _dio.post('/grievances/categories/', data: {
        'code': code.length > 50 ? code.substring(0, 50) : code,
        'name': trimmed,
        'default_target_role': 'HOD',
        'sla_days': 7,
      });
      if (res.data is Map) {
        final cat = GrievanceCategoryModel.fromMap(res.data as Map<String, dynamic>);
        _categories.add(cat);
        notifyListeners();
        return cat;
      }
    } catch (_) {}

    final newId = 1000 + _categories.length;
    final cat = GrievanceCategoryModel(
      id: newId,
      code: trimmed.toUpperCase().replaceAll(' ', '_'),
      name: trimmed,
      defaultTargetRole: 'HOD',
      slaDays: 7,
    );
    _categories.add(cat);
    notifyListeners();
    return cat;
  }

  // 4. Fetch Officers for Assignment
  Future<void> fetchOfficers() async {
    try {
      final res = await _dio.get('/grievances/officers/');
      if (res.data is List) {
        _officers = (res.data as List).map((e) => OfficerModel.fromMap(e as Map<String, dynamic>)).toList();
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  // 5. Fetch Single Grievance Details
  Future<GrievanceModel?> fetchGrievanceDetail(int id) async {
    try {
      final res = await _dio.get('/grievances/$id/');
      if (res.data is Map) {
        final g = GrievanceModel.fromMap(res.data as Map<String, dynamic>);
        _selectedGrievance = g;
        notifyListeners();
        return g;
      }
    } catch (e) {
      _errorMessage = "Failed to load grievance details: $e";
      notifyListeners();
    }
    return null;
  }

  // 6. Submit Grievance
  Future<bool> submitGrievance({
    required String topic,
    required String description,
    int? categoryId,
    String? categoryName,
    String priority = 'MEDIUM',
    String? targetRole,
    int? targetUserId,
    bool isConfidential = false,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mapData = <String, dynamic>{
        'topic': topic,
        'description': description,
        'priority': priority,
        'is_confidential': isConfidential,
      };
      if (categoryId != null) mapData['category_id'] = categoryId;
      if (categoryName != null) mapData['category_name'] = categoryName;
      if (targetRole != null) mapData['target_role'] = targetRole;
      if (targetUserId != null) mapData['target_user'] = targetUserId;

      dynamic payload;
      if (fileBytes != null && fileName != null) {
        mapData['attachment'] = MultipartFile.fromBytes(fileBytes, filename: fileName);
        payload = FormData.fromMap(mapData);
      } else {
        payload = mapData;
      }

      await _dio.post('/grievances/', data: payload);
      _isSubmitting = false;
      await fetchGrievances();
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to submit grievance");
      notifyListeners();
      return false;
    }
  }

  // 7. Update Status
  Future<bool> updateStatus(
    int id, {
    required String status,
    String? notes,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mapData = <String, dynamic>{
        'status': status,
        'notes': notes ?? '',
      };
      dynamic payload;
      if (fileBytes != null && fileName != null) {
        mapData['attachment'] = MultipartFile.fromBytes(fileBytes, filename: fileName);
        payload = FormData.fromMap(mapData);
      } else {
        payload = mapData;
      }

      await _dio.post('/grievances/$id/update_status/', data: payload);
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to update status");
      notifyListeners();
      return false;
    }
  }

  // 8. Assign / Reassign Officer
  Future<bool> assignOfficer(
    int id, {
    required int targetUserId,
    String? targetRole,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dio.post('/grievances/$id/assign/', data: {
        'target_user_id': targetUserId,
        'target_role': targetRole ?? '',
        'notes': notes ?? '',
      });
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to assign officer");
      notifyListeners();
      return false;
    }
  }

  // 9. Request Information from Complainant
  Future<bool> requestInfo(int id, {required String notes}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dio.post('/grievances/$id/request_info/', data: {'notes': notes});
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to request information");
      notifyListeners();
      return false;
    }
  }

  // 10. Provide Information (Complainant)
  Future<bool> provideInfo(
    int id, {
    required String notes,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mapData = <String, dynamic>{'notes': notes};
      dynamic payload;
      if (fileBytes != null && fileName != null) {
        mapData['attachment'] = MultipartFile.fromBytes(fileBytes, filename: fileName);
        payload = FormData.fromMap(mapData);
      } else {
        payload = mapData;
      }

      await _dio.post('/grievances/$id/provide_info/', data: payload);
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to provide information");
      notifyListeners();
      return false;
    }
  }

  // 11. Escalate Grievance
  Future<bool> escalate(
    int id, {
    required String reason,
    int? destinationUserId,
    String destinationRole = 'PRINCIPAL',
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dio.post('/grievances/$id/escalate/', data: {
        'reason': reason,
        'escalated_to_id': destinationUserId,
        'destination_role': destinationRole,
      });
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to escalate grievance");
      notifyListeners();
      return false;
    }
  }

  // 12. Resolve Grievance
  Future<bool> resolve(
    int id, {
    required String remarks,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mapData = <String, dynamic>{'resolution_remarks': remarks};
      dynamic payload;
      if (fileBytes != null && fileName != null) {
        mapData['attachment'] = MultipartFile.fromBytes(fileBytes, filename: fileName);
        payload = FormData.fromMap(mapData);
      } else {
        payload = mapData;
      }

      await _dio.post('/grievances/$id/resolve/', data: payload);
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to resolve grievance");
      notifyListeners();
      return false;
    }
  }

  // 13. Reject Grievance
  Future<bool> reject(int id, {required String reason}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dio.post('/grievances/$id/reject/', data: {'rejection_reason': reason});
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to reject grievance");
      notifyListeners();
      return false;
    }
  }

  // 14. Request Reopening (Complainant)
  Future<bool> requestReopen(int id, {required String reason}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dio.post('/grievances/$id/request_reopen/', data: {'reason': reason});
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to request reopening");
      notifyListeners();
      return false;
    }
  }

  // 15. Review Reopen Request (Officer)
  Future<bool> reviewReopen(
    int id, {
    required String decision, // "APPROVE" or "REJECT"
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dio.post('/grievances/$id/reopen/', data: {
        'decision': decision,
        'notes': notes ?? '',
      });
      _isSubmitting = false;
      await fetchGrievances();
      await fetchGrievanceDetail(id);
      await fetchStats();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = _parseError(e, "Failed to review reopening request");
      notifyListeners();
      return false;
    }
  }

  String _parseError(dynamic e, String defaultMessage) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        if (data.containsKey('error')) return data['error'].toString();
        if (data.containsKey('detail')) return data['detail'].toString();
        if (data.values.isNotEmpty) return data.values.first.toString();
      }
      return data.toString();
    }
    return "$defaultMessage: $e";
  }
}
