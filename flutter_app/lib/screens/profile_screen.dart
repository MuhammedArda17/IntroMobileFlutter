import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'location_service.dart';
  
  class ProfileScreen extends StatefulWidget {
    const ProfileScreen({super.key});
  
    @override
    State<ProfileScreen> createState() => _ProfileScreenState();
  }
  
  class _ProfileScreenState extends State<ProfileScreen> {
    final _nameController = TextEditingController();
    final _addressController = TextEditingController();
    bool _isEditing = false;
    bool _isSaving = false;
    bool _isLoading = true;
    bool _isGpsLoading = false;
  
    double? _latitude;
    double? _longitude;
  
    final _user = FirebaseAuth.instance.currentUser;
  
    @override
    void initState() {
      super.initState();
      _loadUserData();
    }
  
    @override
    void dispose() {
      _nameController.dispose();
      _addressController.dispose();
      super.dispose();
    }
  
    Future<void> _loadUserData() async {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _latitude = (data['latitude'] as num?)?.toDouble();
        _longitude = (data['longitude'] as num?)?.toDouble();
      }
      if (mounted) setState(() => _isLoading = false);
    }
  
    /// GPS-knop: haalt huidige locatie op en vult adresveld in.
    Future<void> _fillAddressFromGps() async {
      setState(() => _isGpsLoading = true);
      try {
        final position = await LocationService.getCurrentPosition();
        final address = await LocationService.reverseGeocode(
            position.latitude, position.longitude);
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
  
    Future<void> _saveChanges() async {
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
  
      if (name.isEmpty || address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naam en adres mogen niet leeg zijn')),
        );
        return;
      }
  
      setState(() => _isSaving = true);
  
      try {
        // Geocodeer adres als coördinaten nog niet ingesteld zijn via GPS
        if (address.isNotEmpty && (_latitude == null || _longitude == null)) {
          final result = await LocationService.geocodeAddress(address);
          if (result != null) {
            _latitude = result['latitude'];
            _longitude = result['longitude'];
          }
        }
  
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({
          'name': name,
          'address': address,
          'latitude': _latitude,
          'longitude': _longitude,
        });
  
        if (mounted) {
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profiel opgeslagen!')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opslaan mislukt: $e')),
          );
        }
      }
    }
  
    void _cancelEditing() {
      _loadUserData();
      setState(() => _isEditing = false);
    }
  
    @override
    Widget build(BuildContext context) {
      if (_isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
  
      final initials = _nameController.text.isNotEmpty
          ? _nameController.text[0].toUpperCase()
          : '?';
  
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profiel'),
          actions: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Bewerken',
                onPressed: () => setState(() => _isEditing = true),
              ),
            if (_isEditing) ...[
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Annuleren',
                onPressed: _cancelEditing,
              ),
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                tooltip: 'Opslaan',
                onPressed: _isSaving ? null : _saveChanges,
              ),
            ],
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  child: Text(
                    initials,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(height: 32),
  
              // ── Naam ──
              _isEditing
                  ? TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Naam',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    )
                  : ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Naam'),
                      subtitle: Text(_nameController.text),
                    ),
  
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
  
              // ── Adres ──
              _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Adres',
                                  prefixIcon: Icon(Icons.home),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) {
                                  // Reset coördinaten bij manuele aanpassing
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
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
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
                        const SizedBox(height: 4),
                        Text(
                          _latitude != null
                              ? '✓ Locatie gevonden'
                              : 'Adres wordt opgezocht bij opslaan',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _latitude != null ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.home),
                      title: const Text('Adres'),
                      subtitle: Text(_addressController.text),
                      trailing: _latitude != null
                          ? const Icon(Icons.location_on,
                              color: Colors.green, size: 18)
                          : null,
                    ),
  
              const SizedBox(height: 8),
              const Divider(),
  
              // ── E-mail (altijd read-only) ──
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('E-mail'),
                subtitle: Text(_user?.email ?? 'Onbekend'),
              ),
  
              const Divider(),
              const SizedBox(height: 24),
  
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Opslaan'),
                  ),
                ),
  
              if (!_isEditing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Uitloggen'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }