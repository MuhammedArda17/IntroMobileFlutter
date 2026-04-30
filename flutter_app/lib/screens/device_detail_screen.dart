import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';
import 'book_device_screen.dart';
import 'chat_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Geef minstens 1 ster!')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userName =
          (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Anoniem';

      await FirebaseFirestore.instance.collection('reviews').add({
        'deviceId': widget.device.id,
        'deviceName': widget.device.name,
        'ownerId': widget.device.ownerId,
        'reviewerId': uid,
        'reviewerName': userName,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _rating = 0;
        _commentController.clear();
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Beoordeling verstuurd!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fout: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isOwner = widget.device.ownerId == currentUser.uid;

    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto
            widget.device.imageUrl.isNotEmpty
                ? Image.network(
                    widget.device.imageUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.devices,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info
                  Text(
                    widget.device.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${widget.device.price}/dag',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      widget.device.available ? 'Beschikbaar' : 'Verhuurd',
                    ),
                    backgroundColor: widget.device.available
                        ? Colors.green[100]
                        : Colors.red[100],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Categorie: ${widget.device.category}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (widget.device.description.isNotEmpty)
                    Text(
                      widget.device.description,
                      style: const TextStyle(fontSize: 15),
                    ),

                  const SizedBox(height: 24),

                  // Knoppen
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.device.available && !isOwner
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BookDeviceScreen(device: widget.device),
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Huren'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: !isOwner
                          ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                deviceId: widget.device.id,
                                deviceName: widget.device.name,
                                otherUserId: widget.device.ownerId,
                              ),
                            ),
                          ) : null,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Reviews sectie
                  const Text(
                    'Beoordelingen',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder<QuerySnapshot>(
                    // Enkel filteren op deviceId — geen orderBy = geen index nodig
                    // Sortering gebeurt in Dart hieronder
                    stream: FirebaseFirestore.instance
                        .collection('reviews')
                        .where('deviceId', isEqualTo: widget.device.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Fout bij laden: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text(
                          'Nog geen beoordelingen.',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      // Sorteren op createdAt in Dart (nieuwste eerst)
                      final reviews = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final aTime =
                              (a.data() as Map<String, dynamic>)['createdAt']
                                  as Timestamp?;
                          final bTime =
                              (b.data() as Map<String, dynamic>)['createdAt']
                                  as Timestamp?;
                          if (aTime == null || bTime == null) return 0;
                          return bTime.compareTo(aTime);
                        });

                      final avg =
                          reviews
                              .map(
                                (d) =>
                                    ((d.data()
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['rating']
                                            as num)
                                        .toInt(),
                              )
                              .reduce((a, b) => a + b) /
                          reviews.length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < avg.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${avg.toStringAsFixed(1)} (${reviews.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...reviews.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final rating = (data['rating'] as num).toInt();
                            final comment = data['comment'] ?? '';
                            final reviewerName =
                                data['reviewerName'] ?? 'Anoniem';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          reviewerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < rating
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (comment.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(comment),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Review schrijven
                  if (!isOwner) ...[
                    const Text(
                      'Schrijf een beoordeling',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                          onPressed: () => setState(() => _rating = index + 1),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Opmerking (optioneel)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _isSubmitting
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitReview,
                              child: const Text('Beoordeling versturen'),
                            ),
                          ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
