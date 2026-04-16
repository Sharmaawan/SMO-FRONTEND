import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'app_config.dart';
import 'app_theme.dart';
import 'models.dart';
import 'api_client.dart';

/// Reusable profile tab — drop into any workspace.
/// Uses the same GET/PUT /api/hr/profile/{empId} endpoints as HR.
class ProfileTab extends StatefulWidget {
  final String empId;

  const ProfileTab({super.key, required this.empId});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _loading = true;
  bool _editMode = false;
  bool _saving = false;

  HrProfileResponse? _profile;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/api/hr/profile/${widget.empId}');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final p = HrProfileResponse.fromJson(res.data as Map<String, dynamic>);
        _profile = p;
        _nameCtrl.text = p.empName;
        _emailCtrl.text = p.email;
        _phoneCtrl.text = p.phone;
        _addressCtrl.text = p.address;
        _dobCtrl.text = p.dob;
        _bloodCtrl.text = p.bloodGroup;
        _emergencyCtrl.text = p.emergencyContact;
      }
    } catch (e) {
      if (mounted) _showError(_extractDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      _showError('Name and email are required');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = UpdateHrProfileRequest(
        empName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        dob: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
        bloodGroup: _bloodCtrl.text.trim().isEmpty ? null : _bloodCtrl.text.trim(),
        emergencyContact: _emergencyCtrl.text.trim().isEmpty ? null : _emergencyCtrl.text.trim(),
        aadharNumber: null,
        panCardNumber: null,
        status: _profile?.status ?? 'ACTIVE',
        password: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      );
      final res = await ApiClient().dio.put(
            '/api/hr/profile/${widget.empId}',
            data: body.toJson(),
          );
      if (!mounted) return;
      if (res.statusCode == 200) {
        _passwordCtrl.clear();
        setState(() => _editMode = false);
        CustomSnackbar.showSuccess(context, 'Profile updated');
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) _showError(_extractDioError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) =>
      CustomSnackbar.showError(context, msg);

  String _extractDioError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        return data['message']?.toString() ?? data['error']?.toString() ?? 'API Error';
      }
      if (data is String && data.isNotEmpty) return data;
      return e.message ?? 'Unknown network error';
    }
    return e.toString();
  }

  Widget _infoRow(String label, String value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark
            ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.5)
            : AppTheme.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark
              ? AppTheme.darkSurfaceVariant
              : AppTheme.surfaceVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTheme.labelMedium
                  .copyWith(color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: AppTheme.bodyMedium.copyWith(
              color: dark ? AppTheme.darkOnSurface : AppTheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label,
      {bool obscure = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: dark
            ? AppTheme.darkInputDecoration(label)
            : AppTheme.inputDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final p = _profile;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            decoration: dark
                ? AppTheme.darkCardDecoration
                : AppTheme.cardDecoration,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      (p?.empName.isNotEmpty == true)
                          ? p!.empName[0].toUpperCase()
                          : '?',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p?.empName ?? '-',
                          style: AppTheme.titleLarge
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p?.role.roleName ?? '-'} • ID ${widget.empId}',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (p?.status == 'ACTIVE'
                                    ? AppTheme.success
                                    : AppTheme.warning)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (p?.status == 'ACTIVE'
                                      ? AppTheme.success
                                      : AppTheme.warning)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            p?.status ?? '-',
                            style: AppTheme.labelMedium.copyWith(
                              color: p?.status == 'ACTIVE'
                                  ? AppTheme.success
                                  : AppTheme.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_editMode)
                    IconButton(
                      tooltip: 'Edit Profile',
                      onPressed: () => setState(() => _editMode = true),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primary,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (!_editMode) ...[
            // Read-only view
            Container(
              decoration: dark
                  ? AppTheme.darkCardDecoration
                  : AppTheme.cardDecoration,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personal Info', style: AppTheme.titleLarge),
                    const SizedBox(height: 14),
                    _infoRow('Email', p?.email ?? '-'),
                    _infoRow('Phone', p?.phone ?? '-'),
                    _infoRow('Address', p?.address ?? '-'),
                    _infoRow('Date of Birth', p?.dob ?? '-'),
                    _infoRow('Blood Group', p?.bloodGroup ?? '-'),
                    _infoRow('Emergency Contact', p?.emergencyContact ?? '-'),
                    _infoRow('Aadhar', p?.aadharNumber ?? '-'),
                    _infoRow('PAN Card', p?.panCardNumber ?? '-'),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Edit form
            Container(
              decoration: dark
                  ? AppTheme.darkCardDecoration
                  : AppTheme.cardDecoration,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Profile', style: AppTheme.titleLarge),
                    const SizedBox(height: 14),
                    _editField(_nameCtrl, 'Full Name *'),
                    _editField(_emailCtrl, 'Email *'),
                    _editField(_phoneCtrl, 'Phone'),
                    _editField(_addressCtrl, 'Address'),
                    _editField(_dobCtrl, 'Date of Birth (YYYY-MM-DD)'),
                    _editField(_bloodCtrl, 'Blood Group'),
                    _editField(_emergencyCtrl, 'Emergency Contact'),
                    _editField(_passwordCtrl, 'New Password (leave blank to keep)',
                        obscure: true),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(() => _editMode = false);
                                    _loadProfile();
                                  },
                            style: AppTheme.outlinedButtonStyle,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            style: AppTheme.primaryButtonStyle,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: _saving
                                  ? const CircularProgressIndicator(
                                      color: AppTheme.onPrimary)
                                  : Text(
                                      'Save',
                                      style: AppTheme.labelLarge.copyWith(
                                          color: AppTheme.onPrimary,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
