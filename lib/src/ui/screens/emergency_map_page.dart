import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyMapPage extends StatefulWidget {
  final String consultantId;
  final double lat;
  final double lng;

  /// 👇 Parámetro opcional para mostrar dentro de un diálogo
  final bool isDialog;

  const EmergencyMapPage({
    super.key,
    required this.consultantId,
    required this.lat,
    required this.lng,
    this.isDialog = false,
  });

  @override
  State<EmergencyMapPage> createState() => _EmergencyMapPageState();
}

class _EmergencyMapPageState extends State<EmergencyMapPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = pos;
      });
    } catch (e) {
      debugPrint('⚠️ Error obteniendo ubicación actual: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng patientLocation = LatLng(widget.lat, widget.lng);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('patient'),
        position: patientLocation,
        infoWindow: const InfoWindow(title: 'Ubicación del consultante'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('caregiver'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    final mapWidget = GoogleMap(
      initialCameraPosition: CameraPosition(
        target: patientLocation,
        zoom: 15,
      ),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (controller) => _mapController = controller,
    );

    // 🟣 Si se muestra dentro de una ventana, solo devolvemos el mapa sin Scaffold
    if (widget.isDialog) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: mapWidget,
      );
    }

    // 🟢 Si se muestra como pantalla independiente
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de emergencia'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: mapWidget,
    );
  }
}
