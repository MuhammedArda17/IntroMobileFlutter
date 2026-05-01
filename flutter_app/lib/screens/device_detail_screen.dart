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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geef minstens 1 ster!'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userName = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Anoniem';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beoordeling verstuurd!'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: ${e.toString()}'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isOwner = widget.device.ownerId == currentUser.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Mooie uitklapbare header met foto
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: CircleAvatar(
              backgroundColor: Colors.white24,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'device_img_${widget.device.id}',
                child: widget.device.imageUrl.isNotEmpty
                    ? Image.network(widget.device.imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.blueGrey[100],
                        child: const Icon(Icons.devices, size: 80, color: Colors.white),
                      ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titel en Prijs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.device.name,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '€${widget.device.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Straatnaam & Locatie (Toegevoegd)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(
                        widget.device.address.isNotEmpty ? widget.device.address : "Locatie onbekend",
                        style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Chips (Status & Categorie)
                  Row(
                    children: [
                      _buildBadge(
                        widget.device.available ? 'Beschikbaar' : 'Niet beschikbaar',
                        widget.device.available ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(widget.device.category, Colors.blueAccent),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Beschrijving
                  const Text("Beschrijving", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    widget.device.description.isNotEmpty ? widget.device.description : "Geen beschrijving beschikbaar.",
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                  ),

                  const SizedBox(height: 30),

                  // Actie Knoppen
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.device.available && !isOwner
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => BookDeviceScreen(device: widget.device)),
                                  )
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Direct Huren', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!isOwner)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  deviceId: widget.device.id,
                                  deviceName: widget.device.name,
                                  otherUserId: widget.device.ownerId,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Reviews sectie
                  const Text('Beoordelingen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reviews')
                        .where('deviceId', isEqualTo: widget.device.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Text('Fout bij laden reviews.');
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Nog geen beoordelingen.', style: TextStyle(color: Colors.grey)),
                        );
                      }

                      final reviews = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                          if (aTime == null || bTime == null) return 0;
                          return bTime.compareTo(aTime);
                        });

                      return Column(
                        children: reviews.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildReviewCard(data);
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Review schrijven
                  if (!isOwner) ...[
                    _buildInputCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Laat een beoordeling achter', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < _rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                                onPressed: () => setState(() => _rating = index + 1),
                              );
                            }),
                          ),
                          TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Wat vind je van dit toestel?',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitReview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verstuur'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers voor de UI
  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data) {
    final rating = (data['rating'] as num).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data['reviewerName'] ?? 'Anoniem', style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 14))),
            ],
          ),
          if (data['comment']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(data['comment'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ]
        ],
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }
}