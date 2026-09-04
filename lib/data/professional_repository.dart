import 'package:flutter/foundation.dart';

import '../domain/phone_mask.dart';
import '../mock_data.dart';
import '../models.dart';
import '../domain/review_criteria.dart';
import 'account_repository.dart';
import 'nee_supabase.dart';
import 'professional_mapper.dart';

bool isMediaVideo(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.mp4') ||
      lower.contains('.mov') ||
      lower.contains('.webm') ||
      lower.contains('video');
}

class PortfolioWork {
  const PortfolioWork({
    required this.id,
    required this.url,
    this.title = '',
    this.isVideo = false,
  });

  final String id;
  final String url;
  final String title;
  final bool isVideo;
}

class PublicReview {
  const PublicReview({
    required this.rating,
    this.comment = '',
    this.createdAt,
    this.criteria,
  });

  final double rating;
  final String comment;
  final DateTime? createdAt;
  final ReviewScores? criteria;
}

class ProfessionalProfileView {
  const ProfessionalProfileView({
    required this.professional,
    this.portfolio = const [],
    this.reviews = const [],
  });

  final Professional professional;
  final List<PortfolioWork> portfolio;
  final List<PublicReview> reviews;
}

class ProfessionalRepository {
  static const _baseColumns =
      'professional_id, display_name, avatar_url, user_type, category_name, category_id, specialty, bio, zone, city, service_area, latlng, reviews_average, stored_rating, rating_count, completed_jobs_count, is_featured, is_suspended, is_blocked, document_status';

  static const _columnsWithVerified = '$_baseColumns, verified';
  static const _profileColumns = '$_columnsWithVerified, phone_masked';

  static Future<List<Professional>> loadPublic({
    double? originLat,
    double? originLng,
    String? categoryId,
    bool? verified,
    bool featuredOnly = false,
    int limit = 40,
  }) async {
    if (!NeeSupabase.ready) return const [];
    try {
      return await _loadPublic(
        columns: _columnsWithVerified,
        originLat: originLat,
        originLng: originLng,
        categoryId: categoryId,
        verified: verified,
        featuredOnly: featuredOnly,
        limit: limit,
      );
    } catch (error) {
      final text = '$error';
      if (text.contains('verified')) {
        debugPrint('Ñee: view sem coluna verified, recarregando sem o campo');
        return _loadPublic(
          columns: _baseColumns,
          originLat: originLat,
          originLng: originLng,
          categoryId: categoryId,
          featuredOnly: featuredOnly,
          limit: limit,
        );
      }
      debugPrint('Ñee: profissionais públicos: $error');
      rethrow;
    }
  }

  static Future<List<Professional>> _loadPublic({
    required String columns,
    double? originLat,
    double? originLng,
    String? categoryId,
    bool? verified,
    bool featuredOnly = false,
    int limit = 40,
  }) async {
    var query = NeeSupabase.client
        .from('professional_public_profiles')
        .select(columns);
    if (verified != null) {
      query = query.eq('verified', verified);
    }
    if (featuredOnly) {
      query = query.eq('is_featured', true);
    }
    if (categoryId != null &&
        categoryId.isNotEmpty &&
        int.tryParse(categoryId) != null) {
      query = query.eq('category_id', int.parse(categoryId));
    }
    final rows = await (columns.contains('verified')
            ? query.order('verified', ascending: false)
            : query)
        .limit(limit);
    final list = [
      for (final row in rows)
        professionalFromUserRow(
          Map<String, dynamic>.from(row),
          originLat: originLat,
          originLng: originLng,
        ),
    ]..sort((a, b) {
        final verifiedCmp = (b.verified ? 1 : 0).compareTo(a.verified ? 1 : 0);
        if (verifiedCmp != 0) return verifiedCmp;
        return (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9);
      });
    return list.where((p) => p.id.isNotEmpty && p.isActive).toList();
  }

  static Future<Professional?> getById(
    String professionalId, {
    double? originLat,
    double? originLng,
  }) async {
    if (!NeeSupabase.ready || professionalId.isEmpty) return null;
    try {
      Map<String, dynamic>? row;
      try {
        row = await NeeSupabase.client
            .from('professional_public_profiles')
            .select(_profileColumns)
            .eq('professional_id', professionalId)
            .maybeSingle();
      } catch (error) {
        final text = '$error';
        if (text.contains('phone_masked') || text.contains('verified')) {
          row = await NeeSupabase.client
              .from('professional_public_profiles')
              .select(_columnsWithVerified)
              .eq('professional_id', professionalId)
              .maybeSingle();
        } else {
          rethrow;
        }
      }
      if (row == null) return null;
      final professional = professionalFromUserRow(
        Map<String, dynamic>.from(row),
        originLat: originLat,
        originLng: originLng,
      );
      final signed = await AccountRepository.signedAvatarUrl(
        professional.avatarUrl,
      );
      return signed == null ? professional : professional.withAvatarUrl(signed);
    } catch (error) {
      debugPrint('Ñee: perfil profissional: $error');
      rethrow;
    }
  }

