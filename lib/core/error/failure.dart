import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Something went wrong on the network / backend side (the e-commerce
/// Supabase link). [message] carries a localization key, never a raw
/// database error, so it can be shown to a customer as-is.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}
