import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class WatermarkService {
  static Future<File> watermarkImage(File imageFile, String location, {String? gpsLocation}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      final now = DateTime.now();
      final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');
      final dateStr = dateFormat.format(now);
      
      String text = '$location\n$dateStr';
      if (gpsLocation != null && gpsLocation.isNotEmpty) {
        text += '\nGPS: $gpsLocation';
      }

      // Add text watermark
      // We'll use the default bitmap font for now as loading custom fonts requires assets
      // Position: Bottom Left
      
      // Draw a semi-transparent background for the text
      // Note: 'image' package drawing primitives are basic.
      // We'll try to draw text directly.
      
      // Since the 'image' package's text drawing is limited without custom fonts,
      // and we want a clear watermark, we will use drawString.
      
      // Calculate position (bottom left with padding)
      // We can't easily measure text width with bitmap fonts, so we'll just place it.
      
      // To make it readable, we might need a background strip.
      // Or just draw white text with black shadow/outline (simulated by drawing multiple times).
      
      final x = 20;
      // Adjust Y based on number of lines (approx 30px per line)
      final lineCount = text.split('\n').length;
      final y = image.height - (lineCount * 30) - 20; 

      // Draw shadow (black)
      img.drawString(
        image,
        text,
        font: img.arial24,
        x: x + 2,
        y: y + 2,
        color: img.ColorRgb8(0, 0, 0),
      );

      // Draw text (white)
      img.drawString(
        image,
        text,
        font: img.arial24,
        x: x,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );

      final watermarkedBytes = img.encodeJpg(image, quality: 85);
      await imageFile.writeAsBytes(watermarkedBytes);
      
      return imageFile;
    } catch (e) {
      print('Error watermarking image: $e');
      return imageFile;
    }
  }
}
