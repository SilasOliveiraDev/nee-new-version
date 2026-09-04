import '../models.dart';

/// Payload alinhado a `public.users` em [schema-nee.sql].
class UsersRow {
  static Map<String, dynamic> toMap({
    required UserAccount user,
    required OnboardingStep step,
    required AppRole? activeRole,
  }) {
    final address = user.registeredAddress.summary.isNotEmpty
        ? user.registeredAddress
        : user.currentLocation;
    final latlng = address.hasCoords
        ? '${address.latitude},${address.longitude}'
        : null;
    final name = user.fullName;
    final payload = <String, dynamic>{
      'name': name == 'Ñee' ? null : name,
      'email': user.email.isEmpty ? null : user.email,
      'phone': user.phone.isEmpty ? null : user.phone,
      'user_type': 'Cliente',
      'verified': user.phoneVerified,
      'Zona': address.zone.isEmpty ? null : address.zone,
      'fechaNacimiento': user.birthDate?.toIso8601String(),
      'sexo': user.sexo.isEmpty ? null : user.sexo,
      'cidade': address.city.isEmpty ? null : address.city,
      'step': step.name,
      'latlng': latlng,
      'adress': address.street.isEmpty ? null : address.street,
      'city': address.city.isEmpty ? null : address.city,
      'country': address.country.isEmpty ? 'Bolivia' : address.country,
      'complemento': address.reference.isEmpty ? null : address.reference,
      'numeroresidencia': address.number.isEmpty ? null : address.number,
      'statusDocumentos': user.phoneVerified ? 'BASIC' : null,
      'userTest': true,
    };
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  static bool isDeleted(Map<String, dynamic>? row) =>
      row != null && row['isDeletado'] == true;
}
