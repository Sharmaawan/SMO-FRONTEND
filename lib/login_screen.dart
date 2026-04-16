import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'models.dart';
import 'app_theme.dart';
import 'hr_dashboard_screen.dart';
import 'operator_workspace.dart';
import 'store_workspace.dart';
import 'qc_workspace.dart';
import 'purchase_workspace.dart';
import 'floor_manager_workspace.dart';
import 'gm_workspace.dart';
import 'process_planner_workspace.dart';
import 'api_client.dart';

class LoginScreen extends StatefulWidget {
  final Function(bool)? setDarkMode;

  const LoginScreen({super.key, this.setDarkMode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Employee ID is required';
    }
    if (value.trim().length < 3) {
      return 'Employee ID must be at least 3 characters';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'Employee ID must contain only numbers';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.trim().length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  Future<void> _performLogin() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      CustomSnackbar.showError(context, "Please enter both Employee ID and Password");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = LoginRequest(loginid: username, password: password);
      
      final response = await ApiClient().dio.post(
        '/api/auth/login',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final roleResponse = RoleResponse.fromJson(response.data);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('EMPLOYEE_NAME', roleResponse.employeeName);
        await prefs.setString('ROLE', roleResponse.role);
        await prefs.setString('EMP_ID', roleResponse.empId);
        
        // Set Emp ID in ApiClient
        ApiClient().setEmpId(roleResponse.empId);

        if (!mounted) return;

        final normalizedRole = roleResponse.role.toUpperCase().trim();
        final Widget home = _buildHomeForRole(
          normalizedRole,
          roleResponse.empId,
          roleResponse.employeeName,
        );
        
        CustomSnackbar.showSuccess(
            context, 'Welcome ${roleResponse.employeeName}');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => home),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String message = "Login failed";
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          message = "Invalid username or password";
        } else {
          // ApiClient already logs and handles basic errors, 
          // but we can extract specific messages from response body if available
          final data = e.response?.data;
          if (data is Map && data.containsKey('message')) {
            message = data['message'];
          } else if (data is String && data.isNotEmpty) {
            message = data;
          }
        }
      }
      CustomSnackbar.showError(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildHomeForRole(String role, String empId, String employeeName) {
    if (role == 'HR' || role == 'ADMIN') {
      return HrDashboardScreen(setDarkMode: widget.setDarkMode);
    }
    if (role == 'OPERATOR' ||
        role == 'CUTTER' ||
        role == 'STITCHER' ||
        role == 'IRONING' ||
        role == 'PACKAGER') {
      return OperatorWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    if (role == 'STORE MANAGER') {
      return StoreWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    if (role == 'PURCHASE MANAGER') {
      return PurchaseWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    if (role == 'QC ENGINEER' ||
        role == 'QUALITY CONTROL ENGINEER' ||
        role == 'QUALITY CONTROL MANAGER' ||
        role == 'QC MANAGER') {
      return QcWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    if (role == 'FLOOR MANAGER' || role == 'SUPERVISOR') {
      return FloorManagerWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    if (role == 'GM') {
      return GmWorkspace(empId: empId, employeeName: employeeName, role: role);
    }
    if (role == 'PROCESS PLANNER') {
      return ProcessPlannerWorkspace(
          empId: empId, employeeName: employeeName, role: role);
    }
    // Fallback
    return HrDashboardScreen(setDarkMode: widget.setDarkMode);
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is removed
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Scaffold is the base for a screen in Flutter
    return Scaffold(
      // The Container with BoxDecoration creates the background gradient
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryVariant],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          // Make the entire screen scrollable to avoid jumps
          child: SizedBox(
            // Set exact height to physical screen size to keep alignment fixed
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  decoration: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkCardDecoration
                      : AppTheme.cardDecoration,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min, // To make the card wrap its content
                        crossAxisAlignment: CrossAxisAlignment
                            .stretch, // Makes children fill the width
                        children: [
                        // App logo or icon
                        const Icon(
                          Icons.precision_manufacturing,
                          size: 64,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "SMO System",
                          textAlign: TextAlign.center,
                          style: AppTheme.headlineLarge.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkOnSurface
                                : AppTheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Sewing Machine Operations",
                          textAlign: TextAlign.center,
                          style: AppTheme.titleLarge.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "Welcome Back",
                          textAlign: TextAlign.center,
                          style: AppTheme.headlineMedium.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkOnSurface
                                : AppTheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Sign in to continue",
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyLarge.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Employee ID field with validation
                        TextFormField(
                          controller: _usernameController,
                          validator: _validateUsername,
                          keyboardType: TextInputType.number,
                          decoration:
                              Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkInputDecoration("Employee ID")
                              : AppTheme.inputDecoration("Employee ID"),
                        ),
                        const SizedBox(height: 16),
                        // Password field with validation
                        TextFormField(
                          controller: _passwordController,
                          validator: _validatePassword,
                          obscureText: _obscurePassword,
                          decoration: (Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkInputDecoration("Password")
                              : AppTheme.inputDecoration("Password"))
                              .copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword 
                                      ? Icons.visibility_off 
                                      : Icons.visibility),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                        ),
                        const SizedBox(height: 24),
                        // The Button is now an ElevatedButton
                        ElevatedButton(
                          onPressed: _isLoading ? null : _performLogin,
                          style: AppTheme.primaryButtonStyle,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: AppTheme.onPrimary,
                                  )
                                : Text(
                                    "LOGIN",
                                    style: AppTheme.labelLarge.copyWith(
                                      color: AppTheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
