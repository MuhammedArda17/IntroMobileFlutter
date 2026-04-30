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

  // Locatie van de ingelogde gebruiker (uit Firestore)
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
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    if (data != null && mounted) {
      setState(() {
        _userLat = (data['latitude'] as num?)?.toDouble();
        _userLon = (data['longitude'] as num?)?.toDouble();
      });
    }
  }

  List<Device> _filterDevices(List<Device> devices) {
    return devices.where((d) {
      // Zoektekst filter
      final matchesSearch =
          _searchQuery.isEmpty ||
          d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.description.toLowerCase().contains(_searchQuery.toLowerCase());

      // Categorie filter
      final matchesCategory =
          _selectedCategory == 'Alle' || d.category == _selectedCategory;

      // Radius filter
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
          // Toestel heeft geen locatie → toon het niet bij radius filter
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
      appBar: AppBar(title: const Text('Toestellen'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Zoekbalk ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Zoek toestel...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // ── Categorie + radius filter ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Categorie chips
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
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Radius dropdown (alleen tonen als gebruiker locatie heeft)
                if (_userLat != null)
                  DropdownButton<double?>(
                    value: _selectedRadius,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.near_me, size: 18),
                    items: _radii
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              _radiusLabels[r]!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedRadius = value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Toestellijst ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('devices')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Fout bij laden van toestellen.'),
                  );
                }

                final allDevices = (snapshot.data?.docs ?? [])
                    .map(
                      (doc) => Device.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList();

                final devices = _filterDevices(allDevices);

                if (devices.isEmpty) {
                  return const Center(child: Text('Geen toestellen gevonden.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
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

// ── Toestelkaartje ──
class _DeviceCard extends StatelessWidget {
  final Device device;
  final double? distance;

  const _DeviceCard({required this.device, this.distance});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
        ),
        child: Row(
          children: [
            // ── Thumbnail ──
            SizedBox(
              width: 100,
              height: 100,
              child: device.imageUrl.isNotEmpty
                  ? Image.network(
                      device.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imageFallback(),
                    )
                  : _imageFallback(),
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.category,
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€${device.price.toStringAsFixed(2)}/dag',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    // ── Afstand ──
                    if (distance != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 13,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            LocationService.formatDistance(distance!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Beschikbaarheid + pijl ──
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Icon(
                    device.available ? Icons.check_circle : Icons.cancel,
                    color: device.available ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.devices, color: Colors.grey, size: 36),
    );
  }
}
