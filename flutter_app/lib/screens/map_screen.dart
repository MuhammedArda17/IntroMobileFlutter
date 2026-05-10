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
  LatLng _center = const LatLng(51.2194, 4.4025);
  double? _userLat;
  double? _userLon;
  double _radiusKm = 50;
  bool _filterByRadius = false;

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('devices').snapshots(),
        builder: (context, snapshot) {
          final devices = (snapshot.data?.docs ?? [])
              .map((doc) => Device.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((d) => d.hasLocation)
              .toList();

          final filteredDevices = _filterByRadius && _userLat != null && _userLon != null
              ? devices.where((d) {
                  final dist = LocationService.distanceInKm(_userLat!, _userLon!, d.latitude!, d.longitude!);
                  return dist <= _radiusKm;
                }).toList()
              : devices;

          return Stack(
            children: [
              // ── Kaart ──
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 10,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.intromobileflutter',
                  ),
                  if (_filterByRadius && _userLat != null && _userLon != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(_userLat!, _userLon!),
                          radius: _radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: Colors.blue.withOpacity(0.08),
                          borderColor: Colors.blue.withOpacity(0.4),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_userLat != null && _userLon != null)
                        Marker(
                          point: LatLng(_userLat!, _userLon!),
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8, spreadRadius: 2),
                              ],
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 22),
                          ),
                        ),
                      ...filteredDevices.map((device) => Marker(
                            point: LatLng(device.latitude!, device.longitude!),
                            width: 56,
                            height: 56,
                            child: GestureDetector(
                              onTap: () => _showDevicePopup(device),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: device.available ? Colors.green[600] : Colors.red[600],
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (device.available ? Colors.green : Colors.red).withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '€${device.price.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Icon(
                                    Icons.location_pin,
                                    color: device.available ? Colors.green[600] : Colors.red[600],
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ],
              ),

              // ── Header ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0)],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined, size: 20, color: Colors.black87),
                      const SizedBox(width: 8),
                      const Text(
                        'Toestellen in de buurt',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${filteredDevices.length} toestel${filteredDevices.length == 1 ? '' : 'len'}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Legende ──
              Positioned(
                top: 100,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendItem(Icons.person, Colors.blue, 'Jij'),
                      const SizedBox(height: 6),
                      _legendItem(Icons.location_pin, Colors.green, 'Beschikbaar'),
                      const SizedBox(height: 6),
                      _legendItem(Icons.location_pin, Colors.red, 'Verhuurd'),
                    ],
                  ),
                ),
              ),

              // ── Radius slider ──
              if (_userLat != null)
                Positioned(
                  bottom: 32,
                  left: 16,
                  width: 200,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.near_me, size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                const Text('Radius', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Row(
                              children: [
                                Switch(
                                  value: _filterByRadius,
                                  onChanged: (val) => setState(() => _filterByRadius = val),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                Text(
                                  _filterByRadius ? '${_radiusKm.toInt()} km' : 'Alles',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _filterByRadius ? Colors.blue : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_filterByRadius) ...[
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: _radiusKm,
                              min: 1,
                              max: 100,
                              divisions: 99,
                              activeColor: Colors.blue,
                              inactiveColor: Colors.blue.withOpacity(0.2),
                              onChanged: (val) => setState(() => _radiusKm = val),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('1 km', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('100 km', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── Zoom knoppen ──
              Positioned(
                bottom: 110,
                right: 16,
                child: Column(
                  children: [
                    _mapButton(Icons.add, 'zoom_in', () => _mapController.move(
                      _mapController.camera.center, _mapController.camera.zoom + 1)),
                    const SizedBox(height: 8),
                    _mapButton(Icons.remove, 'zoom_out', () => _mapController.move(
                      _mapController.camera.center, _mapController.camera.zoom - 1)),
                  ],
                ),
              ),

              // ── GPS knop ──
              Positioned(
                bottom: 32,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'gps',
                  onPressed: _goToMyLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  elevation: 3,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  Widget _mapButton(IconData icon, String tag, VoidCallback onPressed) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }

  void _showDevicePopup(Device device) {
    final distance = (_userLat != null && _userLon != null)
        ? LocationService.distanceInKm(_userLat!, _userLon!, device.latitude!, device.longitude!)
        : null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: device.imageUrl.isNotEmpty
                    ? Image.network(device.imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.devices, color: Colors.grey, size: 32),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(device.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('€${device.price.toStringAsFixed(2)}/dag',
                      style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                  if (distance != null) ...[
                    const SizedBox(height: 4),
                    Text('📍 ${LocationService.formatDistance(distance)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: device.available ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: device.available ? Colors.green : Colors.red, width: 0.8),
                    ),
                    child: Text(
                      device.available ? 'Beschikbaar' : 'Verhuurd',
                      style: TextStyle(
                        fontSize: 12,
                        color: device.available ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)));
              },
            ),
          ],
        ),
      ),
    );
  }
}