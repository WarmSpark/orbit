import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';

class PlaceResult {
  final String name;
  final LatLng position;
  const PlaceResult(this.name, this.position);
}

class GeocodingService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const _userAgent = 'OrbitApp/1.0 (campus hangouts; NCR test build)';

  Future<List<PlaceResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'limit': '6',
        'addressdetails': '0',

        'viewbox':
            '${Config.ncrMinLng},${Config.ncrMaxLat},${Config.ncrMaxLng},${Config.ncrMinLat}',
        'bounded': '1',
        'countrycodes': 'in',
      },
    );

    final res = await http
        .get(
          uri,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) return const [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];

    final out = <PlaceResult>[];
    for (final item in decoded.whereType<Map>()) {
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      final name = (item['display_name'] ?? '').toString();
      if (lat == null || lon == null || name.isEmpty) continue;
      if (!Config.withinNCR(lat, lon)) continue;
      out.add(PlaceResult(_shorten(name), LatLng(lat, lon)));
    }
    return out;
  }

  String _shorten(String full) {
    final parts = full.split(',').map((s) => s.trim()).toList();
    if (parts.length <= 2) return full;
    return '${parts[0]}, ${parts[1]}';
  }
}
