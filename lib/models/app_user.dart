import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  employee,
  employer,
  bank,
  system_admin,
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final bool approved;
  final String? orgId;
  final String? domain;
  final String? organizationName;
  final Timestamp createdAt;
  final Timestamp lastLogin;
  final double carbonCredits;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.approved,
    this.orgId,
    this.domain,
    this.organizationName,
    required this.createdAt,
    required this.lastLogin,
    this.carbonCredits = 0,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    // Handle createdAt field that might be a string or Timestamp
    Timestamp createdAtTimestamp;
    if (data['createdAt'] is Timestamp) {
      createdAtTimestamp = data['createdAt'];
    } else if (data['createdAt'] is String) {
      try {
        // Try to parse ISO 8601 string to DateTime, then to Timestamp
        createdAtTimestamp =
            Timestamp.fromDate(DateTime.parse(data['createdAt']));
      } catch (e) {
        // If parsing fails, use current time
        createdAtTimestamp = Timestamp.now();
      }
    } else {
      createdAtTimestamp = Timestamp.now();
    }

    // Handle lastLogin field that might be a string or Timestamp
    Timestamp lastLoginTimestamp;
    if (data['lastLogin'] is Timestamp) {
      lastLoginTimestamp = data['lastLogin'];
    } else if (data['lastLogin'] is String) {
      try {
        // Try to parse ISO 8601 string to DateTime, then to Timestamp
        lastLoginTimestamp =
            Timestamp.fromDate(DateTime.parse(data['lastLogin']));
      } catch (e) {
        // If parsing fails, use current time
        lastLoginTimestamp = Timestamp.now();
      }
    } else {
      lastLoginTimestamp = Timestamp.now();
    }

    return AppUser(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: _stringToUserRole(data['role']),
      approved: data['approved'] ?? false,
      orgId: data['orgId'],
      domain: data['domain'],
      organizationName: data['organizationName'],
      createdAt: createdAtTimestamp,
      lastLogin: lastLoginTimestamp,
      carbonCredits: data['carbonCredits'] is num
          ? (data['carbonCredits'] as num).toDouble()
          : 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'approved': approved,
      'orgId': orgId,
      'domain': domain,
      'organizationName': organizationName,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'carbonCredits': carbonCredits,
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    bool? approved,
    String? orgId,
    String? domain,
    String? organizationName,
    Timestamp? createdAt,
    Timestamp? lastLogin,
    double? carbonCredits,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      approved: approved ?? this.approved,
      orgId: orgId ?? this.orgId,
      domain: domain ?? this.domain,
      organizationName: organizationName ?? this.organizationName,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      carbonCredits: carbonCredits ?? this.carbonCredits,
    );
  }

  static UserRole _stringToUserRole(String? roleStr) {
    switch (roleStr) {
      case 'employee':
        return UserRole.employee;
      case 'employer':
        return UserRole.employer;
      case 'bank':
        return UserRole.bank;
      case 'system_admin':
        return UserRole.system_admin;
      default:
        return UserRole.employee;
    }
  }
}
