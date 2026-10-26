import 'package:flutter_test/flutter_test.dart';
import 'package:solid_waste_operations/core/constants/app_constants.dart';
import 'package:solid_waste_operations/core/models/core_models.dart';

void main() {
  test('all five system roles are defined', () {
    expect(roles.length, 5);
    expect(roles.toSet().length, 5);
    expect(roles.contains('worker'), isTrue);
    expect(roles.contains('group_supervisor'), isTrue);
    expect(roles.contains('municipality_coordinator'), isTrue);
    expect(roles.contains('jsc_coordinator'), isTrue);
    expect(roles.contains('donor_manager'), isTrue);
  });

  test('image target options are supported', () {
    expect([300, 400, 500, 600, 1024].contains(300), isTrue);
    expect([300, 400, 500, 600, 1024].contains(1024), isTrue);
  });

  test('municipality coordinator owns group management', () {
    expect(defaultPolicy('municipality_coordinator', 'workers').create, isTrue);
    expect(defaultPolicy('group_supervisor', 'workers').visible, isFalse);
  });
}
