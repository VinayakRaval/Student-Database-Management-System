import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/fee_creation_provider.dart';
import '../providers/fee_action_provider.dart';
import '../models/fee_structure_models.dart';

class FeeStructureCreateScreen extends ConsumerStatefulWidget {
  final int? feeId;
  const FeeStructureCreateScreen({super.key, this.feeId});

  @override
  ConsumerState<FeeStructureCreateScreen> createState() =>
      _FeeStructureCreateScreenState();
}

class _FeeStructureCreateScreenState
    extends ConsumerState<FeeStructureCreateScreen> {
  int? _selectedDept;
  int? _selectedYear;
  int? _selectedSem;
  String _selectedSeat = 'gm';

  final List<Map<String, String>> seatOptions = [
    {'label': 'General Merit (GM)', 'value': 'gm'},
    {'label': 'SNQ Quota', 'value': 'snq'},
    {'label': 'Management', 'value': 'management'},
    {'label': 'Lateral Entry', 'value': 'lateral'},
  ];

  static const List<String> _feeTypes = [
    "Registration Fee",
    "Tuition Fee",
    "Sports Fee",
    "Union Fee",
    "Library Fee",
    "Magazine Fee",
    "Library Tax",
    "Laboratory Fee",
    "ID Card Fee",
    "Student Welfare Fee",
    "Teacher's Welfare Fee",
    "Development Fee",
    "NSS Fee",
    "Other Fee",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.feeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingData());
    }
  }

  Future<void> _loadExistingData() async {
    try {
      final fee = await ref.read(
        feeStructureDetailProvider(widget.feeId!).future,
      );
      setState(() => _selectedSeat = fee.seatType.toLowerCase());
      ref.read(feeCreationProvider.notifier).loadExistingData(fee);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      }
    }
  }

  Future<void> _addNewItem(
    String endpoint,
    String fieldName,
    String label,
    dynamic provider,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add $label"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter $label",
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access');
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8000',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      await dio.post(endpoint, data: {fieldName: result});
      ref.invalidate(provider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$label '$result' added!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showCustomSeatDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Custom Seat Type"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "e.g., nri, management-quota",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim().toLowerCase().replaceAll(
                ' ',
                '_',
              );
              if (value.isNotEmpty) {
                setState(() {
                  _selectedSeat = value;
                  seatOptions.add({
                    'label': controller.text.trim(),
                    'value': value,
                  });
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feeCreationProvider);
    final notifier = ref.read(feeCreationProvider.notifier);
    final isEdit = widget.feeId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Fee Structure" : "Create Fee Structure"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdowns(),
            const SizedBox(height: 24),
            const Text(
              "Fee Components",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.components.length,
              separatorBuilder: (c, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') return _feeTypes;
                          return _feeTypes.where((String option) {
                            return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (String selection) {
                          notifier.updateComponent(index, selection, null);
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (textController.text !=
                                      state.components[index].name &&
                                  !focusNode.hasFocus) {
                                textController.text =
                                    state.components[index].name;
                              }
                              return TextFormField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: "Component Name",
                                  border: OutlineInputBorder(),
                                  hintText: "Select or type...",
                                ),
                                onChanged: (val) =>
                                    notifier.updateComponent(index, val, null),
                              );
                            },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey("amount_$index"),
                        initialValue: state.components[index].amount == 0
                            ? ''
                            : state.components[index].amount.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Amount",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) =>
                            notifier.updateComponent(index, null, val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => notifier.removeComponent(index),
                    ),
                  ],
                );
              },
            ),
            TextButton.icon(
              onPressed: notifier.addComponent,
              icon: const Icon(Icons.add),
              label: const Text("Add Another Component"),
            ),
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Fee:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  "₹${state.totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (_selectedDept == null ||
                          _selectedYear == null ||
                          _selectedSem == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please select Department, Year, and Semester",
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      final success = await notifier.submitFeeStructure(
                        id: widget.feeId,
                        deptId: _selectedDept!,
                        yearId: _selectedYear!,
                        semId: _selectedSem!,
                        seatType: _selectedSeat,
                      );
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEdit
                                  ? "Structure Updated!"
                                  : "Structure Created!",
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        if (isEdit) {
                          context.pop();
                        } else {
                          notifier.resetForm();
                        }
                      }
                    },
                    child: Text(
                      isEdit ? "Update Structure" : "Create Structure",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdowns() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _asyncDrop(
                    "Department",
                    ref.watch(departmentListProvider),
                    _selectedDept,
                    (v) => setState(() => _selectedDept = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF13246E),
                  ),
                  onPressed: () => _addNewItem(
                    '/academics/departments/',
                    'name',
                    'Department',
                    departmentListProvider,
                  ),
                  tooltip: 'Add Department',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _asyncDrop(
                    "Year",
                    ref.watch(academicYearListProvider),
                    _selectedYear,
                    (v) => setState(() => _selectedYear = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF13246E),
                  ),
                  onPressed: () => _addNewItem(
                    '/academics/academic-years/',
                    'year_name',
                    'Academic Year',
                    academicYearListProvider,
                  ),
                  tooltip: 'Add Academic Year',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _asyncDrop(
                    "Semester",
                    ref.watch(semesterListProvider),
                    _selectedSem,
                    (v) => setState(() => _selectedSem = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF13246E),
                  ),
                  onPressed: () => _addNewItem(
                    '/academics/semesters/',
                    'sem_number',
                    'Semester Number',
                    semesterListProvider,
                  ),
                  tooltip: 'Add Semester',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSeat,
                    decoration: const InputDecoration(
                      labelText: "Seat Type",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...seatOptions.map(
                        (e) => DropdownMenuItem(
                          value: e['value'],
                          child: Text(e['label']!),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: '__custom__',
                        child: Text('+ Add Custom'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == '__custom__') {
                        _showCustomSeatDialog();
                      } else {
                        setState(() => _selectedSeat = v!);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _asyncDrop(
    String label,
    AsyncValue<List<FeeDropdownItem>> data,
    int? currentValue,
    Function(int?) onChange,
  ) {
    return data.when(
      data: (items) {
        if (items.isEmpty)
          return Text(
            "No $label found",
            style: const TextStyle(color: Colors.orange),
          );
        return DropdownButtonFormField<int>(
          value: currentValue,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          onChanged: onChange,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Error loading $label",
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text("Retry"),
            onPressed: () => ref.invalidate(departmentListProvider),
          ),
        ],
      ),
    );
  }
}
