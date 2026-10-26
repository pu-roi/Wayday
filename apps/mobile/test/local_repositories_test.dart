import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/recurring/domain/errand_group.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  late Directory databaseDirectory;
  late WaydayDatabase database;

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp('wayday-db-');
    database = WaydayDatabase(
      NativeDatabase(File('${databaseDirectory.path}/wayday.sqlite')),
    );
  });

  tearDown(() async {
    await database.close();
    await databaseDirectory.delete(recursive: true);
  });

  test(
    'seeds examples once and round-trips all current fields and ordering',
    () async {
      final repositories = await LocalRepositories.open(database: database);
      expect(repositories.today.read().errands, hasLength(5));
      expect(repositories.recurring.read(), hasLength(2));

      final day = DayPlan(
        from: 'Library',
        to: 'Home',
        departure: 420,
        deadline: 1110,
        profile: TravelProfile.bike,
        errands: const [
          Errand(
            id: 'second',
            title: 'Second stop',
            place: 'Market',
            notes: 'Bring a bag',
            timing: TimingRule.finishBefore,
            minute: 900,
            optional: true,
            sourceGroupId: 'weekly',
            sourceItemId: 'market',
          ),
          Errand(
            id: 'first',
            title: 'First stop',
            timing: TimingRule.at,
            minute: 600,
          ),
        ],
      );
      final groups = [
        ErrandGroup(
          id: 'monthly',
          name: 'Monthly list',
          repeat: RepeatPattern.monthly,
          day: 21,
          items: const [
            Errand(
              id: 'market',
              title: 'Market',
              place: 'Central market',
              notes: 'Vegetables\nFruit',
              timing: TimingRule.arriveBy,
              minute: 540,
              optional: true,
            ),
          ],
        ),
        ErrandGroup(
          id: 'weekly',
          name: 'Weekly list',
          repeat: RepeatPattern.fortnightly,
          day: 3,
          items: const [Errand(id: 'laundry', title: 'Laundry')],
        ),
      ];

      await repositories.today.save(day);
      await repositories.recurring.save(groups);

      await database.close();
      database = WaydayDatabase(
        NativeDatabase(File('${databaseDirectory.path}/wayday.sqlite')),
      );
      final reopened = await LocalRepositories.open(database: database);
      final savedDay = reopened.today.read();
      expect(savedDay.from, 'Library');
      expect(savedDay.to, 'Home');
      expect(savedDay.departure, 420);
      expect(savedDay.deadline, 1110);
      expect(savedDay.profile, TravelProfile.bike);
      expect(savedDay.errands.map((item) => item.id), ['second', 'first']);
      expect(savedDay.errands.first.notes, 'Bring a bag');
      expect(savedDay.errands.first.timing, TimingRule.finishBefore);
      expect(savedDay.errands.first.minute, 900);
      expect(savedDay.errands.first.optional, isTrue);
      expect(savedDay.errands.first.sourceGroupId, 'weekly');
      expect(savedDay.errands.first.sourceItemId, 'market');

      final savedGroups = reopened.recurring.read();
      expect(savedGroups.map((group) => group.id), ['monthly', 'weekly']);
      expect(savedGroups.first.repeat, RepeatPattern.monthly);
      expect(savedGroups.first.day, 21);
      expect(savedGroups.first.items.single.notes, 'Vegetables\nFruit');
      expect(savedGroups.first.items.single.timing, TimingRule.arriveBy);
      expect(savedGroups.first.items.single.minute, 540);
      expect(savedGroups.first.items.single.optional, isTrue);
    },
  );

  test(
    'intentionally empty lists remain empty when repositories reopen',
    () async {
      final repositories = await LocalRepositories.open(database: database);
      await repositories.today.save(DayPlan(errands: const []));
      await repositories.recurring.save(const []);

      await database.close();
      database = WaydayDatabase(
        NativeDatabase(File('${databaseDirectory.path}/wayday.sqlite')),
      );
      final reopened = await LocalRepositories.open(database: database);

      expect(reopened.today.read().errands, isEmpty);
      expect(reopened.recurring.read(), isEmpty);
    },
  );

  test(
    'rapid consecutive saves leave the newest Today and Recurring state',
    () async {
      final repositories = await LocalRepositories.open(database: database);
      final dayWrites = [
        repositories.today.save(
          DayPlan(
            errands: const [Errand(id: 'one', title: 'One')],
          ),
        ),
        repositories.today.save(
          DayPlan(
            errands: const [Errand(id: 'two', title: 'Two')],
          ),
        ),
        repositories.today.save(
          DayPlan(
            errands: const [Errand(id: 'three', title: 'Three')],
          ),
        ),
      ];
      final groupWrites = [
        repositories.recurring.save([
          ErrandGroup(id: 'one', name: 'One', items: const []),
        ]),
        repositories.recurring.save([
          ErrandGroup(id: 'two', name: 'Two', items: const []),
        ]),
        repositories.recurring.save([
          ErrandGroup(id: 'three', name: 'Three', items: const []),
        ]),
      ];

      await Future.wait([...dayWrites, ...groupWrites]);
      await database.close();
      database = WaydayDatabase(
        NativeDatabase(File('${databaseDirectory.path}/wayday.sqlite')),
      );
      final reopened = await LocalRepositories.open(database: database);

      expect(reopened.today.read().errands.single.id, 'three');
      expect(reopened.recurring.read().single.id, 'three');
    },
  );

  test(
    'a failed replacement rolls back instead of deleting saved data',
    () async {
      final repositories = await LocalRepositories.open(database: database);
      final originalDay = repositories.today.read();
      final originalGroups = repositories.recurring.read();

      await expectLater(
        repositories.today.save(
          DayPlan(
            errands: const [
              Errand(id: 'duplicate', title: 'First'),
              Errand(id: 'duplicate', title: 'Second'),
            ],
          ),
        ),
        throwsA(anything),
      );
      await expectLater(
        repositories.recurring.save([
          ErrandGroup(
            id: 'first-group',
            name: 'First group',
            items: const [Errand(id: 'duplicate', title: 'First')],
          ),
          ErrandGroup(
            id: 'second-group',
            name: 'Second group',
            items: const [Errand(id: 'duplicate', title: 'Second')],
          ),
        ]),
        throwsA(anything),
      );

      await database.close();
      database = WaydayDatabase(
        NativeDatabase(File('${databaseDirectory.path}/wayday.sqlite')),
      );
      final reopened = await LocalRepositories.open(database: database);
      expect(
        reopened.today.read().errands.map((item) => item.id),
        originalDay.errands.map((item) => item.id),
      );
      expect(
        reopened.recurring.read().map((group) => group.id),
        originalGroups.map((group) => group.id),
      );
    },
  );
}
