// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorkspaceDocumentsTable extends WorkspaceDocuments
    with TableInfo<$WorkspaceDocumentsTable, WorkspaceDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspaceDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
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
  List<GeneratedColumn> get $columns => [key, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspace_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  WorkspaceDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceDocument(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $WorkspaceDocumentsTable createAlias(String alias) {
    return $WorkspaceDocumentsTable(attachedDatabase, alias);
  }
}

class WorkspaceDocument extends DataClass
    implements Insertable<WorkspaceDocument> {
  final String key;
  final String payload;
  const WorkspaceDocument({required this.key, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  WorkspaceDocumentsCompanion toCompanion(bool nullToAbsent) {
    return WorkspaceDocumentsCompanion(
      key: Value(key),
      payload: Value(payload),
    );
  }

  factory WorkspaceDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceDocument(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
    };
  }

  WorkspaceDocument copyWith({String? key, String? payload}) =>
      WorkspaceDocument(key: key ?? this.key, payload: payload ?? this.payload);
  WorkspaceDocument copyWithCompanion(WorkspaceDocumentsCompanion data) {
    return WorkspaceDocument(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceDocument(')
          ..write('key: $key, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceDocument &&
          other.key == this.key &&
          other.payload == this.payload);
}

class WorkspaceDocumentsCompanion extends UpdateCompanion<WorkspaceDocument> {
  final Value<String> key;
  final Value<String> payload;
  final Value<int> rowid;
  const WorkspaceDocumentsCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspaceDocumentsCompanion.insert({
    required String key,
    required String payload,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload);
  static Insertable<WorkspaceDocument> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspaceDocumentsCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return WorkspaceDocumentsCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
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
    return (StringBuffer('WorkspaceDocumentsCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorkspaceDocumentsTable workspaceDocuments =
      $WorkspaceDocumentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [workspaceDocuments];
}

typedef $$WorkspaceDocumentsTableCreateCompanionBuilder =
    WorkspaceDocumentsCompanion Function({
      required String key,
      required String payload,
      Value<int> rowid,
    });
typedef $$WorkspaceDocumentsTableUpdateCompanionBuilder =
    WorkspaceDocumentsCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<int> rowid,
    });

class $$WorkspaceDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspaceDocumentsTable> {
  $$WorkspaceDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkspaceDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspaceDocumentsTable> {
  $$WorkspaceDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkspaceDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspaceDocumentsTable> {
  $$WorkspaceDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$WorkspaceDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkspaceDocumentsTable,
          WorkspaceDocument,
          $$WorkspaceDocumentsTableFilterComposer,
          $$WorkspaceDocumentsTableOrderingComposer,
          $$WorkspaceDocumentsTableAnnotationComposer,
          $$WorkspaceDocumentsTableCreateCompanionBuilder,
          $$WorkspaceDocumentsTableUpdateCompanionBuilder,
          (
            WorkspaceDocument,
            BaseReferences<
              _$AppDatabase,
              $WorkspaceDocumentsTable,
              WorkspaceDocument
            >,
          ),
          WorkspaceDocument,
          PrefetchHooks Function()
        > {
  $$WorkspaceDocumentsTableTableManager(
    _$AppDatabase db,
    $WorkspaceDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspaceDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspaceDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspaceDocumentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspaceDocumentsCompanion(
                key: key,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => WorkspaceDocumentsCompanion.insert(
                key: key,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkspaceDocumentsTable, WorkspaceDocument>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkspaceDocumentsTable,
                    WorkspaceDocument
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkspaceDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkspaceDocumentsTable,
      WorkspaceDocument,
      $$WorkspaceDocumentsTableFilterComposer,
      $$WorkspaceDocumentsTableOrderingComposer,
      $$WorkspaceDocumentsTableAnnotationComposer,
      $$WorkspaceDocumentsTableCreateCompanionBuilder,
      $$WorkspaceDocumentsTableUpdateCompanionBuilder,
      (
        WorkspaceDocument,
        BaseReferences<
          _$AppDatabase,
          $WorkspaceDocumentsTable,
          WorkspaceDocument
        >,
      ),
      WorkspaceDocument,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorkspaceDocumentsTableTableManager get workspaceDocuments =>
      $$WorkspaceDocumentsTableTableManager(_db, _db.workspaceDocuments);
}
