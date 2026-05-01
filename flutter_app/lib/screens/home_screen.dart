import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/device.dart';
import 'location_service.dart';
import 'device_detail_screen.dart';
import 'add_device_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Alle';
  double? _selectedRadius; // null = alle afstanden

  double? _userLat;
  double? _userLon;

  final List<String> _categories = [
    'Alle',
    'Stofzuiger',
    'Grasmaaier',
    'Keukenmachine',
    'Boormachine',
    'Andere',
  ];

  final List<double?> _radii = [null, 5, 10, 25, 50];
  final Map<double?, String> _radiusLabels = {
    null: 'Alle afstanden',
    5: '5 km',
    10: '10 km',
    25: '25 km',
    50: '50 km',
  };

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && mounted) {
      setState(() {
        _userLat = (data['latitude'] as num?)?.toDouble();
        _userLon = (data['longitude'] as num?)?.toDouble();
      });
    }
  }

  // JOUW ORIGINELE LOGICA (NIET AANGEPAST)
  List<Device> _filterDevices(List<Device> devices) {
    return devices.where((d) {
      final matchesSearch = _searchQuery.isEmpty ||
          d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.description.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'Alle' || d.category == _selectedCategory;

      bool matchesRadius = true;
      if (_selectedRadius != null && _userLat != null && _userLon != null) {
        if (d.hasLocation) {
          final dist = LocationService.distanceInKm(
            _userLat!,
            _userLon!,
            d.latitude!,
            d.longitude!,
          );
          matchesRadius = dist <= _selectedRadius!;
        } else {
          matchesRadius = false;
        }
      }

      return matchesSearch && matchesCategory && matchesRadius;
    }).toList();
  }

  double? _getDistance(Device device) {
    if (_userLat == null || _userLon == null || !device.hasLocation) {
      return null;
    }
    return LocationService.distanceInKm(
      _userLat!,
      _userLon!,
      device.latitude!,
      device.longitude!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Toestellen',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
        ),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Zoekbalk
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'Zoek toestel...',
                  prefixIcon: Icon(Icons.search, color: Colors.blueAccent),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Filters Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final selected = cat == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                            selectedColor: Colors.blueAccent,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide.none,
                            showCheckmark: false,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_userLat != null)
                  DropdownButton<double?>(
                    value: _selectedRadius,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.near_me, size: 18, color: Colors.blueAccent),
                    items: _radii.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(
                          _radiusLabels[r]!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedRadius = value),
                  ),
              ],
            ),
          ),

          // Toestellijst
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('devices').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Fout bij laden.'));
                }

                final allDevices = (snapshot.data?.docs ?? [])
                    .map((doc) => Device.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                final devices = _filterDevices(allDevices);

                if (devices.isEmpty) {
                  return const Center(child: Text('Geen toestellen gevonden.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _DeviceCard(
                      device: device,
                      distance: _getDistance(device),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final double? distance;

  const _DeviceCard({required this.device, this.distance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: device.imageUrl.isNotEmpty
                    ? Image.network(device.imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.devices, color: Colors.grey),
                      ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      device.category,
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '€${device.price.toStringAsFixed(2)}/dag',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (distance != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.grey),
                              Text(
                                LocationService.formatDistance(distance!),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Status
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                device.available ? Icons.check_circle : Icons.cancel,
                color: device.available ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}