import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const MethodChannel _smsChannel = MethodChannel('com.womensafety/sms');

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('03') && cleaned.length == 11) {
      cleaned = '+92${cleaned.substring(1)}';
    }
    return cleaned;
  }

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions were denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> sendSOSAlert({required List<String> emergencyPhones}) async {
    User? user = _auth.currentUser;
    Position position = await getCurrentLocation();

    String mapLink =
        "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String addressStr =
        "Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";

    try {
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        addressStr =
            "${place.street ?? ''}, ${place.subLocality ?? place.locality ?? ''}"
                .trim();
      }
    } catch (_) {}

    // 1. Log to Firestore
    await _firestore.collection('sos_alerts').add({
      'userId': user?.uid ?? 'anonymous',
      'userEmail': user?.email ?? 'Unknown User',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'address': addressStr,
      'googleMapsLink': mapLink,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'ACTIVE',
    });

    // 2. Request SMS permission via permission_handler package (or native check)
    var status = await Permission.sms.request();
    if (status.isGranted) {
      String message =
          "🚨 EMERGENCY! I need help! My current location: $mapLink ($addressStr)";

      // Native Direct Silent SMS Dispatch
      Object? firstError;
      for (final emergencyPhone in emergencyPhones) {
        try {
          await _smsChannel.invokeMethod('sendDirectSms', {
            'phone': _formatPhoneNumber(emergencyPhone),
            'message': message,
          });
        } catch (error) {
          firstError ??= error;
        }
      }
      if (firstError != null) {
        throw firstError;
      }
    } else {
      throw Exception("SMS permission denied.");
    }
  }

  Future<void> makeEmergencyCall(String phoneNumber) async {
    String formattedPhone = _formatPhoneNumber(phoneNumber);
    final Uri callUri = Uri(scheme: 'tel', path: formattedPhone);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri, mode: LaunchMode.externalApplication);
    }
  }
}
