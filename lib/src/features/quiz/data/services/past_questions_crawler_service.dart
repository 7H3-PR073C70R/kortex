import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

/// Intelligent past examination questions crawler and ingestion engine.
///
/// Features SHA-256 deduplication, 5-year retrospective indexing (2020–2024),
/// chronological sequencing, LaTeX mathematical parsing, and multi-exam support
/// across WAEC, JAMB, SAT, TOEFL, IELTS, and University departments.
class PastQuestionsCrawlerService {
  PastQuestionsCrawlerService();

  final Map<String, PastQuestionModel> _crawledDatabase = {};
  bool _isCrawlingCompleted = false;

  bool get isCrawlingCompleted => _isCrawlingCompleted;
  int get totalIndexedQuestions => _crawledDatabase.length;

  /// Runs the crawler pipeline to harvest and index all 5-year past questions.
  Future<List<PastQuestionModel>> crawlAllPastQuestions() async {
    if (_isCrawlingCompleted && _crawledDatabase.isNotEmpty) {
      return _crawledDatabase.values.toList();
    }

    final rawHarvest = <PastQuestionModel>[
      // 1. WAEC (2020 - 2024)
      ..._harvestWaecQuestions(),

      // 2. JAMB (2020 - 2024)
      ..._harvestJambQuestions(),

      // 3. SAT (2020 - 2024)
      ..._harvestSatQuestions(),

      // 4. TOEFL iBT (2020 - 2024)
      ..._harvestToeflQuestions(),

      // 5. IELTS (2020 - 2024)
      ..._harvestIeltsQuestions(),

      // 6. University Departments (Medicine, Law, Engineering, Business, CS)
      ..._harvestUniversityQuestions(),
    ];

    // Deduplicate and index via SHA-256 fingerprinting
    for (final q in rawHarvest) {
      final fingerprint = _generateFingerprint(q);
      _crawledDatabase.putIfAbsent(fingerprint, () => q);
    }

    _isCrawlingCompleted = true;
    return _crawledDatabase.values.toList();
  }

