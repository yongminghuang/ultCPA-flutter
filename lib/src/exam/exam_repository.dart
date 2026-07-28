import '../network/app_api_client.dart';
import '../practice/practice_models.dart';
import '../storage/legacy_app_state_store.dart';
import '../vip_purchase/vip_purchase_models.dart';
import 'exam_models.dart';

abstract interface class ExamDataSource {
  Future<ExamCatalog> load(ExamRequest request);

  Future<void> submit(ExamResult result);
}

final class ExamRepository implements ExamDataSource {
  ExamRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
  }) : _api = api,
       _stateStore = stateStore;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;

  @override
  Future<ExamCatalog> load(ExamRequest request) async {
    final query = request.queryParameters;
    final body = await _api.getBody(
      '/app/goods/pageGoodsData',
      queryParameters: query,
    );
    final batch = PracticePageBatch.fromBody(body);
    final hasMemberTier = await _resolveHasMemberTier();
    return ExamCatalog(
      request: request,
      questions: batch.items
          .whereType<PracticeQuestionItem>()
          .map((item) => item.question)
          .toList(growable: false),
      hasMemberTier: hasMemberTier,
    );
  }

  Future<bool> _resolveHasMemberTier() async {
    try {
      final snapshot = await _stateStore.readAppSnapshot();
      return resolveVipPurchaseSuccessSummary(
        snapshot['userBenefitsJson'],
        category: snapshot['category']?.toString() ?? '',
        level: snapshot['selectedLevel']?.toString() ?? '',
      ).hasMemberTier;
    } catch (_) {
      // Membership only controls an optional report card. Question loading
      // must remain available when the native snapshot is unavailable.
      return false;
    }
  }

  @override
  Future<void> submit(ExamResult result) async {
    final questionList = <Map<String, dynamic>>[];
    for (final question in result.questions) {
      final answer = result.answerFor(question);
      final questionId = int.tryParse(question.id.trim());
      if (answer == null || questionId == null || questionId <= 0) continue;
      questionList.add({
        'questionId': questionId,
        'choose': answer.choose,
        'isRight': answer.isRight ? 1 : 0,
      });
    }
    if (questionList.isEmpty) return;
    final snapshot = await _stateStore.readAppSnapshot();
    await _api.postBody('/app/question/saveQuestionRecordBatch', {
      'subject': snapshot['selectedSubject']?.toString() ?? '',
      'level': snapshot['selectedLevel']?.toString() ?? '',
      'questionList': questionList,
    });
  }
}
