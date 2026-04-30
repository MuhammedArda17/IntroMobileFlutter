import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/device.dart';
import 'location_service.dart';
import 'device_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(51.2194, 4.4025); // België centrum
  double? _userLat;
  double? _userLon;
  double? _selectedRadius; // null = alle afstanden

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
      final lat = (data['latitude'] as num?)?.toDouble();
      final lon = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        setState(() {
          _userLat = lat;
          _userLon = lon;
          _center = LatLng(lat, lon);
        });
        _mapController.move(_center, 12);
      }
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLon = position.longitude;
        _center = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_center, 14);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS fout: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaart'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('devices').snapshots(),
        builder: (context, snapshot) {
          final devices = (snapshot.data?.docs ?? [])
              .map((doc) => Device.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .where((d) => d.hasLocation)
              .toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 10,
                ),
                children: [
                  // ── OpenStreetMap tiles ──
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.intromobileflutter',
                  ),

                  // ── Radius cirkel ──
                  if (_selectedRadius != null &&
                      _userLat != null &&
                      _userLon != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(_userLat!, _userLon!),
                          radius: _selectedRadius! * 1000, // meter
                          useRadiusInMeter: true,
                          color: Colors.blue.withOpacity(0.1),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),

                  // ── Toestel markers ──
                  MarkerLayer(
                    markers: [
                      // Eigen locatie marker
                      if (_userLat != null && _userLon != null)
                        Marker(
                          point: LatLng(_userLat!, _userLon!),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),

                      // Toestel markers
                      ...devices.map((device) => Marker(
                            point: LatLng(
                                device.latitude!, device.longitude!),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () => _showDevicePopup(device),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: device.available
                                          ? Colors.green
                                          : Colors.red,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '€${device.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.location_pin,
                                    color: device.available
                                        ? Colors.green
                                        : Colors.red,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ],
              ),

              // ── Zoom knoppen ──
              Positioned(
                bottom: 80,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoom_in',
                      onPressed: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      ),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoom_out',
                      onPressed: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      ),
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),

              // ── GPS knop ──
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'gps',
                  onPressed: _goToMyLocation,
                  tooltip: 'Mijn locatie',
                  child: const Icon(Icons.my_location),
                ),
              ),

              // ── Radius selector ──
              if (_userLat != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        DropdownButton<double?>(
                          value: _selectedRadius,
                          underline: const SizedBox(),
                          isDense: true,
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Alles',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: 5,
                              child: Text('5 km',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: 10,
                              child: Text('10 km',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: 25,
                              child: Text('25 km',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: 50,
                              child: Text('50 km',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedRadius = value),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Legende ──
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.person_pin_circle,
                            color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        const Text('Jij', style: TextStyle(fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_pin,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        const Text('Beschikbaar',
                            style: TextStyle(fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_pin,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        const Text('Verhuurd',
                            style: TextStyle(fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        '${devices.length} toestel${devices.length == 1 ? '' : 'len'}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDevicePopup(Device device) {
    final distance = (_userLat != null && _userLon != null)
        ? LocationService.distanceInKm(
            _userLat!, _userLon!, device.latitude!, device.longitude!)
        : null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 70,
                height: 70,
                child: device.imageUrl.isNotEmpty
                    ? Image.network(device.imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[200],
                        child:
                            const Icon(Icons.devices, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(device.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('€${device.price.toStringAsFixed(2)}/dag',
                      style: const TextStyle(color: Colors.green)),
                  if (distance != null)
                    Text(
                      '📍 ${LocationService.formatDistance(distance)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  Chip(
                    label: Text(
                        device.available ? 'Beschikbaar' : 'Verhuurd'),
                    backgroundColor: device.available
                        ? Colors.green[100]
                        : Colors.red[100],
                    padding: EdgeInsets.zero,
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ],
              ),
            ),
            // Pijl naar detail
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceDetailScreen(device: device),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}