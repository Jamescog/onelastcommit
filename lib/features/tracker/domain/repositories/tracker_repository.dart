import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/commit_event.dart';

abstract class TrackerRepository {
  Future<Either<Failure, List<CommitEvent>>> getCommitHistory();
  Future<Either<Failure, void>> refreshCommits();
  Future<Either<Failure, bool>> hasActivityToday();
}
