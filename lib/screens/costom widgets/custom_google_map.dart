import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class CustomGoogleMap extends StatefulWidget {
  final LatLng? initialPosition;
  final CameraPosition? initialCameraPosition;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Function(GoogleMapController)? onMapCreated;
  final bool showUserLocation;
  final double? zoom;
  final MapType mapType;
  final String? mapStyle;

  const CustomGoogleMap({
    Key? key,
    this.initialPosition,
    this.initialCameraPosition,
    this.markers,
    this.polylines,
    this.onMapCreated,
    this.showUserLocation = true,
    this.zoom = 14.4746,
    this.mapType = MapType.normal,
    this.mapStyle,
  }) : super(key: key);

  @override
  _CustomGoogleMapState createState() => _CustomGoogleMapState();

  
}

class _CustomGoogleMapState extends State<CustomGoogleMap> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  CameraPosition? _calculatedCameraPosition;

  @override
  void initState() {
    super.initState();
    _calculateInitialCameraPosition();
    if (widget.showUserLocation) {
      _getCurrentLocation();
    }
  }

  
  void _calculateInitialCameraPosition() {
    if (widget.initialCameraPosition != null) {
      _calculatedCameraPosition = widget.initialCameraPosition;
    } else if (widget.initialPosition != null) {
      _calculatedCameraPosition = CameraPosition(
        target: widget.initialPosition!,
        zoom: widget.zoom ?? 14.4746,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() {
        _currentPosition = position;
        if (_calculatedCameraPosition == null) {
          _calculatedCameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: widget.zoom ?? 14.4746,
          );
        }
      });

      _updateMapCamera(position);
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  void _updateMapCamera(Position position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: widget.zoom ?? 14.4746,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: _calculatedCameraPosition ?? const CameraPosition(
        target: LatLng(0, 0), // Fallback position
        zoom: 14.4746,
      ),
      markers: widget.markers ?? {},
      polylines: widget.polylines ?? {},
      mapType: widget.mapType,
      myLocationEnabled: widget.showUserLocation,
      onMapCreated: (controller) {
        _mapController = controller;
        if (widget.mapStyle != null) {
          controller.setMapStyle(widget.mapStyle);
        }
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
      },
    );
  }
}