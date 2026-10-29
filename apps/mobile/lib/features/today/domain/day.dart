import '../../errands/domain/errand.dart';
import '../../places/domain/place_intent.dart';
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
    this.from = '',
    this.to = '',
    this.departure = 510,
    this.deadline = 1080,
    this.profile = TravelProfile.motor,
    String? date,
    this.timeZone = 'Asia/Manila',
    this.revision = 0,
    PlaceIntent? fromPlace,
    PlaceIntent? toPlace,
  }) : errands = List.unmodifiable(errands),
       date = date ?? pilotToday(),
       fromPlace = fromPlace ?? PlaceIntent(label: from),
       toPlace = toPlace ?? PlaceIntent(label: to);
  final List<Errand> errands;
  final String from;
  final String to;
  final int departure;
  final int deadline;
  final TravelProfile profile;
  final String date;
  final String timeZone;
  final int revision;
  final PlaceIntent fromPlace;
  final PlaceIntent toPlace;
  DayPlan copyWith({
    List<Errand>? errands,
    String? from,
    String? to,
    int? departure,
    int? deadline,
    TravelProfile? profile,
    String? date,
    String? timeZone,
    int? revision,
    PlaceIntent? fromPlace,
    PlaceIntent? toPlace,
  }) => DayPlan(
    errands: errands ?? this.errands,
    from: from ?? this.from,
    to: to ?? this.to,
    departure: departure ?? this.departure,
    deadline: deadline ?? this.deadline,
    profile: profile ?? this.profile,
    date: date ?? this.date,
    timeZone: timeZone ?? this.timeZone,
    revision: revision ?? this.revision,
    fromPlace:
        fromPlace ?? (from != null ? PlaceIntent(label: from) : this.fromPlace),
    toPlace: toPlace ?? (to != null ? PlaceIntent(label: to) : this.toPlace),
  );

  Map<String, Object?> toJson() => {
    'errands': errands.map((e) => e.toJson()).toList(),
    'from': from,
    'to': to,
    'departure': departure,
    'deadline': deadline,
    'profile': profile.name,
    'date': date,
    'timeZone': timeZone,
    'revision': revision,
    'fromPlace': fromPlace.toJson(),
    'toPlace': toPlace.toJson(),
  };

  factory DayPlan.fromJson(
    Map<String, dynamic> json, {
    GooglePinResolver? resolveGooglePin,
  }) {
    final date = json['date'] as String;
    final parsedDate = DateTime.parse(date);
    final departure = json['departure'] as int;
    final deadline = json['deadline'] as int;
    if (calendarDate(parsedDate) != date ||
        departure < 0 ||
        deadline >= 1440 ||
        departure >= deadline ||
        json['timeZone'] != 'Asia/Manila') {
      throw const FormatException('Invalid day constraints');
    }
    return DayPlan(
      errands: (json['errands'] as List)
          .map(
            (e) => Errand.fromJson(
              e as Map<String, dynamic>,
              resolveGooglePin: resolveGooglePin,
            ),
          )
          .toList(),
      from: json['from'] as String,
      to: json['to'] as String,
      departure: departure,
      deadline: deadline,
      profile: TravelProfile.values.byName(json['profile'] as String),
      date: date,
      timeZone: json['timeZone'] as String,
      revision: json['revision'] as int,
      fromPlace: PlaceIntent.fromJson(
        json['fromPlace'] as Map<String, dynamic>,
        resolveGooglePin: resolveGooglePin,
      ),
      toPlace: PlaceIntent.fromJson(
        json['toPlace'] as Map<String, dynamic>,
        resolveGooglePin: resolveGooglePin,
      ),
    );
  }
}

String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String pilotToday([DateTime? instant]) => calendarDate(
  (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 8)),
);
