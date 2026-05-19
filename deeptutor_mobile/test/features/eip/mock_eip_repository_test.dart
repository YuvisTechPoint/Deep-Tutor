import 'package:deeptutor_mobile/features/eip/data/eip_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockEipRepository', () {
    test('myProfile and publicProfile match by slug', () async {
      final repo = MockEipRepository();
      final mine = await repo.myProfile();
      final pub = await repo.publicProfile(mine.slug);
      expect(pub.slug, mine.slug);
    });

    test('publicProfile throws when private', () async {
      final repo = MockEipRepository();
      final mine = await repo.myProfile();
      await repo.updateProfile(mine.copyWith(public: false));
      expect(() => repo.publicProfile(mine.slug), throwsStateError);
    });

    test('shareLink returns canonical URL', () async {
      final repo = MockEipRepository();
      final link = await repo.shareLink('aanya-patel');
      expect(link, contains('aanya-patel'));
    });
  });
}
