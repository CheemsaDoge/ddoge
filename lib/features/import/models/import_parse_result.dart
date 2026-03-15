import 'package:ddoge/core/models/time_slot_template.dart';
import 'package:ddoge/data/database/app_database.dart';

class ImportParseResult {
  const ImportParseResult({
    required this.courses,
    this.timeSlotTemplate,
    this.normalizedWeekOffset = 0,
  });

  final List<Course> courses;
  final TimeSlotTemplate? timeSlotTemplate;
  final int normalizedWeekOffset;
}
