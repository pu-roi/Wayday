// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wayday_database.dart';

// ignore_for_file: type=lint
class $DaySettingsTable extends DaySettings
    with TableInfo<$DaySettingsTable, DaySettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DaySettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromPlaceMeta = const VerificationMeta(
    'fromPlace',
  );
  @override
  late final GeneratedColumn<String> fromPlace = GeneratedColumn<String>(
    'from_place',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toPlaceMeta = const VerificationMeta(
    'toPlace',
  );
  @override
  late final GeneratedColumn<String> toPlace = GeneratedColumn<String>(
    'to_place',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _departureMeta = const VerificationMeta(
    'departure',
  );
  @override
  late final GeneratedColumn<int> departure = GeneratedColumn<int>(
    'departure',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<int> deadline = GeneratedColumn<int>(
    'deadline',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileMeta = const VerificationMeta(
    'profile',
  );
  @override
  late final GeneratedColumn<String> profile = GeneratedColumn<String>(
    'profile',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeDetailsMeta = const VerificationMeta(
    'placeDetails',
  );
  @override
  late final GeneratedColumn<String> placeDetails = GeneratedColumn<String>(
    'place_details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fromPlace,
    toPlace,
    departure,
    deadline,
    profile,
    placeDetails,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DaySettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('from_place')) {
      context.handle(
        _fromPlaceMeta,
        fromPlace.isAcceptableOrUnknown(data['from_place']!, _fromPlaceMeta),
      );
    } else if (isInserting) {
      context.missing(_fromPlaceMeta);
    }
    if (data.containsKey('to_place')) {
      context.handle(
        _toPlaceMeta,
        toPlace.isAcceptableOrUnknown(data['to_place']!, _toPlaceMeta),
      );
    } else if (isInserting) {
      context.missing(_toPlaceMeta);
    }
    if (data.containsKey('departure')) {
      context.handle(
        _departureMeta,
        departure.isAcceptableOrUnknown(data['departure']!, _departureMeta),
      );
    } else if (isInserting) {
      context.missing(_departureMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    } else if (isInserting) {
      context.missing(_deadlineMeta);
    }
    if (data.containsKey('profile')) {
      context.handle(
        _profileMeta,
        profile.isAcceptableOrUnknown(data['profile']!, _profileMeta),
      );
    } else if (isInserting) {
      context.missing(_profileMeta);
    }
    if (data.containsKey('place_details')) {
      context.handle(
        _placeDetailsMeta,
        placeDetails.isAcceptableOrUnknown(
          data['place_details']!,
          _placeDetailsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DaySettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DaySettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fromPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_place'],
      )!,
      toPlace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_place'],
      )!,
      departure: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}departure'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deadline'],
      )!,
      profile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile'],
      )!,
      placeDetails: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_details'],
      ),
    );
  }

  @override
  $DaySettingsTable createAlias(String alias) {
    return $DaySettingsTable(attachedDatabase, alias);
  }
}

