import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class PlacementOffersScreen extends StatefulWidget {
  const PlacementOffersScreen({super.key});

  @override
  State<PlacementOffersScreen> createState() => _PlacementOffersScreenState();
}

class _PlacementOffersScreenState extends State<PlacementOffersScreen> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  List<Map<String, dynamic>> _offers = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOffers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get('/placement/offers/');
      final raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      setState(() {
        _offers = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOffers {
    if (_searchQuery.trim().isEmpty) return _offers;
    final q = _searchQuery.toLowerCase();
    return _offers.where((o) {
      final name = (o['student_name'] ?? '').toString().toLowerCase();
      final usn = (o['student_usn'] ?? '').toString().toLowerCase();
      final comp = (o['company_name'] ?? '').toString().toLowerCase();
      final des = (o['designation'] ?? '').toString().toLowerCase();
      return name.contains(q) || usn.contains(q) || comp.contains(q) || des.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Placement Offers & Selections",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Offers",
            onPressed: _fetchOffers,
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
                // Top Search Bar
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: "Search offer by candidate name, USN, company, or role...",
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
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF13246E))))
                else if (_filteredOffers.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredOffers.map((offer) {
                    final name = (offer['student_name'] ?? 'Candidate Name').toString();
                    final usn = (offer['student_usn'] ?? 'USN').toString();
                    final comp = (offer['company_name'] ?? 'Company').toString();
                    final des = (offer['designation'] ?? 'Software Engineer').toString();
                    final lpa = offer['offered_package_lpa'] != null ? "${offer['offered_package_lpa']} LPA" : "Standard Package";
                    final date = (offer['offer_date'] ?? 'Recent').toString();
                    final status = (offer['status'] ?? 'OFFERED').toString().toUpperCase();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF059669), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                    const SizedBox(width: 8),
                                    Text("($usn)", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("$des • $comp", style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text("Offer Date: $date", style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              lpa,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
          Icon(Icons.workspace_premium_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("No Placement Offers Recorded", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            "Offers released by recruiting companies will be documented here with salary packages.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
