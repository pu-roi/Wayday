import '../../errands/domain/errand.dart';
export '../../errands/domain/errand.dart';

enum TravelProfile {
  walk('Walking'),
  bike('Biking'),
  motor('Motorcycle'),
  sedan('Sedan'),
  truck('Truck');

  const TravelProfile(this.label);
  final String label;
}

class DayPlan {
  DayPlan({
    required List<Errand> errands,
    this.from = 'PLP',
    this.to = 'Home',
    this.departure = 510,
    this.deadline = 1080,
    this.profile = TravelProfile.motor,
  }) : errands = List.unmodifiable(errands);
  final List<Errand> errands;
  final String from;
  final String to;
  final int departure;
  final int deadline;
  final TravelProfile profile;
  DayPlan copyWith({
    List<Errand>? errands,
    String? from,
    String? to,
    int? departure,
    int? deadline,
    TravelProfile? profile,
  }) => DayPlan(
    errands: errands ?? this.errands,
    from: from ?? this.from,
    to: to ?? this.to,
    departure: departure ?? this.departure,
    deadline: deadline ?? this.deadline,
    profile: profile ?? this.profile,
  );
}
