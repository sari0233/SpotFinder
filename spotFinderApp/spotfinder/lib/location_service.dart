import 'package:geolocator/geolocator.dart';

class LocationService {
  // Methode om de huidige locatie van de gebruiker op te halen
  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }
}
