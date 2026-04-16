import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'app_theme.dart';
import 'login_screen.dart';
import 'profile_tab.dart';
import 'api_client.dart';

class FloorManagerWorkspace extends StatefulWidget {
  final String empId;
  final String employeeName;
  final String role;

  const FloorManagerWorkspace({
    super.key,
    required this.empId,
    required this.employeeName,
    required this.role,
  });

  @override
  State<FloorManagerWorkspace> createState() => _FloorManagerWorkspaceState();
}

class _FloorManagerWorkspaceState extends State<FloorManagerWorkspace> {
  int _tab = 0;
  bool _loading = false;
  Map<String, dynamic>? _insights;

  // Reassign (merge bins)
  final _targetBundleCtrl = TextEditingController();
  final _sourceBundleCtrl = TextEditingController();
  bool _reassigning = false;

  String get _empId => widget.empId.trim();

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  @override
  void dispose() {
    _targetBundleCtrl.dispose();
    _sourceBundleCtrl.dispose();
    super.dispose();
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

  Future<void> _loadInsights() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/api/insights/floor-manager');
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() =>
            _insights = Map<String, dynamic>.from(res.data as Map));
      }
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, _extractDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reassignWork() async {
    final target = int.tryParse(_targetBundleCtrl.text.trim());
    final source = int.tryParse(_sourceBundleCtrl.text.trim());
    if (target == null || source == null) {
      CustomSnackbar.showError(
          context, 'Both Target and Source Bundle IDs are required');
      return;
    }
    setState(() => _reassigning = true);
    try {
      final body = {'targetBundleId': target, 'sourceBundleId': source};
      final res = await ApiClient().dio.post('/api/production/merge-bins', data: body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = res.data as Map;
        CustomSnackbar.showSuccess(
            context, d['message']?.toString() ?? 'Bins merged');
        _targetBundleCtrl.clear();
        _sourceBundleCtrl.clear();
      }
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, _extractDioError(e));
    } finally {
      if (mounted) setState(() => _reassigning = false);
    }
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

  Widget _card(Widget child) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration:
          dark ? AppTheme.darkCardDecoration : AppTheme.cardDecoration,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(value,
                style: AppTheme.titleMedium.copyWith(
                    color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget _dashboardTab() {
    final d = _insights;
    final bottlenecks = (d?['bottleneckOperationCount'] ?? 0) as num;
    final hint = d?['lineBalancingHint']?.toString() ?? '-';
    final balanced = bottlenecks == 0;

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Row(children: [
            Expanded(
                child: Text('Monitor WIP', style: AppTheme.headlineMedium)),
            IconButton(
                onPressed: _loading ? null : _loadInsights,
                icon: const Icon(Icons.refresh)),
          ])),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator()))
          else if (d == null)
            _card(Text('No data. Pull to refresh.',
                style: AppTheme.bodyLarge))
          else ...[
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WIP Overview', style: AppTheme.titleLarge),
                const SizedBox(height: 12),
                _metricRow('Active WIP Count',
                    '${d['activeWipCount'] ?? 0}', AppTheme.primary),
                _metricRow(
                    'Bottleneck Operations',
                    '$bottlenecks',
                    bottlenecks > 0 ? AppTheme.error : AppTheme.success),
              ],
            )),
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Line Balancing', style: AppTheme.titleLarge),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(
                    balanced
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    color: balanced ? AppTheme.success : AppTheme.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(hint, style: AppTheme.bodyMedium)),
                ]),
              ],
            )),
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Insights', style: AppTheme.titleLarge),
                const SizedBox(height: 10),
                Text(
                  bottlenecks > 0
                      ? 'AI detected $bottlenecks bottleneck operation(s). Consider reassigning operators from low-load operations to clear the backlog.'
                      : 'Production floor is balanced. No immediate action required.',
                  style: AppTheme.bodyMedium,
                ),
              ],
            )),
          ],
        ],
      ),
    );
  }

  Widget _operatorPerformanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Text('Operator Performance', style: AppTheme.headlineMedium)),
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WIP Summary', style: AppTheme.titleLarge),
            const SizedBox(height: 10),
            if (_insights != null) ...[
              _metricRow('Active WIP',
                  '${_insights!['activeWipCount'] ?? 0}', AppTheme.primary),
              _metricRow(
                  'Bottleneck Ops',
                  '${_insights!['bottleneckOperationCount'] ?? 0}',
                  AppTheme.warning),
            ] else
              Text('Load dashboard first to see WIP data.',
                  style: AppTheme.bodyMedium),
          ],
        )),
        _card(Row(children: [
          const Icon(Icons.info_outline,
              color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Per-operator drill-down requires operator ID. Use Reassign Work to rebalance.',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.onSurfaceVariant))),
        ])),
      ],
    );
  }

  Widget _reassignTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reassign Work', style: AppTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Merge source bundle into target bundle to reassign work.',
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetBundleCtrl,
              keyboardType: TextInputType.number,
              decoration: dark
                  ? AppTheme.darkInputDecoration('Target Bundle ID *')
                  : AppTheme.inputDecoration('Target Bundle ID *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceBundleCtrl,
              keyboardType: TextInputType.number,
              decoration: dark
                  ? AppTheme.darkInputDecoration('Source Bundle ID *')
                  : AppTheme.inputDecoration('Source Bundle ID *'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _reassigning ? null : _reassignWork,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _reassigning
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary)
                      : Text('REASSIGN / MERGE BINS',
                          style: AppTheme.labelLarge.copyWith(
                              color: AppTheme.onPrimary,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        )),
      ],
    );
  }

  Widget _drawerItem(IconData icon, String label, int index) {
    final sel = _tab == index;
    return ListTile(
      leading: Icon(icon,
          color: sel ? AppTheme.primary : AppTheme.onSurfaceVariant),
      title: Text(label,
          style: AppTheme.bodyMedium.copyWith(
            color: sel ? AppTheme.primary : AppTheme.onSurface,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          )),
      selected: sel,
      onTap: () {
        Navigator.of(context).pop();
        setState(() => _tab = index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _dashboardTab(),
      _operatorPerformanceTab(),
      _reassignTab(),
      ProfileTab(empId: _empId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role),
        actions: [
          IconButton(
              onPressed: _logout,
              tooltip: 'Logout',
              icon: const Icon(Icons.logout)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.employeeName} • EMP ${widget.empId}',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.onPrimary),
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
                      const Icon(Icons.factory_outlined,
                          color: Colors.white, size: 34),
                      const SizedBox(height: 10),
                      Text(widget.employeeName,
                          style: AppTheme.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${widget.role} • ID ${widget.empId}',
                          style: AppTheme.bodySmall
                              .copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              _drawerItem(Icons.dashboard_outlined, 'Monitor WIP', 0),
              _drawerItem(
                  Icons.speed_outlined, 'Operator Performance', 1),
              _drawerItem(Icons.swap_horiz_outlined, 'Reassign Work', 2),
              _drawerItem(Icons.person_outline, 'My Profile', 3),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.logout, color: AppTheme.error),
                title: Text('Logout',
                    style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: tabs[_tab],
    );
  }
}
