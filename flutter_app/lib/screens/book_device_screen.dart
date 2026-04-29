import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';

class BookDeviceScreen extends StatefulWidget {
  final Device device;
  const BookDeviceScreen({super.key, required this.device});

  @override
  State<BookDeviceScreen> createState() => _BookDeviceScreenState();
}

class _BookDeviceScreenState extends State<BookDeviceScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kies een start- en einddatum!')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!) || _endDate!.isAtSameMomentAs(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einddatum moet na startdatum zijn!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final days = _endDate!.difference(_startDate!).inDays;
      final totalPrice = days * widget.device.price;

      await FirebaseFirestore.instance.collection('reservations').add({
        'deviceId': widget.device.id,
        'deviceName': widget.device.name,
        'renterId': user.uid,
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
        'totalPrice': totalPrice,
        'status': 'afwachting',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservatieverzoek verzonden!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: ${e.toString()}')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final days = (_startDate != null && _endDate != null)
        ? _endDate!.difference(_startDate!).inDays
        : 0;
    final totalPrice = days * widget.device.price;

    return Scaffold(
      appBar: AppBar(title: Text('Huur ${widget.device.name}')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('€${widget.device.price}/dag', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(_startDate == null
                  ? 'Kies startdatum'
                  : 'Start: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
              onTap: () => _pickDate(true),
              tileColor: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(_endDate == null
                  ? 'Kies einddatum'
                  : 'Einde: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
              onTap: _startDate == null ? null : () => _pickDate(false),
              tileColor: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 32),
            if (days > 0)
              Text(
                'Totaal: $days dagen · €${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _confirmBooking,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: const Text('Bevestig reservatie', style: TextStyle(fontSize: 16)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}