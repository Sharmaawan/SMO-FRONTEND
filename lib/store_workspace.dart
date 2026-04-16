import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'login_screen.dart';
import 'profile_tab.dart';

class StoreWorkspace extends StatefulWidget {
  final String empId;
  final String employeeName;
  final String role;

  const StoreWorkspace({
    super.key,
    required this.empId,
    required this.employeeName,
    required this.role,
  });

  @override
  State<StoreWorkspace> createState() => _StoreWorkspaceState();
}

class _StoreWorkspaceState extends State<StoreWorkspace> {
  int _selectedTab = 0;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _stockLevels = [];
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _grns = [];

  bool _loadingInventory = false;
  bool _loadingStockLevels = false;
  bool _loadingMovements = false;
  bool _loadingItems = false;
  bool _loadingGrns = false;

  // Manage Inventory form
  final _manageItemIdController = TextEditingController();
  final _manageQtyController = TextEditingController();
  final _manageLocationController = TextEditingController(text: 'MAIN');
  final _manageBatchController = TextEditingController();

  // Issue Material form
  final _issueItemIdController = TextEditingController();
  final _issueQtyController = TextEditingController();
  final _issueLocationController = TextEditingController(text: 'MAIN');
  final _issueBundleIdController = TextEditingController();

  // Item form
  final _itemNameCtrl = TextEditingController();
  final _itemTypeCtrl = TextEditingController();
  final _itemCategoryCtrl = TextEditingController();
  final _itemUnitCtrl = TextEditingController();

  // GRN form
  final _grnPoIdCtrl = TextEditingController();

  String get _actorEmpId => widget.empId.trim();

