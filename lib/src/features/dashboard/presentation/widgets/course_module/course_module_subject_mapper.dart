import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class CourseModuleSubjectMapper {
  const CourseModuleSubjectMapper._();

  static String cleanCode(String code) {
    return code
        .replaceFirst(RegExp('^[WJN]-', caseSensitive: false), '')
        .trim();
  }

  static ExamCategory getExamCategory({
    required String? track,
    required String courseTitle,
    required String courseCode,
  }) {
    final t = (track ?? '').toUpperCase();
    if (t.contains('JAMB') || t.contains('UTME')) return ExamCategory.jamb;
    if (t.contains('NECO') || t.contains('SSCE')) return ExamCategory.neco;
    if (t.contains('SAT')) return ExamCategory.sat;
    if (t.contains('TOEFL')) return ExamCategory.toefl;
    if (t.contains('IELTS')) return ExamCategory.ielts;
    if (t.contains('MEDICINE') ||
        t.contains('HEALTH') ||
        t.contains('MBBS') ||
        t.contains('NURS')) {
      return ExamCategory.medicine;
    }
    if (t.contains('LAW') || t.contains('JURIS')) {
      return ExamCategory.law;
    }
    if (t.contains('ENGINEERING')) {
      return ExamCategory.engineering;
    }
    if (t.contains('COMPUTER') || t.contains('SOFTWARE')) {
      return ExamCategory.computerScience;
    }
    if (t.contains('BUSINESS') || t.contains('FINANCE')) {
      return ExamCategory.business;
    }
    if (t.contains('WAEC') || t.contains('WASSCE')) {
      return ExamCategory.waec;
    }

    // Check courseTitle and courseCode for curriculum clues if track was generic/unset
    final cTitle = '$courseTitle $courseCode'.toUpperCase();
    if (cTitle.contains('CSC') ||
        cTitle.contains('COMP') ||
        cTitle.contains('SOFTWARE')) {
      return ExamCategory.computerScience;
    }
    if (cTitle.contains('ENGR') ||
        cTitle.contains('MECH') ||
        cTitle.contains('ELEC') ||
        cTitle.contains('CIVIL')) {
      return ExamCategory.engineering;
    }
    if (cTitle.contains('MED') ||
        cTitle.contains('ANAT') ||
        cTitle.contains('PHARM') ||
        cTitle.contains('PATH')) {
      return ExamCategory.medicine;
    }
    if (cTitle.contains('LAW') || cTitle.contains('JUR')) {
      return ExamCategory.law;
    }
    if (cTitle.contains('BUS') ||
        cTitle.contains('ACC') ||
        cTitle.contains('FIN') ||
        cTitle.contains('MKT')) {
      return ExamCategory.business;
    }

    return ExamCategory.general;
  }

  static String mapCourseToSubject(String title, String code) {
    final c = cleanCode(code).toUpperCase();
    final lower = '$title $code'.toLowerCase();

    // Secondary WAEC/JAMB specific subjects
    if (c == 'LIT' || lower.contains('literature')) {
      return 'Literature in English';
    }
    if (c == 'FMTH' || lower.contains('further math')) {
      return 'Further Mathematics';
    }
    if (c == 'MTH' || lower.contains('math')) {
      return 'Mathematics';
    }
    if ((c == 'ENG' && !code.contains(RegExp(r'\d'))) ||
        lower.contains('english language')) {
      return 'English Language';
    }
    if (c == 'BIO' || lower.contains('biology')) {
      return 'Biology';
    }
    if (c == 'CHM' || lower.contains('chemistry')) {
      return 'Chemistry';
    }
    if (c == 'PHY' || lower.contains('physics')) {
      return 'Physics';
    }
    if (c == 'ECN' || lower.contains('economics')) {
      return 'Economics';
    }
    if (c == 'GOV' || lower.contains('government')) {
      return 'Government';
    }
    if (c == 'ACC' || lower.contains('accounting')) {
      return 'Principles of Accounts';
    }
    if (c == 'COM' || lower.contains('commerce')) {
      return 'Commerce';
    }
    if (c == 'GEO' || lower.contains('geography')) {
      return 'Geography';
    }
    if (c == 'AGR' || lower.contains('agric')) {
      return 'Agricultural Science';
    }
    if (c == 'CIV' || lower.contains('civic')) {
      return 'Civic Education';
    }
    if (c == 'DPR' || lower.contains('data processing')) {
      return 'Data Processing';
    }
    if (c == 'CMP' ||
        lower.contains('computer science') ||
        lower.contains('computer studies')) {
      return 'Computer Science';
    }
    if (c == 'CRK' || lower.contains('crk') || lower.contains('christian')) {
      return 'Christian Religious Knowledge (CRK)';
    }
    if (c == 'IRK' || lower.contains('irk') || lower.contains('islamic')) {
      return 'Islamic Religious Knowledge (IRK)';
    }

    return title.split('(').first.trim();
  }
}
