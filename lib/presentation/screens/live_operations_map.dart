import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/config_service.dart';
import '../widgets/app_design.dart';
import '../../core/localization.dart';

class LiveOperationsMapScreen extends StatelessWidget {
  const LiveOperationsMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final config = context.watch<ConfigService>();
    if (user == null || (user.role != 'donor_manager' && user.role != 'jsc_coordinator')) {
      return const Scaffold(body: Center(child: AppText('لا توجد صلاحية للوصول إلى خريطة العمليات.')));
    }
    return Scaffold(
      backgroundColor: cleanOpsBg,
      appBar: AppBar(title: const AppText('خريطة العمليات الحية')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('dumpsites').where('isActive', isEqualTo: true).snapshots(),
        builder: (context, dumpsitesSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').where('isActive', isEqualTo: true).snapshots(),
            builder: (context, usersSnap) {
              final dumpsites = (dumpsitesSnap.data?.docs ?? []).map((d) => {'id': d.id, ...d.data()}).toList();
              final groups = <String, Map<String, dynamic>>{};
              for (final doc in usersSnap.data?.docs ?? []) {
                final x = doc.data();
                final role = '${x['role'] ?? ''}';
                if (role != 'worker' && role != 'group_supervisor') continue;
                final groupId = '${x['groupId'] ?? ''}'.trim();
                final point = _point(x['lastLocation']);
                if (groupId.isEmpty || point == null) continue;
                groups[groupId] = {'groupId': groupId, 'point': point, 'name': '${x['groupName'] ?? groupId}', 'role': role};
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                children: [
                  AiSectionCard(
                    title: config.liveOperationsMapEnabled ? 'Live Operations Map' : 'الخريطة الرمزية',
                    subtitle: config.liveOperationsMapEnabled
                        ? (config.workerLocationTrackingEnabled ? 'تظهر المكبات والمجموعات النشطة التي أرسلت آخر موقع.' : 'تتبع العاملين متوقف؛ ستظهر مواقع المكبات فقط.')
                        : 'وضع الخريطة الحية متوقف. هذه الخريطة الرمزية لا تطلب إذن GPS وتعرض الحالة التشغيلية فقط.',
                    feature: 'critical_areas',
                    child: Column(
                      children: [
                        SizedBox(
                          height: 360,
                          child: _SatelliteOperationsMap(
                            dumpsites: dumpsites,
                            groups: groups.values.toList(),
                            enabled: config.liveOperationsMapEnabled,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text('صور جوية © Esri ومساهمو البيانات', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: cleanOpsMuted)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 16, runSpacing: 8, children: [
                          _Legend(color: aiGreen, label: 'مكب نشط'),
                          _Legend(color: aiCyan, label: 'مجموعة نشطة'),
                          _Legend(color: Colors.redAccent, label: 'تحديث حرج/قديم'),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(leading: const Icon(Icons.delete_sweep_outlined, color: aiGreen), title: AppText('المكبات'), trailing: Text('${dumpsites.length}')),
                  ListTile(leading: const Icon(Icons.groups_rounded, color: aiCyan), title: AppText('المجموعات ذات الموقع'), trailing: Text('${groups.length}')),
                  if (dumpsites.isEmpty && groups.isEmpty)
                    const Padding(padding: EdgeInsets.all(18), child: AppText('لا توجد إحداثيات متاحة بعد. أضف إحداثيات للمكبات وفَعّل تتبع مواقع العاملين عند الحاجة.')),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static bool _hasPoint(Map<String, dynamic> x) => _point(x['locationGeo'] ?? x['lastLocation']) != null;

  static GeoPoint? _point(dynamic value) {
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = value['latitude'];
      final lng = value['longitude'];
      if (lat is num && lng is num) return GeoPoint(lat.toDouble(), lng.toDouble());
    }
    return null;
  }
}

class _SatelliteOperationsMap extends StatelessWidget {
  final List<Map<String, dynamic>> dumpsites;
  final List<Map<String, dynamic>> groups;
  final bool enabled;
  const _SatelliteOperationsMap({required this.dumpsites, required this.groups, required this.enabled});

  LatLng? _latLng(dynamic value) {
    if (value is GeoPoint) return LatLng(value.latitude, value.longitude);
    if (value is Map) {
      final lat = value['latitude'] ?? value['lat'];
      final lng = value['longitude'] ?? value['lng'] ?? value['lon'];
      if (lat is num && lng is num && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) return LatLng(lat.toDouble(), lng.toDouble());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[];
    for (final d in dumpsites) {
      final point = _latLng(d['locationGeo'] ?? d['location'] ?? {'latitude': d['latitude'], 'longitude': d['longitude']});
      if (point != null) points.add(point);
    }
    for (final g in groups) {
      final point = _latLng(g['point'] ?? g['lastLocation']);
      if (point != null) points.add(point);
    }
    final center = points.isEmpty ? const LatLng(31.45, 34.4) : LatLng(
      points.map((p) => p.latitude).reduce((a,b) => a+b) / points.length,
      points.map((p) => p.longitude).reduce((a,b) => a+b) / points.length,
    );
    if (!enabled) {
      return Container(
        decoration: BoxDecoration(color: aiDark.withOpacity(.08), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.map_outlined, size: 42, color: aiCyan), SizedBox(height: 8), Text('الخريطة الحية متوقفة من الإعدادات') ])),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: points.isEmpty ? 8.5 : 11),
        children: [
          TileLayer(
            urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.solidwaste.solid_waste_operations',
            maxNativeZoom: 19,
            maxZoom: 19,
            errorTileCallback: (tile, error, stackTrace) {},
          ),
          MarkerLayer(markers: [
            for (final d in dumpsites)
              if (_latLng(d['locationGeo'] ?? d['location'] ?? {'latitude': d['latitude'], 'longitude': d['longitude']}) case final LatLng p)
                Marker(point: p, width: 42, height: 48, child: const Icon(Icons.location_on, size: 38, color: Color(0xFF72D572))),
            for (final g in groups)
              if (_latLng(g['point'] ?? g['lastLocation']) case final LatLng p)
                Marker(point: p, width: 38, height: 42, child: const Icon(Icons.groups_rounded, size: 30, color: Color(0xFF39C6A5))),
          ]),
          RichAttributionWidget(attributions: [TextSourceAttribution('Esri, Maxar, Earthstar Geographics and GIS User Community')]),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), AppText(label, style: const TextStyle(fontSize: 11, color: cleanOpsMuted))]);
}

class _OperationsMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> dumpsites;
  final List<Map<String, dynamic>> groups;
  final bool symbolicOnly;
  _OperationsMapPainter({required this.dumpsites, required this.groups, this.symbolicOnly = false});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF061A2A);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)), bg);
    final grid = Paint()..color = const Color(0x1420D7FF)..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 36) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (var y = 0.0; y < size.height; y += 36) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    if (symbolicOnly) {
      final totalDumpsites = dumpsites.length;
      final totalGroups = groups.length;
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(center, 72, Paint()..color = aiCyan.withOpacity(.06));
      canvas.drawCircle(center, 46, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = aiCyan.withOpacity(.35));
      _label(canvas, 'الوضع الرمزي', center + const Offset(-34, -8));
      final labels = [
        'المكبات: $totalDumpsites',
        'المجموعات: $totalGroups',
        configlessStatus(),
      ];
      for (var i = 0; i < labels.length; i++) {
        _label(canvas, labels[i], Offset(24, 30.0 + i * 28));
      }
      return;
    }
    final all = <GeoPoint>[];
    for (final d in dumpsites) { final p = _point(d['locationGeo'] ?? d['lastLocation']); if (p != null) all.add(p); }
    for (final g in groups) { final p = _point(g['point']); if (p != null) all.add(p); }
    if (all.isEmpty) {
      final tp = TextPainter(text: const TextSpan(text: 'لا توجد نقاط GPS متاحة', style: TextStyle(color: Colors.white70, fontSize: 15)), textDirection: TextDirection.rtl)..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }
    final minLat = all.map((p) => p.latitude).reduce(math.min), maxLat = all.map((p) => p.latitude).reduce(math.max);
    final minLng = all.map((p) => p.longitude).reduce(math.min), maxLng = all.map((p) => p.longitude).reduce(math.max);
    Offset project(GeoPoint p) {
      final dx = (maxLng - minLng).abs() < 0.00001 ? .5 : (p.longitude - minLng) / (maxLng - minLng);
      final dy = (maxLat - minLat).abs() < 0.00001 ? .5 : (maxLat - p.latitude) / (maxLat - minLat);
      return Offset(28 + dx * (size.width - 56), 28 + dy * (size.height - 56));
    }
    for (final d in dumpsites) {
      final p = _point(d['locationGeo'] ?? d['lastLocation']); if (p == null) continue;
      final o = project(p); canvas.drawCircle(o, 10, Paint()..color = aiGreen.withOpacity(.18)); canvas.drawCircle(o, 5, Paint()..color = aiGreen);
      _label(canvas, '${d['nameAr'] ?? d['name'] ?? 'مكب'}', o + const Offset(9, -8));
    }
    for (final g in groups) {
      final p = _point(g['point']); if (p == null) continue;
      final o = project(p); canvas.drawCircle(o, 10, Paint()..color = aiCyan.withOpacity(.16)); canvas.drawCircle(o, 5, Paint()..color = aiCyan);
      _label(canvas, '${g['name'] ?? g['groupId']}', o + const Offset(9, 8));
    }
  }

  String configlessStatus() => 'GPS: غير مطلوب';

  void _label(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)), textDirection: TextDirection.rtl)..layout(maxWidth: 150);
    tp.paint(canvas, offset);
  }

  GeoPoint? _point(dynamic value) {
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = value['latitude']; final lng = value['longitude'];
      if (lat is num && lng is num) return GeoPoint(lat.toDouble(), lng.toDouble());
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant _OperationsMapPainter oldDelegate) => true;
}
