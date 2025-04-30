class PendingEmployee {
  final String id;
  final String fullName;
  final String email;
  final String domain;
  final String orgId;
  final String organizationName;
  final String role;
  final bool approved;
  final String createdAt;

  PendingEmployee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.domain,
    required this.orgId,
    required this.organizationName,
    this.role = 'employee',
    this.approved = false,
    required this.createdAt,
  });

  factory PendingEmployee.fromFirestore(Map<String, dynamic> data) {
    return PendingEmployee(
      id: data['id'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      domain: data['domain'] ?? '',
      orgId: data['orgId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      role: data['role'] ?? 'employee',
      approved: data['approved'] ?? false,
      createdAt: data['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'domain': domain,
      'orgId': orgId,
      'organizationName': organizationName,
      'role': role,
      'approved': approved,
      'createdAt': createdAt,
    };
  }
}
