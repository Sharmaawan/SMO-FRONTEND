import 'package:dio/dio.dart';
import 'api_client.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

import 'app_theme.dart';
import 'login_screen.dart';
import 'models.dart';

class HrDashboardScreen extends StatefulWidget {
  final Function(bool)? setDarkMode;

  const HrDashboardScreen({super.key, this.setDarkMode});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  static const List<String> _employeeStatuses = [
    'ACTIVE',
    'RESIGNED',
    'TERMINATED',
  ];
  static const List<String> _roleStatuses = ['ACTIVE', 'INACTIVE'];

  int _selectedMenu = 0;
  bool _isLoading = false;
  String _employeeName = '';
  String _empId = '';
  HrDashboardResponse? _dashboard;
  List<RoleItem> _roles = [];
  List<EmployeeItem> _employees = [];

  final _roleIdController = TextEditingController();
  final _roleNameController = TextEditingController();
  final _roleActivityController = TextEditingController();
  String _newRoleStatus = 'ACTIVE';
  final _roleSearchController = TextEditingController();
  String _roleStatusFilter = 'ALL';
  bool _selectVisibleRoles = false;
  final Set<String> _selectedRoleIds = {};

  final _empIdController = TextEditingController();
  final _empNameController = TextEditingController();
  String? _newEmployeeRoleId;
  final _empDobController = TextEditingController();
  final _empPhoneController = TextEditingController();
  final _empAddressController = TextEditingController();
  final _empEmailController = TextEditingController();
  final _empSalaryController = TextEditingController();
  final _empDateController = TextEditingController();
  final _empBloodGroupController = TextEditingController();
  final _empEmergencyController = TextEditingController();
  final _empAadharController = TextEditingController();
  final _empPanCardController = TextEditingController();
  final _empPasswordController = TextEditingController();
  final _employeeSearchController = TextEditingController();
  String _employeeRoleFilter = 'ALL';
  bool _selectVisible = false;
  final Set<String> _selectedEmployeeIds = {};

  final _profileNameController = TextEditingController();
  final _profileEmailController = TextEditingController();
  final _profilePhoneController = TextEditingController();
  final _profileAddressController = TextEditingController();
  final _profileDobController = TextEditingController();
  final _profileBloodController = TextEditingController();
  final _profileEmergencyController = TextEditingController();
  final _profileAadharController = TextEditingController();
  final _profilePanCardController = TextEditingController();
  String _profileStatus = 'ACTIVE';
  final _profilePasswordController = TextEditingController();
  bool _isProfileEditMode = false;

  String _friendly(dynamic e) {
    if (e is DioException) {
      return e.response?.data?['message']?.toString() ?? e.message ?? e.toString();
    }
    return e.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadSessionAndData();
  }

