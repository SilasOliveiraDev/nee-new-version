import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nee/domain/availability.dart';
import 'package:nee/domain/chat.dart';
import 'package:nee/models.dart';

void main() {
  test('buffer overlap blocks 15:00-17:00 against 14:00-16:00', () {
    final aStart = DateTime(2026, 8, 23, 14);
    final aEnd = DateTime(2026, 8, 23, 16);
    final bStart = DateTime(2026, 8, 23, 15);
    final bEnd = DateTime(2026, 8, 23, 17);
    expect(
      scheduleOverlaps(
        aStart: aStart,
        aEnd: aEnd,
        bStart: bStart,
        bEnd: bEnd,
      ),
      isTrue,
    );
  });

  test('next slot is occupied end plus buffer', () {
    expect(
      nextSlotAfter(occupiedEnd: DateTime(2026, 8, 23, 16), bufferMinutes: 15),
      DateTime(2026, 8, 23, 16, 15),
    );
    expect(
      scheduleOverlaps(
        aStart: DateTime(2026, 8, 23, 14),
        aEnd: DateTime(2026, 8, 23, 16),
        bStart: DateTime(2026, 8, 23, 16, 15),
        bEnd: DateTime(2026, 8, 23, 17, 15),
      ),
      isFalse,
    );
  });

  test('closed conversation cannot send', () {
    final closed = ServiceConversation(
      id: 'c',
      requestId: '1',
      customerId: 'u',
      professionalId: 'p',
      status: ConversationStatus.serviceCompleted,
      mode: ConversationMode.completed,
    );
    expect(closed.canSend, isFalse);
  });

  test('direct request is not a confirmed service', () {
    final request = ServiceRequest(
      id: 'r1',
      category: const ServiceCategory(
        id: 'plomeria',
        name: 'Plomería',
        icon: Icons.plumbing_outlined,
        hint: '',
      ),
      description: 'Fuga',
      location: 'Equipetrol',
      createdAt: DateTime(2026, 8, 23),
      kind: RequestKind.direct,
      directStatus: DirectStatus.pending,
    );
    expect(request.status, RequestStatus.sent);
    expect(request.directStatus, isNot(DirectStatus.confirmed));
    expect(request.stageLabel, 'Esperando respuesta');
  });

  test('busy professional still can appear to clients', () {
    final pro = Professional(
      id: 'p',
      name: 'Carlos Méndez',
      specialty: 'Plomero',
      categoryId: 'plomeria',
      city: 'SC',
      initials: 'CM',
      rating: 4.9,
      jobs: 214,
      available: false,
      isDestaque: true,
      opsStatus: ProOpsStatus.busy,
      nextAvailableAt: DateTime(2026, 8, 23, 17, 30),
    );
    expect(pro.canHelpClient, isTrue);
    expect(pro.availability.primaryLabel, contains('17:30'));
  });

  test('direct hire copy stays with the chosen professional', () {
    final request = ServiceRequest(
      id: 'r-direct',
      category: const ServiceCategory(
        id: 'plomeria',
        name: 'Plomería',
        icon: Icons.plumbing_outlined,
        hint: '',
      ),
      description: 'Fuga de agua',
      location: 'Urubó',
      createdAt: DateTime(2026, 8, 24),
      kind: RequestKind.direct,
      directStatus: DirectStatus.pending,
      professional: Professional(
        id: 'jhonni',
        name: 'Jhonni',
        specialty: 'Fugas',
        categoryId: 'plomeria',
        city: 'Santa Cruz',
        initials: 'JH',
        rating: 5,
        jobs: 12,
        verified: true,
      ),
    );
    expect(request.isDirect, isTrue);
    expect(request.stageLabel, 'Esperando respuesta');
    expect(request.status, isNot(RequestStatus.professionalFound));
  });

  test('busy availability hides asap window', () {
    const free = AvailabilityView(
      status: ProOpsStatus.available,
      acceptingRequests: true,
    );
    final busy = AvailabilityView(
      status: ProOpsStatus.busy,
      acceptingRequests: true,
      nextAvailableAt: DateTime(2026, 8, 24, 16, 30),
    );
    expect(free.availableNow, isTrue);
    expect(busy.availableNow, isFalse);
    expect(busy.primaryLabel, contains('16:30'));
  });
}
