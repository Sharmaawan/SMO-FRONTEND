import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart' as excel_pkg hide Border;
import 'package:graphview/graphview.dart' as gv;
import 'package:dio/dio.dart';
import 'api_client.dart';

import 'app_theme.dart';
import 'login_screen.dart';
import 'profile_tab.dart';

class ProcessPlannerWorkspace extends StatefulWidget {
  final String empId;
  final String employeeName;
  final String role;

  const ProcessPlannerWorkspace(
      {super.key,
      required this.empId,
      required this.employeeName,
      required this.role});

  @override
  State<ProcessPlannerWorkspace> createState() =>
      _ProcessPlannerWorkspaceState();
}

class _ProcessPlannerWorkspaceState extends State<ProcessPlannerWorkspace> {
  int _tab = 0;

  // Dashboard Data
  PlatformFile? _selectedFile;
  List<String> _tableHeaders = [];
  List<List<dynamic>> _tableRows = [];
  bool _isReadingFile = false;

  // Products
  List<Map<String, dynamic>> _products = [];
  bool _loadingProducts = false;
  final _productNameCtrl = TextEditingController();
  final _productCategoryCtrl = TextEditingController();
  bool _savingProduct = false;

  // Operations
  List<Map<String, dynamic>> _operations = [];
  bool _loadingOps = false;
  final _opNameCtrl = TextEditingController();
  final _opSeqCtrl = TextEditingController();
  final _opStdTimeCtrl = TextEditingController();
  bool _isParallel = false;
  bool _isMergePoint = false;
  bool _savingOp = false;

  // Routings
  List<Map<String, dynamic>> _routings = [];
  bool _loadingRoutings = false;
  String? _selectedProductId;
  final _routingVersionCtrl = TextEditingController(text: '1');
  bool _savingRouting = false;

  // Routing Steps
  List<Map<String, dynamic>> _steps = [];
  bool _loadingSteps = false;
  String? _selectedRoutingId;
  String? _selectedOpId;
  final _stageGroupCtrl = TextEditingController(text: '1');
  bool _savingStep = false;

