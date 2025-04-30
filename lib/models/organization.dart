class Organization {
  final String id;
  final String name;
  final String domain;
  final String address;
  final String createdBy;
  final String createdAt;
  final bool approved;

  Organization({
    required this.id,
    required this.name,
    required this.domain,
    required this.address,
    required this.createdBy,
    required this.createdAt,
    this.approved = false,
  });

  factory Organization.fromFirestore(Map<String, dynamic> data, String id) {
    return Organization(
      id: id,
      name: data['name'] ?? '',
      domain: data['domain'] ?? '',
      address: data['address'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? DateTime.now().toIso8601String(),
      approved: data['approved'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'domain': domain,
      'address': address,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'approved': approved,
    };
  }
}
