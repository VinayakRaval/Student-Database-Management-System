import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class PlacementCompaniesScreen extends StatefulWidget {
  const PlacementCompaniesScreen({super.key});

  @override
  State<PlacementCompaniesScreen> createState() =>
      _PlacementCompaniesScreenState();
}

class _PlacementCompaniesScreenState extends State<PlacementCompaniesScreen> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  List<Map<String, dynamic>> _companies = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get('/placement/companies/');
      final raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      setState(() {
        _companies = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredCompanies {
    if (_searchQuery.trim().isEmpty) return _companies;
    final q = _searchQuery.toLowerCase();
    return _companies.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final ind = (c['industry'] ?? '').toString().toLowerCase();
      final loc = (c['location'] ?? '').toString().toLowerCase();
      return name.contains(q) || ind.contains(q) || loc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Recruiting Partner Companies",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Companies",
            onPressed: _fetchCompanies,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: "Search company by name, industry, or location...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_business_rounded, size: 18),
                      label: const Text("Add Company", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showAddCompanyDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF13246E))))
                else if (_filteredCompanies.isEmpty)
                  _buildEmptyState()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisExtent: 180,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: _filteredCompanies.length,
                    itemBuilder: (ctx, i) {
                      final c = _filteredCompanies[i];
                      final name = (c['name'] ?? 'Company Name').toString();
                      final industry = (c['industry'] ?? 'Technology').toString();
                      final location = (c['location'] ?? 'Location').toString();
                      final email = (c['contact_email'] ?? 'careers@company.com').toString();
                      final website = (c['website'] ?? '').toString();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13246E).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.business_rounded, color: Color(0xFF13246E), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(industry, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(child: Text(location, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(child: Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            if (website.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.language_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(website, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("No Recruiting Companies Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty ? "No companies match your search." : "No partner recruiting companies registered yet. Add companies to schedule campus drives.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Register Company"),
            onPressed: _showAddCompanyDialog,
          ),
        ],
      ),
    );
  }

  void _showAddCompanyDialog() {
    final nameCtrl = TextEditingController();
    final indCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final webCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Recruiting Company", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Company Name *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              TextField(controller: indCtrl, decoration: InputDecoration(labelText: "Industry (e.g. IT, FinTech, Core)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              TextField(controller: locCtrl, decoration: InputDecoration(labelText: "Location (e.g. Bengaluru, Remote)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              TextField(controller: emailCtrl, decoration: InputDecoration(labelText: "Contact Email", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              TextField(controller: webCtrl, decoration: InputDecoration(labelText: "Website URL", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                try {
                  await _dio.post('/placement/companies/', data: {
                    'name': nameCtrl.text.trim(),
                    'industry': indCtrl.text.trim(),
                    'location': locCtrl.text.trim(),
                    'contact_email': emailCtrl.text.trim(),
                    'website': webCtrl.text.trim(),
                  });
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchCompanies();
              }
            },
            child: const Text("Add Company"),
          ),
        ],
      ),
    );
  }
}