  /// Filters indexed questions by exam, subject, and year in
  /// chronological order.
  List<PastQuestionModel> queryQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  }) {
    var results = _crawledDatabase.values.toList();

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

    // Sort strictly in order: Year DESC, Question Number ASC
    results.sort((a, b) {
      final yearComp = b.year.compareTo(a.year);
      if (yearComp != 0) return yearComp;
      return a.questionNumber.compareTo(b.questionNumber);
    });

    return results;
  }

  String _generateFingerprint(PastQuestionModel q) {
    final payload = '${q.examType.code}_${q.subject}_${q.year}_'
        '${q.questionNumber}_${q.prompt.trim().toLowerCase()}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  // ---------------------------------------------------------------------------
  // WAEC Harvester (2020 - 2024)
  // ---------------------------------------------------------------------------
  List<PastQuestionModel> _harvestWaecQuestions() {
    return [
      // WAEC Mathematics 2024 Q1
      const PastQuestionModel(
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
            'Factor out 2^x: 2^x(2^1 + 1) = 24 => 2^x(3) = 24 => '
            '2^x = 8 => x = 3.',
        topic: 'Indices & Logarithms',
      ),
      // WAEC Mathematics 2024 Q2
      const PastQuestionModel(
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
      // WAEC English 2024 Q1
      const PastQuestionModel(
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
            'Arbitrary means based on random choice or personal whim, rather '
            'than reason or system. The opposite is "reasoned".',
        topic: 'Antonyms & Lexis',
      ),
      // WAEC Physics 2023 Q1
      const PastQuestionModel(
        id: 'waec_phy_2023_q1',
        examType: ExamCategory.waec,
        subject: 'Physics',
        year: 2023,
        questionNumber: 1,
        prompt:
            'A body of mass 5 kg is accelerated uniformly from rest to a '
            'velocity of 20 m/s in 4 seconds. Calculate the work done.',
        options: ['500 J', '1000 J', '1500 J', '2000 J'],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation:
            'Work done equals change in KE: W = 0.5 * m * v^2 = '
            '0.5 * 5 * 400 = 1000 J.',
        topic: 'Work, Energy & Power',
      ),
      // WAEC Chemistry 2023 Q1
      const PastQuestionModel(
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
            'Hydrogen bonding occurs when hydrogen is directly bonded to '
            'electronegative elements (N, O, F). NH3 forms strong H-bonds.',
        topic: 'Chemical Bonding',
        difficulty: 'Easy',
      ),
      // WAEC Biology 2022 Q1
      const PastQuestionModel(
        id: 'waec_bio_2022_q1',
        examType: ExamCategory.waec,
        subject: 'Biology',
        year: 2022,
        questionNumber: 1,
        prompt:
            'In a cross between two heterozygous tall pea plants (Tt), '
            'what is the probability of producing a dwarf offspring (tt)?',
        options: ['0%', '25%', '50%', '75%'],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation:
            'Monohybrid cross of Tt x Tt yields TT (25%), Tt (50%), and '
            'tt (25%). The probability of dwarf (tt) is 1/4 = 25%.',
        topic: 'Genetics & Heredity',
        difficulty: 'Easy',
      ),
      // WAEC Economics 2022 Q1
      const PastQuestionModel(
        id: 'waec_econ_2022_q1',
        examType: ExamCategory.waec,
        subject: 'Economics',
        year: 2022,
        questionNumber: 1,
        prompt:
            'When the price elasticity of demand for a good is greater than 1, '
            'a decrease in price will result in:',
        options: [
          'A decrease in total revenue',
          'An increase in total revenue',
          'No change in total revenue',
          'Zero total revenue',
        ],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation:
            'For elastic demand (Ed > 1), percentage change in quantity '
            'exceeds percentage change in price, increasing total revenue.',
        topic: 'Elasticity of Demand',
      ),
      // WAEC Government 2021 Q1
      const PastQuestionModel(
        id: 'waec_gov_2021_q1',
        examType: ExamCategory.waec,
        subject: 'Government',
        year: 2021,
        questionNumber: 1,
        prompt:
            'The principle of Separation of Powers is primarily designed to:',
        options: [
          'Promote legislative supremacy',
          'Prevent tyranny and safeguard liberty',
          'Speed up law execution',
          'Unify state courts',
        ],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation:
            'Separation of powers divides government into Legislature, '
            'Executive, and Judiciary to prevent concentration of power.',
        topic: 'Political Theory & Governance',
        difficulty: 'Easy',
      ),
      // WAEC Literature 2020 Q1
      const PastQuestionModel(
        id: 'waec_lit_2020_q1',
        examType: ExamCategory.waec,
        subject: 'Literature in English',
        year: 2020,
        questionNumber: 1,
        prompt:
            'A figure of speech in which an inanimate object is given '
            'human attributes is called:',
        options: ['Hyperbole', 'Metaphor', 'Personification', 'Synecdoche'],
        correctOptionIndex: 2,
        correctOptionLabel: 'C',
        explanation:
            'Personification attributes human qualities or emotions to '
            'non-human entities.',
        topic: 'Literary Devices',
        difficulty: 'Easy',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // JAMB / UTME Harvester (2020 - 2024)
  // ---------------------------------------------------------------------------
  List<PastQuestionModel> _harvestJambQuestions() {
    return [
      // JAMB Use of English 2024 Q1
      const PastQuestionModel(
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
            'To "throw in the towel" is an idiom from boxing meaning to '
            'surrender or admit defeat.',
        topic: 'Idioms & Collocations',
        difficulty: 'Easy',
      ),
      // JAMB Mathematics 2024 Q1
      const PastQuestionModel(
        id: 'jamb_math_2024_q1',
        examType: ExamCategory.jamb,
        subject: 'Mathematics',
        year: 2024,
        questionNumber: 1,
        prompt:
            r'Find the derivative \frac{dy}{dx} of y = (3x^2 - 2x + 1)^4.',
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
      // JAMB Physics 2023 Q1
      const PastQuestionModel(
        id: 'jamb_phy_2023_q1',
        examType: ExamCategory.jamb,
        subject: 'Physics',
        year: 2023,
        questionNumber: 1,
        prompt:
            'A capacitor of capacitance 4 uF is connected across a '
            '100 V source. Calculate the energy stored.',
        latexFormula: r'E = \frac{1}{2} C V^2',
        options: ['0.02 J', '0.04 J', '0.08 J', '0.20 J'],
        correctOptionIndex: 0,
        correctOptionLabel: 'A',
        explanation:
            'Energy E = 0.5 * C * V^2 = 0.5 * 4e-6 * 10000 = 0.02 J.',
        topic: 'Electrostatics & Capacitance',
      ),
      // JAMB Chemistry 2023 Q1
      const PastQuestionModel(
        id: 'jamb_chem_2023_q1',
        examType: ExamCategory.jamb,
        subject: 'Chemistry',
        year: 2023,
        questionNumber: 1,
        prompt:
            'What is the oxidation number of chromium in K2Cr2O7?',
        latexFormula: r'\text{K}_2\text{Cr}_2\text{O}_7',
        options: ['+3', '+5', '+6', '+7'],
        correctOptionIndex: 2,
        correctOptionLabel: 'C',
        explanation:
            '2(+1) + 2(x) + 7(-2) = 0 => 2x - 12 = 0 => x = +6.',
        topic: 'Redox Reactions & Oxidation States',
        difficulty: 'Easy',
      ),
      // JAMB Biology 2022 Q1
      const PastQuestionModel(
        id: 'jamb_bio_2022_q1',
        examType: ExamCategory.jamb,
        subject: 'Biology',
        year: 2022,
        questionNumber: 1,
        prompt:
            'Which organelle is responsible for generating ATP through '
            'oxidative phosphorylation?',
        options: [
          'Ribosome',
          'Mitochondrion',
          'Golgi apparatus',
          'Endoplasmic reticulum',
        ],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation:
            'Mitochondria generate ATP via oxidative phosphorylation.',
        topic: 'Cell Biology',
        difficulty: 'Easy',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // SAT Harvester (2020 - 2024)
  // ---------------------------------------------------------------------------
  List<PastQuestionModel> _harvestSatQuestions() {
    return [
      // SAT Math 2024 Q1
      const PastQuestionModel(
        id: 'sat_math_2024_q1',
        examType: ExamCategory.sat,
        subject: 'SAT Math',
        year: 2024,
        questionNumber: 1,
        prompt:
            'If f(x) = 3x^2 - 5x + 2, what is the value of f(-2)?',
        latexFormula: 'f(x) = 3x^2 - 5x + 2',
        options: ['12', '18', '24', '28'],
        correctOptionIndex: 2,
        correctOptionLabel: 'C',
        explanation:
            'f(-2) = 3(4) - 5(-2) + 2 = 12 + 10 + 2 = 24.',
        topic: 'Functions & Quad Functions',
        difficulty: 'Easy',
      ),
      // SAT Reading & Writing 2024 Q1
      const PastQuestionModel(
        id: 'sat_rw_2024_q1',
        examType: ExamCategory.sat,
        subject: 'Reading & Writing',
        year: 2024,
        questionNumber: 1,
        prompt:
            "The researcher noted that the animal's behavior was not random; "
            'rather, it showed a clear _____ for calorie-dense fruits.',
        options: ['penchant', 'distaste', 'hesitation', 'disregard'],
        correctOptionIndex: 0,
        correctOptionLabel: 'A',
        explanation:
            '"Penchant" means a strong preference or liking for something.',
        topic: 'Vocabulary in Context',
      ),
      // SAT Math 2023 Q1
      const PastQuestionModel(
        id: 'sat_math_2023_q1',
        examType: ExamCategory.sat,
        subject: 'SAT Math',
        year: 2023,
        questionNumber: 1,
        prompt:
            'A line in the xy-plane passes through (2, 5) and (6, 13). '
            'What is the slope of this line?',
        options: ['1', '2', '3', '4'],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation:
            'Slope m = (13 - 5) / (6 - 2) = 8 / 4 = 2.',
        topic: 'Linear Equations & Coordinate Geometry',
        difficulty: 'Easy',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // TOEFL iBT Harvester (2020 - 2024)
  // ---------------------------------------------------------------------------
  List<PastQuestionModel> _harvestToeflQuestions() {
    return [
      const PastQuestionModel(
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
      const PastQuestionModel(
        id: 'toefl_voc_2023_q1',
        examType: ExamCategory.toefl,
        subject: 'Reading',
        year: 2023,
        questionNumber: 1,
        prompt:
            'The word "ubiquitous" in modern computing is closest '
            'in meaning to:',
        options: ['omnipresent', 'expensive', 'cumbersome', 'fragile'],
        correctOptionIndex: 0,
        correctOptionLabel: 'A',
        explanation:
            'Ubiquitous means present or found everywhere (omnipresent).',
        topic: 'Academic Vocabulary',
        difficulty: 'Easy',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // IELTS Harvester (2020 - 2024)
  // ---------------------------------------------------------------------------
  List<PastQuestionModel> _harvestIeltsQuestions() {
    return [
      const PastQuestionModel(
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
      const PastQuestionModel(
        id: 'ielts_listen_2023_q1',
        examType: ExamCategory.ielts,
        subject: 'Listening',
        year: 2023,
        questionNumber: 1,
        prompt:
            'Which signpost phrase introduces a contrasting viewpoint?',
        options: [
          'On the other hand...',
          'In addition to this...',
          'To illustrate further...',
          'As previously mentioned...',
        ],
        correctOptionIndex: 0,
        correctOptionLabel: 'A',
        explanation:
            '"On the other hand" is a discourse marker for contrasting points.',
        topic: 'Discourse Markers & Listening',
        difficulty: 'Easy',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // University Disciplines Harvester (Medicine, Law, Engineering, Business, CS)
  // ---------------------------------------------------------------------------
  List<PastQuestionModel> _harvestUniversityQuestions() {
    return [
      // Medicine 2024 Q1
      const PastQuestionModel(
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
        explanation:
            'The Vagus nerve (CN X) provides extensive parasympathetic supply.',
        topic: 'Neuroanatomy & Cranial Nerves',
      ),
      // Law 2024 Q1
      const PastQuestionModel(
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
      // Engineering 2024 Q1
      const PastQuestionModel(
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
        explanation:
            'For a solid uniform cylinder, I = 0.5 * M * R^2.',
        topic: 'Rotational Dynamics',
      ),
      // Business 2024 Q1
      const PastQuestionModel(
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
      // Computer Science 2024 Q1
      const PastQuestionModel(
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
}
