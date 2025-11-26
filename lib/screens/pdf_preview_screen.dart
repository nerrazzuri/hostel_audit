import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfData;
  final VoidCallback onBack;

  const PdfPreviewScreen({super.key, required this.pdfData, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text('PDF Preview'),
        centerTitle: true,
      ),
      body: PdfPreview(
        build: (format) async => pdfData,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        useActions: true,
      ),
    );
  }
}


