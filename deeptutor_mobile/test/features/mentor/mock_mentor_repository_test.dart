import 'package:deeptutor_mobile/features/mentor/data/mentor_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockMentorRepository', () {
    const repo = MockMentorRepository();

    test('dashboard returns deterministic counts', () async {
      final d = await repo.dashboard();
      expect(d.totalStudents, greaterThan(0));
      expect(d.activeToday, lessThanOrEqualTo(d.totalStudents));
      expect(d.atRiskCount, lessThanOrEqualTo(d.totalStudents));
    });

    test('students includes Rohan who is at risk', () async {
      final students = await repo.students();
      final rohan = students.firstWhere((s) => s.id == 's2');
      expect(rohan.riskScore, greaterThan(0.5));
    });

    test('studentDetail returns null for missing id', () async {
      expect(await repo.studentDetail('zzz'), isNull);
    });

    test('interventions lists at least one item', () async {
      final items = await repo.interventions();
      expect(items, isNotEmpty);
    });
  });
}
