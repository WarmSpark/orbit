import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus { ok, serviceDisabled, denied, deniedForever, error }

class LocationResult {
  final LocationStatus status;
  final LatLng? position;
  const LocationResult(this.status, [this.position]);

  bool get isOk => status == LocationStatus.ok && position != null;
}

class LocationService {
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationResult(
        LocationStatus.ok,
        LatLng(pos.latitude, pos.longitude),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.error);
    }
  }
}
