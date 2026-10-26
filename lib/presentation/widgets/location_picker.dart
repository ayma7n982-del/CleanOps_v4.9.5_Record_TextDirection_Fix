import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import 'app_design.dart';
import '../../core/constants/app_constants.dart';

const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

Future<LatLng?> showLocationPicker(BuildContext context, {LatLng? initial, bool startWithCurrentLocation = true}) async {
  return Navigator.of(context).push<LatLng>(MaterialPageRoute(builder: (_) => _LocationPickerPage(initial: initial, startWithCurrentLocation: startWithCurrentLocation)));
}

class LocationField extends StatelessWidget {
  final LatLng? value;
  final ValueChanged<LatLng?> onChanged;
  final bool enabled;
  final String? label;
  const LocationField({super.key, required this.value, required this.onChanged, this.enabled = true, this.label});
  @override Widget build(BuildContext context) {
    final p = value;
    return AiSectionCard(title: label ?? 'الموقع الجغرافي', subtitle: p == null ? 'اختر الموقع من الخريطة أو استخدم موقع الهاتف.' : 'الموقع المختار', feature: 'map', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (p != null) Text('GPS: ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}', style: const TextStyle(color: cleanOpsMuted, fontSize: 11)),
      const SizedBox(height: 8),
      SizedBox(height: 150, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: IgnorePointer(child: _MapPreview(point: p)))),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: enabled ? () async { final next = await showLocationPicker(context, initial: value, startWithCurrentLocation: value == null); if (next != null) onChanged(next); } : null, icon: const Icon(Icons.edit_location_alt_rounded), label: AppText(p == null ? 'اختيار الموقع' : 'تغيير الموقع')),
    ]));
  }
}

class _MapPreview extends StatelessWidget {
  final LatLng? point;
  const _MapPreview({this.point});
  @override Widget build(BuildContext context) => FlutterMap(options: MapOptions(initialCenter: point ?? const LatLng(31.52, 34.45), initialZoom: point == null ? 8 : 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)), children: [TileLayer(urlTemplate: _osmUrl, userAgentPackageName: 'com.solidwaste.solid_waste_operations'), if (point != null) MarkerLayer(markers: [Marker(point: point!, width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red, size: 40))]), const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')])]);
}

