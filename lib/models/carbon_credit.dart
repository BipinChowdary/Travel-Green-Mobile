class CarbonCredit {
  final String id;
  final double amount;
  final String source;
  final DateTime createdAt;
  final String userId;
  final String status; // 'active', 'used', 'transferred'

  CarbonCredit({
    required this.id,
    required this.amount,
    required this.source,
    required this.createdAt,
    required this.userId,
    this.status = 'active',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'status': status,
    };
  }

  factory CarbonCredit.fromJson(Map<String, dynamic> json) {
    return CarbonCredit(
      id: json['id'],
      amount: json['amount'],
      source: json['source'],
      createdAt: DateTime.parse(json['createdAt']),
      userId: json['userId'],
      status: json['status'] ?? 'active',
    );
  }
}
