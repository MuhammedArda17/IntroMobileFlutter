 class Device {
    final String id;
    final String name;
    final String description;
    final String category;
    final double price;
    final bool available;
    final String ownerId;
    final String imageUrl;
    final double? latitude;
    final double? longitude;
    final String address;
  
    Device({
      required this.id,
      required this.name,
      required this.description,
      required this.category,
      required this.price,
      required this.available,
      required this.ownerId,
      required this.imageUrl,
      this.latitude,
      this.longitude,
      this.address = '',
    });
  
    bool get hasLocation => latitude != null && longitude != null;
  
    Map<String, dynamic> toMap() {
      return {
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'available': available,
        'ownerId': ownerId,
        'imageUrl': imageUrl,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };
    }
  
    factory Device.fromMap(Map<String, dynamic> map, String id) {
      return Device(
        id: id,
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        category: map['category'] ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        available: map['available'] ?? true,
        ownerId: map['ownerId'] ?? '',
        imageUrl: map['imageUrl'] ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        address: map['address'] ?? '',
      );
    }
  }