import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'app_theme.dart';
import 'login_screen.dart';
import 'profile_tab.dart';
import 'api_client.dart';

class QcWorkspace extends StatefulWidget {
  final String empId;
  final String employeeName;
  final String role;

  const QcWorkspace({
    super.key,
    required this.empId,
    required this.employeeName,
    required this.role,
  });

  @override
  State<QcWorkspace> createState() => _QcWorkspaceState();
}

class _QcWorkspaceState extends State<QcWorkspace> {
  int _selectedTab = 0;
  bool _isSubmitting = false;

  // Perform Inspection
  final _inspectionGarmentIdController = TextEditingController();
  final _inspectionDefectsController = TextEditingController();

  // Approve / Reject
  final _decisionQcIdController = TextEditingController();
  String _decisionStatus = 'APPROVED';

  // Rework
  final _reworkQcIdController = TextEditingController();

  // Recent local results from live API actions (not hardcoded data)
  final List<Map<String, dynamic>> _recentActions = [];

  // Packaging
  List<Map<String, dynamic>> _approvedGarments = [];
  List<Map<String, dynamic>> _packagingRecords = [];
  bool _loadingGarments = false;
  bool _loadingPkgRecords = false;
  final _pkgGarmentIdCtrl = TextEditingController();
  final _pkgQtyCtrl = TextEditingController(text: '1');
  bool _packaging = false;

  String get _actorEmpId => widget.empId.trim();

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

  Future<void> _loadApprovedGarments() async {
    setState(() => _loadingGarments = true);
    try {
      final res = await ApiClient().dio.get('/api/packaging/approved-garments');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = res.data as List;
        setState(() => _approvedGarments =
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingGarments = false);
    }
  }

  Future<void> _loadPackagingRecords() async {
    setState(() => _loadingPkgRecords = true);
    try {
      final res = await ApiClient().dio.get('/api/packaging/records');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = res.data as List;
        setState(() => _packagingRecords =
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingPkgRecords = false);
    }
  }

