import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/follow_up_package.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/new_target_details.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/target_width.dart';
import 'package:digitization_platform/features/follow_up/domain/repositories/follow_up_repository.dart';
import 'package:digitization_platform/features/follow_up/domain/repositories/new_target_repository.dart';
import 'package:digitization_platform/features/follow_up/presentation/cubit/new_target_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _package = FollowUpPackage(
  id: 7,
  siteId: '1',
  siteName: 'Karnak',
  createdAt: null,
  totalBytes: 0,
  annotations: [],
  targets: [],
  files: {},
);

class _FakeNewTargets implements NewTargetRepository {
  final List<({NewTargetDetails details, String photoPath, TargetWidth width})> queued = [];
  Object? failure;

  @override
  String? codeConflict(FollowUpPackage package, String code) =>
      NewTargetDetails.normalized(code) == 'wall-1' ? 'A target of this site is already called $code.' : null;

  @override
  Future<void> queueNewTarget({
    required FollowUpPackage package,
    required NewTargetDetails details,
    required String photoPath,
    required TargetWidth width,
  }) async {
    if (failure != null) throw failure!;
    queued.add((details: details, photoPath: photoPath, width: width));
  }

  @override
  List<FollowUpUploadRecord> newTargets(String siteId) => const [];
}

class _FakeFollowUp implements FollowUpRepository {
  int foldersMade = 0;
  final List<String> foldersDeleted = [];

  @override
  Future<String> newShotsFolder(String siteId) async => 'shots/${++foldersMade}';

  @override
  Future<void> deleteShotsFolder(String folder) async => foldersDeleted.add(folder);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeNewTargets newTargets;
  late _FakeFollowUp followUp;
  late NewTargetCubit cubit;

  setUp(() {
    newTargets = _FakeNewTargets();
    followUp = _FakeFollowUp();
    cubit = NewTargetCubit(newTargets: newTargets, followUp: followUp, package: _package);
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  const width = TargetWidth(1.42, TargetWidth.sourceAr);

  void fillIn() {
    cubit
      ..setPhoto('shots/1/shot_1.jpg')
      ..setCode('W-12-A')
      ..setDescription('A procession.');
  }

  test('it is ready to measure only with a photograph, a code and a description', () {
    expect(cubit.state.readyToMeasure, isFalse);

    cubit.setPhoto('shots/1/shot_1.jpg');
    cubit.setCode('W-12-A');
    expect(cubit.state.readyToMeasure, isFalse);

    cubit.setDescription('A procession.');
    expect(cubit.state.readyToMeasure, isTrue);
  });

  test('a code already in use says why and blocks it until it is changed', () {
    fillIn();

    cubit.setCode('Wall-1');
    expect(cubit.state.conflict, isNotNull);
    expect(cubit.state.readyToMeasure, isFalse);

    cubit.setCode('W-13');
    expect(cubit.state.conflict, isNull);
    expect(cubit.state.readyToMeasure, isTrue);
  });

  test('saving hands over the details, the chosen photograph and the width', () async {
    fillIn();

    await cubit.save(width);

    final queued = newTargets.queued.single;
    expect(queued.details.code, 'W-12-A');
    expect(queued.details.description, 'A procession.');
    expect(queued.photoPath, 'shots/1/shot_1.jpg');
    expect(queued.width, width);
  });

  test('a failed save is passed on, so the width page can offer to try again', () async {
    fillIn();
    newTargets.failure = StateError('disk full');

    await expectLater(cubit.save(width), throwsStateError);
  });

  test('one shots folder however often it is retaken, and it goes when the page closes', () async {
    final first = await cubit.shotsFolder();
    final again = await cubit.shotsFolder();

    await cubit.close();

    expect(again, first);
    expect(followUp.foldersMade, 1);
    expect(followUp.foldersDeleted, [first]);
  });

  test('closing with no photograph taken deletes nothing', () async {
    await cubit.close();

    expect(followUp.foldersDeleted, isEmpty);
  });
}
