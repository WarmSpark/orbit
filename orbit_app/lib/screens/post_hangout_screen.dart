import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/hangout.dart';
import '../services/api_client.dart';
import '../services/geocoding_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class PostHangoutScreen extends StatefulWidget {
  const PostHangoutScreen({super.key});

  @override
  State<PostHangoutScreen> createState() => _PostHangoutScreenState();
}

class _PostHangoutScreenState extends State<PostHangoutScreen> {
  final _map = MapController();
  final _titleCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();

  static final _ncrBounds = LatLngBounds(
    const LatLng(Config.ncrMinLat, Config.ncrMinLng),
    const LatLng(Config.ncrMaxLat, Config.ncrMaxLng),
  );

  String? _category;
  late LatLng _picked;
  DateTime? _when;
  int _capacity = 4;

  bool _checking = true;
  bool _posting = false;
  Hangout? _existing;

  Timer? _placeDebounce;
  List<PlaceResult> _placeSuggestions = [];
  bool _placeSearching = false;

  bool _suppressPlaceSearch = false;

  @override
  void initState() {
    super.initState();
    final loc = context.read<AppState>().myLocation;
    _picked = (loc != null && Config.withinNCR(loc.latitude, loc.longitude))
        ? loc
        : const LatLng(Config.ncrCenterLat, Config.ncrCenterLng);
    _checkExisting();
  }

