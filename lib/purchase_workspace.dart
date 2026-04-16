import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'login_screen.dart';
import 'profile_tab.dart';

class PurchaseWorkspace extends StatefulWidget {
  final String empId;
  final String employeeName;
  final String role;

  const PurchaseWorkspace({
    super.key,
    required this.empId,
    required this.employeeName,
    required this.role,
  });

  @override
  State<PurchaseWorkspace> createState() => _PurchaseWorkspaceState();
}

class _PurchaseWorkspaceState extends State<PurchaseWorkspace> {
  int _selectedTab = 0;
  bool _isSubmitting = false;
  bool _loadingVendors = false;

  final List<Map<String, dynamic>> _vendors = [];
  final List<Map<String, dynamic>> _purchaseOrders = [];

  // Create Vendor
  final _vendorNameController = TextEditingController();
  final _vendorTypeController = TextEditingController();
  String _vendorStatus = 'PENDING';

  // Update Vendor Status
  final _updateVendorIdController = TextEditingController();
  String _selectedVendorStatus = 'ACCEPTABLE';

  // Create Purchase Order
  final _manualVendorIdController = TextEditingController();
  String _poStatus = 'CREATED';
  String? _selectedAcceptableVendorId;

  static const Set<String> _acceptableVendorStatuses = {
    'ACCEPTABLE',
    'APPROVED',
    'ACTIVE',
  };

  String get _actorEmpId => widget.empId.trim();

