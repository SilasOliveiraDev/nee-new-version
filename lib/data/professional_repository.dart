import 'package:flutter/foundation.dart';

import '../mock_data.dart';
import '../models.dart';
import 'nee_supabase.dart';
import 'professional_mapper.dart';

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
  });

  final double rating;
  final String comment;
  final DateTime? createdAt;
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
    final rows = await query.limit(limit);
    final list = [
      for (final row in rows)
        professionalFromUserRow(
          Map<String, dynamic>.from(row),
          originLat: originLat,
          originLng: originLng,
        ),
    ]..sort((a, b) {
        final da = a.distanceKm ?? 1e9;
        final db = b.distanceKm ?? 1e9;
        return da.compareTo(db);
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
            .select(_columnsWithVerified)
            .eq('professional_id', professionalId)
            .maybeSingle();
      } catch (error) {
        if ('$error'.contains('verified')) {
          row = await NeeSupabase.client
              .from('professional_public_profiles')
              .select(_baseColumns)
              .eq('professional_id', professionalId)
              .maybeSingle();
        } else {
          rethrow;
        }
      }
      if (row == null) return null;
      return professionalFromUserRow(
        Map<String, dynamic>.from(row),
        originLat: originLat,
        originLng: originLng,
      );
    } catch (error) {
      debugPrint('Ñee: perfil profissional: $error');
      rethrow;
    }
  }

  static Future<List<PortfolioWork>> portfolioFor(String professionalId) async {
    if (!NeeSupabase.ready || professionalId.isEmpty) return const [];
    try {
      final rows = await NeeSupabase.client
          .from('services')
          .select('id, title, imagem, publicado, user_id')
          .eq('user_id', professionalId)
          .eq('publicado', true);
      final items = <PortfolioWork>[];
      for (final row in rows) {
        final url = '${row['imagem'] ?? ''}'.trim();
        if (url.isEmpty) continue;
        final lower = url.toLowerCase();
        items.add(
          PortfolioWork(
            id: '${row['id']}',
            url: url,
            title: '${row['title'] ?? ''}',
            isVideo: lower.contains('.mp4') ||
                lower.contains('.mov') ||
                lower.contains('video'),
          ),
        );
      }
      return items;
    } catch (error) {
      debugPrint('Ñee: portafolio: $error');
      rethrow;
    }
  }

  static Future<List<PublicReview>> reviewsFor(String professionalId) async {
    if (!NeeSupabase.ready || professionalId.isEmpty) return const [];
    try {
      final rows = await NeeSupabase.client
          .from('reviews')
          .select('rating, comment, created_at, is_visible, profissional_id')
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
            ),
      ];
    } catch (error) {
      debugPrint('Ñee: opiniones: $error');
      rethrow;
    }
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

  static Future<List<ServiceCategory>> loadCategories() async {
    if (!NeeSupabase.ready) return List.of(categories);
    try {
      final rows = await NeeSupabase.client
          .from('categories')
          .select('id, nome, disponivel')
          .eq('disponivel', true)
          .order('id')
          .limit(40);
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
}
