import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import '../models/purpose.dart';
import '../services/admin_service.dart';
import '../services/purpose_service.dart';

class PurposeManagementScreen extends StatefulWidget {
  final AdminUser adminUser;

  const PurposeManagementScreen({super.key, required this.adminUser});

  @override
  State<PurposeManagementScreen> createState() =>
      _PurposeManagementScreenState();
}

class _PurposeManagementScreenState extends State<PurposeManagementScreen> {
  final AdminService _adminService = AdminService();
  final PurposeService _purposeService = PurposeService();

  List<Purpose> _purposes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPurposes();
  }

  Future<void> _loadPurposes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load purposes from database
      await _purposeService.initializeDefaultPurposes();
      _purposes = _purposeService.getAllPurposes();
    } catch (e) {
      _showErrorSnackBar('Error loading purposes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showAddPurposeDialog() {
    // Check if admin is still logged in
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      Navigator.pop(context);
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Purpose'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Purpose Name (e.g., TOR)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showErrorSnackBar('Purpose name is required');
                return;
              }

              try {
                await _purposeService.addPurpose(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                await _loadPurposes();
                _showSuccessSnackBar('Purpose added successfully');
              } catch (e) {
                _showErrorSnackBar('Error adding purpose: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditPurposeDialog(Purpose purpose) {
    // Check if admin is still logged in
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      Navigator.pop(context);
      return;
    }

    final nameController = TextEditingController(text: purpose.name);
    final descriptionController = TextEditingController(
      text: purpose.description,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Purpose'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Purpose Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showErrorSnackBar('Purpose name is required');
                return;
              }

              try {
                await _purposeService.updatePurpose(
                  purpose.id,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                await _loadPurposes();
                _showSuccessSnackBar('Purpose updated successfully');
              } catch (e) {
                _showErrorSnackBar('Error updating purpose: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePurposeStatus(Purpose purpose) async {
    // Check if admin is still logged in
    if (!_adminService.isLoggedIn) {
      _showErrorSnackBar('Admin session expired. Please login again.');
      return;
    }

    try {
      await _purposeService.updatePurpose(
        purpose.id,
        isActive: !purpose.isActive,
      );
      await _loadPurposes();
      _showSuccessSnackBar(
        'Purpose ${purpose.isActive ? 'deactivated' : 'activated'} successfully',
      );
    } catch (e) {
      _showErrorSnackBar('Error updating purpose status: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Widget _buildPurposeCard(Purpose purpose) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF263277),
                        const Color(0xFF4A90E2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    purpose.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    purpose.description,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: purpose.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    purpose.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                // Only show edit/delete buttons if admin is logged in
                if (_adminService.isLoggedIn && _adminService.canModifyDepartments) ...[
                  IconButton(
                    onPressed: () => _showEditPurposeDialog(purpose),
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Edit Purpose',
                  ),
                  IconButton(
                    onPressed: () => _togglePurposeStatus(purpose),
                    icon: Icon(
                      purpose.isActive
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                    tooltip: purpose.isActive ? 'Deactivate' : 'Activate',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2F8),
      appBar: AppBar(
        title: const Text('Purpose Management'),
        backgroundColor: const Color(0xFF263277),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with stats
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purpose Overview',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF263277),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatCard(
                                'Total',
                                _purposes.length.toString(),
                                Icons.label,
                                Colors.blue,
                              ),
                              _buildStatCard(
                                'Active',
                                _purposes
                                    .where((p) => p.isActive)
                                    .length
                                    .toString(),
                                Icons.check_circle,
                                Colors.green,
                              ),
                              _buildStatCard(
                                'Inactive',
                                _purposes
                                    .where((p) => !p.isActive)
                                    .length
                                    .toString(),
                                Icons.cancel,
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Purposes list
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Purposes',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFF263277),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        // Only show Add Purpose button if admin is logged in
                        if (_adminService.isLoggedIn && _adminService.canModifyDepartments)
                          ElevatedButton.icon(
                            onPressed: _showAddPurposeDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Purpose'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF263277),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: _purposes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.label_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No purposes found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: _purposes.length,
                              itemBuilder: (context, index) {
                                return _buildPurposeCard(_purposes[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

