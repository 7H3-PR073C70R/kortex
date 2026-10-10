import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';

void main() {
  group('AppApiEndpoint Contract Verification Tests', () {
    late String migrationsContent;
    late List<String> existingFunctions;

    setUpAll(() {
      // 1. Read all migration files into a single concatenated string
      final migrationsDir = Directory('supabase/migrations');
      expect(
        migrationsDir.existsSync(),
        isTrue,
        reason: 'supabase/migrations directory must exist',
      );

      final sqlFiles = migrationsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList();

      final buffer = StringBuffer();
      for (final file in sqlFiles) {
        buffer.writeln(file.readAsStringSync());
      }
      migrationsContent = buffer.toString().toLowerCase();

      // 2. Discover all Edge Function directories
      final functionsDir = Directory('supabase/functions');
      expect(
        functionsDir.existsSync(),
        isTrue,
        reason: 'supabase/functions directory must exist',
      );

      existingFunctions = functionsDir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.reversed.skip(1).first)
          .where((name) => !name.startsWith('_'))
          .toList();
    });

    test('All RPC endpoints defined in AppApiEndpoint exist in migrations', () {
      final rpcEndpoints = <String>[
        AppApiEndpoint.updateProfileRpc,
        AppApiEndpoint.dashboardFeed,
        AppApiEndpoint.dashboardAnalyticsSummaryRpc,
        AppApiEndpoint.dashboardStartExam,
        AppApiEndpoint.syncCoursesRpc,
        AppApiEndpoint.autoCurateExamRpc,
        AppApiEndpoint.getUserCuratedCoursesRpc,
        AppApiEndpoint.sessionResults,
        AppApiEndpoint.matchDocumentChunksRpc,
        AppApiEndpoint.getSyllabotQuota,
        AppApiEndpoint.recordSyllabotUsage,
        AppApiEndpoint.findOrCreateDocumentReference,
        AppApiEndpoint.claimOrCreateDocumentPreflight,
        AppApiEndpoint.getAiSmartGenQuota,
        AppApiEndpoint.recordAiSmartGenUsage,
        AppApiEndpoint.claimWeeklyXpRpc,
        AppApiEndpoint.syncUserProgressRpc,
        AppApiEndpoint.cloneSharedDeckRpc,
        AppApiEndpoint.rateSharedDeckRpc,
        AppApiEndpoint.deleteSharedDeckRpc,
        AppApiEndpoint.verifyForumReplyRpc,
        AppApiEndpoint.voteForumPostAtomicRpc,
        AppApiEndpoint.voteForumReplyAtomicRpc,
        AppApiEndpoint.autoProvisionCommunityRpc,
        AppApiEndpoint.nudgeStudyCircleRpc,
        AppApiEndpoint.recordPodFocusMinutesRpc,
        AppApiEndpoint.cleanupStaleStudyPodsAndRoomsRpc,
        AppApiEndpoint.toggleForumPostSubscriptionRpc,
        AppApiEndpoint.isForumPostSubscribedRpc,
        AppApiEndpoint.fetchForumPostsKeysetRpc,
        AppApiEndpoint.fetchForumThreadTreeRpc,
        AppApiEndpoint.saveForumSocraticHintRpc,
        AppApiEndpoint.generateDuelQuestionsRpc,
        AppApiEndpoint.submitQuizResultsRpc,
        AppApiEndpoint.registerDeviceTokenRpc,
        AppApiEndpoint.upsertNotificationPreferencesRpc,
        AppApiEndpoint.redeemPromoCodeRpc,
      ];

      final missingRpcs = <String>[];

      for (final endpoint in rpcEndpoints) {
        final rpcName = endpoint.split('/rest/v1/rpc/').last.toLowerCase();
        final functionPattern = RegExp(
          'function\\s+(public\\.)?${RegExp.escape(rpcName)}\\s*\\(',
          caseSensitive: false,
        );

        if (!functionPattern.hasMatch(migrationsContent)) {
          missingRpcs.add(rpcName);
        }
      }

      expect(
        missingRpcs,
        isEmpty,
        reason:
            'The following RPCs defined in AppApiEndpoint do not exist in migrations: $missingRpcs',
      );
    });

    test('All Edge Functions defined in AppApiEndpoint exist in supabase/functions/', () {
      final functionEndpoints = <String>[
        AppApiEndpoint.syllabotStream,
        AppApiEndpoint.generateEmbeddings,
        AppApiEndpoint.parseStemOcr,
        AppApiEndpoint.transcribeAudioWhisper,
        AppApiEndpoint.uploadForumMedia,
        AppApiEndpoint.transcribeVoiceNote,
        AppApiEndpoint.generateLiveKitToken,
        AppApiEndpoint.generateQuizQuestions,
      ];

      final missingFunctions = <String>[];

      for (final endpoint in functionEndpoints) {
        final functionName = endpoint.split('/functions/v1/').last;
        if (!existingFunctions.contains(functionName)) {
          missingFunctions.add(functionName);
        }
      }

      expect(
        missingFunctions,
        isEmpty,
        reason:
            'The following Edge Functions defined in AppApiEndpoint are missing from supabase/functions: $missingFunctions',
      );
    });
  });
}
