import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

class QuickStartMockExamParams extends Equatable {
  const QuickStartMockExamParams({
    required this.examId,
    required this.subject,
  });

  final String examId;
  final String subject;

  @override
  List<Object?> get props => [examId, subject];
}

class QuickStartMockExamUseCase with UseCase<String, QuickStartMockExamParams> {
  const QuickStartMockExamUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, String>> call(QuickStartMockExamParams params) {
    return _repository.quickStartMockExam(
      examId: params.examId,
      subject: params.subject,
    );
  }
}
