import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/queue_entry.dart';

class PrintService {
  /// Generate a PDF ticket for printing with logo
  static Future<Uint8List> generateTicketPdfBytes({
    required QueueEntry entry,
  }) async {
    final pdf = pw.Document();

    // Load a font that supports Unicode characters
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // Load the queue logo image
    final ByteData logoData = await rootBundle.load('assets/queue_logo.jpg');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);

    // Create the PDF ticket
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm thermal printer format
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Logo - Smaller
              pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(
                    color: PdfColors.blue900,
                    width: 1.5,
                  ),
                ),
                child: pw.ClipOval(
                  child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                ),
              ),
              pw.SizedBox(height: 6),

              // Header - Smaller font
              pw.Text(
                'QUEUE TICKET',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 6),

              // Reference Number - Compact
              if (entry.referenceNumber != null) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue600, width: 1.5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'REFERENCE NUMBER',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blue800,
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        entry.referenceNumber!,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          font: fontBold,
                        ),
                        textAlign: pw.TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // Priority Badge if applicable - Compact
              if (entry.isPriority) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green100,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(
                      color: PdfColors.green700,
                      width: 1,
                    ),
                  ),
                  child: pw.Text(
                    '⚡ PRIORITY: ${entry.priorityType}',
                    style: pw.TextStyle(
                      color: PdfColors.green900,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      font: fontBold,
                    ),
                    maxLines: 1,
                  ),
                ),
                pw.SizedBox(height: 6),
              ],

              // Queue Number - Smaller but still prominent
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'QUEUE NUMBER',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                        font: font,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '#${entry.queueNumber.toString().padLeft(3, '0')}',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        font: fontBold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Details Section - Compact
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Name', entry.name, font, fontBold),
                    pw.SizedBox(height: 4),
                    _buildDetailRow('SSU ID', entry.ssuId, font, fontBold),
                    pw.SizedBox(height: 4),
                    _buildDetailRow('Email', entry.email, font, fontBold),
                    pw.SizedBox(height: 4),
                    _buildDetailRow('Phone', entry.phoneNumber, font, fontBold),
                    pw.SizedBox(height: 4),
                    if (entry.gender != null && entry.gender!.isNotEmpty)
                      _buildDetailRow('Gender', entry.gender!, font, fontBold),
                    if (entry.gender != null && entry.gender!.isNotEmpty)
                      pw.SizedBox(height: 4),
                    if (entry.age != null)
                      _buildDetailRow('Age', entry.age.toString(), font, fontBold),
                    if (entry.age != null)
                      pw.SizedBox(height: 4),
                    _buildDetailRow('Dept', entry.department, font, fontBold),
                    pw.SizedBox(height: 4),
                    _buildDetailRow('Purpose', entry.purpose, font, fontBold),
                    pw.SizedBox(height: 4),
                    _buildDetailRow(
                      'Type',
                      entry.studentType == 'Graduated' && entry.graduationYear != null
                          ? '${entry.studentType} (${entry.graduationYear})'
                          : entry.studentType,
                      font,
                      fontBold,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Priority Message if applicable - Compact
              if (entry.isPriority) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '🚀 PRIORITY ACCESS',
                        style: pw.TextStyle(
                          color: PdfColors.green900,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          font: fontBold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Top 2 positions',
                        style: pw.TextStyle(
                          color: PdfColors.green900,
                          fontSize: 8,
                          font: font,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
              ],

              // Footer - Compact
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),
              pw.Text(
                'Please wait for your number',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                  font: font,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                entry.timestamp.toString().substring(0, 19),
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                  font: font,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Helper method to build detail rows in PDF
  static pw.Widget _buildDetailRow(
      String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 60,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
              font: fontBold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.length > 50 ? '${value.substring(0, 47)}...' : value,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.black,
              font: font,
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  /// Print ticket with preview dialog
  static Future<void> printTicket({required QueueEntry entry}) async {
    try {
      final pdfBytes = await generateTicketPdfBytes(entry: entry);
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Queue_Ticket_${entry.queueNumber}.pdf',
        format: PdfPageFormat.roll80,
      );
    } catch (e) {
      print('Error printing ticket: $e');
      rethrow;
    }
  }

  /// Print ticket to default printer without preview
  static Future<void> printTicketDirect({required QueueEntry entry}) async {
    try {
      final pdfBytes = await generateTicketPdfBytes(entry: entry);
      
      // Print to default printer
      final printers = await Printing.listPrinters();
      if (printers.isNotEmpty) {
        await Printing.directPrintPdf(
          printer: printers.first,
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Queue_Ticket_${entry.queueNumber}.pdf',
          format: PdfPageFormat.roll80,
        );
      }
    } catch (e) {
      print('Error direct printing ticket: $e');
      rethrow;
    }
  }

  /// Share or save PDF ticket
  static Future<void> sharePdfTicket({required QueueEntry entry}) async {
    try {
      final pdfBytes = await generateTicketPdfBytes(entry: entry);
      
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Queue_Ticket_${entry.queueNumber}.pdf',
      );
    } catch (e) {
      print('Error sharing ticket: $e');
      rethrow;
    }
  }

  /// Method to get ticket text representation (for debugging/console)
  static String getTicketText(QueueEntry entry) {
    return '''
═══════════════════════════
        Queue Ticket       
═══════════════════════════

Queue Number: #${entry.queueNumber.toString().padLeft(3, '0')}${entry.isPriority ? '\n🟢 PRIORITY: ${entry.priorityType}' : ''}

Name: ${entry.name}
SSU ID: ${entry.ssuId}
Email: ${entry.email}
Phone: ${entry.phoneNumber}${entry.gender != null && entry.gender!.isNotEmpty ? '\nGender: ${entry.gender}' : ''}${entry.age != null ? '\nAge: ${entry.age}' : ''}
Department: ${entry.department}
Purpose: ${entry.purpose}
Type: ${entry.studentType == 'Graduated' && entry.graduationYear != null ? '${entry.studentType} (${entry.graduationYear})' : entry.studentType}${entry.isPriority ? '\n\n🚀 You have priority access!\nYou will be served in the top 2 positions.' : ''}

Timestamp: ${entry.timestamp}

═══════════════════════════
Please wait for your number
to be called.
═══════════════════════════
''';
  }
}
