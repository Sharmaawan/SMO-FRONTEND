import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'app_theme.dart';
import 'login_screen.dart';
import 'profile_tab.dart';
import 'api_client.dart';

class GmWorkspace extends StatefulWidget {
  final String empId;
  final String employeeName;
  final String role;

  const GmWorkspace({
    super.key,
    required this.empId,
    required this.employeeName,
    required this.role,
  });

  @override
  State<GmWorkspace> createState() => _GmWorkspaceState();
}

class _GmWorkspaceState extends State<GmWorkspace> {
  int _tab = 0;
  bool _loading = false;
  Map<String, dynamic>? _insights;

  String get _empId => widget.empId.trim();

  @override
  void initState() {
    super.initState();
    _loadInsights();
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
      final res = await ApiClient().dio.get('/api/insights/gm');
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

  Widget _statTile(String label, String value, IconData icon, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark
            ? AppTheme.darkSurfaceVariant
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(value,
              style: AppTheme.displaySmall
                  .copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: AppTheme.bodySmall
                  .copyWith(color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _productionTab() {
    final d = _insights;
    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Row(children: [
            Expanded(
                child: Text('Production Performance',
                    style: AppTheme.headlineMedium)),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _statTile(
                    'Total WIP Records',
                    '${d['totalWipRecords'] ?? 0}',
                    Icons.inventory_2_outlined,
                    AppTheme.primary),
                _statTile(
                    'Active WIP',
                    '${d['activeWipRecords'] ?? 0}',
                    Icons.play_circle_outline,
                    AppTheme.secondary),
                _statTile(
                    'Total Inventory Qty',
                    '${d['totalInventoryQty'] ?? 0}',
                    Icons.warehouse_outlined,
                    AppTheme.tertiary),
                _statTile(
                    'Report Status',
                    '${d['reportStatus'] ?? '-'}',
                    Icons.assessment_outlined,
                    AppTheme.success),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _inventoryTab() {
    final d = _insights;
    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Row(children: [
            Expanded(
                child: Text('Inventory Analysis',
                    style: AppTheme.headlineMedium)),
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
          else
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Summary', style: AppTheme.titleLarge),
                const SizedBox(height: 14),
                _infoRow('Total Inventory Qty',
                    '${d['totalInventoryQty'] ?? 0}'),
                _infoRow('Active WIP Records',
                    '${d['activeWipRecords'] ?? 0}'),
                _infoRow('Total WIP Records',
                    '${d['totalWipRecords'] ?? 0}'),
              ],
            )),
        ],
      ),
    );
  }

  Widget _reportsTab() {
    final d = _insights;
    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
              Text('Reports', style: AppTheme.headlineMedium)),
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
                Row(children: [
                  Icon(
                    d['reportStatus'] == 'READY'
                        ? Icons.check_circle_outline
                        : Icons.hourglass_empty,
                    color: d['reportStatus'] == 'READY'
                        ? AppTheme.success
                        : AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Text('Report Status: ${d['reportStatus'] ?? '-'}',
                      style: AppTheme.titleLarge),
                ]),
                const SizedBox(height: 14),
                _infoRow('Total WIP Records',
                    '${d['totalWipRecords'] ?? 0}'),
                _infoRow('Active WIP',
                    '${d['activeWipRecords'] ?? 0}'),
                _infoRow('Total Inventory Qty',
                    '${d['totalInventoryQty'] ?? 0}'),
              ],
            )),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium),
          Text(value,
              style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ],
      ),
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
      _productionTab(),
      _inventoryTab(),
      _reportsTab(),
      ProfileTab(empId: _empId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('GM Dashboard'),
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
                      const Icon(Icons.business_center_outlined,
                          color: Colors.white, size: 34),
                      const SizedBox(height: 10),
                      Text(widget.employeeName,
                          style: AppTheme.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('GM • ID ${widget.empId}',
                          style: AppTheme.bodySmall
                              .copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              _drawerItem(Icons.trending_up_outlined,
                  'Production Performance', 0),
              _drawerItem(
                  Icons.warehouse_outlined, 'Inventory Analysis', 1),
              _drawerItem(
                  Icons.assessment_outlined, 'Reports', 2),
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