  Future<void> _packageGarment() async {
    final garmentId = int.tryParse(_pkgGarmentIdCtrl.text.trim());
    if (garmentId == null) {
      CustomSnackbar.showError(context, 'Garment ID is required');
      return;
    }
    setState(() => _packaging = true);
    try {
      final body = {
        'garmentId': garmentId,
        'qty': int.tryParse(_pkgQtyCtrl.text.trim()) ?? 1,
      };
      final res = await ApiClient().dio.post('/api/packaging/package', data: body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        _pkgGarmentIdCtrl.clear();
        _pkgQtyCtrl.text = '1';
        CustomSnackbar.showSuccess(context, 'Garment packaged successfully');
        await _loadApprovedGarments();
        await _loadPackagingRecords();
      }
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, _extractDioError(e));
    } finally {
      if (mounted) setState(() => _packaging = false);
    }
  }

  Widget _buildPackagingTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadApprovedGarments();
        await _loadPackagingRecords();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Package Finished Goods', style: AppTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Only APPROVED garments can be packaged.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            TextField(controller: _pkgGarmentIdCtrl, keyboardType: TextInputType.number,
                decoration: dark ? AppTheme.darkInputDecoration('Garment ID *') : AppTheme.inputDecoration('Garment ID *')),
            const SizedBox(height: 12),
            TextField(controller: _pkgQtyCtrl, keyboardType: TextInputType.number,
                decoration: dark ? AppTheme.darkInputDecoration('Qty') : AppTheme.inputDecoration('Qty')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _packaging ? null : _packageGarment,
              style: AppTheme.tertiaryButtonStyle,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
                child: _packaging ? const CircularProgressIndicator(color: AppTheme.onPrimary)
                    : Text('PACKAGE GARMENT', style: AppTheme.labelLarge.copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold))),
            )),
          ])),
          _sectionCard(child: Row(children: [
            Expanded(child: Text('Approved Garments', style: AppTheme.titleLarge)),
            IconButton(onPressed: _loadingGarments ? null : _loadApprovedGarments, icon: const Icon(Icons.refresh)),
          ])),
          if (_loadingGarments)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_approvedGarments.isEmpty)
            _sectionCard(child: Text('No approved garments.', style: AppTheme.bodyLarge))
          else
            ..._approvedGarments.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _sectionCard(child: Row(children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                const SizedBox(width: 10),
                Text('Garment #${g['garmentId']} • Bundle: ${g['bundleId'] ?? '-'} • ${g['status']}',
                    style: AppTheme.bodyMedium),
              ])),
            )),
          const SizedBox(height: 8),
          _sectionCard(child: Row(children: [
            Expanded(child: Text('Packaging Records', style: AppTheme.titleLarge)),
            IconButton(onPressed: _loadingPkgRecords ? null : _loadPackagingRecords, icon: const Icon(Icons.refresh)),
          ])),
          if (_loadingPkgRecords)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_packagingRecords.isEmpty)
            _sectionCard(child: Text('No packaging records yet.', style: AppTheme.bodyLarge))
          else
            ..._packagingRecords.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _sectionCard(child: Text(
                  'Pkg #${p['packagingId']} • Garment: ${p['garmentId']} • Qty: ${p['qty']}',
                  style: AppTheme.bodyMedium)),
            )),
        ],
      ),
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
    _inspectionGarmentIdController.dispose();
    _inspectionDefectsController.dispose();
    _decisionQcIdController.dispose();
    _reworkQcIdController.dispose();
    _pkgGarmentIdCtrl.dispose();
    _pkgQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _performInspection() async {
    final garmentId = int.tryParse(_inspectionGarmentIdController.text.trim());
    final defects = _inspectionDefectsController.text.trim();

    if (garmentId == null) {
      CustomSnackbar.showError(
        context,
        'garmentId is required and must be numeric',
      );
      return;
    }

    final body = <String, dynamic>{
      'garmentId': garmentId,
      'status': 'INSPECTED',
      'defects': defects.isEmpty ? null : defects,
    };

    setState(() => _isSubmitting = true);
    try {
      final response = await ApiClient().dio.post(
            '/api/qc/inspection',
            data: body,
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data : null;
        final qcId = data?['qcId']?.toString() ?? '-';
        final status = data?['status']?.toString() ?? 'INSPECTED';
        _addRecentAction({
          'action': 'INSPECTION',
          'qcId': qcId,
          'garmentId': data?['garmentId']?.toString() ?? garmentId.toString(),
          'status': status,
          'defects': data?['defects']?.toString() ?? defects,
          'raw': data ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        });
        CustomSnackbar.showSuccess(
          context,
          'Inspection recorded (QC ID: $qcId)',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, _extractDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _approveReject() async {
    final qcId = int.tryParse(_decisionQcIdController.text.trim());

    if (qcId == null) {
      CustomSnackbar.showError(context, 'qcId is required and must be numeric');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await ApiClient().dio.patch(
            '/api/qc/$qcId/decision',
            queryParameters: {'status': _decisionStatus},
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data : null;
        _addRecentAction({
          'action': 'DECISION',
          'qcId': data?['qcId']?.toString() ?? qcId.toString(),
          'status': data?['status']?.toString() ?? _decisionStatus,
          'raw': data ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        });
        CustomSnackbar.showSuccess(
          context,
          'Decision updated to $_decisionStatus',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, _extractDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendForRework() async {
    final qcId = int.tryParse(_reworkQcIdController.text.trim());

    if (qcId == null) {
      CustomSnackbar.showError(context, 'qcId is required and must be numeric');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await ApiClient().dio.patch('/api/qc/$qcId/rework');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data : null;
        _addRecentAction({
          'action': 'REWORK',
          'qcId': data?['qcId']?.toString() ?? qcId.toString(),
          'status': data?['status']?.toString() ?? 'REWORK',
          'message': data?['message']?.toString() ?? '',
          'raw': data ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        });
        CustomSnackbar.showSuccess(context, 'Sent to rework');
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, _extractDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addRecentAction(Map<String, dynamic> action) {
    setState(() {
      _recentActions.insert(0, action);
      if (_recentActions.length > 30) {
        _recentActions.removeLast();
      }
    });
  }

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

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkCardDecoration
          : AppTheme.cardDecoration,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildInspectionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Perform QC Inspection', style: AppTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'Capture inspection directly via live backend API (no hardcoded records).',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inspectionGarmentIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Garment ID *')
                    : AppTheme.inputDecoration('Garment ID *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inspectionDefectsController,
                maxLines: 4,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Defects (optional)')
                    : AppTheme.inputDecoration('Defects (optional)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _performInspection,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'SUBMIT INSPECTION',
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

  Widget _buildDecisionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Approve / Reject', style: AppTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _decisionQcIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('QC ID *')
                    : AppTheme.inputDecoration('QC ID *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _decisionStatus,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Decision Status *')
                    : AppTheme.inputDecoration('Decision Status *'),
                items: const [
                  DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                  DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _decisionStatus = value);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _approveReject,
                style: AppTheme.secondaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'SUBMIT DECISION',
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

  Widget _buildReworkTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send for Rework', style: AppTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _reworkQcIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('QC ID *')
                    : AppTheme.inputDecoration('QC ID *'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _sendForRework,
                style: AppTheme.tertiaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'MARK REWORK',
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

  Widget _buildRecentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent QC Actions',
                  style: AppTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Clear',
                onPressed: _recentActions.isEmpty
                    ? null
                    : () => setState(() => _recentActions.clear()),
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_recentActions.isEmpty)
          _sectionCard(
            child: Text(
              'No QC actions captured in this session yet.',
              style: AppTheme.bodyLarge,
            ),
          )
        else
          ..._recentActions.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a['action'] ?? 'ACTION'} • QC ${a['qcId'] ?? '-'}',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (a['garmentId'] != null)
                      Text('Garment ID: ${a['garmentId']}'),
                    if (a['status'] != null) Text('Status: ${a['status']}'),
                    if (a['defects'] != null &&
                        '${a['defects']}'.trim().isNotEmpty)
                      Text('Defects: ${a['defects']}'),
                    if (a['message'] != null &&
                        '${a['message']}'.trim().isNotEmpty)
                      Text('Message: ${a['message']}'),
                    Text('At: ${a['timestamp'] ?? '-'}'),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _buildInspectionTab(),
      _buildDecisionTab(),
      _buildReworkTab(),
      _buildRecentTab(),
      _buildPackagingTab(),
      ProfileTab(empId: _actorEmpId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QC Engineer Workspace'),
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
                        Icons.verified_outlined,
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
                        'QC Engineer • ID ${widget.empId}',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _drawerItem(icon: Icons.fact_check_outlined, label: 'Perform Inspection', index: 0),
              _drawerItem(icon: Icons.rule_outlined, label: 'Approve / Reject', index: 1),
              _drawerItem(icon: Icons.replay_outlined, label: 'Send for Rework', index: 2),
              _drawerItem(icon: Icons.history_outlined, label: 'Recent Actions', index: 3),
              _drawerItem(icon: Icons.inventory_outlined, label: 'Packaging', index: 4),
              _drawerItem(icon: Icons.person_outline, label: 'My Profile', index: 5),
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
