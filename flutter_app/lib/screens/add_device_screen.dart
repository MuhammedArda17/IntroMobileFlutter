import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'location_service.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();

  String _selectedCategory = 'Alle';
  File? _imageFile;
  bool _isLoading = false;
  bool _isGpsLoading = false;

  // Opgeslagen coördinaten na geocoding of GPS
  double? _latitude;
  double? _longitude;

  final List<String> _categories = [
    'Alle',
    'Stofzuiger',
    'Grasmaaier',
    'Keukenmachine',
    'Boormachine',
    'Andere',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  /// Vult adres in via GPS en slaat coördinaten op.
  Future<void> _fillAddressFromGps() async {
    setState(() => _isGpsLoading = true);
    try {
      final position = await LocationService.getCurrentPosition();
      final address = await LocationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _addressController.text = address ?? '';
        _isGpsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGpsLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('GPS fout: ${e.toString()}')));
    }
  }

  /// Geocodeert het ingetypte adres naar coördinaten.
  Future<void> _geocodeAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    final result = await LocationService.geocodeAddress(address);
    if (result != null) {
      _latitude = result['latitude'];
      _longitude = result['longitude'];
    } else {
      _latitude = null;
      _longitude = null;
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vul naam en prijs in.')));
      return;
    }

    final price = double.tryParse(priceText.replaceAll(',', '.'));
    if (price == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ongeldige prijs.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Geocodeer adres als er nog geen coördinaten zijn
      if (address.isNotEmpty && (_latitude == null || _longitude == null)) {
        await _geocodeAddress();
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      String imageUrl = '';

      // Upload afbeelding naar Firebase Storage
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('devices')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      // Sla toestel op in Firestore
      await FirebaseFirestore.instance.collection('devices').add({
        'name': name,
        'description': description,
        'category': _selectedCategory,
        'price': price,
        'available': true,
        'ownerId': uid,
        'imageUrl': imageUrl,
        'address': address,
        'latitude': _latitude,
        'longitude': _longitude,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Toestel toegevoegd!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fout: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toestel toevoegen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Foto ──
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Foto toevoegen',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Naam ──
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Naam toestel *',
                prefixIcon: Icon(Icons.devices),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Beschrijving ──
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Beschrijving',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Categorie ──
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categorie',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            const SizedBox(height: 16),

            // ── Prijs ──
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Prijs per dag (€) *',
                prefixIcon: Icon(Icons.euro),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Locatie ──
            const Text(
              'Locatie',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adres',
                      hintText: 'bv. Antwerpsesteenweg 1, Hoboken',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      // Reset coördinaten als adres manueel gewijzigd wordt
                      _latitude = null;
                      _longitude = null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 58,
                  child: _isGpsLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filled(
                          tooltip: 'Gebruik GPS-locatie',
                          icon: const Icon(Icons.my_location),
                          onPressed: _fillAddressFromGps,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _latitude != null
                  ? '✓ Locatie gevonden'
                  : 'Adres wordt opgezocht bij opslaan',
              style: TextStyle(
                fontSize: 12,
                color: _latitude != null ? Colors.green : Colors.grey,
              ),
            ),

            const SizedBox(height: 32),

            // ── Opslaan ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isLoading ? 'Bezig met opslaan...' : 'Toestel opslaan',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
