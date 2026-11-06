import 'package:ddoge/core/models/time_slot_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeSlotTemplateSlot', () {
    test('fromJson and toJson should work correctly (round-trip)', () {
      final json = {
        'index': 1,
        'startHour': 8,
        'startMinute': 30,
        'endHour': 9,
        'endMinute': 15,
      };

      final slot = TimeSlotTemplateSlot.fromJson(json);

      expect(slot.index, 1);
      expect(slot.startHour, 8);
      expect(slot.startMinute, 30);
      expect(slot.endHour, 9);
      expect(slot.endMinute, 15);

      final toJsonResult = slot.toJson();
      expect(toJsonResult, json);
    });

    test('fromJson handles num types correctly', () {
      final json = {
        'index': 1.0,
        'startHour': 8.0,
        'startMinute': 30.0,
        'endHour': 9.0,
        'endMinute': 15.0,
      };

      final slot = TimeSlotTemplateSlot.fromJson(json);

      expect(slot.index, 1);
      expect(slot.startHour, 8);
      expect(slot.startMinute, 30);
      expect(slot.endHour, 9);
      expect(slot.endMinute, 15);
    });
  });

  group('TimeSlotTemplate', () {
    test('fromJson and toJson should work correctly (round-trip)', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Template',
        'slots': [
          {
            'index': 1,
            'startHour': 8,
            'startMinute': 30,
            'endHour': 9,
            'endMinute': 15,
          }
        ],
        'isBuiltin': true,
        'source': 'Test Source',
      };

      final template = TimeSlotTemplate.fromJson(json);

      expect(template.id, 'test_id');
      expect(template.name, 'Test Template');
      expect(template.slots.length, 1);
      expect(template.slots.first.index, 1);
      expect(template.isBuiltin, true);
      expect(template.source, 'Test Source');

      final toJsonResult = template.toJson();
      expect(toJsonResult, json);
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Template',
      };

      final template = TimeSlotTemplate.fromJson(json);

      expect(template.id, 'test_id');
      expect(template.name, 'Test Template');
      expect(template.slots, isEmpty);
      expect(template.isBuiltin, false);
      expect(template.source, isNull);

      final toJsonResult = template.toJson();
      expect(toJsonResult, {
        'id': 'test_id',
        'name': 'Test Template',
        'slots': [],
        'isBuiltin': false,
        'source': null,
      });
    });

    test('fromJson handles empty slots array', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Template',
        'slots': [],
      };

      final template = TimeSlotTemplate.fromJson(json);

      expect(template.id, 'test_id');
      expect(template.slots, isEmpty);
    });
  });
}
