import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class SeedPastQuestions {
  const SeedPastQuestions._();

  static List<PastQuestionModel> filter({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  }) {
    var results = List<PastQuestionModel>.from(all);

    if (examCategory != null) {
      results = results.where((q) => q.examType == examCategory).toList();
    }

    if (subject != null && subject.isNotEmpty && subject != 'All') {
      final targetSubj = subject.toLowerCase();
      results = results
          .where((q) => q.subject.toLowerCase() == targetSubj)
          .toList();
    }

    if (year != null) {
      results = results.where((q) => q.year == year).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase();
      results = results.where((q) {
        return q.prompt.toLowerCase().contains(query) ||
            q.topic.toLowerCase().contains(query) ||
            q.subject.toLowerCase().contains(query);
      }).toList();
    }

    results.sort((a, b) {
      final yearComp = b.year.compareTo(a.year);
      if (yearComp != 0) return yearComp;
      return a.questionNumber.compareTo(b.questionNumber);
    });

    return results;
  }

  static const List<PastQuestionModel> all = [
    // WAEC 2024
    PastQuestionModel(
      id: 'waec_math_2024_q1',
      examType: ExamCategory.waec,
      subject: 'Mathematics',
      year: 2024,
      questionNumber: 1,
      prompt: r'If $2^{x+1} + 2^x = 24$, find the value of $x$.',
      latexFormula: '2^{x+1} + 2^x = 24',
      options: ['2', '3', '4', '5'],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation:
          'Factor out 2^x: 2^x(2 + 1) = 24 => 2^x(3) = 24 => 2^x = 8 => x = 3.',
      topic: 'Indices & Logarithms',
    ),
    PastQuestionModel(
      id: 'waec_math_2024_q2',
      examType: ExamCategory.waec,
      subject: 'Mathematics',
      year: 2024,
      questionNumber: 2,
      prompt: r'Evaluate $\log_{10} 25 + \log_{10} 4 - \log_{10} 10$.',
      latexFormula: r'\log_{10} 25 + \log_{10} 4 - \log_{10} 10',
      options: ['1', '2', '10', '100'],
      correctOptionIndex: 0,
      correctOptionLabel: 'A',
      explanation:
          r'Using log laws: \log_{10}((25 * 4)/10) = \log_{10}(10) = 1.',
      topic: 'Logarithms',
      difficulty: 'Easy',
    ),
    PastQuestionModel(
      id: 'waec_eng_2024_q1',
      examType: ExamCategory.waec,
      subject: 'English Language',
      year: 2024,
      questionNumber: 1,
      prompt:
          'From the words lettered A to D, choose the word OPPOSITE '
          'in meaning: "The manager made an *arbitrary* decision."',
      options: ['hasty', 'reasoned', 'harsh', 'objective'],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation:
          'Arbitrary means based on random choice or personal whim; '
          'the opposite is "reasoned".',
      topic: 'Antonyms & Lexis',
    ),
    // WAEC 2023
    PastQuestionModel(
      id: 'waec_phy_2023_q1',
      examType: ExamCategory.waec,
      subject: 'Physics',
      year: 2023,
      questionNumber: 1,
      prompt:
          'A body of mass 5 kg is accelerated uniformly from rest to a '
          'velocity of 20 m/s in 4 seconds. Calculate work done.',
      options: ['500 J', '1000 J', '1500 J', '2000 J'],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation: 'Work done equals change in KE: W = 0.5 * 5 * 400 = 1000 J.',
      topic: 'Work, Energy & Power',
    ),
    PastQuestionModel(
      id: 'waec_chem_2023_q1',
      examType: ExamCategory.waec,
      subject: 'Chemistry',
      year: 2023,
      questionNumber: 1,
      prompt:
          'Which of the following compounds has hydrogen bonding as its '
          'primary intermolecular force?',
      options: ['CH4', 'H2S', 'NH3', 'HCl'],
      correctOptionIndex: 2,
      correctOptionLabel: 'C',
      explanation:
          'Hydrogen bonding occurs with N, O, F. NH3 forms strong H-bonds.',
      topic: 'Chemical Bonding',
      difficulty: 'Easy',
    ),
    // JAMB 2024
    PastQuestionModel(
      id: 'jamb_eng_2024_q1',
      examType: ExamCategory.jamb,
      subject: 'Use of English',
      year: 2024,
      questionNumber: 1,
      prompt:
          'Select the option that best explains the idiom: '
          '"The politician *threw in the towel* after preliminary results."',
      options: [
        'Took a bath',
        'Conceded defeat and withdrew',
        'Protested aggressively',
        'Celebrated an early victory',
      ],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation:
          'To "throw in the towel" means to surrender or admit defeat.',
      topic: 'Idioms & Collocations',
      difficulty: 'Easy',
    ),
    PastQuestionModel(
      id: 'jamb_math_2024_q1',
      examType: ExamCategory.jamb,
      subject: 'Mathematics',
      year: 2024,
      questionNumber: 1,
      prompt: r'Find the derivative \frac{dy}{dx} of y = (3x^2 - 2x + 1)^4.',
      latexFormula: 'y = (3x^2 - 2x + 1)^4',
      options: [
        '4(6x - 2)(3x^2 - 2x + 1)^3',
        '(6x - 2)(3x^2 - 2x + 1)^3',
        '4(3x^2 - 2x + 1)^3',
        '(12x - 8)(3x^2 - 2x + 1)^4',
      ],
      correctOptionIndex: 0,
      correctOptionLabel: 'A',
      explanation:
          r'Chain Rule: \frac{dy}{dx} = 4(3x^2 - 2x + 1)^3 * (6x - 2).',
      topic: 'Calculus & Differentiation',
    ),
    // SAT 2024
    PastQuestionModel(
      id: 'sat_math_2024_q1',
      examType: ExamCategory.sat,
      subject: 'SAT Math',
      year: 2024,
      questionNumber: 1,
      prompt: 'If f(x) = 3x^2 - 5x + 2, what is the value of f(-2)?',
      latexFormula: 'f(x) = 3x^2 - 5x + 2',
      options: ['12', '18', '24', '28'],
      correctOptionIndex: 2,
      correctOptionLabel: 'C',
      explanation: 'f(-2) = 3(4) - 5(-2) + 2 = 12 + 10 + 2 = 24.',
      topic: 'Functions & Quad Functions',
      difficulty: 'Easy',
    ),
    // TOEFL 2024
    PastQuestionModel(
      id: 'toefl_read_2024_q1',
      examType: ExamCategory.toefl,
      subject: 'Reading',
      year: 2024,
      questionNumber: 1,
      passage:
          'Desert plants have evolved adaptations to minimize '
          'transpiration. Succulents store water in fleshy stems, while '
          'xerophytes possess thick waxy cuticles and sunken stomata.',
      prompt:
          'According to the passage, what is the primary function of '
          'sunken stomata in xerophytes?',
      options: [
        'To increase photosynthetic absorption',
        'To reduce water loss through transpiration',
        'To attract desert pollinators',
        'To store excess metabolic sugars',
      ],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation:
          'Sunken stomata create a microclimate that slows transpiration.',
      topic: 'Academic Reading Comprehension',
    ),
    // IELTS 2024
    PastQuestionModel(
      id: 'ielts_read_2024_q1',
      examType: ExamCategory.ielts,
      subject: 'Academic Reading',
      year: 2024,
      questionNumber: 1,
      passage:
          'Urban heat islands occur when cities replace natural land cover '
          'with dense concentrations of pavement and buildings.',
      prompt:
          'Do the following statements agree with the text? '
          '"Urban development increases surface temperatures."',
      options: ['TRUE', 'FALSE', 'NOT GIVEN', 'CANNOT BE DETERMINED'],
      correctOptionIndex: 0,
      correctOptionLabel: 'A',
      explanation:
          'Pavements and buildings absorb heat, causing higher temperatures.',
      topic: 'True/False/Not Given',
    ),
    // Medicine 2024
    PastQuestionModel(
      id: 'med_anat_2024_q1',
      examType: ExamCategory.medicine,
      subject: 'Human Anatomy',
      year: 2024,
      questionNumber: 1,
      prompt:
          'Which cranial nerve provides parasympathetic innervation to '
          'the thoracic and abdominal viscera?',
      options: [
        'CN VII (Facial Nerve)',
        'CN IX (Glossopharyngeal Nerve)',
        'CN X (Vagus Nerve)',
        'CN XII (Hypoglossal Nerve)',
      ],
      correctOptionIndex: 2,
      correctOptionLabel: 'C',
      explanation: 'The Vagus nerve (CN X) provides parasympathetic supply.',
      topic: 'Neuroanatomy & Cranial Nerves',
    ),
    // Law 2024
    PastQuestionModel(
      id: 'law_tort_2024_q1',
      examType: ExamCategory.law,
      subject: 'Law of Torts',
      year: 2024,
      questionNumber: 1,
      prompt:
          'The landmark case of Donoghue v Stevenson (1932) established '
          'which fundamental legal principle?',
      options: [
        'The "Neighbour Principle" and duty of care',
        'Strict liability in dangerous animal keeping',
        'The doctrine of sovereign immunity',
        'Res ipsa loquitur in surgical procedures',
      ],
      correctOptionIndex: 0,
      correctOptionLabel: 'A',
      explanation:
          'Lord Atkin formulated the Neighbour Principle in negligence law.',
      topic: 'Tort Law & Negligence',
    ),
    // Engineering 2024
    PastQuestionModel(
      id: 'eng_mech_2024_q1',
      examType: ExamCategory.engineering,
      subject: 'Engineering Mechanics',
      year: 2024,
      questionNumber: 1,
      prompt:
          'What is the moment of inertia I of a solid cylinder of mass '
          'M and radius R rotating about its central axis?',
      latexFormula: r'I = \frac{1}{2} M R^2',
      options: [
        'M R^2',
        r'\frac{1}{2} M R^2',
        r'\frac{2}{5} M R^2',
        r'\frac{1}{12} M R^2',
      ],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation: 'For a solid uniform cylinder, I = 0.5 * M * R^2.',
      topic: 'Rotational Dynamics',
    ),
    // Business 2024
    PastQuestionModel(
      id: 'bus_acc_2024_q1',
      examType: ExamCategory.business,
      subject: 'Financial Accounting',
      year: 2024,
      questionNumber: 1,
      prompt:
          'Under the fundamental accounting equation, which statement '
          'is always true?',
      options: [
        'Assets = Liabilities + Equity',
        'Assets = Liabilities - Equity',
        'Equity = Assets + Liabilities',
        'Net Income = Revenue + Expenses',
      ],
      correctOptionIndex: 0,
      correctOptionLabel: 'A',
      explanation:
          'The balance sheet is governed by Assets = Liabilities + Equity.',
      topic: 'Accounting Principles',
      difficulty: 'Easy',
    ),
    // Computer Science 2024
    PastQuestionModel(
      id: 'cs_algo_2024_q1',
      examType: ExamCategory.computerScience,
      subject: 'Data Structures & Algorithms',
      year: 2024,
      questionNumber: 1,
      prompt:
          'What is the worst-case time complexity of QuickSort when a '
          'deterministic first-element pivot is used on a sorted array?',
      options: ['O(N log N)', 'O(N)', 'O(N^2)', 'O(log N)'],
      correctOptionIndex: 2,
      correctOptionLabel: 'C',
      explanation:
          'First element pivot on sorted array leads to O(N^2) runtime.',
      topic: 'Sorting Algorithms & Asymptotic Analysis',
    ),
  ];
}
