import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deeptutor_mobile/data/models/api_mappers.dart';
import 'package:deeptutor_mobile/data/models/gamification_mappers.dart';

Future<dynamic> _loadFixture(String name) async {
  final file = File('test/fixtures/$name');
  final raw = await file.readAsString();
  return jsonDecode(raw);
}

void main() {
  group('ApiMappers', () {
    test('parseChatMessages maps role and content', () {
      final messages = ApiMappers.parseChatMessages([
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Hi there'},
      ]);
      expect(messages, hasLength(2));
      expect(messages.first.role, 'user');
      expect(messages.last.content, 'Hi there');
    });

    test('parseChatSessionList maps session_id and null title', () async {
      final data = await _loadFixture('chat_sessions.json');
      final sessions = ApiMappers.parseChatSessionList(data);

      expect(sessions, hasLength(2));
      expect(sessions[0].id, 'sess-abc-123');
      expect(sessions[0].title, 'New chat');
      expect(sessions[0].messageCount, 4);
      expect(sessions[1].title, 'Python loops');
    });

    test('parseChatSessionList handles numeric epoch timestamps', () {
      final sessions = ApiMappers.parseChatSessionList([
        {
          'session_id': 'chat_123',
          'title': 'Test',
          'created_at': 1716638400.5,
          'updated_at': 1716638500.0,
          'message_count': 2,
        },
      ]);

      expect(sessions, hasLength(1));
      expect(sessions.first.createdAt, isNotNull);
      expect(sessions.first.updatedAt, contains('T'));
    });

    test('parsePracticeTopics unwraps string list', () async {
      final json = await _loadFixture('practice_topics.json') as Map<String, dynamic>;
      final topics = ApiMappers.parsePracticeTopics(json);

      expect(topics, hasLength(3));
      expect(topics.first.id, 'algorithms');
      expect(topics.first.name, 'Algorithms');
    });

    test('parsePracticeQuestions maps items and option keys', () async {
      final json =
          await _loadFixture('practice_questions.json') as Map<String, dynamic>;
      final response = ApiMappers.parsePracticeQuestions(json);

      expect(response.quizId, 'quiz-xyz');
      expect(response.questions, hasLength(1));
      expect(response.questions.first.options, [
        'Constant time',
        'Linear time',
        'Quadratic time',
      ]);
      expect(response.questions.first.optionKeys, ['A', 'B', 'C']);
      expect(
        ApiMappers.answerKeyForIndex(response.questions.first, 1),
        'B',
      );
    });

    test('parsePracticeSubmitResult reads score map and awarded_xp', () {
      final result = ApiMappers.parsePracticeSubmitResult({
        'score': {'correct': 3, 'total': 5, 'percentage': 60},
        'awarded_xp': 25,
      });

      expect(result.score, 3);
      expect(result.total, 5);
      expect(result.xpAwarded, 25);
      expect(result.feedback, contains('60%'));
    });

    test('parseCareerPathsResponse maps title and readiness', () async {
      final json =
          await _loadFixture('career_paths.json') as Map<String, dynamic>;
      final response = ApiMappers.parseCareerPathsResponse(json);

      expect(response.paths, hasLength(1));
      expect(response.paths.first.name, 'Machine Learning Engineer');
      expect(response.paths.first.readinessPercent, 42);
      expect(response.paths.first.estimatedMonths, 6);
      expect(response.profileSummary, contains('ml-engineer'));
    });

    test('parseNotificationList maps message and read', () async {
      final json =
          await _loadFixture('notifications.json') as Map<String, dynamic>;
      final items = ApiMappers.parseNotificationList(json);

      expect(items, hasLength(1));
      expect(items.first.body, 'You earned 50 XP!');
      expect(items.first.isRead, false);
    });

    test('parseRevisionQueue maps card_id and topic', () async {
      final json =
          await _loadFixture('revision_queue.json') as Map<String, dynamic>;
      final items = ApiMappers.parseRevisionQueue(json);

      expect(items, hasLength(1));
      expect(items.first.id, 'card-1');
      expect(items.first.topic, 'Recursion');
    });

    test('revisionGradeFromRating maps ratings to grades', () {
      expect(ApiMappers.revisionGradeFromRating(1), 'again');
      expect(ApiMappers.revisionGradeFromRating(3), 'good');
      expect(ApiMappers.revisionGradeFromRating(4), 'easy');
    });

    test('parseLearningProfile tolerates missing fields', () {
      final profile = ApiMappers.parseLearningProfile({
        'goals': ['learn ML'],
        'weekly_hours': 5,
      });

      expect(profile.goals, ['learn ML']);
      expect(profile.weeklyHours, 5.0);
      expect(profile.diagnosticCompleted, false);
    });
  });

  group('GamificationMappers', () {
    test('parseMissionsToday maps xp and totals', () async {
      final json =
          await _loadFixture('missions_today.json') as Map<String, dynamic>;
      final today = GamificationMappers.parseMissionsToday(json);

      expect(today.completedCount, 1);
      expect(today.totalCount, 2);
      expect(today.missions.first.xpReward, 50);
      expect(today.missions.first.category, 'Practice');
      expect(today.missions.last.completed, true);
    });
  });
}