  static Future<List<PortfolioWork>> portfolioFor(String professionalId) async {
    if (!NeeSupabase.ready || professionalId.isEmpty) return const [];
    final items = <PortfolioWork>[];
    final seen = <String>{};
    try {
      final files = await NeeSupabase.client.storage
          .from('avatars')
          .list(path: '$professionalId/portfolio');
      for (final file in files) {
        final name = file.name.trim();
        if (name.isEmpty || name.startsWith('.')) continue;
        final path = '$professionalId/portfolio/$name';
        final url = await AccountRepository.signedAvatarUrl(path);
        if (url == null || url.isEmpty || !seen.add(path)) continue;
        items.add(
          PortfolioWork(
            id: path,
            url: url,
            title: name,
            isVideo: isMediaVideo(name),
          ),
        );
      }
    } catch (error) {
      debugPrint('Ñee: portafolio storage: $error');
    }
    try {
      final rows = await NeeSupabase.client
          .from('services')
          .select('id, title, imagem, publicado, user_id')
          .eq('user_id', professionalId)
          .eq('publicado', true);
      for (final row in rows) {
        var url = '${row['imagem'] ?? ''}'.trim();
        if (url.isEmpty) continue;
        if (!url.startsWith('http')) {
          url = await AccountRepository.signedAvatarUrl(url) ?? url;
        }
        final id = 's-${row['id']}';
        if (!seen.add(id) || !seen.add(url)) continue;
        items.add(
          PortfolioWork(
            id: id,
            url: url,
            title: '${row['title'] ?? ''}',
            isVideo: isMediaVideo(url),
          ),
        );
      }
    } catch (error) {
      debugPrint('Ñee: portafolio: $error');
    }
    return items;
  }

  static Future<List<PublicReview>> reviewsFor(String professionalId) async {
    if (!NeeSupabase.ready || professionalId.isEmpty) return const [];
    try {
      final rows = await NeeSupabase.client
          .from('reviews')
          .select(
            'rating, comment, created_at, is_visible, profissional_id, rating_quality, rating_conduct, rating_ethics, rating_courtesy, rating_punctuality',
          )
          .eq('profissional_id', professionalId)
          .eq('is_visible', true)
          .order('created_at', ascending: false)
          .limit(20);
      return [
        for (final row in rows)
          if (row['rating'] != null)
            PublicReview(
              rating: (row['rating'] as num).toDouble(),
              comment: '${row['comment'] ?? ''}'.trim(),
              createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
              criteria: _scoresFromRow(row),
            ),
      ];
    } catch (error) {
      debugPrint('Ñee: opiniones: $error');
      rethrow;
    }
  }

  static ReviewScores? _scoresFromRow(Map<String, dynamic> row) {
    int? star(String key) {
      final n = (row[key] as num?)?.toInt();
      if (n == null || n < 1 || n > 5) return null;
      return n;
    }

    final quality = star('rating_quality');
    final conduct = star('rating_conduct');
    final ethics = star('rating_ethics');
    final courtesy = star('rating_courtesy');
    final punctuality = star('rating_punctuality');
    if (quality == null ||
        conduct == null ||
        ethics == null ||
        courtesy == null ||
        punctuality == null) {
      return null;
    }
    return ReviewScores(
      quality: quality,
      conduct: conduct,
      ethics: ethics,
      courtesy: courtesy,
      punctuality: punctuality,
    );
  }

  static Future<ProfessionalProfileView> loadProfile(
    String professionalId, {
    double? originLat,
    double? originLng,
  }) async {
    final professional = await getById(
      professionalId,
      originLat: originLat,
      originLng: originLng,
    );
    if (professional == null) {
      throw StateError('missing');
    }
    List<PortfolioWork> portfolio = const [];
    List<PublicReview> reviews = const [];
    try {
      portfolio = await portfolioFor(professionalId);
    } catch (_) {}
    try {
      reviews = await reviewsFor(professionalId);
    } catch (_) {}
    return ProfessionalProfileView(
      professional: professional,
      portfolio: portfolio,
      reviews: reviews,
    );
  }

  static Future<String?> whatsappNumber(String professionalId) async {
    if (!NeeSupabase.ready || professionalId.isEmpty) return null;
    try {
      final raw = await NeeSupabase.client.rpc(
        'professional_whatsapp_number',
        params: {'p_professional_id': professionalId},
      );
      final value = '$raw'.trim();
      if (value.isEmpty || value == 'null') return null;
      return PhoneMask.whatsapp(value);
    } catch (error) {
      debugPrint('Ñee: whatsapp: $error');
      return null;
    }
  }

  static Future<List<ServiceCategory>> loadCategories() async {
    if (!NeeSupabase.ready) return List.of(categories);
    try {
      final rows = await NeeSupabase.client
          .from('categories')
          .select('id, nome, disponivel')
          .eq('disponivel', true)
          .order('id')
          .limit(200);
      if (rows.isEmpty) return List.of(categories);
      return [
        for (final row in rows)
          ServiceCategory(
            id: '${row['id']}',
            name: '${row['nome'] ?? ''}',
            icon: iconForCategoryName('${row['nome'] ?? ''}'),
            hint: '',
          ),
      ];
    } catch (error) {
      debugPrint('Ñee: categorías: $error');
      rethrow;
    }
  }

  static Future<List<String>> loadSubcategories(String categoryId) async {
    if (!NeeSupabase.ready || categoryId.isEmpty) return const [];
    final id = int.tryParse(categoryId);
    if (id == null) return const [];
    try {
      final rows = await NeeSupabase.client
          .from('subcategorias')
          .select('id, nomeSubCategoria, categoria')
          .eq('categoria', id)
          .order('id')
          .limit(80);
      return [
        for (final row in rows)
          if ('${row['nomeSubCategoria'] ?? ''}'.trim().isNotEmpty)
            '${row['nomeSubCategoria']}'.trim(),
      ];
    } catch (error) {
      debugPrint('Ñee: subcategorías: $error');
      return const [];
    }
  }
}