  @override
  void dispose() {
    _placeDebounce?.cancel();
    _titleCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  void _onPlaceChanged(String value) {
    if (_suppressPlaceSearch) return;
    _placeDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _placeSuggestions = [];
        _placeSearching = false;
      });
      return;
    }
    setState(() => _placeSearching = true);
    _placeDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await context.read<AppState>().geocoding.search(q);
        if (!mounted) return;
        setState(() {
          _placeSuggestions = results;
          _placeSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _placeSuggestions = [];
          _placeSearching = false;
        });
      }
    });
  }

  void _pickPlace(PlaceResult place) {
    _placeDebounce?.cancel();
    _suppressPlaceSearch = true;
    _placeCtrl.text = place.name;
    _placeCtrl.selection = TextSelection.collapsed(offset: place.name.length);
    _suppressPlaceSearch = false;
    _picked = place.position;
    _map.move(place.position, 16);
    FocusScope.of(context).unfocus();
    setState(() {
      _placeSuggestions = [];
      _placeSearching = false;
    });
  }

  Future<void> _checkExisting() async {
    try {
      final events = await context.read<AppState>().events.listEvents();
      final mine = events.where((e) => e.isHost).toList();
      if (!mounted) return;
      setState(() {
        _existing = mine.isEmpty ? null : mine.first;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: now.subtract(const Duration(minutes: 1)),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _when ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _useMyLocation() async {
    final app = context.read<AppState>();
    final result = await app.location.current();
    if (!mounted) return;
    if (result.isOk &&
        Config.withinNCR(
          result.position!.latitude,
          result.position!.longitude,
        )) {
      app.setLocation(result.position!);
      _picked = result.position!;
      _map.move(result.position!, 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not use your location (must be in the NCR).'),
        ),
      );
    }
  }

  String? _validate() {
    if (_category == null) return 'Pick a category for your hangout.';
    if (_titleCtrl.text.trim().isEmpty) return 'Add a short plan title.';
    if (_placeCtrl.text.trim().isEmpty) return 'Add where you are meeting.';
    if (_when == null) return 'Choose when it happens.';
    if (_when!.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      return 'Pick a time in the future.';
    }
    if (!Config.withinNCR(_picked.latitude, _picked.longitude)) {
      return 'Move the pin inside the NCR test area.';
    }
    return null;
  }

  Future<void> _post() async {
    final problem = _validate();
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _posting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<AppState>().events.createEvent(
        title: _titleCtrl.text.trim(),
        category: _category!,
        location: _placeCtrl.text.trim(),
        latitude: _picked.latitude,
        longitude: _picked.longitude,
        time: _when!,
        maxParticipants: _capacity,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Hangout posted 🎉')),
      );
      navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _posting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) setState(() => _posting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not post the hangout. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a hangout')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : (_existing != null ? _alreadyHosting(_existing!) : _form()),
    );
  }

  Widget _alreadyHosting(Hangout h) {
    final cat = categoryFor(h.category);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: cat.color, size: 34),
            ),
            const SizedBox(height: 18),
            const Text(
              'You already have an active hangout',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '“${h.title}” is live. It\'s one hangout per person — cancel it '
              'from its pin or the members list before posting a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cInkSoft, height: 1.4),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _label('Category'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in kCategories)
              _CategoryOption(
                category: c,
                selected: _category == c.key,
                onTap: () => setState(() => _category = c.key),
              ),
          ],
        ),
        const SizedBox(height: 22),
        _label('What\'s the plan?'),
        const SizedBox(height: 10),
        TextField(
          controller: _titleCtrl,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'e.g. Evening football at the turf',
            counterText: '',
          ),
        ),
        const SizedBox(height: 18),
        _label('Where?'),
        const SizedBox(height: 10),
        TextField(
          controller: _placeCtrl,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          onChanged: _onPlaceChanged,
          decoration: InputDecoration(
            hintText: 'e.g. CCD, Sector 18, Noida',
            prefixIcon: const Icon(Icons.place_outlined),
            counterText: '',
            suffixIcon: _placeSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : null,
          ),
        ),
        _placeSuggestionsBox(),
        const SizedBox(height: 18),
        _label('Drop the pin'),
        const SizedBox(height: 6),
              Text(
          'Move the map to place your pin exactly.',
          style: TextStyle(color: context.cInkSoft, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _mapPicker(),
        const SizedBox(height: 22),
        _label('When?'),
        const SizedBox(height: 10),
        _whenTile(),
        const SizedBox(height: 22),
        _label('Group size'),
        const SizedBox(height: 10),
        _capacityTile(),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _posting ? null : _post,
          icon: _posting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.push_pin_rounded),
          label: Text(_posting ? 'Posting…' : 'Post hangout'),
        ),
      ],
    );
  }

  Widget _placeSuggestionsBox() {
    if (_placeSuggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cLine),
      ),
      child: Column(
        children: [
          for (final p in _placeSuggestions)
            InkWell(
              onTap: () => _pickPlace(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 18,
                      color: OrbitColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapPicker() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _picked,
                initialZoom: 15,
                minZoom: 10,
                maxZoom: 18,
                cameraConstraint: CameraConstraint.contain(bounds: _ncrBounds),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onPositionChanged: (camera, _) => _picked = camera.center,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.orbit.app',
                  maxNativeZoom: 19,
                ),
              ],
            ),

            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 42,
                    color: OrbitColors.primary,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: context.cSurface,
                elevation: 2,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _useMyLocation,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: OrbitColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whenTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickWhen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cLine),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: OrbitColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _when == null ? 'Pick a date & time' : formatWhen(_when!),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _when == null ? context.cInkSoft : context.cInk,
                ),
              ),
            ),
                  Icon(Icons.chevron_right_rounded, color: context.cInkSoft),
          ],
        ),
      ),
    );
  }

  Widget _capacityTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_capacity people',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'You + up to ${_capacity - 1} others',
                  style: TextStyle(
                    color: context.cInkSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _stepBtn(
            icon: Icons.remove_rounded,
            enabled: _capacity > 2,
            onTap: () => setState(() => _capacity--),
          ),
          const SizedBox(width: 10),
          _stepBtn(
            icon: Icons.add_rounded,
            enabled: _capacity < 8,
            onTap: () => setState(() => _capacity++),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled
          ? OrbitColors.primary.withValues(alpha: 0.12)
          : context.cLine,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? OrbitColors.primary : context.cInkSoft,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  );
}

class _CategoryOption extends StatelessWidget {
  final HangoutCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? category.color
              : category.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? category.color : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 18,
              color: selected ? Colors.white : category.color,
            ),
            const SizedBox(width: 8),
            Text(
              category.key,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : category.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
