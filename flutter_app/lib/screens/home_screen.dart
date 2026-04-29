import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';
import 'add_device_screen.dart';
import 'book_device_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Alle';

  final List<String> _categories = [
    'Alle', 'Stofzuiger', 'Grasmaaier', 'Keukenmachine', 'Boormachine', 'Andere',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toestellen App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Zoek op naam of beschrijving',
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nog geen toestellen beschikbaar.'));
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          final currentUser = FirebaseAuth.instance.currentUser!;
                          if (device.ownerId == currentUser.uid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dit is jouw eigen toestel!')),
                            );
                            return;
                          }
                          if (!device.available) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dit toestel is momenteel niet beschikbaar.')),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookDeviceScreen(device: device)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              device.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(device.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.devices, size: 60),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${device.category} · €${device.price}/dag', style: const TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Chip(
                                      label: Text(device.available ? 'Beschikbaar' : 'Verhuurd'),
                                      backgroundColor: device.available ? Colors.green[100] : Colors.red[100],
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                                onPressed: () {
                                  final currentUser = FirebaseAuth.instance.currentUser!;
                                  if (device.ownerId == currentUser.uid) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Dit is jouw eigen toestel!')),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        deviceId: device.id,
                                        deviceName: device.name,
                                        otherUserId: device.ownerId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}