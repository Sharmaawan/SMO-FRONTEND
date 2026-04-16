import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'login_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  final Function(bool)? setDarkMode;
  final String role;
  final String empId;
  final String employeeName;

  const RoleHomeScreen({
    super.key,
    required this.role,
    required this.empId,
    required this.employeeName,
    this.setDarkMode,
  });

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  static const Map<String, List<String>> _featuresByRole = {
    'ADMIN': [
      'Manage Users',
      'Role & Permission Setup',
      'System Configuration',
    ],
    'OPERATOR': [
      'Scan QR Code',
      'Start Work',
      'Complete Work',
      'View Assigned Tasks',
      'View Personal Performance',
    ],
    'STORE MANAGER': [
      'View Inventory',
      'Manage Inventory',
      'View Stock Levels',
      'Issue Material',
      'View Stock Movements',
    ],
    'PURCHASE MANAGER': [
      'Create Vendor/Supplier',
      'View Vendor List',
      'Update Vendor Status',
      'Create Purchase Order',
      'Select Vendor (Acceptable Only)',
    ],
    'QC ENGINEER': [
      'Perform QC Inspection',
      'Record Defects',
      'Approve / Reject',
      'Send for Rework',
    ],
    'FLOOR MANAGER': [
      'Monitor WIP',
      'View Line Balancing',
      'Detect Bottlenecks',
      'View Operator Performance',
      'View AI Insights',
      'Reassign Work',
    ],
    'SUPERVISOR': [
      'Monitor WIP',
      'View Line Balancing',
      'Detect Bottlenecks',
      'View Operator Performance',
      'View AI Insights',
      'Reassign Work',
    ],
    'GM': [
      'View Production Performance',
      'View Inventory Analysis',
      'View Report',
    ],
    'PROCESS PLANNER': [
      'Define Product Routing',
      'Define Operations',
      'Define Parallel Steps',
      'Define Merge Points',
      'Set Standard Time',
      'Define WIP Limits',
    ],
  };

  int _selectedIndex = 0;

  List<String> get _features {
    final normalizedRole = widget.role.trim().toUpperCase();
    return _featuresByRole[normalizedRole] ?? ['Dashboard'];
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('EMPLOYEE_NAME');
    await prefs.remove('ROLE');
    await prefs.remove('EMP_ID');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(setDarkMode: widget.setDarkMode),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final selectedFeature = _features[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role} Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryVariant],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white),
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
                      'ID: ${widget.empId}',
                      style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _features.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedIndex;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? AppTheme.primary : null,
                      ),
                      title: Text(_features[index]),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: brightness == Brightness.dark
              ? const LinearGradient(
                  colors: [Color(0xFF0E1425), Color(0xFF101B35)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : const LinearGradient(
                  colors: [Color(0xFFF2F6FF), Color(0xFFFFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: brightness == Brightness.dark
                  ? AppTheme.darkCardDecoration
                  : AppTheme.cardDecoration,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedFeature,
                      style: AppTheme.headlineMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Screen wiring is active for your role. Next step is connecting this feature to its dedicated API workflow.',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: brightness == Brightness.dark
                  ? AppTheme.darkCardDecoration
                  : AppTheme.cardDecoration,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Role access is enforced from backend activities. Unauthorized APIs are blocked server-side.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
