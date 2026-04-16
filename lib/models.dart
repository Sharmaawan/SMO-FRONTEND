class LoginRequest {
  final String loginid;
  final String password;

  LoginRequest({required this.loginid, required this.password});

  Map<String, dynamic> toJson() {
    return {'loginid': loginid, 'password': password};
  }
}

class RoleResponse {
  final String role;
  final String employeeName;
  final String empId;

  RoleResponse({
    required this.role,
    required this.employeeName,
    required this.empId,
  });

  factory RoleResponse.fromJson(Map<String, dynamic> json) {
    return RoleResponse(
      role: (json['role'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      empId: (json['empId'] ?? '').toString(),
    );
  }
}

class HrDashboardResponse {
  final int totalRoles;
  final int totalEmployees;

  HrDashboardResponse({required this.totalRoles, required this.totalEmployees});

  factory HrDashboardResponse.fromJson(Map<String, dynamic> json) {
    return HrDashboardResponse(
      totalRoles: (json['totalRoles'] ?? 0) as int,
      totalEmployees: (json['totalEmployees'] ?? 0) as int,
    );
  }
}

class CreateRoleRequest {
  final int roleId;
  final String roleName;
  final String activity;
  final String status;

  CreateRoleRequest({
    required this.roleId,
    required this.roleName,
    required this.activity,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'roleId': roleId,
      'roleName': roleName,
      'activity': activity,
      'status': status,
    };
  }
}

class RoleItem {
  final int roleId;
  final String roleName;
  final String activity;
  final String status;

  RoleItem({
    required this.roleId,
    required this.roleName,
    required this.activity,
    required this.status,
  });

  factory RoleItem.fromJson(Map<String, dynamic> json) {
    return RoleItem(
      roleId: int.tryParse(json['roleId']?.toString() ?? '0') ?? 0,
      roleName: (json['roleName'] ?? '').toString(),
      activity: (json['activity'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roleId': roleId,
      'roleName': roleName,
      'activity': activity,
      'status': status,
    };
  }
}

class CreateEmployeeRequest {
  final String empId;
  final String empName;
  final RoleItem role;
  final String? dob;
  final String? phone;
  final String? address;
  final String email;
  final double? salary;
  final String? empDate;
  final String? bloodGroup;
  final String? emergencyContact;
  final String? aadharNumber;
  final String? panCardNumber;
  final String status;
  final String? password;

  CreateEmployeeRequest({
    required this.empId,
    required this.empName,
    required this.role,
    this.dob,
    this.phone,
    this.address,
    required this.email,
    this.salary,
    this.empDate,
    this.bloodGroup,
    this.emergencyContact,
    this.aadharNumber,
    this.panCardNumber,
    required this.status,
    this.password,
  });

  Map<String, dynamic> toJson() {
    // Format dates to yyyy-MM-dd for backend LocalDate parsing
    String? formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      // If already in yyyy-MM-dd format, return as-is
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) return dateStr;
      // Try to parse and reformat
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          // Assume dd-MM-yyyy format and convert
          return '${parts[2]}-${parts[1]}-${parts[0]}';
        }
      } catch (_) {}
      return dateStr;
    }

    return {
      'empId': empId,
      'empName': empName,
      'role': {
        'roleId': role.roleId,
        'roleName': role.roleName,
        'status': role.status,
      },
      'dob': formatDate(dob),
      'phone': phone,
      'address': address,
      'email': email,
      'salary': salary,
      'empDate': formatDate(empDate),
      'bloodGroup': bloodGroup,
      'emergencyContact': emergencyContact,
      'aadharNumber': aadharNumber,
      'panCardNumber': panCardNumber,
      'status': status,
      'password': password,
    };
  }
}

class CreateLoginRequest {
  final String empId;
  final String password;
  final String status;

  CreateLoginRequest({
    required this.empId,
    required this.password,
    this.status = 'ACTIVE',
  });

  Map<String, dynamic> toJson() {
    return {
      'empId': empId,
      'password': password,
      'status': status,
    };
  }
}

class EmployeeItem {
  final String empId;
  final String empName;
  final RoleItem role;
  final String email;
  final String phone;
  final String status;

  EmployeeItem({
    required this.empId,
    required this.empName,
    required this.role,
    required this.email,
    required this.phone,
    required this.status,
  });

  factory EmployeeItem.fromJson(Map<String, dynamic> json) {
    return EmployeeItem(
      empId: (json['empId'] ?? '').toString(),
      empName: (json['empName'] ?? '').toString(),
      role: RoleItem.fromJson(json['role'] as Map<String, dynamic>),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class HrProfileResponse {
  final String empId;
  final String empName;
  final String email;
  final String phone;
  final String address;
  final String dob;
  final String bloodGroup;
  final String emergencyContact;
  final String aadharNumber;
  final String panCardNumber;
  final RoleItem role;
  final String status;

  HrProfileResponse({
    required this.empId,
    required this.empName,
    required this.email,
    required this.phone,
    required this.address,
    required this.dob,
    required this.bloodGroup,
    required this.emergencyContact,
    required this.aadharNumber,
    required this.panCardNumber,
    required this.role,
    required this.status,
  });

  factory HrProfileResponse.fromJson(Map<String, dynamic> json) {
    return HrProfileResponse(
      empId: (json['empId'] ?? '').toString(),
      empName: (json['empName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      dob: (json['dob'] ?? '').toString(),
      bloodGroup: (json['bloodGroup'] ?? '').toString(),
      emergencyContact: (json['emergencyContact'] ?? '').toString(),
      aadharNumber: (json['aadharNumber'] ?? '').toString(),
      panCardNumber: (json['panCardNumber'] ?? '').toString(),
      role: RoleItem.fromJson(json['role'] as Map<String, dynamic>),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class UpdateHrProfileRequest {
  final String empName;
  final String email;
  final String? phone;
  final String? address;
  final String? dob;
  final String? bloodGroup;
  final String? emergencyContact;
  final String? aadharNumber;
  final String? panCardNumber;
  final String status;
  final String? password;

  UpdateHrProfileRequest({
    required this.empName,
    required this.email,
    required this.phone,
    required this.address,
    required this.dob,
    required this.bloodGroup,
    required this.emergencyContact,
    required this.aadharNumber,
    required this.panCardNumber,
    required this.status,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'empName': empName,
      'email': email,
      'phone': phone,
      'address': address,
      'dob': dob,
      'bloodGroup': bloodGroup,
      'emergencyContact': emergencyContact,
      'aadharNumber': aadharNumber,
      'panCardNumber': panCardNumber,
      'status': status,
      'password': password,
    };
  }
}
