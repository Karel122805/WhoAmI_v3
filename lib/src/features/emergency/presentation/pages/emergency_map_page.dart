import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart'; // Para kInk

class EmergencyMapPage extends StatelessWidget {
  final String consultantId;
  final double lat;
  final double lng;

  /// Vista dentro del diálogo
  final bool isDialog;

  /// 🎨 Declaramos aquí el color de emergencia
  static const Color kEmergencyRed = Color(0xFFFF9FA1);

  const EmergencyMapPage({
    super.key,
    required this.consultantId,
    required this.lat,
    required this.lng,
    this.isDialog = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = 'https://www.google.com/maps?q=$lat,$lng';
    final uri = Uri.parse(url);

    // ⭐ VISTA PARA EL DIÁLOGO (sin mapa, con icono y color oficial Who Am I)
    if (isDialog) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kEmergencyRed.withValues(alpha: 0.5),
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.emergency_share_rounded,
              color: kEmergencyRed,   // 🟠 Ícono de emergencia
              size: 72,
            ),
            SizedBox(height: 14),
            Text(
              "Toca el botón para abrir la ubicación\nen Google Maps",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kInk,
              ),
            ),
          ],
        ),
      );
    }

    // ⭐ VISTA COMPLETA COMO PANTALLA (solo botón)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de emergencia'),
        backgroundColor: Colors.white,
        foregroundColor: kInk,
      ),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.navigation_rounded, color: Colors.white),
          label: const Text(
            "Abrir en Google Maps",
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: kEmergencyRed, // 🟠 Botón usando color oficial
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
          ),
          onPressed: () async {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }
}






