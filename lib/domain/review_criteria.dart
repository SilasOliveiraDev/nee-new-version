class ReviewCriterion {
  const ReviewCriterion({
    required this.id,
    required this.label,
    required this.hint,
  });

  final String id;
  final String label;
  final String hint;
}

class ReviewScores {
  const ReviewScores({
    required this.quality,
    required this.conduct,
    required this.ethics,
    required this.courtesy,
    required this.punctuality,
  });

  final int quality;
  final int conduct;
  final int ethics;
  final int courtesy;
  final int punctuality;

  static const empty = ReviewScores(
    quality: 0,
    conduct: 0,
    ethics: 0,
    courtesy: 0,
    punctuality: 0,
  );

  bool get isComplete =>
      _ok(quality) &&
      _ok(conduct) &&
      _ok(ethics) &&
      _ok(courtesy) &&
      _ok(punctuality);

  double get overall {
    if (!isComplete) return 0;
    return (quality + conduct + ethics + courtesy + punctuality) / 5;
  }

  ReviewScores withValue(String id, int stars) {
    switch (id) {
      case 'quality':
        return ReviewScores(
          quality: stars,
          conduct: conduct,
          ethics: ethics,
          courtesy: courtesy,
          punctuality: punctuality,
        );
      case 'conduct':
        return ReviewScores(
          quality: quality,
          conduct: stars,
          ethics: ethics,
          courtesy: courtesy,
          punctuality: punctuality,
        );
      case 'ethics':
        return ReviewScores(
          quality: quality,
          conduct: conduct,
          ethics: stars,
          courtesy: courtesy,
          punctuality: punctuality,
        );
      case 'courtesy':
        return ReviewScores(
          quality: quality,
          conduct: conduct,
          ethics: ethics,
          courtesy: stars,
          punctuality: punctuality,
        );
      case 'punctuality':
        return ReviewScores(
          quality: quality,
          conduct: conduct,
          ethics: ethics,
          courtesy: courtesy,
          punctuality: stars,
        );
      default:
        return this;
    }
  }

  int valueFor(String id) {
    switch (id) {
      case 'quality':
        return quality;
      case 'conduct':
        return conduct;
      case 'ethics':
        return ethics;
      case 'courtesy':
        return courtesy;
      case 'punctuality':
        return punctuality;
      default:
        return 0;
    }
  }

  static bool _ok(int stars) => stars >= 1 && stars <= 5;
}

class CriteriaAverages {
  const CriteriaAverages({
    this.quality,
    this.conduct,
    this.ethics,
    this.courtesy,
    this.punctuality,
  });

  final double? quality;
  final double? conduct;
  final double? ethics;
  final double? courtesy;
  final double? punctuality;

  bool get hasAny =>
      quality != null ||
      conduct != null ||
      ethics != null ||
      courtesy != null ||
      punctuality != null;

  static CriteriaAverages fromRow(Map<String, dynamic> row) {
    return CriteriaAverages(
      quality: (row['reviews_quality_average'] as num?)?.toDouble(),
      conduct: (row['reviews_conduct_average'] as num?)?.toDouble(),
      ethics: (row['reviews_ethics_average'] as num?)?.toDouble(),
      courtesy: (row['reviews_courtesy_average'] as num?)?.toDouble(),
      punctuality: (row['reviews_punctuality_average'] as num?)?.toDouble(),
    );
  }

  double? valueFor(String id) {
    switch (id) {
      case 'quality':
        return quality;
      case 'conduct':
        return conduct;
      case 'ethics':
        return ethics;
      case 'courtesy':
        return courtesy;
      case 'punctuality':
        return punctuality;
      default:
        return null;
    }
  }
}

class ReviewCriteria {
  static const items = [
    ReviewCriterion(
      id: 'quality',
      label: 'Calidad',
      hint: 'Cómo quedó el trabajo',
    ),
    ReviewCriterion(
      id: 'conduct',
      label: 'Conducta',
      hint: 'Profesionalismo y trato durante el servicio',
    ),
    ReviewCriterion(
      id: 'ethics',
      label: 'Ética',
      hint: 'Honestidad, claridad y respeto a lo acordado',
    ),
    ReviewCriterion(
      id: 'courtesy',
      label: 'Educación',
      hint: 'Respeto, cortesía y forma de hablar',
    ),
    ReviewCriterion(
      id: 'punctuality',
      label: 'Puntualidad',
      hint: 'Llegó y respetó los horarios',
    ),
  ];
}
