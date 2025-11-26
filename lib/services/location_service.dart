import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<String?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null; // Location services are disabled.
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null; // Permissions are denied
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      // We can't request permissions again, but we can open app settings.
      // For now, we'll just return null, but in a real app we might want to prompt the user.
      return null;
    } 

    try {
      final position = await Geolocator.getCurrentPosition();
      
      // Try to get address
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final address = [
            place.street,
            place.subLocality,
            place.locality,
            place.postalCode,
            place.country
          ].where((e) => e != null && e.isNotEmpty).join(', ');
          
          return '$address\n(${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
        }
      } catch (e) {
        // Ignore geocoding error and return coordinates
      }

      return '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    } catch (e) {
      return null;
    }
  }
}
