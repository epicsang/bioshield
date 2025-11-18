// lib/screens/admin_requests_screen.dart
// Admin Support Requests Screen - Handle user requests for account activation/password reset

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import 'package:intl/intl.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String _filterStatus = 'All'; // All, Pending, Resolved

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _db
          .collection('supportRequests')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _requests = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'requestId': doc.id,
            'userId': data['userId'] ?? '',
            'userEmail': data['userEmail'] ?? 'Unknown',
            'requestType': data['requestType'] ?? 'unknown',
            'status': data['status'] ?? 'pending',
            'createdAt': data['createdAt'],
            'resolvedAt': data['resolvedAt'],
            'resolvedBy': data['resolvedBy'],
            'message': data['message'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });

      print('📊 Loaded ${_requests.length} support requests');
    } catch (e) {
      print('❌ Error loading requests: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_filterStatus == 'All') return _requests;
    return _requests.where((r) => r['status'] == _filterStatus.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Support Requests",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy),
          ),
          const SizedBox(height: 10),
          const Text(
            "User requests for account activation and password resets",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Filter Chips
          Wrap(
            spacing: 8,
            children: [
              const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
              ChoiceChip(
                label: const Text("All"),
                selected: _filterStatus == 'All',
                onSelected: (selected) {
                  setState(() => _filterStatus = 'All');
                },
              ),
              ChoiceChip(
                label: const Text("Pending"),
                selected: _filterStatus == 'Pending',
                selectedColor: Colors.orange.shade200,
                onSelected: (selected) {
                  setState(() => _filterStatus = 'Pending');
                },
              ),
              ChoiceChip(
                label: const Text("Resolved"),
                selected: _filterStatus == 'Resolved',
                selectedColor: Colors.green.shade200,
                onSelected: (selected) {
                  setState(() => _filterStatus = 'Resolved');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Request List
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _filteredRequests.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No support requests found",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          if (!_isLoading && _filteredRequests.isNotEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRequests,
                child: ListView.builder(
                  itemCount: _filteredRequests.length,
                  itemBuilder: (context, index) {
                    final request = _filteredRequests[index];
                    return _buildRequestCard(request);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final isPending = request['status'] == 'pending';
    final requestType = request['requestType'] as String;
    final createdAt = request['createdAt'] as Timestamp?;

    IconData iconData;
    Color iconColor;
    String typeLabel;

    switch (requestType) {
      case 'account_activation':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        typeLabel = "Account Activation";
        break;
      case 'password_reset':
        iconData = Icons.lock_reset;
        iconColor = Colors.orange;
        typeLabel = "Password Reset";
        break;
      default:
        iconData = Icons.help;
        iconColor = Colors.grey;
        typeLabel = "Unknown Request";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPending ? Colors.orange.shade300 : Colors.green.shade300,
          width: isPending ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request['userEmail'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPending ? "Pending" : "Resolved",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (request['message'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request['message'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                createdAt != null
                    ? DateFormat('MMM d, yyyy - HH:mm').format(createdAt.toDate())
                    : "Unknown date",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (isPending)
                ElevatedButton.icon(
                  onPressed: () => _handleRequest(request),
                  icon: const Icon(Icons.done, size: 16),
                  label: const Text("Resolve"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleRequest(Map<String, dynamic> request) async {
    final requestType = request['requestType'];
    final userId = request['userId'];
    final userEmail = request['userEmail'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kAuthNavy,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Colors.white),
        title: Text("Resolve ${requestType == 'account_activation' ? 'Activation' : 'Password Reset'} Request"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("User: $userEmail"),
            const SizedBox(height: 16),
            if (requestType == 'account_activation')
              const Text("This will activate the user's account and allow them to log in.")
            else
              const Text("This will send a password reset email to the user."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Resolve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Perform the action
        if (requestType == 'account_activation') {
          // Activate user account
          await _db.collection('users').doc(userId).update({
            'accountStatus': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (requestType == 'password_reset') {
          // In a real app, you'd trigger password reset email here
          // For now, just mark as resolved
          print('Password reset request resolved for $userEmail');
        }

        // Mark request as resolved
        await _db.collection('supportRequests').doc(request['requestId']).update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': 'admin', // You can add admin user ID here
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request resolved for $userEmail")),
        );

        _loadRequests();
      } catch (e) {
        print('❌ Error resolving request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}