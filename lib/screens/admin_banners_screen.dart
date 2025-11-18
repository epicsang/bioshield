// lib/screens/admin_banners_screen.dart
// Banner Management Screen - Add, Edit, Delete advertisement banners
// Matches Wireframe 7.13

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/admin_service.dart';
import 'package:intl/intl.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _isLoading = true);

    try {
      final banners = await _adminService.getAllBanners();
      setState(() {
        _banners = banners;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading banners: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  "Advertisement Banners",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddEditBannerDialog(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text("Add Banner"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSkyBlue,
                  foregroundColor: kAuthNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Banner List
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _banners.isEmpty)
            const Expanded(child: Center(child: Text("No banners found. Add your first banner!"))),
          if (!_isLoading && _banners.isNotEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBanners,
                child: ListView.builder(
                  itemCount: _banners.length,
                  itemBuilder: (context, index) {
                    final banner = _banners[index];
                    return _buildBannerCard(banner);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    final isActive = banner['status'] == 'active';
    final startDate = banner['startDate'] as String;
    final endDate = banner['endDate'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: isActive ? Colors.green : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: isActive ? Colors.green.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? "Active" : "Inactive",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: kAuthNavy),
                    onPressed: () => _showAddEditBannerDialog(banner: banner),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBanner(banner),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Banner Content
          Text(
            banner['content'],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Date Range
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                "Start: $startDate",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                "End: $endDate",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEditBannerDialog({Map<String, dynamic>? banner}) {
    final isEdit = banner != null;
    final contentController = TextEditingController(text: banner?['content'] ?? '');
    final startDateController = TextEditingController(text: banner?['startDate'] ?? '');
    final endDateController = TextEditingController(text: banner?['endDate'] ?? '');
    String status = banner?['status'] ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: kAuthNavy,
            titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            contentTextStyle: const TextStyle(color: Colors.white),
            title: Text(isEdit ? "Edit Banner" : "Add New Banner"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Content Field
                  TextField(
                    controller: contentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Banner Content",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kSkyBlue)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Start Date
                  TextField(
                    controller: startDateController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Start Date (YYYY-MM-DD)",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kSkyBlue)),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        startDateController.text = DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // End Date
                  TextField(
                    controller: endDateController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "End Date (YYYY-MM-DD)",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kSkyBlue)),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        endDateController.text = DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Status Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Status:", style: TextStyle(color: Colors.white)),
                      DropdownButton<String>(
                        value: status,
                        dropdownColor: kAuthNavy,
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text("Active")),
                          DropdownMenuItem(value: 'inactive', child: Text("Inactive")),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            status = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
                onPressed: () async {
                  if (contentController.text.isEmpty ||
                      startDateController.text.isEmpty ||
                      endDateController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill all fields")),
                    );
                    return;
                  }

                  try {
                    if (isEdit) {
                      await _adminService.updateBanner(
                        bannerId: banner['bannerId'],
                        content: contentController.text,
                        startDate: startDateController.text,
                        endDate: endDateController.text,
                        status: status,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Banner updated")),
                      );
                    } else {
                      await _adminService.addBanner(
                        content: contentController.text,
                        startDate: startDateController.text,
                        endDate: endDateController.text,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Banner added")),
                      );
                    }

                    Navigator.pop(ctx);
                    _loadBanners();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                },
                child: Text(isEdit ? "Update" : "Add", style: const TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteBanner(Map<String, dynamic> banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Banner"),
        content: const Text("Are you sure you want to delete this banner?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _adminService.deleteBanner(banner['bannerId']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Banner deleted")),
      );
      _loadBanners();
    }
  }
}