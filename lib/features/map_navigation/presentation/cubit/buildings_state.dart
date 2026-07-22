import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/site.dart';

sealed class BuildingsState extends Equatable {
  const BuildingsState();

  @override
  List<Object?> get props => [];
}

class BuildingsLoading extends BuildingsState {
  const BuildingsLoading();
}

class BuildingsLoaded extends BuildingsState {
  const BuildingsLoaded(this.site);

  final SiteEntity site;

  @override
  List<Object?> get props => [site];
}

class BuildingsNotFound extends BuildingsState {
  const BuildingsNotFound();
}

class BuildingsError extends BuildingsState {
  const BuildingsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
