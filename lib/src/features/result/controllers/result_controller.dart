import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/utils.dart';
import '../../../models/result_model.dart';
import '../../../providers/type_defs.dart';
import '../../../providers/utils_providers.dart';
import '../repository/result_repository.dart';

part 'result_controller.g.dart';

@riverpod
Future<void> resultFuture(ResultFutureRef ref, {bool isRefreshed = false}) {
  return ref
      .watch(resultControllerProvider.notifier)
      .getAllResults(isRefreshed: isRefreshed);
}

@Riverpod(keepAlive: true)
class ResultController extends _$ResultController {
  String _resultFolder() =>
      '${ref.read(myUserProvider)?.dept ?? ''}/${ref.read(myUserProvider)?.session ?? ''}/${ref.read(myUserProvider)?.roll ?? ''}/Results';
  @override
  List<Result> build() {
    return [];
  }

  Future<void> getAllResults({bool isRefreshed = false}) async {
    if (!isRefreshed && state.isNotEmpty) return;
    state = await ResultRepository.getAllResults(_resultFolder());
  }

  FutureEither<String> saveResultFile(Result result) async {
    final appDocDir = (await getTemporaryDirectory()).path;
    final filePath =
        '$appDocDir/${result.file.name}'; // Path : /data/user/0/com.example.jgec_notice/cache/
    final file = File(filePath);
    try {
      await file.writeAsBytes(await ResultRepository.download(result));
    } catch (e) {
      return left(e.toString());
    }
    return right(filePath);
  }

  FutureEither<String> downloadResult(Result doc) async {
    String filePath = (await getDownloadPath())!;
    final file = File('$filePath/${doc.file.name}');
    try {
      if (await Permission.manageExternalStorage.request().isGranted) {
        await file.writeAsBytes(await ResultRepository.download(doc));
        return right(filePath);
      }
    } catch (e) {
      return left(e.toString());
    }
    return left('Permita o acesso aos arquivos para baixar o arquivo');
  }
}