  @override
  void initState() {
    super.initState();
    _refreshAll();
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
    _manageItemIdController.dispose();
    _manageQtyController.dispose();
    _manageLocationController.dispose();
    _manageBatchController.dispose();
    _issueItemIdController.dispose();
    _issueQtyController.dispose();
    _issueLocationController.dispose();
    _issueBundleIdController.dispose();
    _itemNameCtrl.dispose();
    _itemTypeCtrl.dispose();
    _itemCategoryCtrl.dispose();
    _itemUnitCtrl.dispose();
    _grnPoIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchInventory(),
      _fetchStockLevels(),
      _fetchMovements(),
      _fetchItems(),
      _fetchGrns(),
    ]);
  }

  Future<void> _fetchInventory() async {
    setState(() => _loadingInventory = true);
    try {
      final res = await ApiClient().dio.get('/api/store/inventory');

      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = res.data;
        if (decoded is List) {
          setState(() {
            _inventory = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        } else {
          setState(() => _inventory = []);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to fetch inventory');
    } finally {
      if (mounted) setState(() => _loadingInventory = false);
    }
  }

  Future<void> _fetchStockLevels() async {
    setState(() => _loadingStockLevels = true);
    try {
      final res = await ApiClient().dio.get('/api/store/stock-levels');

      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = res.data;
        if (decoded is List) {
          setState(() {
            _stockLevels = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        } else {
          setState(() => _stockLevels = []);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to fetch stock levels');
    } finally {
      if (mounted) setState(() => _loadingStockLevels = false);
    }
  }

  Future<void> _fetchMovements() async {
    setState(() => _loadingMovements = true);
    try {
      final res = await ApiClient().dio.get('/api/store/stock-movements');

      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = res.data;
        if (decoded is List) {
          setState(() {
            _movements = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        } else {
          setState(() => _movements = []);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to fetch movements');
    } finally {
      if (mounted) setState(() => _loadingMovements = false);
    }
  }

  Future<void> _upsertInventory() async {
    final itemId = int.tryParse(_manageItemIdController.text.trim());
    final qty = int.tryParse(_manageQtyController.text.trim());
    final location = _manageLocationController.text.trim();
    final batch = _manageBatchController.text.trim();

    if (itemId == null || qty == null) {
      CustomSnackbar.showError(
        context,
        'itemId and qty are required and must be numbers',
      );
      return;
    }

    final body = {
      'itemId': itemId,
      'qty': qty,
      'location': location.isEmpty ? 'MAIN' : location,
      'batch': batch.isEmpty ? null : batch,
    };

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiClient().dio.post(
            '/api/store/inventory',
            data: body,
          );

      if (!mounted) return;
      if (res.statusCode == 200) {
        CustomSnackbar.showSuccess(context, 'Inventory updated');
        await _fetchInventory();
        await _fetchStockLevels();
        await _fetchMovements();
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to update inventory');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _issueMaterial() async {
    final itemId = int.tryParse(_issueItemIdController.text.trim());
    final qty = int.tryParse(_issueQtyController.text.trim());
    final location = _issueLocationController.text.trim();
    final bundleIdText = _issueBundleIdController.text.trim();
    final bundleId = bundleIdText.isEmpty ? null : int.tryParse(bundleIdText);

    if (itemId == null || qty == null || qty <= 0) {
      CustomSnackbar.showError(context, 'itemId and positive qty are required');
      return;
    }

    if (bundleIdText.isNotEmpty && bundleId == null) {
      CustomSnackbar.showError(context, 'bundleId must be numeric');
      return;
    }

    final body = {
      'itemId': itemId,
      'qty': qty,
      'location': location.isEmpty ? 'MAIN' : location,
      'bundleId': bundleId,
    };

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiClient().dio.post(
            '/api/store/issue-material',
            data: body,
          );

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = res.data;
        final remain = data?['remainingQty']?.toString() ?? '-';
        CustomSnackbar.showSuccess(
          context,
          'Material issued. Remaining Qty: $remain',
        );
        await _fetchInventory();
        await _fetchStockLevels();
        await _fetchMovements();
      }
    } catch (e) {
      if (!mounted) return;
      _handleDioError(e, 'Failed to issue material');
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

  Widget _inventoryList(List<Map<String, dynamic>> data, bool loading) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (data.isEmpty) {
      return _sectionCard(
        child: Text('No data found.', style: AppTheme.bodyLarge),
      );
    }

    return Column(
      children: data.map((item) {
        final stockId = item['stockId'] ?? '-';
        final itemId = item['itemId'] ?? '-';
        final qty = item['qty'] ?? '-';
        final location = item['location'] ?? '-';
        final batch = item['batch'] ?? '-';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock #$stockId',
                  style: AppTheme.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Item ID: $itemId'),
                Text('Qty: $qty'),
                Text('Location: $location'),
                Text('Batch: $batch'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _movementList() {
    if (_loadingMovements) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_movements.isEmpty) {
      return _sectionCard(
        child: Text('No stock movements found.', style: AppTheme.bodyLarge),
      );
    }

    return Column(
      children: _movements.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Movement #${m['movementId'] ?? '-'}',
                  style: AppTheme.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Item ID: ${m['itemId'] ?? '-'}'),
                Text('Type: ${m['type'] ?? '-'}'),
                Text('Qty: ${m['qty'] ?? '-'}'),
                Text('Timestamp: ${m['timestamp'] ?? '-'}'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventoryTab() {
    return RefreshIndicator(
      onRefresh: _fetchInventory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Text('Inventory', style: AppTheme.headlineMedium),
                ),
                IconButton(
                  onPressed: _loadingInventory ? null : _fetchInventory,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _inventoryList(_inventory, _loadingInventory),
        ],
      ),
    );
  }

  Widget _buildManageInventoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manage Inventory', style: AppTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'Create/update stock using live backend API. No hardcoded values.',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manageItemIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Item ID *')
                    : AppTheme.inputDecoration('Item ID *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manageQtyController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Quantity *')
                    : AppTheme.inputDecoration('Quantity *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manageLocationController,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Location (default MAIN)')
                    : AppTheme.inputDecoration('Location (default MAIN)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manageBatchController,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Batch (optional)')
                    : AppTheme.inputDecoration('Batch (optional)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _upsertInventory,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'SAVE INVENTORY',
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

  Widget _buildStockLevelsTab() {
    return RefreshIndicator(
      onRefresh: _fetchStockLevels,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Text('Stock Levels', style: AppTheme.headlineMedium),
                ),
                IconButton(
                  onPressed: _loadingStockLevels ? null : _fetchStockLevels,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _inventoryList(_stockLevels, _loadingStockLevels),
        ],
      ),
    );
  }

  Widget _buildIssueMaterialTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Issue Material', style: AppTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _issueItemIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Item ID *')
                    : AppTheme.inputDecoration('Item ID *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issueQtyController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Issue Qty *')
                    : AppTheme.inputDecoration('Issue Qty *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issueLocationController,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Location (default MAIN)')
                    : AppTheme.inputDecoration('Location (default MAIN)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issueBundleIdController,
                keyboardType: TextInputType.number,
                decoration: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkInputDecoration('Bundle ID (optional)')
                    : AppTheme.inputDecoration('Bundle ID (optional)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _issueMaterial,
                style: AppTheme.secondaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimary,
                        )
                      : Text(
                          'ISSUE MATERIAL',
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

  Widget _buildMovementsTab() {
    return RefreshIndicator(
      onRefresh: _fetchMovements,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Stock Movements',
                    style: AppTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: _loadingMovements ? null : _fetchMovements,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _movementList(),
        ],
      ),
    );
  }

  Future<void> _fetchItems() async {
    setState(() => _loadingItems = true);
    try {
      final res = await ApiClient().dio.get('/api/store/items');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = res.data;
        setState(() {
          _items = decoded is List
              ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _fetchGrns() async {
    setState(() => _loadingGrns = true);
    try {
      final res = await ApiClient().dio.get('/api/store/grn');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = res.data;
        setState(() {
          _grns = decoded is List
              ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingGrns = false);
    }
  }

  Future<void> _createItem() async {
    if (_itemNameCtrl.text.trim().isEmpty) {
      CustomSnackbar.showError(context, 'Item name is required');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final body = {
        'name': _itemNameCtrl.text.trim(),
        'type': _itemTypeCtrl.text.trim().isEmpty ? null : _itemTypeCtrl.text.trim(),
        'category': _itemCategoryCtrl.text.trim().isEmpty ? null : _itemCategoryCtrl.text.trim(),
        'unit': _itemUnitCtrl.text.trim().isEmpty ? null : _itemUnitCtrl.text.trim(),
        'status': 'ACTIVE',
      };
      final res = await ApiClient().dio.post('/api/store/items', data: body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        _itemNameCtrl.clear(); _itemTypeCtrl.clear();
        _itemCategoryCtrl.clear(); _itemUnitCtrl.clear();
        CustomSnackbar.showSuccess(context, 'Item created');
        await _fetchItems();
      }
    } catch (e) {
      if (mounted) _handleDioError(e, 'Failed to create item');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createGrn() async {
    setState(() => _isSubmitting = true);
    try {
      final body = {
        'poId': _grnPoIdCtrl.text.trim().isEmpty ? null : int.tryParse(_grnPoIdCtrl.text.trim()),
        'status': 'RECEIVED',
      };
      final res = await ApiClient().dio.post('/api/store/grn', data: body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        _grnPoIdCtrl.clear();
        CustomSnackbar.showSuccess(context, 'GRN created');
        await _fetchGrns();
      }
    } catch (e) {
      if (mounted) _handleDioError(e, 'Failed to create GRN');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildItemsTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _fetchItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Create Item', style: AppTheme.headlineMedium),
            const SizedBox(height: 14),
            TextField(controller: _itemNameCtrl,
                decoration: dark ? AppTheme.darkInputDecoration('Item Name *') : AppTheme.inputDecoration('Item Name *')),
            const SizedBox(height: 12),
            TextField(controller: _itemTypeCtrl,
                decoration: dark ? AppTheme.darkInputDecoration('Type') : AppTheme.inputDecoration('Type')),
            const SizedBox(height: 12),
            TextField(controller: _itemCategoryCtrl,
                decoration: dark ? AppTheme.darkInputDecoration('Category') : AppTheme.inputDecoration('Category')),
            const SizedBox(height: 12),
            TextField(controller: _itemUnitCtrl,
                decoration: dark ? AppTheme.darkInputDecoration('Unit (e.g. meters, pcs)') : AppTheme.inputDecoration('Unit (e.g. meters, pcs)')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _isSubmitting ? null : _createItem,
              style: AppTheme.primaryButtonStyle,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
                child: _isSubmitting ? const CircularProgressIndicator(color: AppTheme.onPrimary)
                    : Text('CREATE ITEM', style: AppTheme.labelLarge.copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold))),
            )),
          ])),
          _sectionCard(child: Row(children: [
            Expanded(child: Text('Items (${_items.length})', style: AppTheme.titleLarge)),
            IconButton(onPressed: _loadingItems ? null : _fetchItems, icon: const Icon(Icons.refresh)),
          ])),
          if (_loadingItems)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            _sectionCard(child: Text('No items yet.', style: AppTheme.bodyLarge))
          else
            ..._items.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i['name'] ?? '-'}', style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                Text('ID: ${i['itemId']} • Type: ${i['type'] ?? '-'} • Unit: ${i['unit'] ?? '-'} • ${i['status'] ?? '-'}',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.onSurfaceVariant)),
              ])),
            )),
        ],
      ),
    );
  }

  Widget _buildGrnTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _fetchGrns,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Receive Goods (GRN)', style: AppTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Create a Goods Receipt Note when goods arrive.', style: AppTheme.bodyMedium.copyWith(color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            TextField(controller: _grnPoIdCtrl, keyboardType: TextInputType.number,
                decoration: dark ? AppTheme.darkInputDecoration('Purchase Order ID (optional)') : AppTheme.inputDecoration('Purchase Order ID (optional)')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _isSubmitting ? null : _createGrn,
              style: AppTheme.secondaryButtonStyle,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
                child: _isSubmitting ? const CircularProgressIndicator(color: AppTheme.onPrimary)
                    : Text('CREATE GRN', style: AppTheme.labelLarge.copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold))),
            )),
          ])),
          _sectionCard(child: Row(children: [
            Expanded(child: Text('GRN Records (${_grns.length})', style: AppTheme.titleLarge)),
            IconButton(onPressed: _loadingGrns ? null : _fetchGrns, icon: const Icon(Icons.refresh)),
          ])),
          if (_loadingGrns)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_grns.isEmpty)
            _sectionCard(child: Text('No GRN records yet.', style: AppTheme.bodyLarge))
          else
            ..._grns.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GRN #${g['grnId'] ?? '-'}', style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                Text('PO ID: ${g['poId'] ?? '-'} • Date: ${g['date'] ?? '-'} • ${g['status'] ?? '-'}',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.onSurfaceVariant)),
              ])),
            )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _buildInventoryTab(),
      _buildManageInventoryTab(),
      _buildStockLevelsTab(),
      _buildIssueMaterialTab(),
      _buildMovementsTab(),
      _buildItemsTab(),
      _buildGrnTab(),
      ProfileTab(empId: _actorEmpId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Manager Workspace'),
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
                        Icons.storefront_outlined,
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
                        'Store Manager • ID ${widget.empId}',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _drawerItem(icon: Icons.inventory_2_outlined, label: 'Inventory', index: 0),
              _drawerItem(icon: Icons.edit_note_outlined, label: 'Manage Inventory', index: 1),
              _drawerItem(icon: Icons.stacked_bar_chart_outlined, label: 'Stock Levels', index: 2),
              _drawerItem(icon: Icons.outbox_outlined, label: 'Issue Material', index: 3),
              _drawerItem(icon: Icons.swap_horiz_outlined, label: 'Stock Movements', index: 4),
              _drawerItem(icon: Icons.category_outlined, label: 'Items', index: 5),
              _drawerItem(icon: Icons.local_shipping_outlined, label: 'Receive Goods (GRN)', index: 6),
              _drawerItem(icon: Icons.person_outline, label: 'My Profile', index: 7),
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