  String get _empId => widget.empId.trim();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadOperations();
    _loadRoutings();
  }

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _productCategoryCtrl.dispose();
    _opNameCtrl.dispose();
    _opSeqCtrl.dispose();
    _opStdTimeCtrl.dispose();
    _routingVersionCtrl.dispose();
    _stageGroupCtrl.dispose();
    super.dispose();
  }

  // ── Dashboard Logic ──────────────────────────────────────────────────────

  Future<void> _browseFile() async {
    debugPrint('Opening file picker...');
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        log('File selected: ${result.files.first.name}');
        setState(() {
          _selectedFile = result.files.first;
          _tableHeaders = [];
          _tableRows = [];
        });
      } else {
        log('File selection cancelled');
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      _err('Error picking file: $e');
    }
  }

  Future<void> _readFile() async {
    debugPrint('Starting _readFile process...');
    if (_selectedFile == null) {
      debugPrint('Error: No file selected');
      _err('Please select a file first');
      return;
    }

    setState(() => _isReadingFile = true);

    try {
      var bytes = _selectedFile!.bytes;
      if (bytes == null && _selectedFile!.path != null) {
        debugPrint('File bytes are null, reading from path: ${_selectedFile!.path}');
        bytes = await File(_selectedFile!.path!).readAsBytes();
      }

      if (bytes == null) {
        debugPrint('Error: File bytes are null after attempt to read');
        _err('Could not read file content');
        return;
      }
      debugPrint('File bytes length: ${bytes.length}');

      debugPrint('Decoding Excel bytes...');
      try {
        final decoder = SpreadsheetDecoder.decodeBytes(
          bytes,
          update: false,
        );
        debugPrint('SpreadsheetDecoder successful.');

        if (decoder.tables.keys.isEmpty) {
          _err('No sheets found in the Excel file');
          return;
        }

        final sheetName = decoder.tables.keys.first;
        final sheet = decoder.tables[sheetName];
        final rows = sheet?.rows ?? [];

        debugPrint('Reading sheet: $sheetName');
        debugPrint('Total rows found: ${rows.length}');

        if (rows.isEmpty) {
          _err('No data found in the Excel file');
          setState(() {
            _tableHeaders = [];
            _tableRows = [];
          });
          return;
        }

        setState(() {
          _tableHeaders = rows[0].map((e) => e?.toString() ?? '').toList();
          debugPrint('STEP 1: Headers identified -> $_tableHeaders');

          final headerCount = _tableHeaders.length;
          _tableRows = rows.skip(1).map((row) {
            final list = List<dynamic>.from(row);
            while (list.length < headerCount) {
              list.add('');
            }
            return list.take(headerCount).toList();
          }).toList();

          debugPrint('STEP 2: Successfully mapped ${_tableRows.length} data rows.');
        });
      } catch (e) {
        debugPrint('SpreadsheetDecoder failed, trying Excel fallback: $e');
        final excel = excel_pkg.Excel.decodeBytes(bytes);
        if (excel.tables.keys.isEmpty) {
          _err('No sheets found in the Excel file');
          return;
        }

        final firstSheet = excel.tables.keys.first;
        final table = excel.tables[firstSheet];
        final rows = table?.rows ?? [];

        debugPrint('Reading sheet (fallback): $firstSheet');
        debugPrint('Total rows found (fallback): ${rows.length}');

        if (rows.isEmpty) {
          _err('No data found in the Excel file');
          setState(() {
            _tableHeaders = [];
            _tableRows = [];
          });
          return;
        }

        setState(() {
          _tableHeaders = rows.first.map((e) => e?.value?.toString() ?? '').toList();
          debugPrint('STEP 1 (fallback): Headers identified -> $_tableHeaders');

          final headerCount = _tableHeaders.length;
          _tableRows = rows.skip(1).map((row) {
            final list = row.map((cell) => cell?.value?.toString() ?? '').toList();
            while (list.length < headerCount) {
              list.add('');
            }
            return list.take(headerCount).toList();
          }).toList();

          debugPrint('STEP 2 (fallback): Successfully mapped ${_tableRows.length} data rows.');
        });
      }

      CustomSnackbar.showSuccess(context, 'File read successfully');
    } catch (e, stackTrace) {
      debugPrint('EXCEPTION DURING EXCEL PARSING: $e');
      debugPrint('STACK TRACE: $stackTrace');
      _err('Unable to read this Excel file');
    } finally {
      setState(() => _isReadingFile = false);
      debugPrint('_readFile process finished');
    }
  }

  void _visualizeWorkflow() {
    if (_tableRows.isEmpty) {
      _err('No data to visualize. Please read a file first.');
      return;
    }

    final gv.Graph graph = gv.Graph()..isTree = false;
    final builder = gv.SugiyamaConfiguration()
      ..orientation = gv.SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT
      ..levelSeparation = 100
      ..nodeSeparation = 80;

    final Map<String, gv.Node> nodeMap = {};
    final Set<String> edgeSet = {};

    gv.Node getNode(String id) {
      return nodeMap.putIfAbsent(id, () => gv.Node.Id(id));
    }

    String? findNodeId(String query) {
      if (query.isEmpty) return null;
      for (var r in _tableRows) {
        final rsNo = r.length > 0 ? r[0]?.toString().trim() ?? '' : '';
        final rName = r.length > 1 ? r[1]?.toString().trim() ?? '' : '';
        if (rsNo == query || rName == query) return '$rsNo|$rName';
      }
      return null;
    }

    for (int i = 0; i < _tableRows.length; i++) {
      final row = _tableRows[i];
      final sNo = row.length > 0 ? row[0]?.toString() ?? '' : '';
      final name = row.length > 1 ? row[1]?.toString() ?? 'Unnamed' : 'Unnamed';
      if (name.isEmpty && sNo.isEmpty) continue;

      final currentId = '$sNo|$name';
      final currentNode = getNode(currentId);

      // 1. currentWS -> nextWS (Sequential or Branching)
      final nextWS = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';
      if (nextWS.isNotEmpty) {
        for (var t in nextWS.split(',').map((e) => e.trim())) {
          final targetId = findNodeId(t) ?? t;
          final nextNode = getNode(targetId);
          final edgeKey = "$currentId->$targetId";
          if (!edgeSet.contains(edgeKey)) {
            graph.addEdge(currentNode, nextNode);
            edgeSet.add(edgeKey);
          }
        }
      } else if (i < _tableRows.length - 1) {
        // Fallback: Link to next row if no explicit nextWS
        final nextRow = _tableRows[i + 1];
        final nSNo = nextRow.length > 0 ? nextRow[0]?.toString() ?? '' : '';
        final nName = nextRow.length > 1 ? nextRow[1]?.toString() ?? '' : '';
        if (nSNo.isNotEmpty || nName.isNotEmpty) {
          final nextId = '$nSNo|$nName';
          final nextNode = getNode(nextId);
          final edgeKey = "$currentId->$nextId";
          if (!edgeSet.contains(edgeKey)) {
            graph.addEdge(currentNode, nextNode);
            edgeSet.add(edgeKey);
          }
        }
      }

      // 2. mergeTarget logic (as requested)
      final mTarget = row.length > 4 ? row[4]?.toString().trim() ?? '' : '';
      if (mTarget.isNotEmpty) {
        for (var t in mTarget.split(',').map((e) => e.trim())) {
          final targetId = findNodeId(t) ?? t;
          final mergeNode = getNode(targetId);
          final edgeKey = "$currentId->$targetId";
          if (!edgeSet.contains(edgeKey)) {
            graph.addEdge(currentNode, mergeNode);
            edgeSet.add(edgeKey);
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: const Text('Process Flow Graph'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.1,
              maxScale: 5.0,
              child: gv.GraphView(
                graph: graph,
                algorithm: gv.SugiyamaAlgorithm(builder),
                paint: Paint()
                  ..color = Colors.grey
                  ..strokeWidth = 1.5
                  ..style = PaintingStyle.stroke,
                builder: (gv.Node node) {
                  final String rawValue = node.key!.value as String;
                  final parts = rawValue.split('|');
                  final displayName = parts.length > 1 ? parts[1] : parts[0];
                  return _buildNode(displayName);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNode(String name) {
    bool isMerge = name.toLowerCase().contains('merge') || 
                   name.toLowerCase().contains('final') ||
                   name.toLowerCase().contains('goods');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isMerge ? const Color(0xFFFB8C00) : const Color(0xFF283593),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _submitForReview() async {
    if (_tableRows.isEmpty) {
      _err('No data to submit.');
      return;
    }

    // Prepare data for /api/processplan/{routingId}/draft
    // Since we are creating a NEW draft, we need a routingId. 
    // Usually, this would be generated or asked. We'll use a timestamp or prompt.
    // Based on backend: @PostMapping("/{routingId}/draft")
    
    final routingId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // We need a productId. We'll try to find it from the first row or ask.
    // For now, let's assume the user has a selected product in the UI or we use a default.
    if (_products.isEmpty) {
      await _loadProducts();
    }
    
    if (_products.isEmpty) {
      _err('Please create a product first.');
      return;
    }

    final productId = _products.first['productId'];

    setState(() => _loadingRoutings = true);
    try {
      // Smart Excel parsing - detects column headers and maps accordingly
      final List<Map<String, dynamic>> steps = [];
      
      // Check if first row contains headers
      bool hasHeaders = false;
      List<String> headers = [];
      int startRow = 0;
      
      if (_tableRows.isNotEmpty) {
        final firstRow = _tableRows.first;
        final firstCell = firstRow.isNotEmpty ? firstRow[0]?.toString().toLowerCase() ?? '' : '';
        // Detect headers by checking if first cell contains text like "current", "step", "operation", "sequence"
        if (firstCell.contains('current') || firstCell.contains('step') || 
            firstCell.contains('operation') || firstCell.contains('sequence') ||
            firstCell.contains('ws') || firstCell.contains('work')) {
          hasHeaders = true;
          headers = firstRow.map((cell) => cell?.toString().toLowerCase() ?? '').toList();
          startRow = 1;
        }
      }
      
      // Process each data row
      for (int i = startRow; i < _tableRows.length; i++) {
        final row = _tableRows[i];
        if (row.isEmpty) continue;
        
        // Smart column detection
        String name = '';
        String description = '';
        bool isParallel = false;
        bool mergePoint = false;
        int stageGroup = 1;
        int standardTime = 5;
        
        // Try to find name column (Current WS, Operation, Step, etc.)
        for (int col = 0; col < row.length && col < (hasHeaders ? headers.length : 6); col++) {
          final cellValue = row[col]?.toString() ?? '';
          final header = hasHeaders && col < headers.length ? headers[col] : '';
          
          // Detect name column
          if (name.isEmpty && (
              header.contains('current') || header.contains('ws') || 
              header.contains('operation') || header.contains('step') ||
              header.contains('name') || (col == 0 && !hasHeaders))) {
            name = cellValue;
          }
          // Detect description column
          else if (description.isEmpty && (
              header.contains('description') || header.contains('desc') || 
              header.contains('op description') || (col == 1 && !hasHeaders))) {
            description = cellValue;
          }
          // Detect parallel lines (if column contains comma-separated values or "PARALLEL" in notes)
          else if (header.contains('parallel') || 
                   cellValue.toUpperCase().contains('PARALLEL') ||
                   (col == 5 && cellValue.contains(','))) {
            isParallel = true;
          }
          // Detect merge points (if column contains "MERGE" or "MERGING")
          else if (header.contains('merge') || 
                   cellValue.toUpperCase().contains('MERGE') ||
                   header.contains('notes') && cellValue.toUpperCase().contains('MERGE')) {
            mergePoint = true;
          }
        }
        
        // Fallback: use first non-empty column as name, second as description
        if (name.isEmpty && row.isNotEmpty) {
          name = row[0]?.toString() ?? 'Unnamed';
        }
        if (description.isEmpty && row.length > 1) {
          description = row[1]?.toString() ?? 'No description';
        }
        
        // Detect parallel operations by checking if multiple machines are allocated
        if (row.length > 5) {
          final machinesCell = row[5]?.toString() ?? '';
          if (machinesCell.toLowerCase().contains('parallel') || 
              machinesCell.contains(',') ||
              machinesCell.toLowerCase().contains('bins')) {
            isParallel = true;
          }
        }
        
        // Detect merge points from notes column
        if (row.length > 4) {
          final notesCell = row[4]?.toString() ?? '';
          if (notesCell.toUpperCase().contains('MERGE')) {
            mergePoint = true;
          }
        }
        
        // Stage group detection based on merge points
        if (mergePoint) {
          stageGroup = 2; // Merge points are stage 2
        } else if (isParallel) {
          stageGroup = 1; // Parallel operations are stage 1
        }
        
        steps.add({
          'name': name.isEmpty ? 'Unnamed Step ${i + 1}' : name,
          'description': description.isEmpty ? 'No description' : description,
          'sequence': i - startRow + 1,
          'is_parallel': isParallel,
          'merge_point': mergePoint,
          'stage_group': stageGroup,
          'standard_time': standardTime,
        });
      }

      // Debug: Show detected steps
      debugPrint('Detected ${steps.length} steps from Excel:');
      for (int i = 0; i < steps.length && i < 3; i++) {
        debugPrint('  Step ${i + 1}: ${steps[i]['name']} (parallel: ${steps[i]['is_parallel']}, merge: ${steps[i]['merge_point']})');
      }
      
      if (steps.isEmpty) {
        if (mounted) {
          setState(() => _loadingRoutings = false);
          _err('No valid steps found in Excel. Please check your data.');
        }
        return;
      }
      
      debugPrint('Submitting to: /api/processplan/$routingId/draft with productId: $productId');
      debugPrint('Steps JSON: ${steps.map((s) => s['name']).toList()}');
      
      try {
        final res = await ApiClient().dio.post(
          '/api/processplan/$routingId/draft',
          queryParameters: {
            'productId': productId,
          },
          data: steps,
        );

        debugPrint('Response: ${res.statusCode} - ${res.data}');

        if (mounted && (res.statusCode == 200 || res.statusCode == 201)) {
          CustomSnackbar.showSuccess(context, 'Process submitted for review successfully (Routing #$routingId)');
          _tableRows.clear(); // Clear after successful submission
          _tableHeaders.clear();
          _tab = 3; // Switch to Routings tab to see it
          _loadRoutings();
        } else {
          if (mounted) _err('Server returned: ${res.statusCode}');
        }
      } on DioException catch (e) {
        debugPrint('DioError: ${e.type} - ${e.message}');
        debugPrint('Response: ${e.response?.statusCode} - ${e.response?.data}');
        if (mounted) _err('API Error: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) _err('Submission failed: ${_friendly(e)}');
    } finally {
      if (mounted) setState(() => _loadingRoutings = false);
    }
  }

  // ── Dashboard / Add Process Planner UI ──────────────────────────────────────

  Widget _dashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _processPlannerCard(),
        ],
      ),
    );
  }

  Widget _processPlannerCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: (dark ? AppTheme.darkCardDecoration : AppTheme.cardDecoration).copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: AppTheme.primary,
            child: const Text(
              'Add Process Planner',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            color: dark ? AppTheme.darkSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top Row: Browse File and Add Step (Responsive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          ElevatedButton(
                            onPressed: _browseFile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dark ? AppTheme.darkSurfaceVariant : const Color(0xFFF0F2F5),
                              foregroundColor: dark ? Colors.white : Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(color: dark ? Colors.white12 : Colors.grey.shade300),
                              ),
                            ),
                            child: const Text('Browse File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFile?.name ?? 'no file selected',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _isReadingFile ? null : () {
                            debugPrint('Read button tapped');
                            _readFile();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: _isReadingFile 
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: dark ? Colors.white : Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            debugPrint('Add Step button tapped');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB8C00), // Orange
                            foregroundColor: Colors.white,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Add Step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Table
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: dark ? Colors.white12 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _tableRows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'No data loaded. Please upload and read an Excel file.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ),
                        )
                      : Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: dark ? Colors.white12 : Colors.grey.shade200,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  dark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F9FA),
                                ),
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                dataTextStyle: TextStyle(
                                  fontSize: 13,
                                  color: dark ? Colors.white70 : Colors.black87,
                                ),
                                dataRowMinHeight: 48,
                                dataRowMaxHeight: 100,
                                columnSpacing: 24,
                                horizontalMargin: 16,
                                columns: [
                                  // Only show actual Excel headers from uploaded file
                                  ..._tableHeaders.map((h) => DataColumn(
                                        label: Container(
                                          width: 140,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text(
                                            h,
                                            style: TextStyle(
                                              color: dark ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            softWrap: true,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )),
                                ],
                                rows: _tableRows.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final row = entry.value;
                                  final iconColor = dark ? Colors.white70 : Colors.black54;
                                  return DataRow(
                                    cells: [
                                      ...row.map((cell) => DataCell(
                                            Container(
                                              width: 140,
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Text(
                                                cell?.toString() ?? '',
                                                softWrap: true,
                                                overflow: TextOverflow.visible,
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          )),
                                      // Actions column removed - only showing Excel data
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                // Bottom Buttons (Responsive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _styledButton('Visualize', const Color(0xFF283593), _visualizeWorkflow), // Blue
                    const SizedBox(width: 12),
                    _styledButton('Submit for Review', const Color(0xFF2E7D32), _submitForReview), // Green
                    const SizedBox(width: 12),
                    _styledButton('Cancel', Colors.grey.shade600, () {
                      setState(() {
                        _selectedFile = null;
                        _tableHeaders = [];
                        _tableRows = [];
                      });
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactRow(dynamic sno, String name, String time) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white70 : Colors.black54;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(flex: 1, child: Text('$sno', style: const TextStyle(fontSize: 13))),
              Expanded(flex: 4, child: Text(name, style: const TextStyle(fontSize: 13))),
              Expanded(flex: 2, child: Text(time, style: const TextStyle(fontSize: 13))),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () {}),
                    const SizedBox(width: 10),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () {}),
                    const SizedBox(width: 10),
                    IconButton(icon: Icon(Icons.arrow_upward, size: 18, color: iconColor), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () {}),
                    const SizedBox(width: 10),
                    IconButton(icon: Icon(Icons.arrow_downward, size: 18, color: iconColor), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: dark ? Colors.white12 : Colors.grey.shade100),
      ],
    );
  }

  Widget _styledButton(String label, Color color, [VoidCallback? onPressed]) {
    return ElevatedButton(
      onPressed: onPressed ?? () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiClient().clearEmpId();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final res = await ApiClient().dio.get('/api/production/products');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = res.data as List;
        setState(() => _products =
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _saveProduct() async {
    if (_productNameCtrl.text.trim().isEmpty) {
      _err('Product name is required');
      return;
    }
    setState(() => _savingProduct = true);
    try {
      final data = {
        'productId': DateTime.now().millisecondsSinceEpoch ~/ 10000, // Generating a numeric ID
        'name': _productNameCtrl.text.trim(),
        'category': _productCategoryCtrl.text.trim().isEmpty
            ? 'General'
            : _productCategoryCtrl.text.trim(),
        'status': 'ACTIVE',
      };
      final res = await ApiClient().dio.post(
            '/api/production/products',
            data: data,
          );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        _productNameCtrl.clear();
        _productCategoryCtrl.clear();
        CustomSnackbar.showSuccess(context, 'Product created');
        await _loadProducts();
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _savingProduct = false);
    }
  }

  Future<void> _loadOperations() async {
    setState(() => _loadingOps = true);
    try {
      final res = await ApiClient().dio.get('/api/production/operations');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = res.data as List;
        setState(() => _operations =
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _loadingOps = false);
    }
  }

  Future<void> _saveOperation() async {
    if (_opNameCtrl.text.trim().isEmpty) {
      _err('Operation name is required');
      return;
    }
    setState(() => _savingOp = true);
    try {
      final data = {
        'operationId': DateTime.now().millisecondsSinceEpoch ~/ 10000,
        'name': _opNameCtrl.text.trim(),
        'description': 'Manual Entry',
        'sequence': int.tryParse(_opSeqCtrl.text.trim()) ?? 0,
        'standardTime': int.tryParse(_opStdTimeCtrl.text.trim()) ?? 0,
        'isParallel': _isParallel,
        'mergePoint': _isMergePoint,
        'stageGroup': 1,
      };
      final res = await ApiClient().dio.post(
            '/api/production/operations',
            data: data,
          );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        _opNameCtrl.clear();
        _opSeqCtrl.clear();
        _opStdTimeCtrl.clear();
        setState(() {
          _isParallel = false;
          _isMergePoint = false;
        });
        CustomSnackbar.showSuccess(context, 'Operation created');
        await _loadOperations();
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _savingOp = false);
    }
  }

  Future<void> _loadRoutings() async {
    setState(() => _loadingRoutings = true);
    try {
      final res = await ApiClient().dio.get('/api/production/routings');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = res.data as List;
        setState(() => _routings =
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _loadingRoutings = false);
    }
  }

  Future<void> _saveRouting() async {
    if (_selectedProductId == null) {
      _err('Select a product');
      return;
    }
    setState(() => _savingRouting = true);
    try {
      final data = {
        'routingId': DateTime.now().millisecondsSinceEpoch ~/ 10000,
        'productId': int.tryParse(_selectedProductId!),
        'version': int.tryParse(_routingVersionCtrl.text.trim()) ?? 1,
        'status': 'ACTIVE',
        'approvalStatus': 'PENDING',
      };
      final res = await ApiClient().dio.post(
            '/api/production/routings',
            data: data,
          );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        CustomSnackbar.showSuccess(context, 'Routing created');
        await _loadRoutings();
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _savingRouting = false);
    }
  }

  Future<void> _loadSteps(String routingId) async {
    setState(() => _loadingSteps = true);
    try {
      final res = await ApiClient().dio.get('/api/production/routingsteps/routing/$routingId');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = res.data as List;
        setState(() => _steps =
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _loadingSteps = false);
    }
  }

  Future<void> _saveStep() async {
    if (_selectedRoutingId == null || _selectedOpId == null) {
      _err('Select routing and operation');
      return;
    }
    setState(() => _savingStep = true);
    try {
      final data = {
        'routingStepId': DateTime.now().millisecondsSinceEpoch ~/ 10000,
        'routingId': int.tryParse(_selectedRoutingId!),
        'operationId': int.tryParse(_selectedOpId!),
        'stageGroup': int.tryParse(_stageGroupCtrl.text.trim()) ?? 1,
      };
      final res = await ApiClient().dio.post(
            '/api/production/routingsteps',
            data: data,
          );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        CustomSnackbar.showSuccess(context, 'Step added');
        await _loadSteps(_selectedRoutingId!);
      }
    } catch (e) {
      if (mounted) _err(_friendly(e));
    } finally {
      if (mounted) setState(() => _savingStep = false);
    }
  }

  void _err(String msg) => CustomSnackbar.showError(context, msg);

  String _friendly(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
      return e.message ?? 'API Error';
    }
    return 'Error: $e';
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _card(Widget child) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: dark ? AppTheme.darkCardDecoration : AppTheme.cardDecoration,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType keyboard = TextInputType.text}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration:
            dark ? AppTheme.darkInputDecoration(label) : AppTheme.inputDecoration(label),
      ),
    );
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _productsTab() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Create Product', style: AppTheme.headlineMedium),
            const SizedBox(height: 14),
            _field(_productNameCtrl, 'Product Name *'),
            _field(_productCategoryCtrl, 'Category (optional)'),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingProduct ? null : _saveProduct,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _savingProduct
                      ? const CircularProgressIndicator(color: AppTheme.onPrimary)
                      : Text('CREATE PRODUCT',
                          style: AppTheme.labelLarge
                              .copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ])),
          _card(Row(children: [
            Expanded(child: Text('Products (${_products.length})', style: AppTheme.titleLarge)),
            IconButton(onPressed: _loadingProducts ? null : _loadProducts, icon: const Icon(Icons.refresh)),
          ])),
          if (_loadingProducts)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_products.isEmpty)
            _card(Text('No products yet.', style: AppTheme.bodyLarge))
          else
            ..._products.map((p) => _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['name'] ?? '-'}',
                        style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                    Text('ID: ${p['productId'] ?? '-'} • Category: ${p['category'] ?? '-'} • ${p['status'] ?? '-'}',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.onSurfaceVariant)),
                  ],
                ))),
        ],
      ),
    );
  }

  Widget _operationsTab() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _loadOperations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Create Operation', style: AppTheme.headlineMedium),
            const SizedBox(height: 14),
            _field(_opNameCtrl, 'Operation Name *'),
            _field(_opSeqCtrl, 'Sequence', keyboard: TextInputType.number),
            _field(_opStdTimeCtrl, 'Standard Time (mins)', keyboard: TextInputType.number),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Parallel Operation', style: AppTheme.bodyMedium),
              value: _isParallel,
              onChanged: (v) => setState(() => _isParallel = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Merge Point', style: AppTheme.bodyMedium),
              value: _isMergePoint,
              onChanged: (v) => setState(() => _isMergePoint = v),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingOp ? null : _saveOperation,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _savingOp
                      ? const CircularProgressIndicator(color: AppTheme.onPrimary)
                      : Text('CREATE OPERATION',
                          style: AppTheme.labelLarge
                              .copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ])),
          _card(Row(children: [
            Expanded(child: Text('Operations (${_operations.length})', style: AppTheme.titleLarge)),
            IconButton(onPressed: _loadingOps ? null : _loadOperations, icon: const Icon(Icons.refresh)),
          ])),
          if (_loadingOps)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_operations.isEmpty)
            _card(Text('No operations yet.', style: AppTheme.bodyLarge))
          else
            ..._operations.map((o) => _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${o['name'] ?? '-'}',
                        style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                        'ID: ${o['operationId']} • Seq: ${o['sequence']} • Std Time: ${o['standardTime']} min',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.onSurfaceVariant)),
                    Wrap(spacing: 8, children: [
                      if (o['isParallel'] == true)
                        Chip(
                            label: Text('Parallel',
                                style: AppTheme.labelMedium.copyWith(color: AppTheme.primary))),
                      if (o['mergePoint'] == true)
                        Chip(
                            label: Text('Merge Point',
                                style: AppTheme.labelMedium.copyWith(color: AppTheme.secondary))),
                    ]),
                  ],
                ))),
        ],
      ),
    );
  }

  Widget _routingsTab() {
    return RefreshIndicator(
      onRefresh: _loadRoutings,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Create Routing', style: AppTheme.headlineMedium),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              decoration: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkInputDecoration('Select Product *')
                  : AppTheme.inputDecoration('Select Product *'),
              items: _products
                  .map((p) => DropdownMenuItem<String>(
                      value: '${p['productId']}',
                      child: Text('${p['name']} (ID: ${p['productId']})')))
                  .toList(),
              onChanged: (v) => setState(() => _selectedProductId = v),
            ),
            const SizedBox(height: 12),
            _field(_routingVersionCtrl, 'Version', keyboard: TextInputType.number),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingRouting ? null : _saveRouting,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _savingRouting
                      ? const CircularProgressIndicator(color: AppTheme.onPrimary)
                      : Text('CREATE ROUTING',
                          style: AppTheme.labelLarge
                              .copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ])),
          _card(Row(children: [
            Expanded(child: Text('Routings (${_routings.length})', style: AppTheme.titleLarge)),
            IconButton(onPressed: _loadingRoutings ? null : _loadRoutings, icon: const Icon(Icons.refresh)),
          ])),
          if (_loadingRoutings)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_routings.isEmpty)
            _card(Text('No routings yet.', style: AppTheme.bodyLarge))
          else
            ..._routings.map((r) => _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Routing #${r['routingId']}',
                        style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                        'Product ID: ${r['productId']} • Version: ${r['version']} • ${r['status']}',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.onSurfaceVariant)),
                  ],
                ))),
        ],
      ),
    );
  }

  Widget _stepsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Routing Step', style: AppTheme.headlineMedium),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedRoutingId,
            decoration: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkInputDecoration('Select Routing *')
                : AppTheme.inputDecoration('Select Routing *'),
            items: _routings
                .map((r) => DropdownMenuItem<String>(
                    value: '${r['routingId']}',
                    child: Text('Routing #${r['routingId']} (Product ${r['productId']})')))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedRoutingId = v;
                _steps = [];
              });
              if (v != null) _loadSteps(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedOpId,
            decoration: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkInputDecoration('Select Operation *')
                : AppTheme.inputDecoration('Select Operation *'),
            items: _operations
                .map((o) => DropdownMenuItem<String>(
                    value: '${o['operationId']}',
                    child: Text('${o['name']} (ID: ${o['operationId']})')))
                .toList(),
            onChanged: (v) => setState(() => _selectedOpId = v),
          ),
          const SizedBox(height: 12),
          _field(_stageGroupCtrl, 'Stage Group', keyboard: TextInputType.number),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingStep ? null : _saveStep,
              style: AppTheme.secondaryButtonStyle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _savingStep
                    ? const CircularProgressIndicator(color: AppTheme.onPrimary)
                    : Text('ADD STEP',
                        style: AppTheme.labelLarge
                            .copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ])),
        if (_selectedRoutingId != null) ...[
          _card(Text('Steps for Routing #$_selectedRoutingId',
              style: AppTheme.titleLarge)),
          if (_loadingSteps)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_steps.isEmpty)
            _card(Text('No steps yet.', style: AppTheme.bodyLarge))
          else
            ..._steps.map((s) => _card(Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(
                        child: Text('${s['stageGroup']}',
                            style: AppTheme.titleMedium
                                .copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Step #${s['routingStepId']}',
                        style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                    Text('Operation ID: ${s['operationId']}',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.onSurfaceVariant)),
                  ])),
                ]))),
        ],
      ],
    );
  }

  Widget _drawerItem(IconData icon, String label, int index) {
    final sel = _tab == index;
    return ListTile(
      leading: Icon(icon, color: sel ? AppTheme.primary : AppTheme.onSurfaceVariant),
      title: Text(label,
          style: AppTheme.bodyMedium.copyWith(
              color: sel ? AppTheme.primary : AppTheme.onSurface,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
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
      _productsTab(),
      _operationsTab(),
      _routingsTab(),
      _stepsTab(),
      ProfileTab(empId: _empId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Dashboard' : 'Process Planner'),
        actions: [
          IconButton(onPressed: _logout, tooltip: 'Logout', icon: const Icon(Icons.logout)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${widget.employeeName} • EMP ${widget.empId}',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.onPrimary)),
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
                      end: Alignment.bottomRight),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.account_tree_outlined, color: Colors.white, size: 34),
                      const SizedBox(height: 10),
                      Text(widget.employeeName,
                          style: AppTheme.titleLarge
                              .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Process Planner • ID ${widget.empId}',
                          style: AppTheme.bodySmall.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              _drawerItem(Icons.dashboard_outlined, 'Dashboard', 0),
              _drawerItem(Icons.inventory_outlined, 'Products', 1),
              _drawerItem(Icons.settings_outlined, 'Operations', 2),
              _drawerItem(Icons.route_outlined, 'Routings', 3),
              _drawerItem(Icons.list_alt_outlined, 'Routing Steps', 4),
              _drawerItem(Icons.person_outline, 'My Profile', 5),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.error),
                title: Text('Logout',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.error, fontWeight: FontWeight.w700)),
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
