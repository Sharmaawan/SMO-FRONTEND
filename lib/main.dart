import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'package:dio/dio.dart';

import 'login_screen.dart';
import 'app_config.dart';
import 'app_theme.dart';
import 'hr_dashboard_screen.dart';
import 'operator_workspace.dart';
import 'store_workspace.dart';
import 'qc_workspace.dart';
import 'purchase_workspace.dart';
import 'floor_manager_workspace.dart';
import 'gm_workspace.dart';
import 'process_planner_workspace.dart';

// Current app version — update this when releasing a new build
const String kAppVersion = '1.0';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  bool _isLoading = true;
  bool _isCheckingConnection = true;
  String _connectionStatus = 'Checking server connection...';
  bool _connectionSuccess = false;
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    debugPrint('Initializing app...');
    await _loadThemePreference();
    debugPrint('Theme loaded');
    await _restoreSession();
    debugPrint('Session restored, home: ${_home?.runtimeType}');
    
    // Start connection check but don't block on it
    _checkBackendConnection();
    
    // Minimum splash screen display time (1.5 seconds)
    await Future.delayed(const Duration(milliseconds: 1500));
    
    debugPrint('Setting isLoading to false');
    setState(() => _isLoading = false);
  }

  Future<void> _checkBackendConnection() async {
    try {
      // Use a longer timeout for the health check (45 seconds) for Render cold start
      final res = await ApiClient().dio.get(
        '/api/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      if (res.statusCode == 200) {
        setState(() {
          _connectionStatus = 'Server is running';
          _connectionSuccess = true;
          _isCheckingConnection = false;
        });
      } else {
        setState(() {
          _connectionStatus = 'Server returned error: ${res.statusCode}';
          _connectionSuccess = false;
          _isCheckingConnection = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _connectionSuccess = false;
        _isCheckingConnection = false;
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            _connectionStatus = 'Server is waking up (Render free tier). Please wait...';
            break;
          case DioExceptionType.connectionError:
            _connectionStatus = 'Cannot connect to server. Please check your network.';
            break;
          case DioExceptionType.badResponse:
            _connectionStatus = 'Server error: ${e.response?.statusCode}';
            break;
          case DioExceptionType.cancel:
            _connectionStatus = 'Request was cancelled.';
            break;
          default:
            _connectionStatus = 'Connection failed: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Unexpected error: $e';
        _connectionSuccess = false;
        _isCheckingConnection = false;
      });
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('dark_mode') ?? false;
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('ROLE') ?? '').toUpperCase().trim();
    final empId = prefs.getString('EMP_ID');
    final employeeName = prefs.getString('EMPLOYEE_NAME') ?? 'Employee';

    if (empId != null && empId.isNotEmpty && role.isNotEmpty) {
      ApiClient().setEmpId(empId);
      _home = _buildHomeForRole(role, empId, employeeName);
      return;
    }
    _home = LoginScreen(setDarkMode: setDarkMode);
  }

  Widget _buildHomeForRole(String role, String empId, String employeeName) {
    // HR / Admin
    if (role == 'HR' || role == 'ADMIN') {
      return HrDashboardScreen(setDarkMode: setDarkMode);
    }
    // Operator-type roles — all use OperatorWorkspace
    if (role == 'OPERATOR' ||
        role == 'CUTTER' ||
        role == 'STITCHER' ||
        role == 'IRONING' ||
        role == 'PACKAGER') {
      return OperatorWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // Store Manager
    if (role == 'STORE MANAGER') {
      return StoreWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // Purchase Manager
    if (role == 'PURCHASE MANAGER') {
      return PurchaseWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // QC roles
    if (role == 'QC ENGINEER' ||
        role == 'QUALITY CONTROL ENGINEER' ||
        role == 'QUALITY CONTROL MANAGER' ||
        role == 'QC MANAGER') {
      return QcWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // Floor Manager / Supervisor
    if (role == 'FLOOR MANAGER' || role == 'SUPERVISOR') {
      return FloorManagerWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // GM
    if (role == 'GM') {
      return GmWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // Process Planner
    if (role == 'PROCESS PLANNER') {
      return ProcessPlannerWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // Fallback
    return HrDashboardScreen(setDarkMode: setDarkMode);
  }

  void setDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDarkMode);
    setState(() => _isDarkMode = isDarkMode);
  }

  void _showConnectionSnackbar(BuildContext context) {
    // Show snackbar with connection result
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_connectionSuccess) {
        CustomSnackbar.showSuccess(
          context,
          'Server is running, Connected to $baseUrl',
        );
      } else {
        CustomSnackbar.showError(
          context,
          'Connection issue: $_connectionStatus',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        title: 'SMO App',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryVariant],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  const Icon(
                    Icons.precision_manufacturing,
                    size: 80,
                    color: AppTheme.onPrimary,
                  ),
                  const SizedBox(height: 24),
                  // App Name
                  const Text(
                    'SMO System',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sewing Machine Operations',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Simple loading indicator
                  const CircularProgressIndicator(
                    color: AppTheme.onPrimary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'SMO App',
      theme: AppTheme.themeData,
      darkTheme: AppTheme.darkThemeData,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) {
          // Show connection snackbar when app loads
          _showConnectionSnackbar(context);
          return _home ?? LoginScreen(setDarkMode: setDarkMode);
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
