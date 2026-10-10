import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/transition_parser_engine.dart';

void main() {
  late TransitionParserEngine parser;

  setUp(() {
    parser = TransitionParserEngine.instance;
  });

  group('TransitionParserEngine - Layer 2', () {
    test('parses SVO sentence into valid DependencyTree', () {
      final tree = parser.parse(
        'Glycolysis splits one glucose molecule into two molecules of pyruvate.',
      );

      expect(tree.root.form.toLowerCase(), equals('splits'));
      expect(tree.root.pos, equals('VBZ'));

      final nsubj = tree.root.findFirstChild('nsubj');
      expect(nsubj, isNotNull);
      expect(nsubj!.form, equals('Glycolysis'));

      final dobj = tree.root.findFirstChild('dobj');
      expect(dobj, isNotNull);
      expect(dobj!.form, equals('molecule'));
    });

    test('reconstructs subtree span text accurately', () {
      final tree = parser.parse('Flutter compiles code using the AOT compiler.');
      final nsubj = tree.root.findFirstChild('nsubj');
      expect(nsubj, isNotNull);
      expect(nsubj!.getSubtreeSpanText(), equals('Flutter'));
    });

    test('hydrates model from JSON representation correctly', () {
      final weightsJson = {
        'biases': {'SHIFT': 1.0, 'RIGHT_ARC:root': 2.0},
        'pos_lexicon': {'run': 'VB', 'fast': 'RB'},
        'weights': {
          's0_p:VB': {'RIGHT_ARC:root': 4.0},
        },
      };

      final customModel = AveragedPerceptron.fromJson(weightsJson);
      final customParser = TransitionParserEngine(model: customModel);
      final tree = customParser.parse('run fast');

      expect(tree.nodes.length, greaterThan(1));
    });
  });
}
