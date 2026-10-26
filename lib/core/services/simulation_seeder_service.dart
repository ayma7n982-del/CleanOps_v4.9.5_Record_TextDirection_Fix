/// Temporary, local-only Cycle 11 demo data.
///
/// IMPORTANT: This service intentionally does NOT use Firebase, Firestore,
/// callable functions, authentication, or any production data collection.
/// All generated records live only in this Dart process and disappear when
/// the app process is restarted. This is a disposable UI/demo simulation.
class SimulationSeederService {
  static List<Map<String, dynamic>> _municipalities = <Map<String, dynamic>>[];
  static List<Map<String, dynamic>> _groups = <Map<String, dynamic>>[];
  static List<Map<String, dynamic>> _workers = <Map<String, dynamic>>[];
  static List<Map<String, dynamic>> _containers = <Map<String, dynamic>>[];
  static List<Map<String, dynamic>> _trips = <Map<String, dynamic>>[];

  static bool get hasSimulation => _municipalities.isNotEmpty;
  static List<Map<String, dynamic>> get municipalities => List<Map<String, dynamic>>.unmodifiable(_municipalities);
  static List<Map<String, dynamic>> get groups => List<Map<String, dynamic>>.unmodifiable(_groups);
  static List<Map<String, dynamic>> get workers => List<Map<String, dynamic>>.unmodifiable(_workers);
  static List<Map<String, dynamic>> get containers => List<Map<String, dynamic>>.unmodifiable(_containers);
  static List<Map<String, dynamic>> get trips => List<Map<String, dynamic>>.unmodifiable(_trips);
  static Map<String, int> get counts => <String, int>{
        'municipalities': _municipalities.length,
        'groups': _groups.length,
        'workers': _workers.length,
        'containers': _containers.length,
        'trips': _trips.length,
        'volumeTons': _trips.length * 10,
      };

  /// Generates an isolated in-memory demo; no Firestore writes are performed.
  static Future<Map<String, dynamic>> runCycle11Simulation() async {
    if (hasSimulation) return <String, dynamic>{...counts, 'alreadyExists': true, 'localOnly': true};

    const municipalityId = 'demo_bani_suheila_cycle11';
    _municipalities = <Map<String, dynamic>>[
      <String, dynamic>{'id': municipalityId, 'name': 'بلدية بني سهيلا', 'cycle': 11, 'month': 'أكتوبر 2026', 'isSimulation': true},
    ];
    _groups = <Map<String, dynamic>>[];
    _workers = <Map<String, dynamic>>[];
    _containers = <Map<String, dynamic>>[];
    _trips = <Map<String, dynamic>>[];

    for (var groupNo = 1; groupNo <= 5; groupNo++) {
      final groupId = 'demo_cycle11_group_$groupNo';
      _groups.add(<String, dynamic>{'id': groupId, 'name': 'المجموعة $groupNo', 'municipalityId': municipalityId, 'isSimulation': true});
      _workers.add(<String, dynamic>{'id': '${groupId}_supervisor', 'name': 'مشرف المجموعة $groupNo', 'role': 'field_supervisor', 'groupId': groupId, 'isSimulation': true});
      for (var i = 1; i <= 7; i++) {
        _workers.add(<String, dynamic>{'id': '${groupId}_worker_$i', 'name': 'عامل جمع $i - المجموعة $groupNo', 'role': 'primary_collection_worker', 'groupId': groupId, 'isSimulation': true});
      }
      for (var i = 1; i <= 2; i++) {
        _workers.add(<String, dynamic>{'id': '${groupId}_cart_worker_$i', 'name': 'عامل كارة $i - المجموعة $groupNo', 'role': 'animal_cart_worker', 'groupId': groupId, 'isSimulation': true});
      }
    }

    for (var i = 1; i <= 2; i++) {
      _containers.add(<String, dynamic>{
        'id': 'demo_cycle11_container_$i',
        'name': 'حاوية تجريبية $i',
        'location': 'شارع الرشيد، خان يونس',
        'capacityTons': 20,
        'latitude': 31.34 + (i * 0.001),
        'longitude': 34.30 + (i * 0.001),
        'imageUrl': 'https://via.placeholder.com/150',
        'isSimulation': true,
      });
    }

    var tripNo = 0;
    for (var day = 1; day <= 20; day++) {
      for (var groupNo = 1; groupNo <= 5; groupNo++) {
        final groupId = 'demo_cycle11_group_$groupNo';
        final dailyTrips = 5 + ((groupNo - 1) * 2);
        for (var tripInDay = 1; tripInDay <= dailyTrips; tripInDay++) {
          tripNo++;
          _trips.add(<String, dynamic>{
            'id': 'demo_cycle11_trip_$tripNo',
            'cycleNumber': 11,
            'date': '2026-10-${day.toString().padLeft(2, '0')}',
            'municipalityId': municipalityId,
            'groupId': groupId,
            'volumeTons': 10,
            'destination': tripNo.isEven ? 'مكب أصداء' : 'مكب الأقصى',
            'imageUrl': 'https://via.placeholder.com/150',
            'latitude': 31.34 + (groupNo * 0.001),
            'longitude': 34.30 + (day * 0.001),
            'isSimulation': true,
          });
        }
      }
    }
    return <String, dynamic>{...counts, 'localOnly': true};
  }

  /// Clears only the local in-memory demo lists. Does not delete remote data.
  static Future<Map<String, dynamic>> deleteSimulationData() async {
    final deleted = _municipalities.length + _groups.length + _workers.length + _containers.length + _trips.length;
    _municipalities = <Map<String, dynamic>>[];
    _groups = <Map<String, dynamic>>[];
    _workers = <Map<String, dynamic>>[];
    _containers = <Map<String, dynamic>>[];
    _trips = <Map<String, dynamic>>[];
    return <String, dynamic>{'deleted': deleted, 'localOnly': true};
  }
}

Future<Map<String, dynamic>> runCycle11Simulation() =>
    SimulationSeederService.runCycle11Simulation();

Future<Map<String, dynamic>> deleteSimulationData() =>
    SimulationSeederService.deleteSimulationData();