class DaySettingsRow extends DataClass implements Insertable<DaySettingsRow> {
  final int id;
  final String fromPlace;
  final String toPlace;
  final int departure;
  final int deadline;
  final String profile;
  final String? placeDetails;
  const DaySettingsRow({
    required this.id,
    required this.fromPlace,
    required this.toPlace,
    required this.departure,
    required this.deadline,
    required this.profile,
    this.placeDetails,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['from_place'] = Variable<String>(fromPlace);
    map['to_place'] = Variable<String>(toPlace);
    map['departure'] = Variable<int>(departure);
    map['deadline'] = Variable<int>(deadline);
    map['profile'] = Variable<String>(profile);
    if (!nullToAbsent || placeDetails != null) {
      map['place_details'] = Variable<String>(placeDetails);
    }
    return map;
  }

  DaySettingsCompanion toCompanion(bool nullToAbsent) {
    return DaySettingsCompanion(
      id: Value(id),
      fromPlace: Value(fromPlace),
      toPlace: Value(toPlace),
      departure: Value(departure),
      deadline: Value(deadline),
      profile: Value(profile),
      placeDetails: placeDetails == null && nullToAbsent
          ? const Value.absent()
          : Value(placeDetails),
    );
  }

  factory DaySettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DaySettingsRow(
      id: serializer.fromJson<int>(json['id']),
      fromPlace: serializer.fromJson<String>(json['fromPlace']),
      toPlace: serializer.fromJson<String>(json['toPlace']),
      departure: serializer.fromJson<int>(json['departure']),
      deadline: serializer.fromJson<int>(json['deadline']),
      profile: serializer.fromJson<String>(json['profile']),
      placeDetails: serializer.fromJson<String?>(json['placeDetails']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fromPlace': serializer.toJson<String>(fromPlace),
      'toPlace': serializer.toJson<String>(toPlace),
      'departure': serializer.toJson<int>(departure),
      'deadline': serializer.toJson<int>(deadline),
      'profile': serializer.toJson<String>(profile),
      'placeDetails': serializer.toJson<String?>(placeDetails),
    };
  }

  DaySettingsRow copyWith({
    int? id,
    String? fromPlace,
    String? toPlace,
    int? departure,
    int? deadline,
    String? profile,
    Value<String?> placeDetails = const Value.absent(),
  }) => DaySettingsRow(
    id: id ?? this.id,
    fromPlace: fromPlace ?? this.fromPlace,
    toPlace: toPlace ?? this.toPlace,
    departure: departure ?? this.departure,
    deadline: deadline ?? this.deadline,
    profile: profile ?? this.profile,
    placeDetails: placeDetails.present ? placeDetails.value : this.placeDetails,
  );
  DaySettingsRow copyWithCompanion(DaySettingsCompanion data) {
    return DaySettingsRow(
      id: data.id.present ? data.id.value : this.id,
      fromPlace: data.fromPlace.present ? data.fromPlace.value : this.fromPlace,
      toPlace: data.toPlace.present ? data.toPlace.value : this.toPlace,
      departure: data.departure.present ? data.departure.value : this.departure,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      profile: data.profile.present ? data.profile.value : this.profile,
      placeDetails: data.placeDetails.present
          ? data.placeDetails.value
          : this.placeDetails,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DaySettingsRow(')
          ..write('id: $id, ')
          ..write('fromPlace: $fromPlace, ')
          ..write('toPlace: $toPlace, ')
          ..write('departure: $departure, ')
          ..write('deadline: $deadline, ')
          ..write('profile: $profile, ')
          ..write('placeDetails: $placeDetails')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fromPlace,
    toPlace,
    departure,
    deadline,
    profile,
    placeDetails,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DaySettingsRow &&
          other.id == this.id &&
          other.fromPlace == this.fromPlace &&
          other.toPlace == this.toPlace &&
          other.departure == this.departure &&
          other.deadline == this.deadline &&
          other.profile == this.profile &&
          other.placeDetails == this.placeDetails);
}

class DaySettingsCompanion extends UpdateCompanion<DaySettingsRow> {
  final Value<int> id;
  final Value<String> fromPlace;
  final Value<String> toPlace;
  final Value<int> departure;
  final Value<int> deadline;
  final Value<String> profile;
  final Value<String?> placeDetails;
  const DaySettingsCompanion({
    this.id = const Value.absent(),
    this.fromPlace = const Value.absent(),
    this.toPlace = const Value.absent(),
    this.departure = const Value.absent(),
    this.deadline = const Value.absent(),
    this.profile = const Value.absent(),
    this.placeDetails = const Value.absent(),
  });
  DaySettingsCompanion.insert({
    this.id = const Value.absent(),
    required String fromPlace,
    required String toPlace,
    required int departure,
    required int deadline,
    required String profile,
    this.placeDetails = const Value.absent(),
  }) : fromPlace = Value(fromPlace),
       toPlace = Value(toPlace),
       departure = Value(departure),
       deadline = Value(deadline),
       profile = Value(profile);
  static Insertable<DaySettingsRow> custom({
    Expression<int>? id,
    Expression<String>? fromPlace,
    Expression<String>? toPlace,
    Expression<int>? departure,
    Expression<int>? deadline,
    Expression<String>? profile,
    Expression<String>? placeDetails,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromPlace != null) 'from_place': fromPlace,
      if (toPlace != null) 'to_place': toPlace,
      if (departure != null) 'departure': departure,
      if (deadline != null) 'deadline': deadline,
      if (profile != null) 'profile': profile,
      if (placeDetails != null) 'place_details': placeDetails,
    });
  }

  DaySettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? fromPlace,
    Value<String>? toPlace,
    Value<int>? departure,
    Value<int>? deadline,
    Value<String>? profile,
    Value<String?>? placeDetails,
  }) {
    return DaySettingsCompanion(
      id: id ?? this.id,
      fromPlace: fromPlace ?? this.fromPlace,
      toPlace: toPlace ?? this.toPlace,
      departure: departure ?? this.departure,
      deadline: deadline ?? this.deadline,
      profile: profile ?? this.profile,
      placeDetails: placeDetails ?? this.placeDetails,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fromPlace.present) {
      map['from_place'] = Variable<String>(fromPlace.value);
    }
    if (toPlace.present) {
      map['to_place'] = Variable<String>(toPlace.value);
    }
    if (departure.present) {
      map['departure'] = Variable<int>(departure.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<int>(deadline.value);
    }
    if (profile.present) {
      map['profile'] = Variable<String>(profile.value);
    }
    if (placeDetails.present) {
      map['place_details'] = Variable<String>(placeDetails.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DaySettingsCompanion(')
          ..write('id: $id, ')
          ..write('fromPlace: $fromPlace, ')
          ..write('toPlace: $toPlace, ')
          ..write('departure: $departure, ')
          ..write('deadline: $deadline, ')
          ..write('profile: $profile, ')
          ..write('placeDetails: $placeDetails')
          ..write(')'))
        .toString();
  }
}

class $DayErrandsTable extends DayErrands
    with TableInfo<$DayErrandsTable, DayErrandRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayErrandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timingMeta = const VerificationMeta('timing');
  @override
  late final GeneratedColumn<String> timing = GeneratedColumn<String>(
    'timing',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionalMeta = const VerificationMeta(
    'optional',
  );
  @override
  late final GeneratedColumn<bool> optional = GeneratedColumn<bool>(
    'optional',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("optional" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sourceGroupIdMeta = const VerificationMeta(
    'sourceGroupId',
  );
  @override
  late final GeneratedColumn<String> sourceGroupId = GeneratedColumn<String>(
    'source_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceItemIdMeta = const VerificationMeta(
    'sourceItemId',
  );
  @override
  late final GeneratedColumn<String> sourceItemId = GeneratedColumn<String>(
    'source_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    position,
    title,
    place,
    notes,
    timing,
    minute,
    optional,
    sourceGroupId,
    sourceItemId,
    details,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_errands';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayErrandRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    } else if (isInserting) {
      context.missing(_placeMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('timing')) {
      context.handle(
        _timingMeta,
        timing.isAcceptableOrUnknown(data['timing']!, _timingMeta),
      );
    } else if (isInserting) {
      context.missing(_timingMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    }
    if (data.containsKey('optional')) {
      context.handle(
        _optionalMeta,
        optional.isAcceptableOrUnknown(data['optional']!, _optionalMeta),
      );
    } else if (isInserting) {
      context.missing(_optionalMeta);
    }
    if (data.containsKey('source_group_id')) {
      context.handle(
        _sourceGroupIdMeta,
        sourceGroupId.isAcceptableOrUnknown(
          data['source_group_id']!,
          _sourceGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('source_item_id')) {
      context.handle(
        _sourceItemIdMeta,
        sourceItemId.isAcceptableOrUnknown(
          data['source_item_id']!,
          _sourceItemIdMeta,
        ),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayErrandRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayErrandRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      timing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timing'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      ),
      optional: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}optional'],
      )!,
      sourceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_group_id'],
      ),
      sourceItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_item_id'],
      ),
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
    );
  }

  @override
  $DayErrandsTable createAlias(String alias) {
    return $DayErrandsTable(attachedDatabase, alias);
  }
}

class DayErrandRow extends DataClass implements Insertable<DayErrandRow> {
  final String id;
  final int position;
  final String title;
  final String place;
  final String notes;
  final String timing;
  final int? minute;
  final bool optional;
  final String? sourceGroupId;
  final String? sourceItemId;
  final String? details;
  const DayErrandRow({
    required this.id,
    required this.position,
    required this.title,
    required this.place,
    required this.notes,
    required this.timing,
    this.minute,
    required this.optional,
    this.sourceGroupId,
    this.sourceItemId,
    this.details,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['title'] = Variable<String>(title);
    map['place'] = Variable<String>(place);
    map['notes'] = Variable<String>(notes);
    map['timing'] = Variable<String>(timing);
    if (!nullToAbsent || minute != null) {
      map['minute'] = Variable<int>(minute);
    }
    map['optional'] = Variable<bool>(optional);
    if (!nullToAbsent || sourceGroupId != null) {
      map['source_group_id'] = Variable<String>(sourceGroupId);
    }
    if (!nullToAbsent || sourceItemId != null) {
      map['source_item_id'] = Variable<String>(sourceItemId);
    }
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    return map;
  }

  DayErrandsCompanion toCompanion(bool nullToAbsent) {
    return DayErrandsCompanion(
      id: Value(id),
      position: Value(position),
      title: Value(title),
      place: Value(place),
      notes: Value(notes),
      timing: Value(timing),
      minute: minute == null && nullToAbsent
          ? const Value.absent()
          : Value(minute),
      optional: Value(optional),
      sourceGroupId: sourceGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceGroupId),
      sourceItemId: sourceItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceItemId),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
    );
  }

  factory DayErrandRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayErrandRow(
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      title: serializer.fromJson<String>(json['title']),
      place: serializer.fromJson<String>(json['place']),
      notes: serializer.fromJson<String>(json['notes']),
      timing: serializer.fromJson<String>(json['timing']),
      minute: serializer.fromJson<int?>(json['minute']),
      optional: serializer.fromJson<bool>(json['optional']),
      sourceGroupId: serializer.fromJson<String?>(json['sourceGroupId']),
      sourceItemId: serializer.fromJson<String?>(json['sourceItemId']),
      details: serializer.fromJson<String?>(json['details']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'title': serializer.toJson<String>(title),
      'place': serializer.toJson<String>(place),
      'notes': serializer.toJson<String>(notes),
      'timing': serializer.toJson<String>(timing),
      'minute': serializer.toJson<int?>(minute),
      'optional': serializer.toJson<bool>(optional),
      'sourceGroupId': serializer.toJson<String?>(sourceGroupId),
      'sourceItemId': serializer.toJson<String?>(sourceItemId),
      'details': serializer.toJson<String?>(details),
    };
  }

  DayErrandRow copyWith({
    String? id,
    int? position,
    String? title,
    String? place,
    String? notes,
    String? timing,
    Value<int?> minute = const Value.absent(),
    bool? optional,
    Value<String?> sourceGroupId = const Value.absent(),
    Value<String?> sourceItemId = const Value.absent(),
    Value<String?> details = const Value.absent(),
  }) => DayErrandRow(
    id: id ?? this.id,
    position: position ?? this.position,
    title: title ?? this.title,
    place: place ?? this.place,
    notes: notes ?? this.notes,
    timing: timing ?? this.timing,
    minute: minute.present ? minute.value : this.minute,
    optional: optional ?? this.optional,
    sourceGroupId: sourceGroupId.present
        ? sourceGroupId.value
        : this.sourceGroupId,
    sourceItemId: sourceItemId.present ? sourceItemId.value : this.sourceItemId,
    details: details.present ? details.value : this.details,
  );
  DayErrandRow copyWithCompanion(DayErrandsCompanion data) {
    return DayErrandRow(
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      title: data.title.present ? data.title.value : this.title,
      place: data.place.present ? data.place.value : this.place,
      notes: data.notes.present ? data.notes.value : this.notes,
      timing: data.timing.present ? data.timing.value : this.timing,
      minute: data.minute.present ? data.minute.value : this.minute,
      optional: data.optional.present ? data.optional.value : this.optional,
      sourceGroupId: data.sourceGroupId.present
          ? data.sourceGroupId.value
          : this.sourceGroupId,
      sourceItemId: data.sourceItemId.present
          ? data.sourceItemId.value
          : this.sourceItemId,
      details: data.details.present ? data.details.value : this.details,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayErrandRow(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('title: $title, ')
          ..write('place: $place, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('minute: $minute, ')
          ..write('optional: $optional, ')
          ..write('sourceGroupId: $sourceGroupId, ')
          ..write('sourceItemId: $sourceItemId, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    position,
    title,
    place,
    notes,
    timing,
    minute,
    optional,
    sourceGroupId,
    sourceItemId,
    details,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayErrandRow &&
          other.id == this.id &&
          other.position == this.position &&
          other.title == this.title &&
          other.place == this.place &&
          other.notes == this.notes &&
          other.timing == this.timing &&
          other.minute == this.minute &&
          other.optional == this.optional &&
          other.sourceGroupId == this.sourceGroupId &&
          other.sourceItemId == this.sourceItemId &&
          other.details == this.details);
}

class DayErrandsCompanion extends UpdateCompanion<DayErrandRow> {
  final Value<String> id;
  final Value<int> position;
  final Value<String> title;
  final Value<String> place;
  final Value<String> notes;
  final Value<String> timing;
  final Value<int?> minute;
  final Value<bool> optional;
  final Value<String?> sourceGroupId;
  final Value<String?> sourceItemId;
  final Value<String?> details;
  final Value<int> rowid;
  const DayErrandsCompanion({
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.title = const Value.absent(),
    this.place = const Value.absent(),
    this.notes = const Value.absent(),
    this.timing = const Value.absent(),
    this.minute = const Value.absent(),
    this.optional = const Value.absent(),
    this.sourceGroupId = const Value.absent(),
    this.sourceItemId = const Value.absent(),
    this.details = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayErrandsCompanion.insert({
    required String id,
    required int position,
    required String title,
    required String place,
    required String notes,
    required String timing,
    this.minute = const Value.absent(),
    required bool optional,
    this.sourceGroupId = const Value.absent(),
    this.sourceItemId = const Value.absent(),
    this.details = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       position = Value(position),
       title = Value(title),
       place = Value(place),
       notes = Value(notes),
       timing = Value(timing),
       optional = Value(optional);
  static Insertable<DayErrandRow> custom({
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? title,
    Expression<String>? place,
    Expression<String>? notes,
    Expression<String>? timing,
    Expression<int>? minute,
    Expression<bool>? optional,
    Expression<String>? sourceGroupId,
    Expression<String>? sourceItemId,
    Expression<String>? details,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (title != null) 'title': title,
      if (place != null) 'place': place,
      if (notes != null) 'notes': notes,
      if (timing != null) 'timing': timing,
      if (minute != null) 'minute': minute,
      if (optional != null) 'optional': optional,
      if (sourceGroupId != null) 'source_group_id': sourceGroupId,
      if (sourceItemId != null) 'source_item_id': sourceItemId,
      if (details != null) 'details': details,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayErrandsCompanion copyWith({
    Value<String>? id,
    Value<int>? position,
    Value<String>? title,
    Value<String>? place,
    Value<String>? notes,
    Value<String>? timing,
    Value<int?>? minute,
    Value<bool>? optional,
    Value<String?>? sourceGroupId,
    Value<String?>? sourceItemId,
    Value<String?>? details,
    Value<int>? rowid,
  }) {
    return DayErrandsCompanion(
      id: id ?? this.id,
      position: position ?? this.position,
      title: title ?? this.title,
      place: place ?? this.place,
      notes: notes ?? this.notes,
      timing: timing ?? this.timing,
      minute: minute ?? this.minute,
      optional: optional ?? this.optional,
      sourceGroupId: sourceGroupId ?? this.sourceGroupId,
      sourceItemId: sourceItemId ?? this.sourceItemId,
      details: details ?? this.details,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (timing.present) {
      map['timing'] = Variable<String>(timing.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (optional.present) {
      map['optional'] = Variable<bool>(optional.value);
    }
    if (sourceGroupId.present) {
      map['source_group_id'] = Variable<String>(sourceGroupId.value);
    }
    if (sourceItemId.present) {
      map['source_item_id'] = Variable<String>(sourceItemId.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayErrandsCompanion(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('title: $title, ')
          ..write('place: $place, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('minute: $minute, ')
          ..write('optional: $optional, ')
          ..write('sourceGroupId: $sourceGroupId, ')
          ..write('sourceItemId: $sourceItemId, ')
          ..write('details: $details, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringGroupsTable extends RecurringGroups
    with TableInfo<$RecurringGroupsTable, RecurringGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<String> repeat = GeneratedColumn<String>(
    'repeat',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, position, name, repeat, day];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day'],
      )!,
    );
  }

  @override
  $RecurringGroupsTable createAlias(String alias) {
    return $RecurringGroupsTable(attachedDatabase, alias);
  }
}

class RecurringGroupRow extends DataClass
    implements Insertable<RecurringGroupRow> {
  final String id;
  final int position;
  final String name;
  final String repeat;
  final int day;
  const RecurringGroupRow({
    required this.id,
    required this.position,
    required this.name,
    required this.repeat,
    required this.day,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['name'] = Variable<String>(name);
    map['repeat'] = Variable<String>(repeat);
    map['day'] = Variable<int>(day);
    return map;
  }

  RecurringGroupsCompanion toCompanion(bool nullToAbsent) {
    return RecurringGroupsCompanion(
      id: Value(id),
      position: Value(position),
      name: Value(name),
      repeat: Value(repeat),
      day: Value(day),
    );
  }

  factory RecurringGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringGroupRow(
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      name: serializer.fromJson<String>(json['name']),
      repeat: serializer.fromJson<String>(json['repeat']),
      day: serializer.fromJson<int>(json['day']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'name': serializer.toJson<String>(name),
      'repeat': serializer.toJson<String>(repeat),
      'day': serializer.toJson<int>(day),
    };
  }

  RecurringGroupRow copyWith({
    String? id,
    int? position,
    String? name,
    String? repeat,
    int? day,
  }) => RecurringGroupRow(
    id: id ?? this.id,
    position: position ?? this.position,
    name: name ?? this.name,
    repeat: repeat ?? this.repeat,
    day: day ?? this.day,
  );
  RecurringGroupRow copyWithCompanion(RecurringGroupsCompanion data) {
    return RecurringGroupRow(
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      name: data.name.present ? data.name.value : this.name,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      day: data.day.present ? data.day.value : this.day,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringGroupRow(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('repeat: $repeat, ')
          ..write('day: $day')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, position, name, repeat, day);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringGroupRow &&
          other.id == this.id &&
          other.position == this.position &&
          other.name == this.name &&
          other.repeat == this.repeat &&
          other.day == this.day);
}

class RecurringGroupsCompanion extends UpdateCompanion<RecurringGroupRow> {
  final Value<String> id;
  final Value<int> position;
  final Value<String> name;
  final Value<String> repeat;
  final Value<int> day;
  final Value<int> rowid;
  const RecurringGroupsCompanion({
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.name = const Value.absent(),
    this.repeat = const Value.absent(),
    this.day = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringGroupsCompanion.insert({
    required String id,
    required int position,
    required String name,
    required String repeat,
    required int day,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       position = Value(position),
       name = Value(name),
       repeat = Value(repeat),
       day = Value(day);
  static Insertable<RecurringGroupRow> custom({
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? name,
    Expression<String>? repeat,
    Expression<int>? day,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (name != null) 'name': name,
      if (repeat != null) 'repeat': repeat,
      if (day != null) 'day': day,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringGroupsCompanion copyWith({
    Value<String>? id,
    Value<int>? position,
    Value<String>? name,
    Value<String>? repeat,
    Value<int>? day,
    Value<int>? rowid,
  }) {
    return RecurringGroupsCompanion(
      id: id ?? this.id,
      position: position ?? this.position,
      name: name ?? this.name,
      repeat: repeat ?? this.repeat,
      day: day ?? this.day,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<String>(repeat.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringGroupsCompanion(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('repeat: $repeat, ')
          ..write('day: $day, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupErrandsTable extends GroupErrands
    with TableInfo<$GroupErrandsTable, GroupErrandRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupErrandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timingMeta = const VerificationMeta('timing');
  @override
  late final GeneratedColumn<String> timing = GeneratedColumn<String>(
    'timing',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionalMeta = const VerificationMeta(
    'optional',
  );
  @override
  late final GeneratedColumn<bool> optional = GeneratedColumn<bool>(
    'optional',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("optional" IN (0, 1))',
    ),
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    position,
    title,
    place,
    notes,
    timing,
    minute,
    optional,
    details,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_errands';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupErrandRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    } else if (isInserting) {
      context.missing(_placeMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('timing')) {
      context.handle(
        _timingMeta,
        timing.isAcceptableOrUnknown(data['timing']!, _timingMeta),
      );
    } else if (isInserting) {
      context.missing(_timingMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    }
    if (data.containsKey('optional')) {
      context.handle(
        _optionalMeta,
        optional.isAcceptableOrUnknown(data['optional']!, _optionalMeta),
      );
    } else if (isInserting) {
      context.missing(_optionalMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupErrandRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupErrandRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      timing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timing'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      ),
      optional: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}optional'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
    );
  }

  @override
  $GroupErrandsTable createAlias(String alias) {
    return $GroupErrandsTable(attachedDatabase, alias);
  }
}

class GroupErrandRow extends DataClass implements Insertable<GroupErrandRow> {
  final String id;
  final String groupId;
  final int position;
  final String title;
  final String place;
  final String notes;
  final String timing;
  final int? minute;
  final bool optional;
  final String? details;
  const GroupErrandRow({
    required this.id,
    required this.groupId,
    required this.position,
    required this.title,
    required this.place,
    required this.notes,
    required this.timing,
    this.minute,
    required this.optional,
    this.details,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['position'] = Variable<int>(position);
    map['title'] = Variable<String>(title);
    map['place'] = Variable<String>(place);
    map['notes'] = Variable<String>(notes);
    map['timing'] = Variable<String>(timing);
    if (!nullToAbsent || minute != null) {
      map['minute'] = Variable<int>(minute);
    }
    map['optional'] = Variable<bool>(optional);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    return map;
  }

  GroupErrandsCompanion toCompanion(bool nullToAbsent) {
    return GroupErrandsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      position: Value(position),
      title: Value(title),
      place: Value(place),
      notes: Value(notes),
      timing: Value(timing),
      minute: minute == null && nullToAbsent
          ? const Value.absent()
          : Value(minute),
      optional: Value(optional),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
    );
  }

  factory GroupErrandRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupErrandRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      position: serializer.fromJson<int>(json['position']),
      title: serializer.fromJson<String>(json['title']),
      place: serializer.fromJson<String>(json['place']),
      notes: serializer.fromJson<String>(json['notes']),
      timing: serializer.fromJson<String>(json['timing']),
      minute: serializer.fromJson<int?>(json['minute']),
      optional: serializer.fromJson<bool>(json['optional']),
      details: serializer.fromJson<String?>(json['details']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'position': serializer.toJson<int>(position),
      'title': serializer.toJson<String>(title),
      'place': serializer.toJson<String>(place),
      'notes': serializer.toJson<String>(notes),
      'timing': serializer.toJson<String>(timing),
      'minute': serializer.toJson<int?>(minute),
      'optional': serializer.toJson<bool>(optional),
      'details': serializer.toJson<String?>(details),
    };
  }

  GroupErrandRow copyWith({
    String? id,
    String? groupId,
    int? position,
    String? title,
    String? place,
    String? notes,
    String? timing,
    Value<int?> minute = const Value.absent(),
    bool? optional,
    Value<String?> details = const Value.absent(),
  }) => GroupErrandRow(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    position: position ?? this.position,
    title: title ?? this.title,
    place: place ?? this.place,
    notes: notes ?? this.notes,
    timing: timing ?? this.timing,
    minute: minute.present ? minute.value : this.minute,
    optional: optional ?? this.optional,
    details: details.present ? details.value : this.details,
  );
  GroupErrandRow copyWithCompanion(GroupErrandsCompanion data) {
    return GroupErrandRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      position: data.position.present ? data.position.value : this.position,
      title: data.title.present ? data.title.value : this.title,
      place: data.place.present ? data.place.value : this.place,
      notes: data.notes.present ? data.notes.value : this.notes,
      timing: data.timing.present ? data.timing.value : this.timing,
      minute: data.minute.present ? data.minute.value : this.minute,
      optional: data.optional.present ? data.optional.value : this.optional,
      details: data.details.present ? data.details.value : this.details,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupErrandRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('position: $position, ')
          ..write('title: $title, ')
          ..write('place: $place, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('minute: $minute, ')
          ..write('optional: $optional, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    position,
    title,
    place,
    notes,
    timing,
    minute,
    optional,
    details,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupErrandRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.position == this.position &&
          other.title == this.title &&
          other.place == this.place &&
          other.notes == this.notes &&
          other.timing == this.timing &&
          other.minute == this.minute &&
          other.optional == this.optional &&
          other.details == this.details);
}

class GroupErrandsCompanion extends UpdateCompanion<GroupErrandRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<int> position;
  final Value<String> title;
  final Value<String> place;
  final Value<String> notes;
  final Value<String> timing;
  final Value<int?> minute;
  final Value<bool> optional;
  final Value<String?> details;
  final Value<int> rowid;
  const GroupErrandsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.position = const Value.absent(),
    this.title = const Value.absent(),
    this.place = const Value.absent(),
    this.notes = const Value.absent(),
    this.timing = const Value.absent(),
    this.minute = const Value.absent(),
    this.optional = const Value.absent(),
    this.details = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupErrandsCompanion.insert({
    required String id,
    required String groupId,
    required int position,
    required String title,
    required String place,
    required String notes,
    required String timing,
    this.minute = const Value.absent(),
    required bool optional,
    this.details = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       position = Value(position),
       title = Value(title),
       place = Value(place),
       notes = Value(notes),
       timing = Value(timing),
       optional = Value(optional);
  static Insertable<GroupErrandRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<int>? position,
    Expression<String>? title,
    Expression<String>? place,
    Expression<String>? notes,
    Expression<String>? timing,
    Expression<int>? minute,
    Expression<bool>? optional,
    Expression<String>? details,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (position != null) 'position': position,
      if (title != null) 'title': title,
      if (place != null) 'place': place,
      if (notes != null) 'notes': notes,
      if (timing != null) 'timing': timing,
      if (minute != null) 'minute': minute,
      if (optional != null) 'optional': optional,
      if (details != null) 'details': details,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupErrandsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<int>? position,
    Value<String>? title,
    Value<String>? place,
    Value<String>? notes,
    Value<String>? timing,
    Value<int?>? minute,
    Value<bool>? optional,
    Value<String?>? details,
    Value<int>? rowid,
  }) {
    return GroupErrandsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      position: position ?? this.position,
      title: title ?? this.title,
      place: place ?? this.place,
      notes: notes ?? this.notes,
      timing: timing ?? this.timing,
      minute: minute ?? this.minute,
      optional: optional ?? this.optional,
      details: details ?? this.details,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (timing.present) {
      map['timing'] = Variable<String>(timing.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (optional.present) {
      map['optional'] = Variable<bool>(optional.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupErrandsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('position: $position, ')
          ..write('title: $title, ')
          ..write('place: $place, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('minute: $minute, ')
          ..write('optional: $optional, ')
          ..write('details: $details, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedPlacesTable extends SavedPlaces
    with TableInfo<$SavedPlacesTable, SavedPlace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedPlacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_places';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedPlace> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedPlace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedPlace(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $SavedPlacesTable createAlias(String alias) {
    return $SavedPlacesTable(attachedDatabase, alias);
  }
}

class SavedPlace extends DataClass implements Insertable<SavedPlace> {
  final String id;
  final String payload;
  const SavedPlace({required this.id, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  SavedPlacesCompanion toCompanion(bool nullToAbsent) {
    return SavedPlacesCompanion(id: Value(id), payload: Value(payload));
  }

  factory SavedPlace.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedPlace(
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
    };
  }

  SavedPlace copyWith({String? id, String? payload}) =>
      SavedPlace(id: id ?? this.id, payload: payload ?? this.payload);
  SavedPlace copyWithCompanion(SavedPlacesCompanion data) {
    return SavedPlace(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedPlace(')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedPlace &&
          other.id == this.id &&
          other.payload == this.payload);
}

class SavedPlacesCompanion extends UpdateCompanion<SavedPlace> {
  final Value<String> id;
  final Value<String> payload;
  final Value<int> rowid;
  const SavedPlacesCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedPlacesCompanion.insert({
    required String id,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payload = Value(payload);
  static Insertable<SavedPlace> custom({
    Expression<String>? id,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedPlacesCompanion copyWith({
    Value<String>? id,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return SavedPlacesCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedPlacesCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AcceptedItinerariesTable extends AcceptedItineraries
    with TableInfo<$AcceptedItinerariesTable, AcceptedItineraryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AcceptedItinerariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accepted_itineraries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AcceptedItineraryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AcceptedItineraryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AcceptedItineraryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $AcceptedItinerariesTable createAlias(String alias) {
    return $AcceptedItinerariesTable(attachedDatabase, alias);
  }
}

class AcceptedItineraryRow extends DataClass
    implements Insertable<AcceptedItineraryRow> {
  final int id;
  final String payload;
  const AcceptedItineraryRow({required this.id, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  AcceptedItinerariesCompanion toCompanion(bool nullToAbsent) {
    return AcceptedItinerariesCompanion(id: Value(id), payload: Value(payload));
  }

  factory AcceptedItineraryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AcceptedItineraryRow(
      id: serializer.fromJson<int>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'payload': serializer.toJson<String>(payload),
    };
  }

  AcceptedItineraryRow copyWith({int? id, String? payload}) =>
      AcceptedItineraryRow(id: id ?? this.id, payload: payload ?? this.payload);
  AcceptedItineraryRow copyWithCompanion(AcceptedItinerariesCompanion data) {
    return AcceptedItineraryRow(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AcceptedItineraryRow(')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcceptedItineraryRow &&
          other.id == this.id &&
          other.payload == this.payload);
}

class AcceptedItinerariesCompanion
    extends UpdateCompanion<AcceptedItineraryRow> {
  final Value<int> id;
  final Value<String> payload;
  const AcceptedItinerariesCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
  });
  AcceptedItinerariesCompanion.insert({
    this.id = const Value.absent(),
    required String payload,
  }) : payload = Value(payload);
  static Insertable<AcceptedItineraryRow> custom({
    Expression<int>? id,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
    });
  }

  AcceptedItinerariesCompanion copyWith({
    Value<int>? id,
    Value<String>? payload,
  }) {
    return AcceptedItinerariesCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AcceptedItinerariesCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

abstract class _$WaydayDatabase extends GeneratedDatabase {
  _$WaydayDatabase(QueryExecutor e) : super(e);
  $WaydayDatabaseManager get managers => $WaydayDatabaseManager(this);
  late final $DaySettingsTable daySettings = $DaySettingsTable(this);
  late final $DayErrandsTable dayErrands = $DayErrandsTable(this);
  late final $RecurringGroupsTable recurringGroups = $RecurringGroupsTable(
    this,
  );
  late final $GroupErrandsTable groupErrands = $GroupErrandsTable(this);
  late final $SavedPlacesTable savedPlaces = $SavedPlacesTable(this);
  late final $AcceptedItinerariesTable acceptedItineraries =
      $AcceptedItinerariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    daySettings,
    dayErrands,
    recurringGroups,
    groupErrands,
    savedPlaces,
    acceptedItineraries,
  ];
}

typedef $$DaySettingsTableCreateCompanionBuilder =
    DaySettingsCompanion Function({
      Value<int> id,
      required String fromPlace,
      required String toPlace,
      required int departure,
      required int deadline,
      required String profile,
      Value<String?> placeDetails,
    });
typedef $$DaySettingsTableUpdateCompanionBuilder =
    DaySettingsCompanion Function({
      Value<int> id,
      Value<String> fromPlace,
      Value<String> toPlace,
      Value<int> departure,
      Value<int> deadline,
      Value<String> profile,
      Value<String?> placeDetails,
    });

class $$DaySettingsTableFilterComposer
    extends Composer<_$WaydayDatabase, $DaySettingsTable> {
  $$DaySettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromPlace => $composableBuilder(
    column: $table.fromPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toPlace => $composableBuilder(
    column: $table.toPlace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get departure => $composableBuilder(
    column: $table.departure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get placeDetails => $composableBuilder(
    column: $table.placeDetails,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DaySettingsTableOrderingComposer
    extends Composer<_$WaydayDatabase, $DaySettingsTable> {
  $$DaySettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromPlace => $composableBuilder(
    column: $table.fromPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toPlace => $composableBuilder(
    column: $table.toPlace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get departure => $composableBuilder(
    column: $table.departure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profile => $composableBuilder(
    column: $table.profile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get placeDetails => $composableBuilder(
    column: $table.placeDetails,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DaySettingsTableAnnotationComposer
    extends Composer<_$WaydayDatabase, $DaySettingsTable> {
  $$DaySettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fromPlace =>
      $composableBuilder(column: $table.fromPlace, builder: (column) => column);

  GeneratedColumn<String> get toPlace =>
      $composableBuilder(column: $table.toPlace, builder: (column) => column);

  GeneratedColumn<int> get departure =>
      $composableBuilder(column: $table.departure, builder: (column) => column);

  GeneratedColumn<int> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<String> get profile =>
      $composableBuilder(column: $table.profile, builder: (column) => column);

  GeneratedColumn<String> get placeDetails => $composableBuilder(
    column: $table.placeDetails,
    builder: (column) => column,
  );
}

class $$DaySettingsTableTableManager
    extends
        RootTableManager<
          _$WaydayDatabase,
          $DaySettingsTable,
          DaySettingsRow,
          $$DaySettingsTableFilterComposer,
          $$DaySettingsTableOrderingComposer,
          $$DaySettingsTableAnnotationComposer,
          $$DaySettingsTableCreateCompanionBuilder,
          $$DaySettingsTableUpdateCompanionBuilder,
          (
            DaySettingsRow,
            BaseReferences<_$WaydayDatabase, $DaySettingsTable, DaySettingsRow>,
          ),
          DaySettingsRow,
          PrefetchHooks Function()
        > {
  $$DaySettingsTableTableManager(_$WaydayDatabase db, $DaySettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DaySettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DaySettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DaySettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fromPlace = const Value.absent(),
                Value<String> toPlace = const Value.absent(),
                Value<int> departure = const Value.absent(),
                Value<int> deadline = const Value.absent(),
                Value<String> profile = const Value.absent(),
                Value<String?> placeDetails = const Value.absent(),
              }) => DaySettingsCompanion(
                id: id,
                fromPlace: fromPlace,
                toPlace: toPlace,
                departure: departure,
                deadline: deadline,
                profile: profile,
                placeDetails: placeDetails,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fromPlace,
                required String toPlace,
                required int departure,
                required int deadline,
                required String profile,
                Value<String?> placeDetails = const Value.absent(),
              }) => DaySettingsCompanion.insert(
                id: id,
                fromPlace: fromPlace,
                toPlace: toPlace,
                departure: departure,
                deadline: deadline,
                profile: profile,
                placeDetails: placeDetails,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DaySettingsTable, DaySettingsRow>(table),
                  BaseReferences<
                    _$WaydayDatabase,
                    $DaySettingsTable,
                    DaySettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DaySettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$WaydayDatabase,
      $DaySettingsTable,
      DaySettingsRow,
      $$DaySettingsTableFilterComposer,
      $$DaySettingsTableOrderingComposer,
      $$DaySettingsTableAnnotationComposer,
      $$DaySettingsTableCreateCompanionBuilder,
      $$DaySettingsTableUpdateCompanionBuilder,
      (
        DaySettingsRow,
        BaseReferences<_$WaydayDatabase, $DaySettingsTable, DaySettingsRow>,
      ),
      DaySettingsRow,
      PrefetchHooks Function()
    >;
typedef $$DayErrandsTableCreateCompanionBuilder =
    DayErrandsCompanion Function({
      required String id,
      required int position,
      required String title,
      required String place,
      required String notes,
      required String timing,
      Value<int?> minute,
      required bool optional,
      Value<String?> sourceGroupId,
      Value<String?> sourceItemId,
      Value<String?> details,
      Value<int> rowid,
    });
typedef $$DayErrandsTableUpdateCompanionBuilder =
    DayErrandsCompanion Function({
      Value<String> id,
      Value<int> position,
      Value<String> title,
      Value<String> place,
      Value<String> notes,
      Value<String> timing,
      Value<int?> minute,
      Value<bool> optional,
      Value<String?> sourceGroupId,
      Value<String?> sourceItemId,
      Value<String?> details,
      Value<int> rowid,
    });

class $$DayErrandsTableFilterComposer
    extends Composer<_$WaydayDatabase, $DayErrandsTable> {
  $$DayErrandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceGroupId => $composableBuilder(
    column: $table.sourceGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceItemId => $composableBuilder(
    column: $table.sourceItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayErrandsTableOrderingComposer
    extends Composer<_$WaydayDatabase, $DayErrandsTable> {
  $$DayErrandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceGroupId => $composableBuilder(
    column: $table.sourceGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceItemId => $composableBuilder(
    column: $table.sourceItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayErrandsTableAnnotationComposer
    extends Composer<_$WaydayDatabase, $DayErrandsTable> {
  $$DayErrandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get timing =>
      $composableBuilder(column: $table.timing, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<bool> get optional =>
      $composableBuilder(column: $table.optional, builder: (column) => column);

  GeneratedColumn<String> get sourceGroupId => $composableBuilder(
    column: $table.sourceGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceItemId => $composableBuilder(
    column: $table.sourceItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);
}

class $$DayErrandsTableTableManager
    extends
        RootTableManager<
          _$WaydayDatabase,
          $DayErrandsTable,
          DayErrandRow,
          $$DayErrandsTableFilterComposer,
          $$DayErrandsTableOrderingComposer,
          $$DayErrandsTableAnnotationComposer,
          $$DayErrandsTableCreateCompanionBuilder,
          $$DayErrandsTableUpdateCompanionBuilder,
          (
            DayErrandRow,
            BaseReferences<_$WaydayDatabase, $DayErrandsTable, DayErrandRow>,
          ),
          DayErrandRow,
          PrefetchHooks Function()
        > {
  $$DayErrandsTableTableManager(_$WaydayDatabase db, $DayErrandsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayErrandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayErrandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayErrandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> place = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> timing = const Value.absent(),
                Value<int?> minute = const Value.absent(),
                Value<bool> optional = const Value.absent(),
                Value<String?> sourceGroupId = const Value.absent(),
                Value<String?> sourceItemId = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayErrandsCompanion(
                id: id,
                position: position,
                title: title,
                place: place,
                notes: notes,
                timing: timing,
                minute: minute,
                optional: optional,
                sourceGroupId: sourceGroupId,
                sourceItemId: sourceItemId,
                details: details,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int position,
                required String title,
                required String place,
                required String notes,
                required String timing,
                Value<int?> minute = const Value.absent(),
                required bool optional,
                Value<String?> sourceGroupId = const Value.absent(),
                Value<String?> sourceItemId = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayErrandsCompanion.insert(
                id: id,
                position: position,
                title: title,
                place: place,
                notes: notes,
                timing: timing,
                minute: minute,
                optional: optional,
                sourceGroupId: sourceGroupId,
                sourceItemId: sourceItemId,
                details: details,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayErrandsTable, DayErrandRow>(table),
                  BaseReferences<
                    _$WaydayDatabase,
                    $DayErrandsTable,
                    DayErrandRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DayErrandsTableProcessedTableManager =
    ProcessedTableManager<
      _$WaydayDatabase,
      $DayErrandsTable,
      DayErrandRow,
      $$DayErrandsTableFilterComposer,
      $$DayErrandsTableOrderingComposer,
      $$DayErrandsTableAnnotationComposer,
      $$DayErrandsTableCreateCompanionBuilder,
      $$DayErrandsTableUpdateCompanionBuilder,
      (
        DayErrandRow,
        BaseReferences<_$WaydayDatabase, $DayErrandsTable, DayErrandRow>,
      ),
      DayErrandRow,
      PrefetchHooks Function()
    >;
typedef $$RecurringGroupsTableCreateCompanionBuilder =
    RecurringGroupsCompanion Function({
      required String id,
      required int position,
      required String name,
      required String repeat,
      required int day,
      Value<int> rowid,
    });
typedef $$RecurringGroupsTableUpdateCompanionBuilder =
    RecurringGroupsCompanion Function({
      Value<String> id,
      Value<int> position,
      Value<String> name,
      Value<String> repeat,
      Value<int> day,
      Value<int> rowid,
    });

class $$RecurringGroupsTableFilterComposer
    extends Composer<_$WaydayDatabase, $RecurringGroupsTable> {
  $$RecurringGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurringGroupsTableOrderingComposer
    extends Composer<_$WaydayDatabase, $RecurringGroupsTable> {
  $$RecurringGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurringGroupsTableAnnotationComposer
    extends Composer<_$WaydayDatabase, $RecurringGroupsTable> {
  $$RecurringGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);
}

class $$RecurringGroupsTableTableManager
    extends
        RootTableManager<
          _$WaydayDatabase,
          $RecurringGroupsTable,
          RecurringGroupRow,
          $$RecurringGroupsTableFilterComposer,
          $$RecurringGroupsTableOrderingComposer,
          $$RecurringGroupsTableAnnotationComposer,
          $$RecurringGroupsTableCreateCompanionBuilder,
          $$RecurringGroupsTableUpdateCompanionBuilder,
          (
            RecurringGroupRow,
            BaseReferences<
              _$WaydayDatabase,
              $RecurringGroupsTable,
              RecurringGroupRow
            >,
          ),
          RecurringGroupRow,
          PrefetchHooks Function()
        > {
  $$RecurringGroupsTableTableManager(
    _$WaydayDatabase db,
    $RecurringGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> repeat = const Value.absent(),
                Value<int> day = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringGroupsCompanion(
                id: id,
                position: position,
                name: name,
                repeat: repeat,
                day: day,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int position,
                required String name,
                required String repeat,
                required int day,
                Value<int> rowid = const Value.absent(),
              }) => RecurringGroupsCompanion.insert(
                id: id,
                position: position,
                name: name,
                repeat: repeat,
                day: day,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecurringGroupsTable, RecurringGroupRow>(table),
                  BaseReferences<
                    _$WaydayDatabase,
                    $RecurringGroupsTable,
                    RecurringGroupRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurringGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$WaydayDatabase,
      $RecurringGroupsTable,
      RecurringGroupRow,
      $$RecurringGroupsTableFilterComposer,
      $$RecurringGroupsTableOrderingComposer,
      $$RecurringGroupsTableAnnotationComposer,
      $$RecurringGroupsTableCreateCompanionBuilder,
      $$RecurringGroupsTableUpdateCompanionBuilder,
      (
        RecurringGroupRow,
        BaseReferences<
          _$WaydayDatabase,
          $RecurringGroupsTable,
          RecurringGroupRow
        >,
      ),
      RecurringGroupRow,
      PrefetchHooks Function()
    >;
typedef $$GroupErrandsTableCreateCompanionBuilder =
    GroupErrandsCompanion Function({
      required String id,
      required String groupId,
      required int position,
      required String title,
      required String place,
      required String notes,
      required String timing,
      Value<int?> minute,
      required bool optional,
      Value<String?> details,
      Value<int> rowid,
    });
typedef $$GroupErrandsTableUpdateCompanionBuilder =
    GroupErrandsCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<int> position,
      Value<String> title,
      Value<String> place,
      Value<String> notes,
      Value<String> timing,
      Value<int?> minute,
      Value<bool> optional,
      Value<String?> details,
      Value<int> rowid,
    });

class $$GroupErrandsTableFilterComposer
    extends Composer<_$WaydayDatabase, $GroupErrandsTable> {
  $$GroupErrandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupErrandsTableOrderingComposer
    extends Composer<_$WaydayDatabase, $GroupErrandsTable> {
  $$GroupErrandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupErrandsTableAnnotationComposer
    extends Composer<_$WaydayDatabase, $GroupErrandsTable> {
  $$GroupErrandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get timing =>
      $composableBuilder(column: $table.timing, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<bool> get optional =>
      $composableBuilder(column: $table.optional, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);
}

class $$GroupErrandsTableTableManager
    extends
        RootTableManager<
          _$WaydayDatabase,
          $GroupErrandsTable,
          GroupErrandRow,
          $$GroupErrandsTableFilterComposer,
          $$GroupErrandsTableOrderingComposer,
          $$GroupErrandsTableAnnotationComposer,
          $$GroupErrandsTableCreateCompanionBuilder,
          $$GroupErrandsTableUpdateCompanionBuilder,
          (
            GroupErrandRow,
            BaseReferences<
              _$WaydayDatabase,
              $GroupErrandsTable,
              GroupErrandRow
            >,
          ),
          GroupErrandRow,
          PrefetchHooks Function()
        > {
  $$GroupErrandsTableTableManager(_$WaydayDatabase db, $GroupErrandsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupErrandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupErrandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupErrandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> place = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> timing = const Value.absent(),
                Value<int?> minute = const Value.absent(),
                Value<bool> optional = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupErrandsCompanion(
                id: id,
                groupId: groupId,
                position: position,
                title: title,
                place: place,
                notes: notes,
                timing: timing,
                minute: minute,
                optional: optional,
                details: details,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required int position,
                required String title,
                required String place,
                required String notes,
                required String timing,
                Value<int?> minute = const Value.absent(),
                required bool optional,
                Value<String?> details = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupErrandsCompanion.insert(
                id: id,
                groupId: groupId,
                position: position,
                title: title,
                place: place,
                notes: notes,
                timing: timing,
                minute: minute,
                optional: optional,
                details: details,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GroupErrandsTable, GroupErrandRow>(table),
                  BaseReferences<
                    _$WaydayDatabase,
                    $GroupErrandsTable,
                    GroupErrandRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupErrandsTableProcessedTableManager =
    ProcessedTableManager<
      _$WaydayDatabase,
      $GroupErrandsTable,
      GroupErrandRow,
      $$GroupErrandsTableFilterComposer,
      $$GroupErrandsTableOrderingComposer,
      $$GroupErrandsTableAnnotationComposer,
      $$GroupErrandsTableCreateCompanionBuilder,
      $$GroupErrandsTableUpdateCompanionBuilder,
      (
        GroupErrandRow,
        BaseReferences<_$WaydayDatabase, $GroupErrandsTable, GroupErrandRow>,
      ),
      GroupErrandRow,
      PrefetchHooks Function()
    >;
typedef $$SavedPlacesTableCreateCompanionBuilder =
    SavedPlacesCompanion Function({
      required String id,
      required String payload,
      Value<int> rowid,
    });
typedef $$SavedPlacesTableUpdateCompanionBuilder =
    SavedPlacesCompanion Function({
      Value<String> id,
      Value<String> payload,
      Value<int> rowid,
    });

class $$SavedPlacesTableFilterComposer
    extends Composer<_$WaydayDatabase, $SavedPlacesTable> {
  $$SavedPlacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedPlacesTableOrderingComposer
    extends Composer<_$WaydayDatabase, $SavedPlacesTable> {
  $$SavedPlacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedPlacesTableAnnotationComposer
    extends Composer<_$WaydayDatabase, $SavedPlacesTable> {
  $$SavedPlacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$SavedPlacesTableTableManager
    extends
        RootTableManager<
          _$WaydayDatabase,
          $SavedPlacesTable,
          SavedPlace,
          $$SavedPlacesTableFilterComposer,
          $$SavedPlacesTableOrderingComposer,
          $$SavedPlacesTableAnnotationComposer,
          $$SavedPlacesTableCreateCompanionBuilder,
          $$SavedPlacesTableUpdateCompanionBuilder,
          (
            SavedPlace,
            BaseReferences<_$WaydayDatabase, $SavedPlacesTable, SavedPlace>,
          ),
          SavedPlace,
          PrefetchHooks Function()
        > {
  $$SavedPlacesTableTableManager(_$WaydayDatabase db, $SavedPlacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedPlacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedPlacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedPlacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  SavedPlacesCompanion(id: id, payload: payload, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => SavedPlacesCompanion.insert(
                id: id,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedPlacesTable, SavedPlace>(table),
                  BaseReferences<
                    _$WaydayDatabase,
                    $SavedPlacesTable,
                    SavedPlace
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedPlacesTableProcessedTableManager =
    ProcessedTableManager<
      _$WaydayDatabase,
      $SavedPlacesTable,
      SavedPlace,
      $$SavedPlacesTableFilterComposer,
      $$SavedPlacesTableOrderingComposer,
      $$SavedPlacesTableAnnotationComposer,
      $$SavedPlacesTableCreateCompanionBuilder,
      $$SavedPlacesTableUpdateCompanionBuilder,
      (
        SavedPlace,
        BaseReferences<_$WaydayDatabase, $SavedPlacesTable, SavedPlace>,
      ),
      SavedPlace,
      PrefetchHooks Function()
    >;
typedef $$AcceptedItinerariesTableCreateCompanionBuilder =
    AcceptedItinerariesCompanion Function({
      Value<int> id,
      required String payload,
    });
typedef $$AcceptedItinerariesTableUpdateCompanionBuilder =
    AcceptedItinerariesCompanion Function({
      Value<int> id,
      Value<String> payload,
    });

class $$AcceptedItinerariesTableFilterComposer
    extends Composer<_$WaydayDatabase, $AcceptedItinerariesTable> {
  $$AcceptedItinerariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AcceptedItinerariesTableOrderingComposer
    extends Composer<_$WaydayDatabase, $AcceptedItinerariesTable> {
  $$AcceptedItinerariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AcceptedItinerariesTableAnnotationComposer
    extends Composer<_$WaydayDatabase, $AcceptedItinerariesTable> {
  $$AcceptedItinerariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$AcceptedItinerariesTableTableManager
    extends
        RootTableManager<
          _$WaydayDatabase,
          $AcceptedItinerariesTable,
          AcceptedItineraryRow,
          $$AcceptedItinerariesTableFilterComposer,
          $$AcceptedItinerariesTableOrderingComposer,
          $$AcceptedItinerariesTableAnnotationComposer,
          $$AcceptedItinerariesTableCreateCompanionBuilder,
          $$AcceptedItinerariesTableUpdateCompanionBuilder,
          (
            AcceptedItineraryRow,
            BaseReferences<
              _$WaydayDatabase,
              $AcceptedItinerariesTable,
              AcceptedItineraryRow
            >,
          ),
          AcceptedItineraryRow,
          PrefetchHooks Function()
        > {
  $$AcceptedItinerariesTableTableManager(
    _$WaydayDatabase db,
    $AcceptedItinerariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AcceptedItinerariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AcceptedItinerariesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AcceptedItinerariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => AcceptedItinerariesCompanion(id: id, payload: payload),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String payload,
              }) =>
                  AcceptedItinerariesCompanion.insert(id: id, payload: payload),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AcceptedItinerariesTable, AcceptedItineraryRow>(
                    table,
                  ),
                  BaseReferences<
                    _$WaydayDatabase,
                    $AcceptedItinerariesTable,
                    AcceptedItineraryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AcceptedItinerariesTableProcessedTableManager =
    ProcessedTableManager<
      _$WaydayDatabase,
      $AcceptedItinerariesTable,
      AcceptedItineraryRow,
      $$AcceptedItinerariesTableFilterComposer,
      $$AcceptedItinerariesTableOrderingComposer,
      $$AcceptedItinerariesTableAnnotationComposer,
      $$AcceptedItinerariesTableCreateCompanionBuilder,
      $$AcceptedItinerariesTableUpdateCompanionBuilder,
      (
        AcceptedItineraryRow,
        BaseReferences<
          _$WaydayDatabase,
          $AcceptedItinerariesTable,
          AcceptedItineraryRow
        >,
      ),
      AcceptedItineraryRow,
      PrefetchHooks Function()
    >;

class $WaydayDatabaseManager {
  final _$WaydayDatabase _db;
  $WaydayDatabaseManager(this._db);
  $$DaySettingsTableTableManager get daySettings =>
      $$DaySettingsTableTableManager(_db, _db.daySettings);
  $$DayErrandsTableTableManager get dayErrands =>
      $$DayErrandsTableTableManager(_db, _db.dayErrands);
  $$RecurringGroupsTableTableManager get recurringGroups =>
      $$RecurringGroupsTableTableManager(_db, _db.recurringGroups);
  $$GroupErrandsTableTableManager get groupErrands =>
      $$GroupErrandsTableTableManager(_db, _db.groupErrands);
  $$SavedPlacesTableTableManager get savedPlaces =>
      $$SavedPlacesTableTableManager(_db, _db.savedPlaces);
  $$AcceptedItinerariesTableTableManager get acceptedItineraries =>
      $$AcceptedItinerariesTableTableManager(_db, _db.acceptedItineraries);
}
