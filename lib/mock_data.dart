import 'package:flutter/material.dart';

import 'models.dart';

const categories = <ServiceCategory>[
  ServiceCategory(
    id: 'plomeria',
    name: 'Plomería',
    icon: Icons.water_drop_outlined,
    hint: 'Fugas, caños, grifos, desagües',
  ),
  ServiceCategory(
    id: 'electricidad',
    name: 'Electricidad',
    icon: Icons.bolt_outlined,
    hint: 'Cortocircuitos, enchufes, luminarias',
  ),
  ServiceCategory(
    id: 'pintura',
    name: 'Pintura',
    icon: Icons.format_paint_outlined,
    hint: 'Paredes, fachadas, interiores',
  ),
  ServiceCategory(
    id: 'limpieza',
    name: 'Limpieza',
    icon: Icons.cleaning_services_outlined,
    hint: 'Casa, oficina, post-obra',
  ),
  ServiceCategory(
    id: 'belleza',
    name: 'Belleza',
    icon: Icons.spa_outlined,
    hint: 'Corte, uñas, barbería',
  ),
  ServiceCategory(
    id: 'cursos',
    name: 'Cursos',
    icon: Icons.school_outlined,
    hint: 'Clases y formación',
  ),
  ServiceCategory(
    id: 'tech',
    name: 'Tech',
    icon: Icons.laptop_mac_outlined,
    hint: 'Computadoras, redes, soporte',
  ),
  ServiceCategory(
    id: 'jardineria',
    name: 'Jardinería',
    icon: Icons.yard_outlined,
    hint: 'Corte de césped, plantas, riego',
  ),
  ServiceCategory(
    id: 'construccion',
    name: 'Construcción',
    icon: Icons.apartment_outlined,
    hint: 'Albañil, yesero, remodelación',
  ),
  ServiceCategory(
    id: 'refrigeracion',
    name: 'Refrigeración',
    icon: Icons.ac_unit_outlined,
    hint: 'Aire, heladeras, cámaras',
  ),
  ServiceCategory(
    id: 'mecanica',
    name: 'Mecánica',
    icon: Icons.directions_car_outlined,
    hint: 'Autos, motos, diagnóstico',
  ),
  ServiceCategory(
    id: 'cerrajeria',
    name: 'Cerrajería',
    icon: Icons.lock_open_outlined,
    hint: 'Llaves, cerraduras, emergencias',
  ),
  ServiceCategory(
    id: 'reparaciones',
    name: 'Reparaciones',
    icon: Icons.handyman_outlined,
    hint: 'Muebles, puertas, arreglos varios',
  ),
];

const trades = <TradeCategory>[
  TradeCategory(
    id: 'albanil',
    group: 'Construcción',
    name: 'Albañil',
    specialties: ['Muros', 'Revoque', 'Losas', 'Remodelación'],
  ),
  TradeCategory(
    id: 'pintura',
    group: 'Construcción',
    name: 'Pintor',
    specialties: ['Interiores', 'Fachadas', 'Impermeabilización'],
  ),
  TradeCategory(
    id: 'electricidad',
    group: 'Construcción',
    name: 'Electricista',
    specialties: [
      'Instalaciones eléctricas',
      'Duchas eléctricas',
      'Tableros',
      'Cortocircuitos',
      'Iluminación',
    ],
  ),
  TradeCategory(
    id: 'plomeria',
    group: 'Construcción',
    name: 'Plomero',
    specialties: ['Fugas', 'Desagües', 'Calefones', 'Grifería'],
  ),
  TradeCategory(
    id: 'yesero',
    group: 'Construcción',
    name: 'Yesero',
    specialties: ['Cielorrasos', 'Tabiques', 'Revestimientos'],
  ),
  TradeCategory(
    id: 'limpieza',
    group: 'Hogar',
    name: 'Limpieza',
    specialties: ['Hogar', 'Oficinas', 'Post-obra', 'Vidrios'],
  ),
  TradeCategory(
    id: 'jardineria',
    group: 'Hogar',
    name: 'Jardinería',
    specialties: ['Césped', 'Poda', 'Riego', 'Paisajismo'],
  ),
  TradeCategory(
    id: 'piscinas',
    group: 'Hogar',
    name: 'Piscinas',
    specialties: ['Limpieza', 'Motores', 'Filtrado'],
  ),
  TradeCategory(
    id: 'mudanzas',
    group: 'Hogar',
    name: 'Mudanzas',
    specialties: ['Departamentos', 'Casas', 'Embalaje'],
  ),
  TradeCategory(
    id: 'refrigeracion',
    group: 'Técnico',
    name: 'Refrigeración',
    specialties: ['Aire acondicionado', 'Heladeras', 'Cámaras'],
  ),
  TradeCategory(
    id: 'mecanica',
    group: 'Técnico',
    name: 'Mecánica',
    specialties: ['Motor', 'Frenos', 'Eléctrico automotriz'],
  ),
  TradeCategory(
    id: 'cerrajeria',
    group: 'Técnico',
    name: 'Cerrajería',
    specialties: ['Aperturas', 'Cerraduras', 'Copias de llave'],
  ),
];

