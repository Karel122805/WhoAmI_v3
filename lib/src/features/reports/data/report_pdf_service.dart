import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:whoami_app/src/features/reports/data/activity_summary_period.dart';
import 'package:whoami_app/src/features/reports/data/activity_summary_report.dart';

class ReportPdfService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF0B67C2);
  static const PdfColor _secondary = PdfColor.fromInt(0xFFF36A12);
  static const PdfColor _darkText = PdfColor.fromInt(0xFF161616);
  static const PdfColor _softBlue = PdfColor.fromInt(0xFFEAF4FF);
  static const PdfColor _softGray = PdfColor.fromInt(0xFFF4F6F8);
  static const PdfColor _border = PdfColor.fromInt(0xFFDDE3EA);

  Future<File> generateActivitySummaryPdf({
    required ActivitySummaryReport report,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;

    try {
      final logoBytes = await rootBundle.load('assets/logo-sin-fondo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _border, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'WhoAmI · Reporte generado automáticamente',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            _header(report, logoImage),
            pw.SizedBox(height: 18),

            _patientCard(report),
            pw.SizedBox(height: 16),

            _summaryCards(report),
            pw.SizedBox(height: 18),

            _section(
              title: 'Juegos de memoria',
              children: [
                _infoRow(
                  'Memorama',
                  'Nivel ${report.memoramaUnlockedLevel} de 3',
                ),
                _infoRow(
                  'Secuencia de colores',
                  '${report.brainSaysHighScore} puntos',
                ),
                _infoRow(
                  'Nivel máximo en Secuencia',
                  '${report.brainSaysHighLevel}',
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            _section(
              title: 'Recuerdos y recordatorios',
              children: [
                _infoRow(
                  'Recuerdos agregados',
                  '${report.memoriesAdded}',
                ),
                _infoRow(
                  'Recordatorios registrados',
                  '${report.remindersTotal}',
                ),
                _infoRow(
                  'Recordatorios completados',
                  '${report.remindersCompleted}',
                ),
                _infoRow(
                  'Recordatorios pendientes',
                  '${report.remindersPending}',
                ),
                _infoRow(
                  'Cumplimiento',
                  '${(report.reminderProgress * 100).round()}%',
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            _section(
              title: 'Emergencias',
              children: [
                _infoRow(
                  'Emergencias registradas',
                  '${report.emergenciesCount}',
                ),
                _infoRow(
                  'Última emergencia',
                  _formatDate(report.lastEmergencyAt),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            _textBox(
              title: 'Resumen automático',
              text: report.automaticSummary,
              color: _softBlue,
            ),
            pw.SizedBox(height: 14),

            _textBox(
              title: 'Recomendación',
              text: report.motivationalMessage,
              color: PdfColor.fromInt(0xFFFFF3E8),
              titleColor: _secondary,
            ),

            pw.SizedBox(height: 20),
            pw.Text(
              'Nota: Este documento es un resumen informativo del uso de la aplicación. No sustituye una valoración médica profesional.',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();

    final fileName =
        'resumen_actividad_${report.patientId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(await pdf.save());

    return file;
  }

  Future<void> generateAndOpenActivitySummaryPdf({
    required ActivitySummaryReport report,
  }) async {
    final file = await generateActivitySummaryPdf(report: report);
    await OpenFilex.open(file.path);
  }

  pw.Widget _header(
    ActivitySummaryReport report,
    pw.MemoryImage? logoImage,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _primary,
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null)
            pw.Container(
              width: 58,
              height: 58,
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Image(
                logoImage,
                fit: pw.BoxFit.contain,
              ),
            )
          else
            pw.Container(
              width: 58,
              height: 58,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text(
                  'W',
                  style: pw.TextStyle(
                    color: _primary,
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Resumen de actividad',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Recordar, Cuidar y Proteger',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(999),
                  ),
                  child: pw.Text(
                    '${report.period.label} · ${report.periodRangeText}',
                    style: pw.TextStyle(
                      color: _primary,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _patientCard(ActivitySummaryReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _softGray,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 42,
            height: 42,
            decoration: const pw.BoxDecoration(
              color: _softBlue,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                'P',
                style: pw.TextStyle(
                  color: _primary,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  report.patientName,
                  style: pw.TextStyle(
                    color: _darkText,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  report.patientEmail.isEmpty
                      ? 'Correo no registrado'
                      : report.patientEmail,
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryCards(ActivitySummaryReport report) {
    return pw.Row(
      children: [
        _miniCard(
          title: 'Recuerdos',
          value: '${report.memoriesAdded}',
          color: PdfColor.fromInt(0xFFEAF8EE),
        ),
        pw.SizedBox(width: 8),
        _miniCard(
          title: 'Recordatorios',
          value: '${report.remindersTotal}',
          color: PdfColor.fromInt(0xFFFFF9E6),
        ),
        pw.SizedBox(width: 8),
        _miniCard(
          title: 'Completados',
          value: '${report.remindersCompleted}',
          color: _softBlue,
        ),
        pw.SizedBox(width: 8),
        _miniCard(
          title: 'Emergencias',
          value: '${report.emergenciesCount}',
          color: PdfColor.fromInt(0xFFFFEDED),
        ),
      ],
    );
  }

  pw.Widget _miniCard({
    required String title,
    required String value,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                color: _darkText,
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              title,
              style: const pw.TextStyle(
                color: PdfColors.grey700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _section({
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _border, width: 0.6),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 170,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _darkText,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _textBox({
    required String title,
    required String text,
    required PdfColor color,
    PdfColor titleColor = _primary,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: titleColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            text,
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey800,
              lineSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin registro';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}