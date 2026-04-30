class Reservation {
  final String id;
  final String deviceId;
  final String deviceName;
  final String renterId;
  final String ownerId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final String status;
  final bool reviewed;

  Reservation({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.renterId,
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.status,
    this.reviewed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'renterId': renterId,
      'ownerId': ownerId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalPrice': totalPrice,
      'status': status,
      'reviewed': reviewed,
    };
  }

  factory Reservation.fromMap(String id, Map<String, dynamic> map) {
    return Reservation(
      id: id,
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? '',
      renterId: map['renterId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      totalPrice: map['totalPrice']?.toDouble() ?? 0.0,
      status: map['status'] ?? 'afwachting',
      reviewed: map['reviewed'] ?? false,
    );
  }
}