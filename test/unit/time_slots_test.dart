import 'package:ddoge/core/constants/time_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the configured 11-slot UESTC timetable by default', () {
    final slots = TimeSlotConstants.defaultTimeSlots;

    expect(TimeSlotConstants.maxSlotsPerDay, 11);
    expect(slots, hasLength(11));
    expect(slots.first, (
      startHour: 8,
      startMinute: 30,
      endHour: 9,
      endMinute: 15,
    ));
    expect(slots.last, (
      startHour: 21,
      startMinute: 10,
      endHour: 21,
      endMinute: 55,
    ));
  });
}
