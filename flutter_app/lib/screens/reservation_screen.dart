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

    // Als geaccepteerd → toestel op onbeschikbaar, als geweigerd → terug beschikbaar
    final deviceRef = FirebaseFirestore.instance.collection('devices').doc(deviceId);
    batch.update(deviceRef, {'available': status == 'geweigerd'});

    await batch.commit();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'geaccepteerd':
        return Colors.green;
      case 'geweigerd':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
              Tab(text: 'Mijn verhuurde toestellen'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: reservaties als huurder
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservations')
                  .where('renterId', isEqualTo: user!.uid)
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
                          label: Text(
                            r.status,
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _statusColor(r.status),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // TAB 2: reservaties als verhuurder
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservations')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Geen verzoeken ontvangen.'));
                }

                // Filter op toestellen van de huidige gebruiker
                final allReservations = snapshot.data!.docs
                    .map((doc) => Reservation.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('devices')
                      .where('ownerId', isEqualTo: user.uid)
                      .get(),
                  builder: (context, deviceSnapshot) {
                    if (deviceSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final myDeviceIds = deviceSnapshot.data!.docs.map((d) => d.id).toSet();
                    final myReservations = allReservations
                        .where((r) => myDeviceIds.contains(r.deviceId))
                        .toList();

                    if (myReservations.isEmpty) {
                      return const Center(child: Text('Geen verzoeken ontvangen.'));
                    }

                    return ListView.builder(
                      itemCount: myReservations.length,
                      itemBuilder: (context, index) {
                        final r = myReservations[index];
                        final days = r.endDate.difference(r.startDate).inDays;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.devices, size: 40),
                                title: Text(r.deviceName),
                                subtitle: Text(
                                  '${r.startDate.day}/${r.startDate.month}/${r.startDate.year} → '
                                  '${r.endDate.day}/${r.endDate.month}/${r.endDate.year}\n'
                                  '$days dagen · €${r.totalPrice.toStringAsFixed(2)}',
                                ),
                                isThreeLine: true,
                                trailing: Chip(
                                  label: Text(
                                    r.status,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: _statusColor(r.status),
                                ),
                              ),
                              if (r.status == 'afwachting')
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _updateStatus(r.id, r.deviceId, 'geweigerd'),
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        label: const Text('Weigeren', style: TextStyle(color: Colors.red)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(r.id, r.deviceId, 'geaccepteerd'),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Accepteren'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
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