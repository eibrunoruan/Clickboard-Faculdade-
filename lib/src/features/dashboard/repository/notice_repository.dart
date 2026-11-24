import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';

import '../../../models/notice_model.dart';
import '../../../providers/supabase_storage_service.dart';
import '../../../providers/utils_providers.dart';

/// Ponto unico de criacao do repositorio, no mesmo molde do
/// `documentRepositoryProvider`: o teste troca o storage por um fake e
/// exercita publicar e listar sem rede.
///
/// Observa o perfil porque e dele que saem departamento e turma. Antes o
/// `NoticeController` montava o repositorio uma unica vez no `build`, e se o
/// perfil ainda nao tivesse chegado a pasta ficava errada ate reiniciar o app.
final noticeRepositoryProvider = Provider((ref) {
  final usuario = ref.watch(myUserProvider);
  return NoticeRepository(
    department: usuario?.dept ?? '',
    session: usuario?.session ?? '',
  );
});

class NoticeRepository {
  final StorageService _storageService;
  final Client _httpClient;
  final String _noticesFolder;
  final String department, session;
  NoticeRepository({
    StorageService? storageService,
    Client? httpClient,
    required this.department,
    required this.session,
  })  : _storageService = storageService ?? SupabaseStorageService(),
        _httpClient = httpClient ?? Client(),
        _noticesFolder = '$department/$session/Notice';

  Future<List<Notice>> getAllNotices() async {
    List<Notice> notices = [];
    notices.addAll(await getFBNotices());
    notices.addAll(await getCollegeNotices());
    notices = notices
        .sortWithDate((instance) => instance.timeCreated ?? DateTime.now())
        .reversed
        .toList();
    return notices;
  }

  /// Avisos do mural da turma. Sem `try`: se o storage falhar, a falha sobe
  /// ate a tela. Antes um `catch (e) {}` devolvia lista vazia e o mural
  /// mostrava "No Notices" como se nao houvesse aviso nenhum.
  Future<List<Notice>> getFBNotices() async {
    List<Notice> fbNotices = [];
    final files = await _storageService.list(_noticesFolder);
    for (var file in files) {
      fbNotices.add(Notice(
        name: file.name.split('.pdf')[0],
        downloadUrl: await _storageService.signedUrl(file.path),
        timeCreated: file.timeCreated,
      ));
    }
    return fbNotices;
  }

  /// Avisos raspados do site da faculdade de origem do projeto. E fonte
  /// secundaria: se o site estiver fora, o mural da turma continua de pe. A
  /// falha agora fica registrada no log em vez de sumir num `catch` vazio.
  Future<List<Notice>> getCollegeNotices() async {
    List<Notice> webNotices = [];
    final url = Uri.parse('https://jgec.ac.in/announcement/1');
    try {
      final Response response = await _httpClient.get(url);
      var document = parse(response.body);
      webNotices = document.querySelectorAll('div.notice-info').map((e) {
        return Notice(
            name: e.querySelector('a')?.innerHtml.trim() ?? '',
            downloadUrl: e.querySelector('a')?.attributes['href']?.trim() ?? '',
            timeCreated: DateFormat('dd MMMM yyyy')
                .parse(e.querySelector('span')!.innerHtml.trim()));
      }).toList();
    } catch (e) {
      debugPrint('Avisos do site da faculdade indisponiveis: $e');
    }
    return webNotices;
  }

  /// Envia o PDF para a pasta de avisos da turma e devolve o aviso pronto
  /// para entrar no mural, ja com a URL assinada. Erros do storage sobem
  /// para o controller, que decide a mensagem.
  Future<Notice> publishNotice({
    required String title,
    required Uint8List pdf,
  }) async {
    final downloadUrl = await _storageService.uploadBytes(
      folder: _noticesFolder,
      fileName: '$title.pdf',
      bytes: pdf,
      contentType: 'application/pdf',
    );
    return Notice(
      name: title,
      downloadUrl: downloadUrl,
      timeCreated: DateTime.now(),
    );
  }
}
