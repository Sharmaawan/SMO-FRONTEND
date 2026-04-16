import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'login_screen.dart';
import 'profile_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QR Scanner Page
// ─────────────────────────────────────────────────────────────────────────────

class QrScanPage extends StatefulWidget {
  final String title;
  const QrScanPage({super.key, required this.title});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _captured = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_captured) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _captured = true;
        Navigator.of(context).pop(raw.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Align the QR code inside the camera view',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Operator Workspace
// ─────────────────────────────────────────────────────────────────────────────

class OperatorWorkspace extends StatefulWidget {
  final String empId;
  final String employeeName;
  final String role;

  const OperatorWorkspace({
    super.key,
    required this.empId,
    required this.employeeName,
    required this.role,
  });

  @override
  State<OperatorWorkspace> createState() => _OperatorWorkspaceState();
}

class _OperatorWorkspaceState extends State<OperatorWorkspace> {
  int _tab = 0;
  bool _busy = false;

  // Start Work
  final _sTrayQr = TextEditingController();
  final _sBundleId = TextEditingController();
  final _sOperationId = TextEditingController();
  final _sMachineId = TextEditingController();
  final _sQty = TextEditingController();

  // Complete Work
  final _cTrayQr = TextEditingController();
  final _cBundleId = TextEditingController();
  final _cOperationId = TextEditingController();
  final _cMachineId = TextEditingController();
  final _cQty = TextEditingController();

  // Data
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic>? _perf;
  bool _loadingTasks = false;
  bool _loadingPerf = false;

  String get _empId => widget.empId.trim();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadPerf();
  }

  @override
  void dispose() {
    _sTrayQr.dispose();
    _sBundleId.dispose();
    _sOperationId.dispose();
    _sMachineId.dispose();
    _sQty.dispose();
    _cTrayQr.dispose();
    _cBundleId.dispose();
    _cOperationId.dispose();
    _cMachineId.dispose();
    _cQty.dispose();
    super.dispose();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

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

  // ── QR Scanning ────────────────────────────────────────────────────────────

  Future<void> _scan(TextEditingController ctrl, String title) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => QrScanPage(title: title)),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    setState(() => ctrl.text = _parseQr(raw.trim()));
  }

  /// Parse QR payload smartly:
  /// 1. JSON  {"bundleId":12}  → "12"
  /// 2. key=value / key:value  → value part
  /// 3. first number found     → that number
  /// 4. fallback               → raw string
  String _parseQr(String raw) {
    // 1. JSON
    try {
      final d = jsonDecode(raw);
      if (d is Map) {
        for (final k in const [
          'bundleId',
          'machineId',
          'operationId',
          'trayQr',
          'id',
          'value',
          'code',
        ]) {
          final v = d[k];
          if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString().trim();
          }
        }
      }
    } catch (_) {}

    // 2. key=value or key:value
    final kv = RegExp(
      r'(bundleId|machineId|operationId|trayQr|id|value|code)\s*[:=]\s*([A-Za-z0-9\-_]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (kv != null) return kv.group(2)!.trim();

    // 3. first number
    final n = RegExp(r'\d+').firstMatch(raw);
    if (n != null) return n.group(0)!;

    // 4. raw
    return raw;
  }

  // ── API Calls ──────────────────────────────────────────────────────────────

  Future<void> _startWork() async {
    final opId = int.tryParse(_empId);
    final bundleId = int.tryParse(_sBundleId.text.trim());
    final operationId = int.tryParse(_sOperationId.text.trim());
    final machineId = int.tryParse(_sMachineId.text.trim());
    final qty = int.tryParse(_sQty.text.trim());

    if (opId == null) {
      CustomSnackbar.showError(context, 'Invalid EMP ID in session');
      return;
    }
    if (bundleId == null || operationId == null || machineId == null) {
      CustomSnackbar.showError(
          context, 'Bundle ID, Operation ID and Machine ID are required');
      return;
    }

    final body = {
      'trayQr': _sTrayQr.text.trim().isEmpty ? null : _sTrayQr.text.trim(),
      'bundleId': bundleId,
      'operationId': operationId,
      'operatorId': opId,
      'machineId': machineId,
      'qty': qty,
    };

    setState(() => _busy = true);
    try {
      final res = await ApiClient().dio.post(
            '/api/production/start-work',
            data: body,
          );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = res.data;
        CustomSnackbar.showSuccess(
            context, d?['message']?.toString() ?? 'Work started');
        await _loadTasks();
        await _loadPerf();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to start work';
        if (e is DioException) {
          msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
        }
        CustomSnackbar.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeWork() async {
    final opId = int.tryParse(_empId);
    final bundleId = int.tryParse(_cBundleId.text.trim());
    final operationId = int.tryParse(_cOperationId.text.trim());
    final machineId = int.tryParse(_cMachineId.text.trim());
    final qty = int.tryParse(_cQty.text.trim());

    if (opId == null) {
      CustomSnackbar.showError(context, 'Invalid EMP ID in session');
      return;
    }
    if (bundleId == null || operationId == null || machineId == null) {
      CustomSnackbar.showError(
          context, 'Bundle ID, Operation ID and Machine ID are required');
      return;
    }

    final body = {
      'trayQr': _cTrayQr.text.trim().isEmpty ? null : _cTrayQr.text.trim(),
      'bundleId': bundleId,
      'operationId': operationId,
      'operatorId': opId,
      'machineId': machineId,
      'qty': qty,
    };

    setState(() => _busy = true);
    try {
      final res = await ApiClient().dio.post(
            '/api/production/complete-work',
            data: body,
          );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = res.data;
        CustomSnackbar.showSuccess(
            context, d?['message']?.toString() ?? 'Work completed');
        await _loadTasks();
        await _loadPerf();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to complete work';
        if (e is DioException) {
          msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
        }
        CustomSnackbar.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadTasks() async {
    final opId = int.tryParse(_empId);
    if (opId == null) return;
    setState(() => _loadingTasks = true);
    try {
      final res = await ApiClient().dio.get('/api/production/assigned-tasks/$opId');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = res.data;
        setState(() {
          _tasks = decoded is List
              ? decoded
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [];
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to load tasks';
        if (e is DioException) {
          msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
        }
        CustomSnackbar.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  Future<void> _loadPerf() async {
    final opId = int.tryParse(_empId);
    if (opId == null) return;
    setState(() => _loadingPerf = true);
    try {
      final res = await ApiClient().dio.get('/api/production/operator-performance/$opId');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = res.data;
        setState(() {
          _perf = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to load performance';
        if (e is DioException) {
          msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
        }
        CustomSnackbar.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _loadingPerf = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      decoration: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkCardDecoration
          : AppTheme.cardDecoration,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  /// Text field with a QR scan button on the right
  Widget _qrField({
    required TextEditingController ctrl,
    required String label,
    required String scanTitle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            decoration: dark
                ? AppTheme.darkInputDecoration(label)
                : AppTheme.inputDecoration(label),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _busy ? null : () => _scan(ctrl, scanTitle),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.qr_code_scanner,
                  color: Colors.white, size: 22),
            ),
          ),
        ),
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

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _startWorkTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start Work', style: AppTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Scan each QR or type the ID manually.',
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _qrField(
                ctrl: _sTrayQr,
                label: 'Tray QR (optional)',
                scanTitle: 'Scan Tray QR'),
            const SizedBox(height: 12),
            _qrField(
                ctrl: _sBundleId,
                label: 'Bundle ID *',
                scanTitle: 'Scan Bundle QR',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _qrField(
                ctrl: _sOperationId,
                label: 'Operation ID *',
                scanTitle: 'Scan Operation QR',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _qrField(
                ctrl: _sMachineId,
                label: 'Machine ID *',
                scanTitle: 'Scan Machine QR',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(
              controller: _sQty,
              keyboardType: TextInputType.number,
              decoration: dark
                  ? AppTheme.darkInputDecoration('Quantity (optional)')
                  : AppTheme.inputDecoration('Quantity (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _startWork,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _busy
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary)
                      : Text('START WORK',
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

  Widget _completeWorkTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complete Work', style: AppTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Scan each QR or type the ID manually.',
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _qrField(
                ctrl: _cTrayQr,
                label: 'Tray QR (optional)',
                scanTitle: 'Scan Tray QR'),
            const SizedBox(height: 12),
            _qrField(
                ctrl: _cBundleId,
                label: 'Bundle ID *',
                scanTitle: 'Scan Bundle QR',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _qrField(
                ctrl: _cOperationId,
                label: 'Operation ID *',
                scanTitle: 'Scan Operation QR',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _qrField(
                ctrl: _cMachineId,
                label: 'Machine ID *',
                scanTitle: 'Scan Machine QR',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(
              controller: _cQty,
              keyboardType: TextInputType.number,
              decoration: dark
                  ? AppTheme.darkInputDecoration('Quantity (optional)')
                  : AppTheme.inputDecoration('Quantity (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _completeWork,
                style: AppTheme.secondaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _busy
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary)
                      : Text('COMPLETE WORK',
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

  Widget _assignedTasksTab() {
    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Row(children: [
            Expanded(
                child:
                    Text('Assigned Tasks', style: AppTheme.headlineMedium)),
            IconButton(
                onPressed: _loadingTasks ? null : _loadTasks,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh'),
          ])),
          const SizedBox(height: 12),
          if (_loadingTasks)
            const Center(
                child:
                    Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_tasks.isEmpty)
            _card(Text('No active assigned tasks.', style: AppTheme.bodyLarge))
          else
            ..._tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WIP #${t['wipId'] ?? '-'}',
                          style: AppTheme.titleLarge
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Bundle: ${t['bundleId'] ?? '-'}'),
                      Text('Operation: ${t['operationId'] ?? '-'}'),
                      Text('Machine: ${t['machineId'] ?? '-'}'),
                      Text('Qty: ${t['qty'] ?? '-'}'),
                      Text('Started: ${t['startTime'] ?? '-'}'),
                    ],
                  )),
                )),
        ],
      ),
    );
  }

  Widget _performanceTab() {
    return RefreshIndicator(
      onRefresh: _loadPerf,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Row(children: [
            Expanded(
                child: Text('Personal Performance',
                    style: AppTheme.headlineMedium)),
            IconButton(
                onPressed: _loadingPerf ? null : _loadPerf,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh'),
          ])),
          const SizedBox(height: 12),
          if (_loadingPerf)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator()))
          else if (_perf == null)
            _card(Text('No performance data.', style: AppTheme.bodyLarge))
          else
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Operator ID: ${_perf!['operatorId'] ?? widget.empId}',
                    style: AppTheme.titleLarge
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _metric(
                          'Active Tasks',
                          '${_perf!['activeTasks'] ?? 0}')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _metric(
                          'Completed',
                          '${_perf!['completedTasks'] ?? 0}')),
                ]),
              ],
            )),
        ],
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurfaceVariant
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value,
            style: AppTheme.displaySmall.copyWith(
                color: AppTheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title,
            textAlign: TextAlign.center, style: AppTheme.bodySmall),
      ]),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _startWorkTab(),
      _completeWorkTab(),
      _assignedTasksTab(),
      _performanceTab(),
      ProfileTab(empId: _empId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator Workspace'),
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
                      const Icon(Icons.precision_manufacturing,
                          color: Colors.white, size: 34),
                      const SizedBox(height: 10),
                      Text(widget.employeeName,
                          style: AppTheme.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Operator • ID ${widget.empId}',
                          style: AppTheme.bodySmall
                              .copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              _drawerItem(Icons.play_circle_outline, 'Start Work', 0),
              _drawerItem(Icons.task_alt_outlined, 'Complete Work', 1),
              _drawerItem(Icons.assignment_outlined, 'Assigned Tasks', 2),
              _drawerItem(Icons.insights_outlined, 'Performance', 3),
              _drawerItem(Icons.person_outline, 'My Profile', 4),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
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
