import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  Uint8List? _imageBytes;
  String? _imageFileName;
  File? _imageFile;

  bool _isLoading = false;
  bool _isGpsLoading = false;

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
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFileName = picked.name;
        _imageFile = null;
      });
    } else {
      setState(() {
        _imageFile = File(picked.path);
        _imageBytes = null;
        _imageFileName = null;
      });
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS fout: ${e.toString()}')),
      );
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vul naam en prijs in.')),
      );
      return;
    }

    final price = double.tryParse(priceText.replaceAll(',', '.'));
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ongeldige prijs.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (address.isNotEmpty && (_latitude == null || _longitude == null)) {
        await _geocodeAddress();
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      String imageUrl = '';

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('devices').child(fileName);

      if (kIsWeb && _imageBytes != null) {
        await ref.putData(
          _imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrl = await ref.getDownloadURL();
      } else if (!kIsWeb && _imageFile != null) {
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toestel toegevoegd!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: ${e.toString()}')),
      );
    }
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover);
    } else if (!kIsWeb && _imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover);
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_rounded, size: 48, color: Colors.grey),
        SizedBox(height: 8),
        Text('Foto toevoegen', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  bool get _hasImage => (kIsWeb && _imageBytes != null) || (!kIsWeb && _imageFile != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Toestel toevoegen',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Foto Sectie ──
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _buildImagePreview(),
                      ),
                    ),
                  ),
                  if (_hasImage)
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Foto wijzigen'),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 25),

            _buildSectionTitle('INFORMATIE'),
            const SizedBox(height: 8),
            _buildInputCard(
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Naam toestel *',
                  icon: Icons.devices,
                ),
                const Divider(height: 1, indent: 50),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Beschrijving',
                  icon: Icons.description,
                  maxLines: 3,
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildSectionTitle('CATEGORIE & PRIJS'),
            const SizedBox(height: 8),
            _buildInputCard(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category, color: Colors.blueAccent),
                    labelText: 'Categorie',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value!),
                ),
                const Divider(height: 1, indent: 50),
                _buildTextField(
                  controller: _priceController,
                  label: 'Prijs per dag (€) *',
                  icon: Icons.euro,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildSectionTitle('LOCATIE'),
            const SizedBox(height: 8),
            _buildInputCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _addressController,
                        label: 'Adres',
                        icon: Icons.location_on,
                        onChanged: (_) {
                          _latitude = null;
                          _longitude = null;
                        },
                      ),
                    ),
                    _isGpsLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location, color: Colors.blueAccent),
                            onPressed: _fillAddressFromGps,
                            tooltip: 'Gebruik GPS-locatie',
                          ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _latitude != null ? '✓ Locatie gevonden' : 'Adres wordt opgezocht bij opslaan',
                style: TextStyle(fontSize: 12, color: _latitude != null ? Colors.green : Colors.grey),
              ),
            ),

            const SizedBox(height: 32),

            // ── Opslaan Knop ──
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Bezig met opslaan...' : 'Toestel opslaan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}