class _LocationPickerPage extends StatefulWidget {
  final LatLng? initial; final bool startWithCurrentLocation;
  const _LocationPickerPage({this.initial, required this.startWithCurrentLocation});
  @override State<_LocationPickerPage> createState() => _LocationPickerPageState();
}
class _LocationPickerPageState extends State<_LocationPickerPage> {
  late LatLng point = widget.initial ?? const LatLng(31.52, 34.45);
  late final MapController map = MapController();
  final search = TextEditingController();
  final mapLink = TextEditingController();
  Timer? _debounce; DateTime _lastNominatim = DateTime.fromMillisecondsSinceEpoch(0); bool busy = false; double? accuracy; String message = '';
  @override void initState() { super.initState(); if (widget.startWithCurrentLocation && widget.initial == null) unawaited(_current()); }
  @override void dispose(){_debounce?.cancel();search.dispose();mapLink.dispose();super.dispose();}
  Future<void> _current() async {
    setState(()=>busy=true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { if(mounted) setState(()=>message='GPS غير مفعّل — يمكنك فتح إعدادات الموقع.'); return; }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) { if(mounted)setState(()=>message='تم رفض إذن الموقع. يمكنك اختيار الموقع يدويًا من الخريطة.'); return; }
      Position? pos;
      try { pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8))); } catch (_) { pos = await Geolocator.getLastKnownPosition(); }
      if (pos == null) { if(mounted)setState(()=>message='تعذر الحصول على موقع الهاتف.'); return; }
      if (!mounted) return; final current = pos; final p=LatLng(current.latitude,current.longitude); setState((){point=p;accuracy=current.accuracy;message=current.accuracy>50?'دقة GPS أضعف من 50 مترًا.':'تم تحديث موقع الهاتف.';}); map.move(p,16);
    } finally { if(mounted)setState(()=>busy=false); }
  }
  bool _pasteMapLink() {
    final raw = mapLink.text.trim();
    final patterns = [RegExp(r'[@](-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'), RegExp(r'[?&#]q=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'), RegExp(r'#map=\d+(?:\.\d+)?/(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)')];
    for(final re in patterns){ final m=re.firstMatch(raw); if(m!=null){ final lat=double.tryParse(m.group(1)!); final lng=double.tryParse(m.group(2)!); if(lat!=null&&lng!=null&&lat.abs()<=90&&lng.abs()<=180){ final p=LatLng(lat,lng); setState(()=>point=p); map.move(p,16); return true; } } }
    setState(()=>message='لم أتمكن من استخراج إحداثيات من الرابط.'); return false;
  }

  void _searchChanged(String _) { _debounce?.cancel(); _debounce=Timer(const Duration(milliseconds:600),_searchAddress); }
  Future<void> _searchAddress() async { final q=search.text.trim(); if(q.length<3)return; final wait=DateTime.now().difference(_lastNominatim); if(wait<Duration(seconds:1))await Future<void>.delayed(Duration(seconds:1)-wait); _lastNominatim=DateTime.now(); try { final uri=Uri.https('nominatim.openstreetmap.org','/search',{'q':q,'format':'json','limit':'1'}); final r=await http.get(uri,headers:{'User-Agent':'CleanOps/4.7 solid_waste_operations contact: cleanops'}).timeout(const Duration(seconds:8)); if(r.statusCode!=200)throw Exception('Nominatim HTTP ${r.statusCode}'); final a=(jsonDecode(r.body) as List).cast<Map<String,dynamic>>(); if(a.isEmpty){setState(()=>message='لم يتم العثور على العنوان.');return;} final p=LatLng(double.parse('${a.first['lat']}'),double.parse('${a.first['lon']}'));setState(()=>point=p);map.move(p,16);}catch(e){if(mounted)setState(()=>message='تعذر البحث عن العنوان.');} }
  @override
  Widget build(BuildContext context) {
    final rtl = context.watch<LocaleController>().isArabic;
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const AppText('اختيار الموقع')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: search,
              onChanged: _searchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: tr('بحث عن عنوان'),
                suffixIcon: IconButton(onPressed: _searchAddress, icon: const Icon(Icons.arrow_forward)),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(children: [Expanded(child: TextField(controller: mapLink, decoration: InputDecoration(labelText: tr('لصق رابط Google Maps / OSM')))), IconButton(onPressed: _pasteMapLink, icon: const Icon(Icons.link_rounded))])),
          Expanded(
            child: FlutterMap(
              mapController: map,
              options: MapOptions(
                initialCenter: point,
                initialZoom: widget.initial == null ? 14 : 16,
                onPositionChanged: (pos, _) => setState(() => point = pos.center),
              ),
              children: [
                TileLayer(
                  urlTemplate: _osmUrl,
                  userAgentPackageName: 'com.solidwaste.solid_waste_operations',
                ),
                MarkerLayer(markers: [Marker(point: point, width: 54, height: 54, child: const Icon(Icons.location_pin, color: Colors.red, size: 50))]),
                const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (accuracy != null)
                Text('دقة GPS: ${accuracy!.round()} م${accuracy! > 50 ? ' — يفضّل تحسين الدقة' : ''}', style: TextStyle(color: accuracy! > 50 ? Colors.orange : Colors.green, fontWeight: FontWeight.w700)),
              if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(children: [Text(message, style: const TextStyle(fontSize: 11, color: cleanOpsMuted)), if(message.contains('GPS غير مفعّل')) TextButton.icon(onPressed: Geolocator.openLocationSettings, icon: const Icon(Icons.settings), label: const AppText('فتح إعدادات الموقع'))])),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: busy ? null : _current, icon: const Icon(Icons.my_location), label: const AppText('موقعي الحالي'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(context, point), icon: const Icon(Icons.check), label: const AppText('تأكيد الموقع'))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
