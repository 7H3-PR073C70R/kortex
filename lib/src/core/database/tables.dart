import 'package:drift/drift.dart';

@DataClassName('DeckEntry')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get subject => text().withDefault(const Constant('General'))();
  TextColumn get category => text().withDefault(const Constant('General'))();
  IntColumn get totalCards => integer().withDefault(const Constant(0))();
  IntColumn get dueCards => integer().withDefault(const Constant(0))();
  RealColumn get masteryRate => real().withDefault(const Constant(0))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get lastStudied => dateTime().nullable()();
  TextColumn get colorHex => text().nullable()();
  TextColumn get iconName => text().nullable()();
  TextColumn get courseId => text().nullable()();
  TextColumn get courseCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FlashcardEntry')
class Flashcards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId =>
      text().references(Decks, #id, onDelete: KeyAction.cascade)();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get frontLatex => text().nullable()();
  TextColumn get backLatex => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  TextColumn get sourceTopic => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FsrsReviewLogEntry')
class FsrsReviewLogs extends Table {
  TextColumn get id => text()();
  TextColumn get transactionUuid => text().unique()();
  TextColumn get cardId => text()();
  IntColumn get rating => integer()();
  RealColumn get stability => real()();
  RealColumn get difficulty => real()();
  IntColumn get elapsedDays => integer()();
  IntColumn get scheduledDays => integer()();
  DateTimeColumn get reviewedAtUtc => dateTime()();
  IntColumn get reviewedAtEpoch => integer()();
  IntColumn get state => integer()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PastQuestionEntry')
class PastQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get examType => text()();
  TextColumn get subject => text()();
  IntColumn get year => integer()();
  IntColumn get questionNumber => integer()();
  TextColumn get prompt => text()();
  TextColumn get optionsJson => text()();
  IntColumn get correctOptionIndex =>
      integer().withDefault(const Constant(0))();
  TextColumn get correctOptionLabel =>
      text().withDefault(const Constant('A'))();
  TextColumn get explanation => text().withDefault(const Constant(''))();
  TextColumn get topic => text().withDefault(const Constant('General'))();
  TextColumn get passage => text().nullable()();
  TextColumn get latexFormula => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get difficulty => text().withDefault(const Constant('Medium'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CourseModuleEntry')
class CourseModules extends Table {
  TextColumn get id => text()();
  TextColumn get courseCode => text()();
  TextColumn get title => text()();
  TextColumn get department => text()();
  IntColumn get totalMaterials => integer().withDefault(const Constant(0))();
  BoolColumn get hasActivePastPapers =>
      boolean().withDefault(const Constant(false))();
  TextColumn get iconName => text().withDefault(const Constant('menu_book'))();
  TextColumn get colorHex => text().withDefault(const Constant('#2563EB'))();
  TextColumn get pdfDownloadUrl => text().nullable()();
  RealColumn get syllabusCoverage =>
      real().withDefault(const Constant(0.75))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
