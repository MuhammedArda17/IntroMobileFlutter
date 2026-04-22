class Device {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final bool available;
  final String ownerId;
  final String imageUrl;

  Device({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.available,
    required this.ownerId,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'available': available,
      'ownerId': ownerId,
      'imageUrl': imageUrl,
    };
  }

  factory Device.fromMap(String id, Map<String, dynamic> map) {
    return Device(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
      available: map['available'] ?? true,
      ownerId: map['ownerId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}