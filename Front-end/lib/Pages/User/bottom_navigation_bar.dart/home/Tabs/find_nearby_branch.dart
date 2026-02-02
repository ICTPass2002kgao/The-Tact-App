// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'dart:convert'; // For parsing JSON
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ttact/Components/API.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http; // Connect to Django
import 'package:ttact/Components/NeuDesign.dart';

class FindNearbyBranch extends StatefulWidget {
  const FindNearbyBranch({super.key});

  @override
  State<FindNearbyBranch> createState() => _FindNearbyBranchState();
}

class _FindNearbyBranchState extends State<FindNearbyBranch> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  bool _isLoading = true;

  // Default fallback (Polokwane/Limpopo for testing if GPS fails completely)
  static const LatLng _defaultLocation = LatLng(-23.8962, 29.4486);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    // 1. Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Even if denied, try to load map with communities
        _fetchCommunitiesFromDjango();
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2. Get User Position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }

      // 3. Fetch Data from Django
      _fetchCommunitiesFromDjango();
    } catch (e) {
      print("GPS Error: $e");
      // Still fetch communities even if GPS fails
      _fetchCommunitiesFromDjango();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCommunitiesFromDjango() async {
    try {
      // REPLACE WITH YOUR ACTUAL DJANGO IP ADDRESS
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/communities/');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        Set<Marker> newMarkers = {};

        for (var item in data) {
          // Check if coordinates exist (Django "Smart Retry" logic ensures they should)
          if (item['latitude'] != null && item['longitude'] != null) {
            double lat = (item['latitude'] as num).toDouble();
            double lng = (item['longitude'] as num).toDouble();

            String name = item['community_name'] ?? "Unknown Branch";
            String districtName = item['district_elder_name'] ?? '';
            String id = item['id'].toString();

            newMarkers.add(
              Marker(
                markerId: MarkerId(id),
                position: LatLng(lat, lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet,
                ),
                infoWindow: InfoWindow(
                  title: '$name ($districtName)',
                  snippet: "Tap for Directions",
                  onTap: () => _launchNavigation(lat, lng),
                ),
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _markers = newMarkers;
          });

          // Once data is loaded, try to focus the camera
          _zoomToUserOrFitMarkers();
        }
      } else {
        print("Django Error: ${response.statusCode}");
      }
    } catch (e) {
      print("API Connection Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SMART ZOOM LOGIC ---
  void _zoomToUserOrFitMarkers() {
    if (_mapController == null) return;

    // PRIORITY 1: Focus on the User (Limpopo)
    if (_currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: 14.0, // Close zoom level (Street view style)
          ),
        ),
      );
    }
    // PRIORITY 2: If no User GPS, show all markers (Gauteng)
    else if (_markers.isNotEmpty) {
      List<LatLng> points = _markers.map((m) => m.position).toList();

      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (var point in points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80, // Padding
        ),
      );
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      // Fallback for devices without Google Maps app
      final Uri browserUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
      );
      await launchUrl(browserUrl, mode: LaunchMode.inAppBrowserView);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tint Calculation
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: NeumorphicContainer(
                color: neumoBaseColor,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Column(
                  children: [
                    Text(
                      'Just Relocated Or New to this place?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Don\'t worry, Dankie will assist you get a nearest branch.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              "Nearby TACT Branches",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              height: 400,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isLoading
                  ? Center(
                      child: Api().isIOSPlatform
                          ? CupertinoActivityIndicator()
                          : CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.primaryColor,
                            ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        // Start at user location if available, otherwise default
                        target: _currentPosition ?? _defaultLocation,
                        zoom: 14,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapType: MapType.satellite,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // Trigger smart zoom when map is ready
                        _zoomToUserOrFitMarkers();
                      },
                    ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
