import 'hire_repository.dart';
import 'nee_supabase.dart';
import '../domain/review_criteria.dart';

class ReviewRepository {
  static Future<HireResult> submit({
    required int requestId,
    required ReviewScores scores,
    String comment = '',
  }) async {
    if (!NeeSupabase.ready) {
      return const HireResult(ok: false, error: 'OFFLINE');
    }
    if (!scores.isComplete) {
      return const HireResult(ok: false, error: 'INCOMPLETE');
    }
    try {
      final raw = await NeeSupabase.client.rpc(
        'submit_client_review',
        params: {
          'p_request_id': requestId,
          'p_quality': scores.quality,
          'p_conduct': scores.conduct,
          'p_ethics': scores.ethics,
          'p_courtesy': scores.courtesy,
          'p_punctuality': scores.punctuality,
          'p_comment': comment.trim().isEmpty ? null : comment.trim(),
        },
      );
      return HireResult.fromJson(raw);
    } catch (error) {
      return HireResult(ok: false, error: '$error');
    }
  }
}
