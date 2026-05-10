import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceImage extends StatelessWidget {
  final Device device;
  final double? width;
  final double? height;
  final BoxFit fit;

  const DeviceImage({
    super.key,
    required this.device,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (device.imageBase64.isNotEmpty) {
      return Image.memory(
        base64Decode(device.imageBase64),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (device.imageUrl.isNotEmpty) {
      return Image.network(
        device.imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: const Icon(Icons.devices, color: Colors.grey),
    );
  }
}