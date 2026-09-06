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

@DataClassName('ExamEventEntry')
class ExamEvents extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('current-user'))();
  TextColumn get examName => text()();
  DateTimeColumn get targetDate => dateTime()();
  TextColumn get subjectTrack =>
      text().withDefault(const Constant('General'))();
  IntColumn get totalCardsCount => integer().withDefault(const Constant(0))();
  IntColumn get masteredCardsCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalLapses => integer().withDefault(const Constant(0))();
  IntColumn get dailyTarget => integer().withDefault(const Constant(20))();
  RealColumn get targetScorePercent =>
      real().withDefault(const Constant(0.85))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ForumPostEntry')
class ForumPosts extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  TextColumn get authorAvatar => text().nullable()();
  TextColumn get track => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get latexContent => text().nullable()();
  IntColumn get upvotes => integer().withDefault(const Constant(0))();
  IntColumn get repliesCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ForumReplyEntry')
class ForumReplies extends Table {
  TextColumn get id => text()();
  TextColumn get postId =>
      text().references(ForumPosts, #id, onDelete: KeyAction.cascade)();
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  TextColumn get authorAvatar => text().nullable()();
  TextColumn get content => text()();
  TextColumn get latexContent => text().nullable()();
  IntColumn get upvotes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyllabotSessionEntry')
class SyllabotSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('current-user'))();
  TextColumn get title => text()();
  TextColumn get socraticMode =>
      text().withDefault(const Constant('stepByStep'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyllabotMessageEntry')
class SyllabotMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(SyllabotSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text().withDefault(const Constant('current-user'))();
  TextColumn get sender => text()();
  TextColumn get textContent => text()();
  TextColumn get latexSnippets => text().nullable()();
  TextColumn get engineType =>
      text().withDefault(const Constant('cloudRemote'))();
  IntColumn get tokensCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
