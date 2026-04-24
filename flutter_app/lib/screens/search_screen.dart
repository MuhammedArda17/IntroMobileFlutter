import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Alle';

  final List<String> _categories = [
    'Alle', 'Stofzuiger', 'Grasmaaier', 'Keukenmachine', 'Boormachine', 'Andere',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zoeken')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Zoek op naam of locatie',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('devices').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var devices = snapshot.data!.docs
                    .map((doc) => Device.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();

                if (_selectedCategory != 'Alle') {
                  devices = devices.where((d) => d.category == _selectedCategory).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  devices = devices.where((d) =>
                    d.name.toLowerCase().contains(_searchQuery) ||
                    d.description.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                if (devices.isEmpty) {
                  return const Center(child: Text('Geen toestellen gevonden.'));
                }

                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: device.imageUrl.isNotEmpty
                            ? Image.network(device.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.devices, size: 50),
                        title: Text(device.name),
                        subtitle: Text('${device.category} · €${device.price}/dag'),
                        trailing: device.available
                            ? const Chip(label: Text('Beschikbaar'))
                            : const Chip(label: Text('Verhuurd')),
                      ),
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