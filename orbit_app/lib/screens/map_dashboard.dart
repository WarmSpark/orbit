import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/hangout.dart';
import '../services/geocoding_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/category_chip.dart';
import '../widgets/hangout_pin.dart';
import 'hangout_detail_sheet.dart';

class MapDashboard extends StatefulWidget {
  const MapDashboard({super.key});

  @override
  State<MapDashboard> createState() => MapDashboardState();
}

class MapDashboardState extends State<MapDashboard> {
  final MapController _map = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  static final _ncrBounds = LatLngBounds(
    const LatLng(Config.ncrMinLat, Config.ncrMinLng),
    const LatLng(Config.ncrMaxLat, Config.ncrMaxLng),
  );

  List<Hangout> _hangouts = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  String? _selectedId;

  Timer? _searchDebounce;
  Timer? _poll;
  List<PlaceResult> _suggestions = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    reload();

    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _quietRefresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  LatLng get _startCenter {
    final loc = context.read<AppState>().myLocation;
    if (loc != null && Config.withinNCR(loc.latitude, loc.longitude)) {
      return loc;
    }
    return const LatLng(Config.ncrCenterLat, Config.ncrCenterLng);
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<AppState>().events.listEvents();
      if (!mounted) return;
      setState(() {
        _hangouts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load hangouts.';
        _loading = false;
      });
    }
  }

  Future<void> _quietRefresh() async {
    try {
      final list = await context.read<AppState>().events.listEvents();
      if (!mounted) return;
      setState(() => _hangouts = list);
    } catch (_) {}
  }

  List<Hangout> get _visible => _filter == 'All'
      ? _hangouts
      : _hangouts.where((h) => h.category == _filter).toList();

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await context.read<AppState>().geocoding.search(q);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _searching = false;
        });
      }
    });
  }

  void _goToPlace(PlaceResult place) {
    _searchFocus.unfocus();
    _searchCtrl.text = place.name;
    setState(() => _suggestions = []);
    _map.move(place.position, 16);
  }

  Future<void> _locateMe() async {
    final app = context.read<AppState>();
    final result = await app.location.current();
    if (!mounted) return;
    if (result.isOk) {
      app.setLocation(result.position!);
      if (Config.withinNCR(
        result.position!.latitude,
        result.position!.longitude,
      )) {
        _map.move(result.position!, 16);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You appear to be outside the NCR test area.'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location.')),
      );
    }
  }

  void _openHangout(Hangout h) {
    setState(() => _selectedId = h.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HangoutDetailSheet(hangout: h, onChanged: reload),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _startCenter,
            initialZoom: 14,
            minZoom: 10,
            maxZoom: 18,

            cameraConstraint: CameraConstraint.contain(bounds: _ncrBounds),
            onTap: (_, _) => _searchFocus.unfocus(),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.orbit.app',
              maxNativeZoom: 19,
            ),
            MarkerLayer(
              markers: [
                for (final h in _visible)
                  Marker(
                    point: h.latLng,
                    width: kPinSize.width,
                    height: kPinSize.height,
                    alignment: Alignment.topCenter,
                    child: HangoutPin(
                      hangout: h,
                      selected: h.id == _selectedId,
                      onTap: () => _openHangout(h),
                    ),
                  ),
              ],
            ),
          ],
        ),

        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  searching: _searching,
                  onChanged: _onSearchChanged,
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() => _suggestions = []);
                    _searchFocus.unfocus();
                  },
                ),
                if (_suggestions.isNotEmpty)
                  _SuggestionList(suggestions: _suggestions, onTap: _goToPlace),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      CategoryChip(
                        label: 'All',
                        icon: Icons.grid_view_rounded,
                        color: OrbitColors.primary,
                        selected: _filter == 'All',
                        onTap: () => setState(() => _filter = 'All'),
                      ),
                      const SizedBox(width: 8),
                      for (final c in kCategories) ...[
                        CategoryChip(
                          label: c.key,
                          icon: c.icon,
                          color: c.color,
                          selected: _filter == c.key,
                          onTap: () => setState(() => _filter = c.key),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_loading)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.cSurface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Loading hangouts…',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.cInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Positioned(
          right: 16,
          bottom: 96,
          child: _RoundButton(
            icon: Icons.my_location_rounded,
            onTap: _locateMe,
          ),
        ),

        if (_error != null)
          Positioned(
            bottom: 96,
            left: 16,
            child: _RoundButton(icon: Icons.refresh_rounded, onTap: reload),
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search places in the NCR',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              : (controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClear,
                      )
                    : null),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<PlaceResult> suggestions;
  final ValueChanged<PlaceResult> onTap;
  const _SuggestionList({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (final s in suggestions)
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.place_outlined,
                color: OrbitColors.primary,
              ),
              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onTap(s),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cSurface,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: OrbitColors.primary),
        ),
      ),
    );
  }
}