const professionals = <Professional>[
  Professional(
    id: 'p1',
    name: 'Carlos Méndez',
    specialty: 'Plomero',
    categoryId: 'plomeria',
    city: 'Santa Cruz · Equipetrol',
    initials: 'CM',
    rating: 4.9,
    jobs: 214,
    distanceKm: 1.2,
    available: true,
    isActive: true,
    documentsVerified: true,
    latitude: -17.7764,
    longitude: -63.1811,
    tags: ['Urgencias', 'Residencial'],
  ),
  Professional(
    id: 'p2',
    name: 'María Quispe',
    specialty: 'Electricista',
    categoryId: 'electricidad',
    city: 'Santa Cruz · Equipetrol',
    initials: 'MQ',
    rating: 4.8,
    jobs: 94,
    distanceKm: 2.1,
    available: true,
    isActive: true,
    documentsVerified: true,
    latitude: -17.7891,
    longitude: -63.1724,
    tags: ['Tableros', 'Urgencias'],
  ),
  Professional(
    id: 'p3',
    name: 'José Flores',
    specialty: 'Jardinero',
    categoryId: 'jardineria',
    city: 'Santa Cruz · Equipetrol',
    initials: 'JF',
    rating: 4.7,
    jobs: 61,
    distanceKm: 1.6,
    available: true,
    isActive: true,
    documentsVerified: true,
    latitude: -17.7802,
    longitude: -63.1918,
  ),
  Professional(
    id: 'p4',
    name: 'Ana Choque',
    specialty: 'Limpieza del hogar',
    categoryId: 'limpieza',
    city: 'Cochabamba · Cala Cala',
    initials: 'AC',
    rating: 5.0,
    jobs: 210,
    distanceKm: 412,
    available: true,
    isActive: true,
    documentsVerified: true,
    latitude: -17.3895,
    longitude: -66.1568,
    tags: ['Hogar', 'Profunda'],
  ),
  Professional(
    id: 'p5',
    name: 'Luis Vargas',
    specialty: 'Albañil',
    categoryId: 'construccion',
    city: 'La Paz · Miraflores',
    initials: 'LV',
    rating: 4.6,
    jobs: 77,
    distanceKm: 540,
    available: false,
    isActive: false,
    documentsVerified: false,
    latitude: -16.499,
    longitude: -68.123,
  ),
  Professional(
    id: 'p6',
    name: 'Patricia Rojas',
    specialty: 'Refrigeración',
    categoryId: 'refrigeracion',
    city: 'Sucre · Centro',
    initials: 'PR',
    rating: 4.8,
    jobs: 55,
    distanceKm: 260,
    available: true,
    isActive: true,
    documentsVerified: false,
    latitude: -19.0478,
    longitude: -65.2596,
  ),
  Professional(
    id: 'p7',
    name: 'Diego Torrez',
    specialty: 'Pintor',
    categoryId: 'pintura',
    city: 'Santa Cruz · Plan 3000',
    initials: 'DT',
    rating: 4.7,
    jobs: 43,
    distanceKm: 3.4,
    available: false,
    isActive: true,
    documentsVerified: false,
    latitude: -17.8162,
    longitude: -63.1648,
  ),
  Professional(
    id: 'p8',
    name: 'Elena Gutiérrez',
    specialty: 'Cerrajera',
    categoryId: 'cerrajeria',
    city: 'La Paz · San Pedro',
    initials: 'EG',
    rating: 4.9,
    jobs: 89,
    distanceKm: 538,
    available: true,
    isActive: true,
    documentsVerified: true,
    latitude: -16.505,
    longitude: -68.137,
  ),
];

List<Professional> professionalsFor(String categoryId) {
  final matched = professionals
      .where((p) => p.categoryId == categoryId)
      .toList();
  if (matched.isNotEmpty) return matched;
  return professionals.take(3).toList();
}

/// Activos destacados da plataforma. Sem catálogo local de demonstração.
List<Professional> professionalsReadyToHelp(
  String categoryId, {
  Iterable<Professional>? catalog,
  String? categoryName,
}) {
  final needle = categoryId.toLowerCase();
  final named = (categoryName ?? '').trim().toLowerCase();
  final list = (catalog ?? const <Professional>[])
      .where((p) => p.canHelpClient)
      .where((p) {
        if (categoryId.isEmpty) return true;
        if (p.categoryId == categoryId) return true;
        final label = p.categoryLabel.toLowerCase();
        if (named.isNotEmpty && (label == named || label.contains(named))) {
          return true;
        }
        return (p.categoryName ?? '').toLowerCase().contains(needle) ||
            p.specialty.toLowerCase().contains(needle);
      })
      .toList()
    ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
  return list;
}

TradeCategory? tradeById(String id) {
  for (final trade in trades) {
    if (trade.id == id) return trade;
  }
  return null;
}

IconData iconForCategoryName(String nome) {
  final blob = nome.toLowerCase();
  if (blob.contains('plom')) return Icons.water_drop_outlined;
  if (blob.contains('electric')) return Icons.bolt_outlined;
  if (blob.contains('pint')) return Icons.format_paint_outlined;
  if (blob.contains('limp')) return Icons.cleaning_services_outlined;
  if (blob.contains('belleza') || blob.contains('barber')) {
    return Icons.spa_outlined;
  }
  if (blob.contains('jard')) return Icons.yard_outlined;
  if (blob.contains('construc') || blob.contains('albañ')) {
    return Icons.apartment_outlined;
  }
  if (blob.contains('tecno') || blob.contains('comput')) {
    return Icons.laptop_mac_outlined;
  }
  if (blob.contains('cerraj')) return Icons.lock_open_outlined;
  if (blob.contains('refriger') || blob.contains('aire')) {
    return Icons.ac_unit_outlined;
  }
  if (blob.contains('mecán') || blob.contains('mecan') || blob.contains('vehíc')) {
    return Icons.directions_car_outlined;
  }
  return Icons.handyman_outlined;
}