  Future<void> _loadSessionAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _employeeName = prefs.getString('EMPLOYEE_NAME') ?? 'HR';
    _empId = prefs.getString('EMP_ID') ?? '1001';
    if (!mounted) return;
    setState(() {});
    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchDashboard(),
      _fetchRoles(),
      _fetchEmployees(),
      _fetchProfile(),
    ]);
  }

  Future<void> _fetchDashboard() async {
    // Backend doesn't have /api/hr/dashboard. Calculating stats from existing data.
    if (_roles.isEmpty || _employees.isEmpty) {
      await Future.wait([_fetchRoles(), _fetchEmployees()]);
    }
    if (mounted) {
      setState(() {
        _dashboard = HrDashboardResponse(
          totalRoles: _roles.length,
          totalEmployees: _employees.length,
        );
      });
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final res = await ApiClient().dio.get('/api/hr/roles');
      if (res.statusCode == 200 && mounted) {
        final list = (res.data as List<dynamic>)
            .map((e) => RoleItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _roles = list);
      }
    } catch (e) {
      dev.log('Error fetching roles: ${_friendly(e)}');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await ApiClient().dio.get('/api/hr/employees');
      if (res.statusCode == 200 && mounted) {
        final list = (res.data as List<dynamic>)
            .map((e) => EmployeeItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _employees = list);
      }
    } catch (e) {
      dev.log('Error fetching employees: ${_friendly(e)}');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await ApiClient().dio.get('/api/hr/employees/$_empId');
      if (res.statusCode == 200 && mounted) {
        final p = HrProfileResponse.fromJson(res.data);
        _profileNameController.text = p.empName;
        _profileEmailController.text = p.email;
        _profilePhoneController.text = p.phone;
        _profileAddressController.text = p.address;
        _profileDobController.text = p.dob;
        _profileBloodController.text = p.bloodGroup;
        _profileEmergencyController.text = p.emergencyContact;
        _profileAadharController.text = p.aadharNumber;
        _profilePanCardController.text = p.panCardNumber;
        _profileStatus = _employeeStatuses.contains(p.status.toUpperCase())
            ? p.status.toUpperCase()
            : 'ACTIVE';
        setState(() {});
      }
    } catch (e) {
      dev.log('Error fetching profile: ${_friendly(e)}');
    }
  }

  Future<void> _createRole() async {
    final roleIdStr = _roleIdController.text.trim();
    final roleId = int.tryParse(roleIdStr);
    if (roleId == null || _roleNameController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, 'Valid Numeric Role ID and Role Name are required');
      return;
    }

    setState(() => _isLoading = true);
    final req = CreateRoleRequest(
      roleId: roleId,
      roleName: _roleNameController.text.trim(),
      activity: _roleActivityController.text.trim(),
      status: _newRoleStatus,
    );

    try {
      final res = await ApiClient().dio.post(
            '/api/hr/roles',
            data: req.toJson(),
          );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (res.statusCode == 200) {
        CustomSnackbar.showSuccess(context, 'Role created');
        _roleIdController.clear();
        _roleNameController.clear();
        _roleActivityController.clear();
        _newRoleStatus = 'ACTIVE';
        await _fetchRoles();
        await _fetchDashboard();
      } else {
        CustomSnackbar.showError(context, 'Role creation failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackbar.showError(context, 'Role creation failed: ${_friendly(e)}');
    }
  }

  Future<void> _createEmployee() async {
    final selectedRole = _roles.firstWhere((r) => r.roleId.toString() == _newEmployeeRoleId);
    final empId = int.tryParse(_empIdController.text.trim());

    final salary = _empSalaryController.text.trim().isEmpty
        ? null
        : double.tryParse(_empSalaryController.text.trim());
    if (empId == null ||
        _empNameController.text.trim().isEmpty ||
        _empEmailController.text.trim().isEmpty ||
        _empDateController.text.trim().isEmpty ||
        _empPasswordController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, 'Fill required employee fields (ID must be numeric)');
      return;
    }

    setState(() => _isLoading = true);
    final employeeReq = CreateEmployeeRequest(
      empId: empId.toString(),
      empName: _empNameController.text.trim(),
      role: selectedRole,
      dob: _empDobController.text.trim().isEmpty
          ? null
          : _empDobController.text.trim(),
      phone: _empPhoneController.text.trim().isEmpty
          ? null
          : _empPhoneController.text.trim(),
      address: _empAddressController.text.trim().isEmpty
          ? null
          : _empAddressController.text.trim(),
      email: _empEmailController.text.trim(),
      salary: salary,
      empDate: _empDateController.text.trim(),
      bloodGroup: _empBloodGroupController.text.trim().isEmpty
          ? null
          : _empBloodGroupController.text.trim(),
      emergencyContact: _empEmergencyController.text.trim().isEmpty
          ? null
          : _empEmergencyController.text.trim(),
      aadharNumber: _empAadharController.text.trim().isEmpty
          ? null
          : _empAadharController.text.trim(),
      panCardNumber: _empPanCardController.text.trim().isEmpty
          ? null
          : _empPanCardController.text.trim(),
      status: 'ACTIVE',
    );

    try {
      // Debug: Print the request payload
      debugPrint('Creating employee with payload: ${employeeReq.toJson()}');
      
      // 1. Create EmployeeInfo
      final empRes = await ApiClient().dio.post(
            '/api/hr/employees',
            data: employeeReq.toJson(),
          );

      debugPrint('Employee creation response: ${empRes.statusCode} - ${empRes.data}');

      if (empRes.statusCode == 200 || empRes.statusCode == 201) {
        // Verify employee was actually created by checking response data
        if (empRes.data == null) {
          throw Exception('Server returned success but no employee data');
        }
        
        // 2. Create EmployeeLogin
        final loginReq = CreateLoginRequest(
          empId: empId.toString(),
          password: _empPasswordController.text.trim(),
        );
        debugPrint('Creating login with: ${loginReq.toJson()}');
        
        try {
          await ApiClient().dio.post('/api/hr/login', data: loginReq.toJson());
        } catch (loginError) {
          debugPrint('Login creation failed (non-critical): $loginError');
          // Don't fail the whole operation if login creation fails
        }

        if (!mounted) return;
        setState(() => _isLoading = false);
        
        // Verify employee was created by checking response
        final createdEmpId = empRes.data?['empId'];
        if (createdEmpId == null) {
          CustomSnackbar.showError(context, 'Employee creation failed: Invalid response from server');
          return;
        }
        
        CustomSnackbar.showSuccess(context, 'Employee created successfully (ID: $createdEmpId)');
        _clearEmployeeForm();
        await _fetchEmployees();
        await _fetchDashboard();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, 'Employee creation failed: HTTP ${empRes.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Employee creation failed: $e');
      CustomSnackbar.showError(context, 'Employee creation failed: ${_friendly(e)}');
    }
  }

  Future<bool> _updateProfile() async {
    if (_profileNameController.text.trim().isEmpty ||
        _profileEmailController.text.trim().isEmpty) {
      CustomSnackbar.showError(context, 'Name and email are required');
      return false;
    }
    setState(() => _isLoading = true);
    
    // Fetch current profile to get the role object (needed for PUT employee)
    final profileRes = await ApiClient().dio.get('/api/hr/employees/$_empId');
    if (profileRes.statusCode != 200) {
       setState(() => _isLoading = false);
       return false;
    }
    final currentProfile = HrProfileResponse.fromJson(profileRes.data);

    final empReq = CreateEmployeeRequest(
      empId: _empId,
      empName: _profileNameController.text.trim(),
      role: currentProfile.role,
      email: _profileEmailController.text.trim(),
      phone: _profilePhoneController.text.trim().isEmpty
          ? null
          : _profilePhoneController.text.trim(),
      address: _profileAddressController.text.trim().isEmpty
          ? null
          : _profileAddressController.text.trim(),
      dob: _profileDobController.text.trim().isEmpty
          ? null
          : _profileDobController.text.trim(),
      bloodGroup: _profileBloodController.text.trim().isEmpty
          ? null
          : _profileBloodController.text.trim(),
      emergencyContact: _profileEmergencyController.text.trim().isEmpty
          ? null
          : _profileEmergencyController.text.trim(),
      aadharNumber: _profileAadharController.text.trim().isEmpty
          ? null
          : _profileAadharController.text.trim(),
      panCardNumber: _profilePanCardController.text.trim().isEmpty
          ? null
          : _profilePanCardController.text.trim(),
      status: _profileStatus,
      empDate: '2024-01-01', // Fallback
    );

    try {
      final res = await ApiClient().dio.put(
            '/api/hr/employees/$_empId',
            data: empReq.toJson(),
          );
      
      if (res.statusCode == 200) {
        if (_profilePasswordController.text.trim().isNotEmpty) {
           final loginReq = CreateLoginRequest(
             empId: _empId,
             password: _profilePasswordController.text.trim(),
           );
           await ApiClient().dio.put('/api/hr/login/$_empId', data: loginReq.toJson());
        }

        if (!mounted) return false;
        setState(() => _isLoading = false);
        _profilePasswordController.clear();
        CustomSnackbar.showSuccess(context, 'Profile updated');
        await _fetchProfile();
        return true;
      } else {
        if (!mounted) return false;
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, 'Profile update failed');
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isLoading = false);
      CustomSnackbar.showError(context, 'Profile update failed: ${_friendly(e)}');
      return false;
    }
  }

  Future<void> _showEmployeeProfile(int empId) async {
    try {
      final res = await ApiClient().dio.get('/api/hr/employees/$empId');
      if (!mounted) return;
      if (res.statusCode != 200) {
        CustomSnackbar.showError(context, 'Failed to load employee profile');
        return;
      }
      final p = HrProfileResponse.fromJson(res.data);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Profile - ${p.empName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employee ID: ${p.empId}'),
                const SizedBox(height: 6),
                Text('Name: ${p.empName}'),
                const SizedBox(height: 6),
                Text('Role: ${p.role.roleName}'),
                const SizedBox(height: 6),
                Text('Email: ${p.email}'),
                const SizedBox(height: 6),
                Text('Phone: ${p.phone.isEmpty ? '-' : p.phone}'),
                const SizedBox(height: 6),
                Text('Address: ${p.address.isEmpty ? '-' : p.address}'),
                const SizedBox(height: 6),
                Text('DOB: ${p.dob.isEmpty ? '-' : p.dob}'),
                const SizedBox(height: 6),
                Text('Blood Group: ${p.bloodGroup.isEmpty ? '-' : p.bloodGroup}'),
                const SizedBox(height: 6),
                Text(
                  'Emergency Contact: ${p.emergencyContact.isEmpty ? '-' : p.emergencyContact}',
                ),
                const SizedBox(height: 6),
                Text('Aadhar: ${p.aadharNumber.isEmpty ? '-' : p.aadharNumber}'),
                const SizedBox(height: 6),
                Text('PAN: ${p.panCardNumber.isEmpty ? '-' : p.panCardNumber}'),
                const SizedBox(height: 6),
                Text('Status: ${p.status}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, 'Failed to load employee profile: ${_friendly(e)}');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiClient().clearEmpId();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(setDarkMode: widget.setDarkMode),
      ),
      (route) => false,
    );
  }

  void _clearEmployeeForm() {
    _empIdController.clear();
    _empNameController.clear();
    _newEmployeeRoleId = _roles.isNotEmpty ? _roles.first.roleId.toString() : null;
    _empDobController.clear();
    _empPhoneController.clear();
    _empAddressController.clear();
    _empEmailController.clear();
    _empSalaryController.clear();
    _empDateController.clear();
    _empBloodGroupController.clear();
    _empEmergencyController.clear();
    _empAadharController.clear();
    _empPanCardController.clear();
    _empPasswordController.clear();
  }

  List<EmployeeItem> _filteredEmployees() {
    final query = _employeeSearchController.text.trim().toLowerCase();
    return _employees.where((e) {
      final queryMatch = query.isEmpty ||
          e.empName.toLowerCase().contains(query) ||
          e.email.toLowerCase().contains(query) ||
          e.empId.toString().contains(query);
      final roleMatch = _employeeRoleFilter == 'ALL' ||
          e.role.roleName.toLowerCase() == _employeeRoleFilter.toLowerCase();
      return queryMatch && roleMatch;
    }).toList();
  }

  List<RoleItem> _filteredRoles() {
    final query = _roleSearchController.text.trim().toLowerCase();
    return _roles.where((r) {
      final queryMatch = query.isEmpty ||
          r.roleName.toLowerCase().contains(query) ||
          r.activity.toLowerCase().contains(query) ||
          r.roleId.toString().contains(query);
      final statusMatch = _roleStatusFilter == 'ALL' ||
          r.status.toUpperCase() == _roleStatusFilter.toUpperCase();
      return queryMatch && statusMatch;
    }).toList();
  }

  Color _statusChipColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppTheme.success;
      case 'INACTIVE':
        return AppTheme.warning;
      case 'RESIGNED':
        return AppTheme.warning;
      case 'TERMINATED':
        return AppTheme.error;
      default:
        return AppTheme.primary;
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        readOnly: readOnly,
        decoration: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkInputDecoration(label)
            : AppTheme.inputDecoration(label),
      ),
    );
  }

  Widget _profileReadOnlyValue(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelMedium.copyWith(color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDropdown({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        items: _employeeStatuses
            .map(
              (s) => DropdownMenuItem<String>(
                value: s,
                child: Text(s),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkInputDecoration(label)
            : AppTheme.inputDecoration(label),
      ),
    );
  }

  Future<void> _showCreateRoleDialog() async {
    final parentContext = context;
    _roleIdController.clear();
    _roleNameController.clear();
    _roleActivityController.clear();
    _newRoleStatus = 'ACTIVE';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Role'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_roleIdController, 'Role ID'),
              _field(_roleNameController, 'Role Name'),
              _field(_roleActivityController, 'Activity'),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  value: _newRoleStatus,
                  items: _roleStatuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _newRoleStatus = value);
                  },
                  decoration: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkInputDecoration('Status')
                      : AppTheme.inputDecoration('Status'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(parentContext).pop();
              _createRole();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateEmployeeDialog() async {
    final parentContext = context;
    _clearEmployeeForm();
    if (_roles.isEmpty) {
      CustomSnackbar.showError(context, 'Create at least one role first');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        final media = MediaQuery.of(context);
        final keyboardInset = media.viewInsets.bottom;
        final maxDialogHeight = media.size.height - keyboardInset - 24;
        final formHeight = (maxDialogHeight - 120).clamp(220.0, 520.0);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Create Employee', style: AppTheme.titleLarge),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: formHeight,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _field(_empIdController, 'Employee ID'),
                            _field(_empNameController, 'Employee Name'),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: DropdownButtonFormField<String>(
                                value: _newEmployeeRoleId,
                                isExpanded: true,
                                items: _roles
                                    .map(
                                      (r) => DropdownMenuItem<String>(
                                        value: r.roleId.toString(),
                                        child: Text(
                                          '${r.roleName} (${r.roleId})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _newEmployeeRoleId = value);
                                },
                                decoration: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppTheme.darkInputDecoration('Role ID')
                                    : AppTheme.inputDecoration('Role ID'),
                              ),
                            ),
                            _field(_empDobController, 'DOB (YYYY-MM-DD)'),
                            _field(_empPhoneController, 'Phone'),
                            _field(_empAddressController, 'Address'),
                            _field(_empEmailController, 'Email'),
                            _field(_empSalaryController, 'Salary'),
                            _field(
                              _empDateController,
                              'Joining Date (YYYY-MM-DD)',
                            ),
                            _field(_empBloodGroupController, 'Blood Group'),
                            _field(_empEmergencyController, 'Emergency Contact'),
                            _field(_empAadharController, 'Aadhar Number'),
                            _field(_empPanCardController, 'PAN Card Number'),
                            _field(_empPasswordController, 'Password'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(parentContext).pop();
                            _createEmployee();
                          },
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(IconData icon, String label, int index) {
    final selected = _selectedMenu == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pop();
            setState(() => _selectedMenu = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.primary.withValues(alpha: 0.35)
                    : AppTheme.surfaceVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.surfaceVariant.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.primary : AppTheme.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.chevron_right, color: AppTheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboardView() {
    final roles = (_dashboard?.totalRoles ?? 0).toDouble();
    final employees = (_dashboard?.totalEmployees ?? 0).toDouble();
    final maxVal = (roles > employees ? roles : employees).clamp(1, 999999);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(title: 'Total Roles', value: (_dashboard?.totalRoles ?? 0).toString()),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Total Employees',
          value: (_dashboard?.totalEmployees ?? 0).toString(),
        ),
        const SizedBox(height: 20),
        Text('Stats Chart', style: AppTheme.titleLarge),
        const SizedBox(height: 12),
        _BarChart(
          rolesValue: roles / maxVal,
          employeesValue: employees / maxVal,
          rolesLabel: roles.toInt().toString(),
          employeesLabel: employees.toInt().toString(),
        ),
      ],
    );
  }

  Widget _rolesView() {
    final roles = _filteredRoles();
    const roleStatusFilters = ['ALL', 'ACTIVE', 'INACTIVE'];

    if (_selectVisibleRoles) {
      _selectedRoleIds
        ..clear()
        ..addAll(roles.map((r) => r.roleId.toString()));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _roleSearchController,
          onChanged: (_) => setState(() {}),
          decoration: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkInputDecoration('Search by role name or activity...')
              : AppTheme.inputDecoration('Search by role name or activity...'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _roleStatusFilter,
          items: roleStatusFilters
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _roleStatusFilter = value);
          },
          decoration: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkInputDecoration('Status')
              : AppTheme.inputDecoration('Status'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: _selectVisibleRoles,
              onChanged: (value) {
                setState(() {
                  _selectVisibleRoles = value ?? false;
                  if (!_selectVisibleRoles) {
                    _selectedRoleIds.clear();
                  }
                });
              },
            ),
            Text('Select visible (${roles.length})'),
          ],
        ),
        const SizedBox(height: 6),
        ...roles.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _selectedRoleIds.contains(r.roleId.toString()),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedRoleIds.add(r.roleId.toString());
                          } else {
                            _selectedRoleIds.remove(r.roleId.toString());
                          }
                        });
                      },
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.surfaceVariant,
                      child: Text(
                        r.roleName.isNotEmpty ? r.roleName[0].toUpperCase() : 'R',
                        style: AppTheme.titleLarge.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.roleName,
                            style: AppTheme.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Activity: ${r.activity.isEmpty ? '-' : r.activity}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Role ID: ${r.roleId}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusChipColor(r.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _statusChipColor(r.status).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        r.status.toUpperCase(),
                        style: AppTheme.labelMedium.copyWith(
                          color: _statusChipColor(r.status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _employeesView() {
    final employees = _filteredEmployees();
    final roleOptions = <String>{
      'ALL',
      ..._employees.map((e) => e.role.roleName),
    }.toList();

    if (_selectVisible) {
      _selectedEmployeeIds
        ..clear()
        ..addAll(employees.map((e) => e.empId));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _employeeSearchController,
          onChanged: (_) => setState(() {}),
          decoration: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkInputDecoration('Search by name or email...')
              : AppTheme.inputDecoration('Search by name or email...'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _employeeRoleFilter,
          items: roleOptions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _employeeRoleFilter = value);
          },
          decoration: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkInputDecoration('Role')
              : AppTheme.inputDecoration('Role'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: _selectVisible,
              onChanged: (value) {
                setState(() {
                  _selectVisible = value ?? false;
                  if (!_selectVisible) {
                    _selectedEmployeeIds.clear();
                  }
                });
              },
            ),
            Text('Select visible (${employees.length})'),
          ],
        ),
        const SizedBox(height: 6),
        ...employees.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _selectedEmployeeIds.contains(e.empId.toString()),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedEmployeeIds.add(e.empId.toString());
                              } else {
                                _selectedEmployeeIds.remove(e.empId.toString());
                              }
                            });
                          },
                        ),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.surfaceVariant,
                          child: Text(
                            e.empName.isNotEmpty
                                ? e.empName[0].toUpperCase()
                                : 'E',
                            style: AppTheme.titleLarge.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.empName,
                                style: AppTheme.titleLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.email,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      e.role.roleName,
                                      style: AppTheme.labelMedium.copyWith(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    e.empId.toString(),
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusChipColor(
                              e.status,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _statusChipColor(
                                e.status,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            e.status.toUpperCase(),
                            style: AppTheme.labelMedium.copyWith(
                              color: _statusChipColor(e.status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'View Profile',
                          onPressed: () {
                            _showEmployeeProfile(int.parse(e.empId));
                          },
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () async {
                            try {
                              await ApiClient().dio.delete('/api/hr/employees/${e.empId}');
                              CustomSnackbar.showSuccess(context, 'Employee deleted');
                              await _refreshAll();
                            } catch(err) {
                               CustomSnackbar.showError(context, 'Failed to delete: ${err.toString()}');
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _profileView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: !_isProfileEditMode
              ? IconButton(
                  tooltip: 'Edit Profile',
                  onPressed: () => setState(() => _isProfileEditMode = true),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Your Profile',
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.surfaceVariant,
                  child: Text(
                    _profileNameController.text.isNotEmpty
                        ? _profileNameController.text[0].toUpperCase()
                        : 'H',
                    style: AppTheme.titleLarge.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileNameController.text.isEmpty
                            ? 'HR Administrator'
                            : _profileNameController.text,
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Employee ID: $_empId',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isProfileEditMode) ...[
          _field(_profileNameController, 'Name'),
          _field(_profileEmailController, 'Email'),
          _field(_profilePhoneController, 'Phone'),
          _field(_profileAddressController, 'Address'),
          _field(_profileDobController, 'DOB (YYYY-MM-DD)'),
          _field(_profileBloodController, 'Blood Group'),
          _field(_profileEmergencyController, 'Emergency Contact'),
          _field(_profileAadharController, 'Aadhar Number'),
          _field(_profilePanCardController, 'PAN Card Number'),
          _statusDropdown(
            label: 'Status',
            value: _profileStatus,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _profileStatus = value);
            },
          ),
          _field(_profilePasswordController, 'New Password (optional)'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _fetchProfile();
                    if (!mounted) return;
                    setState(() => _isProfileEditMode = false);
                  },
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final ok = await _updateProfile();
                    if (!mounted || !ok) return;
                    setState(() => _isProfileEditMode = false);
                  },
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ] else ...[
          _profileReadOnlyValue('Name', _profileNameController.text),
          _profileReadOnlyValue('Email', _profileEmailController.text),
          _profileReadOnlyValue('Phone', _profilePhoneController.text),
          _profileReadOnlyValue('Address', _profileAddressController.text),
          _profileReadOnlyValue('DOB', _profileDobController.text),
          _profileReadOnlyValue('Blood Group', _profileBloodController.text),
          _profileReadOnlyValue(
            'Emergency Contact',
            _profileEmergencyController.text,
          ),
          _profileReadOnlyValue('Aadhar Number', _profileAadharController.text),
          _profileReadOnlyValue('PAN Card Number', _profilePanCardController.text),
          _profileReadOnlyValue('Status', _profileStatus),
        ],
      ],
    );
  }

  Widget _body() {
    switch (_selectedMenu) {
      case 1:
        return _rolesView();
      case 2:
        return _employeesView();
      case 3:
        return _profileView();
      default:
        return _dashboardView();
    }
  }

  BoxDecoration _headerGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.primary, AppTheme.primaryVariant],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  @override
  void dispose() {
    _roleIdController.dispose();
    _roleNameController.dispose();
    _roleActivityController.dispose();
    _roleSearchController.dispose();
    _empIdController.dispose();
    _empNameController.dispose();
    _empDobController.dispose();
    _empPhoneController.dispose();
    _empAddressController.dispose();
    _empEmailController.dispose();
    _empSalaryController.dispose();
    _empDateController.dispose();
    _empBloodGroupController.dispose();
    _empEmergencyController.dispose();
    _empAadharController.dispose();
    _empPanCardController.dispose();
    _empPasswordController.dispose();
    _profileNameController.dispose();
    _profileEmailController.dispose();
    _profilePhoneController.dispose();
    _profileAddressController.dispose();
    _profileDobController.dispose();
    _profileBloodController.dispose();
    _profileEmergencyController.dispose();
    _profileAadharController.dispose();
    _profilePanCardController.dispose();
    _profilePasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedMenu == 0
              ? 'Dashboard'
              : _selectedMenu == 1
                  ? 'Roles'
                  : _selectedMenu == 2
                      ? 'Employees'
                      : 'Profile Management',
          style: AppTheme.titleLarge.copyWith(
            color: AppTheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        flexibleSpace: Container(decoration: _headerGradient()),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: _headerGradient(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      _employeeName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('HR Administrator', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            'ID $_empId',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _menuItem(Icons.dashboard_rounded, 'Dashboard', 0),
              _menuItem(Icons.badge_rounded, 'Roles', 1),
              _menuItem(Icons.groups_rounded, 'Employees', 2),
              _menuItem(Icons.person_rounded, 'Profile Management', 3),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.background,
                      AppTheme.surfaceVariant.withValues(alpha: 0.28),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: _body(),
              ),
      ),
      floatingActionButton: _selectedMenu == 2
          ? FloatingActionButton.extended(
              onPressed: _showCreateEmployeeDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Employee'),
            )
          : _selectedMenu == 1
              ? FloatingActionButton.extended(
                  onPressed: _showCreateRoleDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Role'),
                )
          : null,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final isRoles = title.toLowerCase().contains('role');
    return Card(
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isRoles ? AppTheme.primary : AppTheme.secondary)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isRoles ? Icons.badge_rounded : Icons.groups_rounded,
                color: isRoles ? AppTheme.primary : AppTheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              value,
              style: AppTheme.headlineSmall.copyWith(color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final double rolesValue;
  final double employeesValue;
  final String rolesLabel;
  final String employeesLabel;

  const _BarChart({
    required this.rolesValue,
    required this.employeesValue,
    required this.rolesLabel,
    required this.employeesLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Bar(title: 'Roles', value: rolesValue, label: rolesLabel, color: AppTheme.primary),
          _Bar(
            title: 'Employees',
            value: employeesValue,
            label: employeesLabel,
            color: AppTheme.secondary,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String title;
  final double value;
  final String label;
  final Color color;

  const _Bar({
    required this.title,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final height = ((value.clamp(0.0, 1.0) * 130) + 20).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(label, style: AppTheme.titleMedium),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 52,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: AppTheme.bodyMedium),
      ],
    );
  }
}
