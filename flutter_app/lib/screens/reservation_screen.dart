import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation.dart';

class ReservationScreen extends StatelessWidget {
  const ReservationScreen({super.key});

  Future<void> _updateStatus(String reservationId, String deviceId, String status) async {
    final batch = FirebaseFirestore.instance.batch();
    final reservationRef = FirebaseFirestore.instance.collection('reservations').doc(reservationId);
    batch.update(reservationRef, {'status': status});
    final deviceRef = FirebaseFirestore.instance.collection('devices').doc(deviceId);
    batch.update(deviceRef, {'available': status == 'geweigerd'});
    await batch.commit();
  }

  Future<void> _deleteDevice(String deviceId) async {
    await FirebaseFirestore.instance.collection('devices').doc(deviceId).delete();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'geaccepteerd': return Colors.green;
      case 'geweigerd': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reservaties'),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            tabs: [
              Tab(text: 'Mijn huurverzoeken'),
              Tab(text: 'Mijn toestellen'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: reservaties als huurder
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservations')
                  .where('renterId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Geen huurverzoeken gevonden.'));
                }
                final reservations = snapshot.data!.docs
                    .map((doc) => Reservation.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();
                return ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final r = reservations[index];
                    final days = r.endDate.difference(r.startDate).inDays;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.devices, size: 40),
                        title: Text(r.deviceName),
                        subtitle: Text(
                          '${r.startDate.day}/${r.startDate.month}/${r.startDate.year} → '
                          '${r.endDate.day}/${r.endDate.month}/${r.endDate.year}\n'
                          '$days dagen · €${r.totalPrice.toStringAsFixed(2)}',
                        ),
                        isThreeLine: true,
                        trailing: Chip(
                          label: Text(r.status, style: const TextStyle(color: Colors.white)),
                          backgroundColor: _statusColor(r.status),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // TAB 2: mijn toestellen als verhuurder
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('devices')
                  .where('ownerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, deviceSnapshot) {
                if (deviceSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!deviceSnapshot.hasData || deviceSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Je hebt nog geen toestellen toegevoegd.'));
                }

                final devices = deviceSnapshot.data!.docs;

                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final doc = devices[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final deviceId = doc.id;
                    final name = data['name'] ?? '';
                    final category = data['category'] ?? '';
                    final price = data['price']?.toDouble() ?? 0.0;
                    final available = data['available'] ?? true;
                    final imageUrl = data['imageUrl'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        children: [
                          ListTile(
                            leading: imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.devices, size: 50),
                            title: Text(name),
                            subtitle: Text('$category · €$price/dag'),
                            trailing: Chip(
                              label: Text(available ? 'Beschikbaar' : 'Verhuurd'),
                              backgroundColor: available ? Colors.green[100] : Colors.red[100],
                            ),
                          ),
                          // Reservaties voor dit toestel
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('reservations')
                                .where('deviceId', isEqualTo: deviceId)
                                .snapshots(),
                            builder: (context, resSnapshot) {
                              if (!resSnapshot.hasData || resSnapshot.data!.docs.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Geen reservaties', style: TextStyle(color: Colors.grey)),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Verwijderen?'),
                                              content: Text('Wil je "$name" verwijderen?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
                                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verwijderen', style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) await _deleteDevice(deviceId);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final reservations = resSnapshot.data!.docs
                                  .map((d) => Reservation.fromMap(d.id, d.data() as Map<String, dynamic>))
                                  .toList();

                              return Column(
                                children: [
                                  ...reservations.map((r) {
                                    final days = r.endDate.difference(r.startDate).inDays;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${r.startDate.day}/${r.startDate.month}/${r.startDate.year} → ${r.endDate.day}/${r.endDate.month}/${r.endDate.year} · $days dagen · €${r.totalPrice.toStringAsFixed(2)}'),
                                            const SizedBox(height: 4),
                                            if (r.status == 'afwachting')
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () => _updateStatus(r.id, deviceId, 'geweigerd'),
                                                    icon: const Icon(Icons.close, color: Colors.red),
                                                    label: const Text('Weigeren', style: TextStyle(color: Colors.red)),
                                                  ),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _updateStatus(r.id, deviceId, 'geaccepteerd'),
                                                    icon: const Icon(Icons.check),
                                                    label: const Text('Accepteren'),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                  ),
                                                ],
                                              )
                                            else
                                              Chip(
                                                label: Text(r.status, style: const TextStyle(color: Colors.white)),
                                                backgroundColor: _statusColor(r.status),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Verwijderen?'),
                                              content: Text('Wil je "$name" verwijderen?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
                                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verwijderen', style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) await _deleteDevice(deviceId);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}