  List<Map<String, dynamic>> get _acceptableVendors => _vendors
      .where(
        (v) => _acceptableVendorStatuses.contains(
          (v['status'] ?? '').toString().trim().toUpperCase(),
        ),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchVendors();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiClient().clearEmpId();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedTab == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: AppTheme.bodyMedium.copyWith(
          color: isSelected ? AppTheme.primary : AppTheme.onSurface,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.of(context).pop();
        setState(() => _selectedTab = index);
      },
    );
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _vendorTypeController.dispose();
    _updateVendorIdController.dispose();
    _manualVendorIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchVendors() async {
    setState(() => _loadingVendors = true);
    try {
      final res = await ApiClient().dio.get('/api/purchase/vendors');

      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = res.data;
        if (decoded is List) {
          _vendors
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
            );
        } else {
          _vendors.clear();
        }

        // Keep selected vendor valid
        if (_selectedAcceptableVendorId != null) {
          final stillExists = _acceptableVendors.any(
            (v) => '${v['vendorId']}' == _selectedAcceptableVendorId,
          );
          if (!stillExists) {
            _selectedAcceptableVendorId = null;
          }
        }

        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to fetch vendors');
    } finally {
      if (mounted) setState(() => _loadingVendors = false);
    }
  }

  Future<void> _createVendor() async {
    final name = _vendorNameController.text.trim();
    final type = _vendorTypeController.text.trim();

    if (name.isEmpty) {
      CustomSnackbar.showError(context, 'Vendor name is required');
      return;
    }

    final body = <String, dynamic>{
      'name': name,
      'type': type.isEmpty ? null : type,
      'status': _vendorStatus,
    };

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiClient().dio.post(
            '/api/purchase/vendors',
            data: body,
          );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final vendor = res.data ?? {};
        _vendors.insert(0, vendor);
        _vendorNameController.clear();
        _vendorTypeController.clear();
        _vendorStatus = 'PENDING';
        CustomSnackbar.showSuccess(
          context,
          'Vendor created (ID: ${vendor['vendorId'] ?? '-'})',
        );
        await _fetchVendors();
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to create vendor');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateVendorStatusAction() async {
    final vendorId = int.tryParse(_updateVendorIdController.text.trim());

    if (vendorId == null) {
      CustomSnackbar.showError(
        context,
        'Vendor ID is required and must be numeric',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiClient().dio.patch(
            '/api/purchase/vendors/$vendorId/status',
            queryParameters: {'status': _selectedVendorStatus},
          );

      if (!mounted) return;

      if (res.statusCode == 200) {
        CustomSnackbar.showSuccess(
          context,
          'Vendor #$vendorId status updated to $_selectedVendorStatus',
        );
        await _fetchVendors();
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to update vendor status');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createPurchaseOrder() async {
    final selectedVendorId = _selectedAcceptableVendorId;
    final fallbackManualVendorId = int.tryParse(
      _manualVendorIdController.text.trim(),
    );

    final vendorId = selectedVendorId != null
        ? int.tryParse(selectedVendorId)
        : fallbackManualVendorId;

    if (vendorId == null) {
      CustomSnackbar.showError(
        context,
        'Select an acceptable vendor (or provide numeric vendor ID)',
      );
      return;
    }

    final body = <String, dynamic>{'vendorId': vendorId, 'status': _poStatus};

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiClient().dio.post(
            '/api/purchase/purchase-orders',
            data: body,
          );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final po = res.data ?? {};
        _purchaseOrders.insert(0, po);
        CustomSnackbar.showSuccess(
          context,
          'Purchase Order created (PO ID: ${po['poId'] ?? '-'})',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to create purchase order');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleDioError(dynamic e, String defaultMsg) {
    String msg = defaultMsg;
    if (e is DioException) {
      msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
    }
    CustomSnackbar.showError(context, msg);
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkCardDecoration
          : AppTheme.cardDecoration,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildVendorListTab() {
    return RefreshIndicator(
      onRefresh: _fetchVendors,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Text('Vendor List', style: AppTheme.headlineMedium),
                ),
                IconButton(
                  onPressed: _loadingVendors ? null : _fetchVendors,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingVendors)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_vendors.isEmpty)
            _sectionCard(
              child: Text('No vendors found.', style: AppTheme.bodyLarge),
            )
          else
            ..._vendors.map((v) {
              final status = (v['status'] ?? '').toString().toUpperCase();
              final acceptable = _acceptableVendorStatuses.contains(status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v['name'] ?? '-'} (ID: ${v['vendorId'] ?? '-'})',
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Type: ${v['type'] ?? '-'}'),
                      Text('Status: $status'),
                      const SizedBox(height: 6),
                      Text(
                        acceptable
                            ? 'Eligible for PO'
                            : 'Not eligible for PO yet',
                        style: AppTheme.bodySmall.copyWith(
                          color: acceptable ? AppTheme.success : AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCreateVendorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Vendor / Supplier', style: AppTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _vendorNameController,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Vendor Name *')
                    : AppTheme.inputDecoration('Vendor Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vendorTypeController,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Type (optional)')
                    : AppTheme.inputDecoration('Type (optional)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _vendorStatus,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Initial Status')
                    : AppTheme.inputDecoration('Initial Status'),
                items: const [
                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                  DropdownMenuItem(
                    value: 'ACCEPTABLE',
                    child: Text('ACCEPTABLE'),
                  ),
                  DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _vendorStatus = value);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _createVendor,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'CREATE VENDOR',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateVendorStatusTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update Vendor Status', style: AppTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _updateVendorIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Vendor ID *')
                    : AppTheme.inputDecoration('Vendor ID *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedVendorStatus,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('New Status *')
                    : AppTheme.inputDecoration('New Status *'),
                items: const [
                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                  DropdownMenuItem(
                    value: 'ACCEPTABLE',
                    child: Text('ACCEPTABLE'),
                  ),
                  DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                  DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedVendorStatus = value);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _updateVendorStatusAction,
                style: AppTheme.secondaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'UPDATE STATUS',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreatePoTab() {
    final acceptable = _acceptableVendors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Purchase Order', style: AppTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'Select vendor from acceptable list. Backend also enforces acceptable-only rule.',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedAcceptableVendorId,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration(
                        'Select Vendor (Acceptable Only)',
                      )
                    : AppTheme.inputDecoration(
                        'Select Vendor (Acceptable Only)',
                      ),
                items: acceptable
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: '${v['vendorId']}',
                        child: Text(
                          '${v['name'] ?? '-'} (ID: ${v['vendorId'] ?? '-'})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: acceptable.isEmpty
                    ? null
                    : (value) =>
                          setState(() => _selectedAcceptableVendorId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualVendorIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration(
                        'Manual Vendor ID (optional fallback)',
                      )
                    : AppTheme.inputDecoration(
                        'Manual Vendor ID (optional fallback)',
                      ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _poStatus,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('PO Status')
                    : AppTheme.inputDecoration('PO Status'),
                items: const [
                  DropdownMenuItem(value: 'CREATED', child: Text('CREATED')),
                  DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                  DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _poStatus = value);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _createPurchaseOrder,
                style: AppTheme.tertiaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'CREATE PO',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent POs (session)', style: AppTheme.titleLarge),
              const SizedBox(height: 10),
              if (_purchaseOrders.isEmpty)
                Text(
                  'No purchase orders created in this session.',
                  style: AppTheme.bodyMedium,
                )
              else
                ..._purchaseOrders.map(
                  (po) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'PO #${po['poId'] ?? '-'} • Vendor ${po['vendorId'] ?? '-'} • ${po['status'] ?? '-'} • ${po['date'] ?? '-'}',
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _buildVendorListTab(),
      _buildCreateVendorTab(),
      _buildUpdateVendorStatusTab(),
      _buildCreatePoTab(),
      ProfileTab(empId: _actorEmpId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Manager Workspace'),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.employeeName} • EMP ${widget.empId}',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.onPrimary),
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                margin: EdgeInsets.zero,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryVariant],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.employeeName,
                        style: AppTheme.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Purchase Manager • ID ${widget.empId}',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _drawerItem(
                icon: Icons.list_alt_outlined,
                label: 'Vendor List',
                index: 0,
              ),
              _drawerItem(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Create Vendor',
                index: 1,
              ),
              _drawerItem(
                icon: Icons.sync_alt_outlined,
                label: 'Update Vendor Status',
                index: 2,
              ),
              _drawerItem(
                icon: Icons.receipt_long_outlined,
                label: 'Create Purchase Order',
                index: 3,
              ),
              _drawerItem(
                icon: Icons.person_outline,
                label: 'My Profile',
                index: 4,
              ),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
                title: Text(
                  'Logout',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: tabs[_selectedTab],
    );
  }
}
