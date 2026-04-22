import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';
import 'add_device_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('devices').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nog geen toestellen beschikbaar.'));
          }
          final devices = snapshot.data!.docs.map((doc) {
            return Device.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                margin: const EdgeInsets.all(8),
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