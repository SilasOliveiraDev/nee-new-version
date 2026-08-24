import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'domain/availability.dart';
import 'places/place_models.dart';
import 'service_schedule.dart';

enum AppRole { customer, provider }

enum OnboardingStep {
  splash,
  value,
  login,
  signup,
  geo,
  address,
  phone,
  otp,
  profile,
  photo,
  role,
  customerPrefs,
  customerReady,
  providerCategory,
  providerRadius,
  providerBio,
  providerPortfolio,
  providerTrust,
  providerPreview,
  done,
}

enum VerificationLevel { basic, verified, pro }

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.hint,
  });

  final String id;
  final String name;
  final IconData icon;
  final String hint;
}

enum RequestStatus {
  sent,
  professionalFound,
  accepted,
  onTheWay,
  inProgress,
  awaitingRating,
  completed,
  cancelledByCustomer,
  cancelledByProfessional,
  notCompleted,
}

extension RequestStatusLabel on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.sent:
        return 'Esperando ofertas';
      case RequestStatus.professionalFound:
        return 'Ofertas recibidas';
      case RequestStatus.accepted:
        return 'Profesional seleccionado';
      case RequestStatus.onTheWay:
        return 'Profesional en camino';
      case RequestStatus.inProgress:
        return 'Servicio en curso';
      case RequestStatus.awaitingRating:
        return 'Pendiente de calificación';
      case RequestStatus.completed:
        return 'Completado';
      case RequestStatus.cancelledByCustomer:
        return 'Cancelado por ti';
      case RequestStatus.cancelledByProfessional:
        return 'Cancelado por el profesional';
      case RequestStatus.notCompleted:
        return 'No se pudo realizar';
    }
  }
}

enum WorkPreview { photo, video }

class Professional {
  const Professional({
    required this.id,
    required this.name,
    required this.specialty,
    required this.categoryId,
    required this.city,
    required this.initials,
    required this.rating,
    required this.jobs,
    this.distanceKm = 1.8,
    this.available = true,
    this.isActive = true,
    this.documentsVerified = false,
    this.latitude = -17.7833,
    this.longitude = -63.1821,
    this.hasMapPin = true,
    this.isDestaque = false,
    this.tags = const [],
    this.opsStatus = ProOpsStatus.available,
    this.nextAvailableAt,
    this.acceptingRequests = true,
  });

  final String id;
  final String name;
  final String specialty;
  final String categoryId;
  final String city;
  final String initials;
  final double rating;
  final int jobs;
  final double distanceKm;
  final bool available;
  final bool isActive;
  final bool documentsVerified;
  final double latitude;
  final double longitude;
  final bool hasMapPin;
  final bool isDestaque;
  final List<String> tags;
  final ProOpsStatus opsStatus;
  final DateTime? nextAvailableAt;
  final bool acceptingRequests;

  AvailabilityView get availability => AvailabilityView(
        status: opsStatus,
        acceptingRequests: acceptingRequests && isActive,
        nextAvailableAt: nextAvailableAt,
      );

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }

  Professional withAvailability(AvailabilityView view) {
    return Professional(
      id: id,
      name: name,
      specialty: specialty,
      categoryId: categoryId,
      city: city,
      initials: initials,
      rating: rating,
      jobs: jobs,
      distanceKm: distanceKm,
      available: view.availableNow,
      isActive: isActive,
      documentsVerified: documentsVerified,
      latitude: latitude,
      longitude: longitude,
      hasMapPin: hasMapPin,
      isDestaque: isDestaque,
      tags: tags,
      opsStatus: view.status,
      nextAvailableAt: view.nextAvailableAt,
      acceptingRequests: view.acceptingRequests,
    );
  }

  /// Destacados e ativos continuam visíveis mesmo ocupados.
  bool get canHelpClient => isDestaque && isActive;

  /// Closer on-air talent reads louder. Occupied talent stays a ghost.
  double get signal {
    final reach = (1.0 - (distanceKm / 8.0)).clamp(0.28, 1.0);
    return available ? reach : reach * 0.32;
  }
}

class ServiceRequest {
  ServiceRequest({
    required this.id,
    required this.category,
    required this.description,
    required this.location,
    required this.createdAt,
    this.professional,
    this.status = RequestStatus.sent,
    this.interestedCount = 0,
    this.urgency = '',
    this.photoCount = 0,
    this.hasAudio = false,
    this.hasVideo = false,
    this.specialty = '',
    this.schedule,
    this.serviceLocation,
    this.rated = false,
    this.remoteId,
    this.closedAt,
    this.closeNote,
    this.kind = RequestKind.marketplace,
    this.directStatus,
    this.targetProfessionalId,
    this.requestedStart,
    this.requestedEnd,
    this.agreedPrice,
    this.agreedDurationMinutes,
    this.declineReason,
  });

