import 'package:deeptutor_mobile/features/recruiter/data/recruiter_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockRecruiterRepository', () {
    const repo = MockRecruiterRepository();

    test('search by empty query returns all candidates', () async {
      final all = await repo.search(query: '');
      expect(all.length, greaterThanOrEqualTo(3));
    });

    test('search filters by skill', () async {
      final r = await repo.search(query: '', skills: ['pytorch']);
      expect(r, hasLength(1));
      expect(r.first.id, 'c3');
    });

    test('search filters by min match', () async {
      final r = await repo.search(query: '', minMatch: 0.9);
      expect(r, hasLength(1));
      expect(r.first.id, 'c1');
    });

    test('shortlists is non-empty', () async {
      expect(await repo.shortlists(), isNotEmpty);
    });
  });
}
