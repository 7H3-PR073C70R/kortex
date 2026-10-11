import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/domain/services/document_zone_classifier.dart';

void main() {
  const classifier = DocumentZoneClassifier.instance;

  group('DocumentZoneClassifier - classifyHeading', () {
    test('classifies navigation and front matter headings as frontMatter (Zone A)', () {
      final frontMatterHeadings = [
        'Table of Contents',
        'TABLE OF CONTENTS',
        'Brief Contents',
        'Contents',
        'Index',
        'Subject Index',
        'List of Figures',
        'List of Tables',
        'Preface',
        'Foreword',
      ];

      for (final heading in frontMatterHeadings) {
        expect(
          classifier.classifyHeading(heading),
          equals(DocumentZone.frontMatter),
          reason: 'Heading "$heading" should be classified as frontMatter',
        );
      }
    });

    test('classifies legal, community, administrative, and feedback as administrative (Zone B)', () {
      final adminHeadings = [
        'Code of Conduct',
        'Code of conduct and guidelines for Kotlin Slack',
        'Community Guidelines',
        'Apache 2.0 License',
        'Copyright and Permissions',
        'All Rights Reserved',
        'About the Authors',
        'Contributors and Acknowledgments',
        'Join Us on Slack and Discord',
        'Documentation Survey & Feedback',
        'Stay Connected',
        'Subscribe to Our Newsletter',
      ];

      for (final heading in adminHeadings) {
        expect(
          classifier.classifyHeading(heading),
          equals(DocumentZone.administrative),
          reason: 'Heading "$heading" should be classified as administrative',
        );
      }
    });

    test('classifies changelogs, release notes, and version highlights as lifecycle (Zone C)', () {
      final lifecycleHeadings = [
        "What's New in Kotlin 2.2",
        'What’s New in Version 3.0',
        'Release Notes',
        'Release Notes for v2.1.0',
        'Changelog',
        'Breaking Changes and Deprecations',
        'Version History',
        'Migration Guide',
        'v1.9.20 Highlights',
        'The Kotlin 2.2.0 release is here! Here are the main highlights',
      ];

      for (final heading in lifecycleHeadings) {
        expect(
          classifier.classifyHeading(heading),
          equals(DocumentZone.lifecycle),
          reason: 'Heading "$heading" should be classified as lifecycle',
        );
      }
    });

    test('classifies exercises, problem sets, and drills as assessment (Zone D)', () {
      final assessmentHeadings = [
        'Exercises',
        'Chapter 4 Exercises',
        'Problem Set 1',
        'Practice Problems',
        'Homework 3',
        'Self-Test Questions',
        'Review Drill',
        'Hint',
        'Loops practice',
        'Functions practice',
        'Quiz Questions',
      ];

      for (final heading in assessmentHeadings) {
        expect(
          classifier.classifyHeading(heading),
          equals(DocumentZone.assessment),
          reason: 'Heading "$heading" should be classified as assessment',
        );
      }
    });

    test('classifies genuine educational headings as bodyKnowledge (Zone E)', () {
      final knowledgeHeadings = [
        'Object-Oriented Programming Concepts',
        'Null Safety in Modern Type Systems',
        'Photosynthesis and Cellular Respiration',
        'First Law of Thermodynamics',
        'Coroutines and Asynchronous Control Flow',
        'Data Structures: Balanced Trees',
        'Memory Layout and LLVM Optimization',
        'Introduction to Extension Functions',
      ];

      for (final heading in knowledgeHeadings) {
        expect(
          classifier.classifyHeading(heading),
          equals(DocumentZone.bodyKnowledge),
          reason: 'Heading "$heading" should be classified as bodyKnowledge',
        );
      }
    });
  });

  group('DocumentZoneClassifier - shouldSkipBlockContent', () {
    test('flags community links, surveys, licenses, and scaffolding blocks to skip', () {
      expect(
        classifier.shouldSkipBlockContent('Get a Slack invite and provide feedback in our #general channel.'),
        isTrue,
      );
      expect(
        classifier.shouldSkipBlockContent('Copyright (c) 2026 JetBrains s.r.o. All rights reserved under Apache 2.0.'),
        isTrue,
      );
      expect(
        classifier.shouldSkipBlockContent('Please fill out our documentation survey to help us improve.'),
        isTrue,
      );
      expect(
        classifier.shouldSkipBlockContent('Subscribe to our channel or follow us on Twitter/X for updates.'),
        isTrue,
      );
      expect(
        classifier.shouldSkipBlockContent('Write your code here // TODO: implement solution'),
        isTrue,
      );
    });

    test('preserves genuine academic explanations', () {
      expect(
        classifier.shouldSkipBlockContent(
          'Kotlin is a statically typed programming language that runs on the JVM and compiles to native binaries.',
        ),
        isFalse,
      );
      expect(
        classifier.shouldSkipBlockContent(
          'An immutable reference (val) cannot be reassigned once initialized with a value.',
        ),
        isFalse,
      );
    });
  });
}