  final String id;
  final ServiceCategory category;
  final String description;
  final String location;
  final DateTime createdAt;
  Professional? professional;
  RequestStatus status;
  int interestedCount;
  String urgency;
  int photoCount;
  bool hasAudio;
  bool hasVideo;
  String specialty;
  ServiceSchedule? schedule;
  ServiceLocationSnapshot? serviceLocation;
  bool rated;
  int? remoteId;
  DateTime? closedAt;
  String? closeNote;
  RequestKind kind;
  DirectStatus? directStatus;
  String? targetProfessionalId;
  DateTime? requestedStart;
  DateTime? requestedEnd;
  double? agreedPrice;
  int? agreedDurationMinutes;
  String? declineReason;
  final offers = <ServiceOffer>[];

  bool get isDirect => kind == RequestKind.direct;

  String get stageLabel {
    if (isDirect) {
      switch (directStatus) {
        case DirectStatus.pending:
          return 'Esperando respuesta';
        case DirectStatus.negotiation:
          return 'Conversando';
        case DirectStatus.pendingConfirmation:
          return 'Pendiente de confirmación';
        case DirectStatus.confirmed:
          break;
        case DirectStatus.declined:
          return 'No puede atender';
        case DirectStatus.expired:
          return 'Sin respuesta a tiempo';
        case DirectStatus.cancelled:
          return 'Solicitud cancelada';
        case null:
          break;
      }
    }
    return status.label;
  }

  String get discoveryLabel {
    final snap = serviceLocation;
    if (snap == null) return location;
    final area = snap.publicHint.trim();
    if (area.isEmpty) return 'Ubicación aproximada';
    return '$area — ubicación aproximada';
  }
}

class ServiceOffer {
  ServiceOffer({
    required this.id,
    required this.professional,
    this.message = '',
    this.priceBs,
    this.availability = 'Disponible hoy',
    this.timeEstimate = '',
  });

  final String id;
  final Professional professional;
  final String message;
  final double? priceBs;
  final String availability;
  final String timeEstimate;
}

class PortfolioItem {
  PortfolioItem({
    required this.bytes,
    required this.isVideo,
    required this.name,
    this.description = '',
    this.isCover = false,
  });

  final Uint8List bytes;
  final bool isVideo;
  final String name;
  String description;
  bool isCover;
}

class GeoAddress {
  GeoAddress({
    this.latitude,
    this.longitude,
    this.country = 'Bolivia',
    this.department = '',
    this.city = '',
    this.zone = '',
    this.street = '',
    this.number = '',
    this.reference = '',
  });

  double? latitude;
  double? longitude;
  String country;
  String department;
  String city;
  String zone;
  String street;
  String number;
  String reference;

  bool get hasCoords => latitude != null && longitude != null;

  String get summary {
    final parts = [
      street,
      if (number.isNotEmpty) number,
      zone,
      city,
      department,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty);
    return parts.join(', ');
  }

  bool get isFilled => city.trim().isNotEmpty || street.trim().isNotEmpty;
}

class ProviderProfile {
  String title = '';
  String bio = '';
  int yearsExperience = 1;
  int serviceRadiusKm = 10;
  bool worksAlone = true;
  bool emergency = false;
  bool weekends = false;
  bool invoices = false;
  bool residential = true;
  bool commercial = false;
  String? primaryCategoryId;
  final specialties = <String>{};
  VerificationLevel verificationLevel = VerificationLevel.basic;
  bool identityVerified = false;
  bool documentVerified = false;
  bool addressVerified = false;
  bool published = false;
}

class UserAccount {
  String firstName = '';
  String lastName = '';
  String phone = '';
  String countryCode = '+591';
  String email = '';
  String sexo = '';
  DateTime? birthDate;
  bool phoneVerified = false;
  bool emailVerified = false;
  Uint8List? photoBytes;
  final currentLocation = GeoAddress();
  final registeredAddress = GeoAddress();
  final roles = <AppRole>{};
  final preferredCategories = <String>{};
  final provider = ProviderProfile();
  final portfolio = <PortfolioItem>[];
  String? supabaseUuid;
  int? supabaseRowId;
  String? photoUrl;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Ñee' : name;
  }

  String get first {
    return firstName.trim().isEmpty ? 'hola' : firstName.trim();
  }

  String get fullAddress {
    if (registeredAddress.summary.isNotEmpty) return registeredAddress.summary;
    return currentLocation.summary;
  }

  String get cityLabel {
    final city = registeredAddress.city.isNotEmpty
        ? registeredAddress.city
        : currentLocation.city;
    if (city.trim().isEmpty) return 'Bolivia';
    return '$city, BO';
  }

  Set<String> get serviceIds => provider.specialties;

  String get initials {
    final parts = fullName.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Ñ';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class TradeCategory {
  const TradeCategory({
    required this.id,
    required this.group,
    required this.name,
    required this.specialties,
  });

  final String id;
  final String group;
  final String name;
  final List<String> specialties;
}
