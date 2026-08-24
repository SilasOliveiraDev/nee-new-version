import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/account_repository.dart';
import 'data/chat_repository.dart';
import 'data/hire_repository.dart';
import 'data/nee_repository.dart';
import 'data/nee_supabase.dart';
import 'data/professional_mapper.dart';
import 'data/users_row.dart';
import 'domain/account.dart';
import 'domain/availability.dart';
import 'domain/cancellation.dart';
import 'domain/chat.dart';
import 'domain/request_lifecycle.dart';
import 'mock_data.dart';
import 'models.dart';
import 'places/place_models.dart';
import 'service_schedule.dart';

class NeeAppState extends ChangeNotifier {
  final user = UserAccount();
  final requests = <ServiceRequest>[];
  final places = <UserPlace>[];
  var step = OnboardingStep.splash;
  AppRole? activeRole;
  String? smsCode;
  DateTime? smsSentAt;
  var hydrated = false;
  int _id = 0;
  List<Professional> directory = [];
  var cancellationPolicy = CancellationPolicy.fallback;
  UserRestriction? createBlock;
  final cancelEvents = <CancelEvent>[];
  final threads = <ServiceConversation>[];
  final messagesByConversation = <String, List<ChatMessage>>{};
  final incomingDirect = <ServiceRequest>[];
  String? viewingConversationId;
  int clientNavIndex = 0;
  var solicitudesHistory = false;
  NotificationPrefs notifPrefs = NotificationPrefs();
  String languageCode = 'es';

  bool get blocksNewSolicitud => createBlock?.isActive ?? false;

  String get customerId =>
      user.supabaseUuid ?? NeeRepository.sessionUserId ?? 'local-customer';

  int get unreadTotal =>
      threads.fold(0, (sum, thread) => sum + thread.unread);

  bool get needsOnboarding => step != OnboardingStep.done;

  List<ServiceRequest> get incomingForPro {
    final mine = user.supabaseUuid;
    final direct = incomingDirect
        .where(
          (r) =>
              r.directStatus == DirectStatus.pending &&
              (mine == null || r.targetProfessionalId == mine),
        )
        .toList();
    final ids = user.provider.specialties;
    if (ids.isEmpty && user.provider.primaryCategoryId == null) {
      return direct;
    }
    final market = requests
        .where(
          (r) =>
              !r.isDirect &&
              (ids.contains(r.category.id) ||
                  r.category.id == user.provider.primaryCategoryId) &&
              r.status == RequestStatus.sent,
        )
        .toList();
    return [...direct, ...market];
  }

  List<ServiceRequest> get activeForPro {
    return requests
        .where(
          (r) =>
              r.professional != null &&
              r.status != RequestStatus.sent &&
              !RequestLifecycle.isClosed(r.status),
        )
        .toList();
  }

  List<ServiceRequest> get historyForPro {
    return requests.where((r) => r.status == RequestStatus.completed).toList();
  }

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nee_onboarding');
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    hydrated = true;
    _forceClient();
    _seedPlacesIfNeeded();
    if (step == OnboardingStep.done) {
      seedDemoSolicitudes();
    }
    unawaited(_refreshRemote());
    notifyListeners();
  }

  Future<void> _refreshRemote() async {
    await NeeRepository.refreshCancellationContext(this);
    await NeeRepository.loadAddresses(this);
    await NeeRepository.loadFeaturedProfessionals(this);
    await HireRepository.applyStatuses(directory);
    await NeeRepository.loadClientRequests(this);
    await refreshIncomingDirect();
    await hydrateChat();
    if (customerId != 'local-customer') {
      notifPrefs = await AccountRepository.loadPrefs(customerId);
    }
    persist();
    notifyListeners();
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nee_onboarding', jsonEncode(_toJson()));
    unawaited(NeeRepository.syncUser(this));
  }

  void goTo(OnboardingStep value) {
    step = value;
    persist();
    notifyListeners();
  }

  void addPlace(UserPlace place) {
    if (place.isDefault) {
      for (final item in places) {
        item.isDefault = false;
      }
      _copyPlaceToRegistered(place);
    }
    places.add(place);
    persist();
    unawaited(NeeRepository.upsertAddress(this, place));
    notifyListeners();
  }

  void updatePlace(UserPlace place) {
    persist();
    unawaited(NeeRepository.upsertAddress(this, place));
    notifyListeners();
  }

  void setDefaultPlace(UserPlace place) {
    for (final item in places) {
      item.isDefault = item.id == place.id;
    }
    _copyPlaceToRegistered(place);
    persist();
    unawaited(NeeRepository.upsertAddress(this, place));
    notifyListeners();
  }

  Future<void> removePlace(UserPlace place) async {
    places.removeWhere((item) => item.id == place.id);
    if (place.isDefault && places.isNotEmpty) {
      setDefaultPlace(places.first);
    }
    persist();
    await NeeRepository.deleteAddress(this, place);
    notifyListeners();
  }

  void goClientTab(int value, {bool? history}) {
    clientNavIndex = value;
    if (history != null) solicitudesHistory = history;
    notifyListeners();
  }

  Future<void> saveNotifPrefs() async {
    persist();
    notifyListeners();
    final id = customerId;
    if (id != 'local-customer') {
      await AccountRepository.savePrefs(id, notifPrefs);
    }
  }

  void _copyPlaceToRegistered(UserPlace place) {
    user.registeredAddress
      ..street = place.street
      ..number = place.streetNumber
      ..zone = place.neighborhood
      ..city = place.city
      ..department = place.state
      ..country = place.country
      ..latitude = place.latitude
      ..longitude = place.longitude
      ..reference = place.reference;
  }

  Future<void> confirmRegisteredAddress() async {
    persist();
    await NeeRepository.upsertRegisteredAddress(this);
    notifyListeners();
  }

  List<Professional> get highlightedProfessionals =>
      directory.where((p) => p.isDestaque).toList();

  List<Professional> readyToHelp(String categoryId) {
    return professionalsReadyToHelp(categoryId, catalog: directory);
  }

  UserPlace? get defaultPlace {
    for (final place in places) {
      if (place.isDefault) return place;
    }
    return places.isEmpty ? null : places.first;
  }

  void _seedPlacesIfNeeded() {
    if (places.isNotEmpty) return;
    final source = user.registeredAddress.summary.isNotEmpty
        ? user.registeredAddress
        : user.currentLocation;
    if (!source.isFilled) return;
    places.add(
      UserPlace(
        id: 'home',
        type: PlaceType.home,
        street: source.street,
        streetNumber: source.number,
        neighborhood: source.zone,
        city: source.city,
        state: source.department,
        country: source.country.isEmpty ? 'Bolivia' : source.country,
        latitude: source.latitude,
        longitude: source.longitude,
        reference: source.reference,
        formattedAddress: source.summary,
        isDefault: true,
        isLocationConfirmed: source.hasCoords,
      ),
    );
    persist();
  }

  void _forceClient() {
    user.roles
      ..clear()
      ..add(AppRole.customer);
    activeRole = AppRole.customer;
    final skipToPrefs =
        step == OnboardingStep.role ||
        (step.index >= OnboardingStep.providerCategory.index &&
            step != OnboardingStep.done);
    if (skipToPrefs) {
      step = OnboardingStep.customerPrefs;
    }
  }

  void seedDemoSolicitudes() {
    if (requests.isNotEmpty) return;
    final plomeria = categories.firstWhere((c) => c.id == 'plomeria');
    final tech = categories.firstWhere((c) => c.id == 'tech');
    requests.addAll([
      ServiceRequest(
        id: 'demo1',
        category: categories.firstWhere((c) => c.id == 'electricidad'),
        description: 'Reparación eléctrica',
        location: user.fullAddress,
        createdAt: DateTime.now(),
        status: RequestStatus.professionalFound,
        interestedCount: 3,
      ),
      ServiceRequest(
        id: 'demo2',
        category: plomeria,
        description: 'Reparación de tubería',
        location: user.fullAddress,
        createdAt: DateTime.now(),
        professional: professionals.first,
        status: RequestStatus.accepted,
      ),
      ServiceRequest(
        id: 'demo3',
        category: tech,
        description: 'Soporte técnico laptop',
        location: user.fullAddress,
        createdAt: DateTime.now(),
        status: RequestStatus.completed,
      ),
    ]);
  }

  void activateRole(AppRole role) {
    finishCustomer();
  }

  void applyUserRow(Map<String, dynamic> row) {
    final name = (row['name'] as String? ?? '').trim();
    if (name.isNotEmpty && name != 'Ñee') {
      final parts = name.split(RegExp(r'\s+'));
      user.firstName = parts.first;
      user.lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    user
      ..email = row['email'] as String? ?? user.email
      ..phone = row['phone'] as String? ?? user.phone
      ..sexo = row['sexo'] as String? ?? user.sexo
      ..phoneVerified = row['verified'] as bool? ?? user.phoneVerified
      ..supabaseUuid = row['UUID'] as String? ?? user.supabaseUuid;
    final id = row['id'];
    if (id is int) user.supabaseRowId = id;
    if (id is num) user.supabaseRowId = id.toInt();
    final city = row['city'] as String? ?? row['cidade'] as String? ?? '';
    if (city.isNotEmpty) {
      user.currentLocation.city = city;
      user.registeredAddress.city = city;
    }
    final street = row['adress'] as String? ?? '';
    if (street.isNotEmpty) user.registeredAddress.street = street;
    final country = row['country'] as String? ?? '';
    if (country.isNotEmpty) {
      user.currentLocation.country = country;
      user.registeredAddress.country = country;
    }
    final zone = row['Zona'] as String? ?? '';
    if (zone.isNotEmpty) user.registeredAddress.zone = zone;
    final number = row['numeroresidencia'] as String? ?? '';
    if (number.isNotEmpty) user.registeredAddress.number = number;
    final extra = row['complemento'] as String? ?? '';
    if (extra.isNotEmpty) user.registeredAddress.reference = extra;
    final coords = parseLatLng(row['latlng']);
    if (coords.lat != null && coords.lng != null) {
      user.registeredAddress
        ..latitude = coords.lat
        ..longitude = coords.lng;
      user.currentLocation
        ..latitude = coords.lat
        ..longitude = coords.lng;
    }
  }

  Future<void> enterAfterLogin() async {
    final row = await NeeRepository.fetchOwnUser();
    if (row != null) applyUserRow(row);
    await NeeRepository.loadAddresses(this);
    await NeeRepository.loadFeaturedProfessionals(this);
    await NeeRepository.loadClientRequests(this);
    final done =
        row != null &&
        ((row['step'] as String?) == 'done' || user.firstName.isNotEmpty);
    if (done) {
      finishLogin();
      return;
    }
    goTo(OnboardingStep.geo);
  }

  void finishLogin() {
    if (user.firstName.trim().isEmpty) {
      user.firstName = 'Alex';
      user.lastName = 'Quispe';
    }
    if (user.registeredAddress.city.isEmpty &&
        user.currentLocation.city.isEmpty) {
      user.currentLocation
        ..city = 'Santa Cruz'
        ..country = 'Bolivia';
    }
    finishCustomer();
  }

  void finishCustomer() {
    user.roles
      ..clear()
      ..add(AppRole.customer);
    activeRole = AppRole.customer;
    step = OnboardingStep.done;
    seedDemoSolicitudes();
    persist();
    unawaited(NeeRepository.upsertRegisteredAddress(this));
    unawaited(() async {
      await NeeRepository.loadFeaturedProfessionals(this);
      await NeeRepository.loadClientRequests(this);
      notifyListeners();
    }());
    notifyListeners();
  }

  void publishProvider() {
    user.roles.add(AppRole.provider);
    user.provider.published = true;
    user.provider.verificationLevel = VerificationLevel.basic;
    activeRole = AppRole.provider;
    step = OnboardingStep.done;
    persist();
    notifyListeners();
  }

  void restartOnboarding() {
    unawaited(NeeRepository.signOut());
    threads.clear();
    messagesByConversation.clear();
    clientNavIndex = 0;
    step = OnboardingStep.value;
    persist();
    notifyListeners();
  }

  void sendSmsCode() {
    smsCode = '123456';
    smsSentAt = DateTime.now();
    persist();
    notifyListeners();
  }

  bool verifySms(String code) {
    final ok = code.trim() == (smsCode ?? '123456');
    if (ok) {
      user.phoneVerified = true;
      persist();
      notifyListeners();
    }
    return ok;
  }

  void notifyAndSave() {
    persist();
    notifyListeners();
  }

  bool _sameRequest(ServiceConversation thread, ServiceRequest request) {
    return thread.requestId == request.id ||
        thread.requestId == '${request.remoteId}';
  }

  void _replaceThreadId(String from, String to) {
    if (from == to) return;
    final index = threads.indexWhere((t) => t.id == from);
    if (index < 0) return;
    final old = threads[index];
    final next = ServiceConversation(
      id: to,
      requestId: old.requestId,
      customerId: old.customerId,
      professionalId: old.professionalId,
      offerId: old.offerId,
      mode: old.mode,
      status: old.status,
      lastMessageAt: old.lastMessageAt,
      lastPreview: old.lastPreview,
      unread: old.unread,
      professionalName: old.professionalName,
      professionalInitials: old.professionalInitials,
      requestTitle: old.requestTitle,
    );
    threads[index] = next;
    messagesByConversation[to] = messagesByConversation.remove(from) ?? [];
  }

  void _enrich(ServiceConversation thread) {
    for (final request in requests) {
      if (!_sameRequest(thread, request)) continue;
      thread.requestTitle = request.description;
      Professional? pro;
      for (final offer in request.offers) {
        if (offer.professional.id == thread.professionalId) {
          pro = offer.professional;
          break;
        }
      }
      pro ??= request.professional?.id == thread.professionalId
          ? request.professional
          : null;
      if (pro == null) {
        for (final item in directory) {
          if (item.id == thread.professionalId) {
            pro = item;
            break;
          }
        }
      }
      if (pro != null) {
        thread.professionalName = pro.name;
        thread.professionalInitials = pro.initials;
      }
    }
  }

  ServiceRequest? requestForThread(ServiceConversation thread) {
    for (final request in requests) {
      if (_sameRequest(thread, request)) return request;
    }
    return null;
  }

  ServiceOffer? offerForThread(ServiceConversation thread) {
    final request = requestForThread(thread);
    if (request == null) return null;
    for (final offer in request.offers) {
      if (offer.professional.id == thread.professionalId) return offer;
    }
    return null;
  }

  ServiceConversation? threadFor(ServiceRequest request, Professional professional) {
    for (final thread in threads) {
      if (_sameRequest(thread, request) &&
          thread.professionalId == professional.id) {
        return thread;
      }
    }
    return null;
  }

  Future<void> hydrateChat() async {
    ChatRepository.subscribe(
      onMessage: ingestMessage,
      onConversation: ingestConversationRow,
    );
    final remote = await ChatRepository.fetchThreads(customerId);
    if (remote.isNotEmpty) {
      threads
        ..clear()
        ..addAll(remote);
    }
    final unread = await ChatRepository.unreadCounts(customerId);
    for (final thread in threads) {
      _enrich(thread);
      thread.unread = unread[thread.id] ?? thread.unread;
    }
    notifyListeners();
  }

  void ingestConversationRow(Map<String, dynamic> row) {
    final incoming = ChatRepository.conversationFromRow(row);
    final index = threads.indexWhere((t) => t.id == incoming.id);
    if (index >= 0) {
      threads[index]
        ..mode = incoming.mode
        ..status = incoming.status
        ..lastPreview = incoming.lastPreview.isEmpty
            ? threads[index].lastPreview
            : incoming.lastPreview
        ..lastMessageAt = incoming.lastMessageAt ?? threads[index].lastMessageAt
        ..offerId = incoming.offerId ?? threads[index].offerId;
      _enrich(threads[index]);
    } else {
      _enrich(incoming);
      threads.insert(0, incoming);
    }
    notifyListeners();
  }

  void ingestMessage(ChatMessage message) {
    final list = messagesByConversation.putIfAbsent(
      message.conversationId,
      () => <ChatMessage>[],
    );
    final duplicate = list.indexWhere(
      (m) =>
          m.id == message.id ||
          (m.clientKey != null && m.clientKey == message.clientKey),
    );
    if (duplicate >= 0) {
      list[duplicate] = message;
    } else {
      list.add(message);
    }
    final threadIndex = threads.indexWhere((t) => t.id == message.conversationId);
    if (threadIndex >= 0) {
      final thread = threads[threadIndex];
      thread.lastPreview = message.content;
      thread.lastMessageAt = message.sentAt;
      final mine = message.senderId == customerId || message.isMine;
      if (!mine &&
          !message.isSystem &&
          viewingConversationId != message.conversationId) {
        thread.unread += 1;
      }
      threads.removeAt(threadIndex);
      threads.insert(0, thread);
    }
    notifyListeners();
  }

  Future<ServiceConversation> openConversation(
    ServiceRequest request,
    ServiceOffer offer,
  ) async {
    final existing = threadFor(request, offer.professional);
    if (existing != null) {
      await loadMessages(existing);
      return existing;
    }
    final created = await ChatRepository.upsertConversation(
      request: request,
      offer: offer,
      customerId: customerId,
    );
    _enrich(created);
    threads.removeWhere((t) => t.id == created.id);
    threads.insert(0, created);
    notifyListeners();
    await loadMessages(created);
    return created;
  }

  Future<void> loadMessages(ServiceConversation conversation) async {
    final remote = await ChatRepository.fetchMessages(conversation.id);
    if (remote.isNotEmpty) {
      messagesByConversation[conversation.id] = remote;
    } else {
      messagesByConversation.putIfAbsent(conversation.id, () => []);
    }
    notifyListeners();
  }

  Future<void> markThreadRead(ServiceConversation conversation) async {
    viewingConversationId = conversation.id;
    conversation.unread = 0;
    notifyListeners();
    await ChatRepository.markRead(conversation.id);
  }

  Future<void> refreshIncomingDirect() async {
    final id = user.supabaseUuid ?? NeeRepository.sessionUserId;
    if (id == null) return;
    final loaded = await HireRepository.loadIncomingDirect(
      professionalId: id,
      mapRow: NeeRepository.requestFromRow,
    );
    incomingDirect
      ..clear()
      ..addAll(loaded);
  }

  Future<ChatMessage> sendText(
    ServiceConversation conversation,
    String text,
  ) async {
    if (!conversation.canSend) {
      return ChatMessage(
        id: 'blocked',
        conversationId: conversation.id,
        senderType: ChatSender.customer,
        type: ChatMessageType.text,
        content: text,
        status: DeliveryStatus.failed,
      );
    }
    final key = '${DateTime.now().microsecondsSinceEpoch}-$customerId';
    final pending = ChatMessage(
      id: key,
      conversationId: conversation.id,
      senderId: customerId,
      senderType: ChatSender.customer,
      type: ChatMessageType.text,
      content: text,
      clientKey: key,
      status: DeliveryStatus.sending,
    );
    ingestMessage(pending);
    final saved = await ChatRepository.insertText(
      conversation: conversation,
      text: text,
      clientKey: key,
    );
    ingestMessage(saved);
    return saved;
  }

  Future<ChatMessage> sendImage(
    ServiceConversation conversation,
    Uint8List bytes,
  ) async {
    final key = '${DateTime.now().microsecondsSinceEpoch}-$customerId-img';
    final pending = ChatMessage(
      id: key,
      conversationId: conversation.id,
      senderId: customerId,
      senderType: ChatSender.customer,
      type: ChatMessageType.image,
      content: 'Foto',
      clientKey: key,
      status: DeliveryStatus.sending,
      localBytes: bytes,
    );
    ingestMessage(pending);
    final saved = await ChatRepository.insertImage(
      conversation: conversation,
      bytes: bytes,
      clientKey: key,
    );
    ingestMessage(saved);
    return saved;
  }

  Future<void> retryMessage(
    ServiceConversation conversation,
    ChatMessage message,
  ) async {
    if (message.status != DeliveryStatus.failed) return;
    if (message.type == ChatMessageType.image && message.localBytes != null) {
      await sendImage(conversation, Uint8List.fromList(message.localBytes!));
      return;
    }
    await sendText(conversation, message.content);
  }

  ServiceRequest createRequest({
    required ServiceCategory category,
    required String description,
    required String location,
    String urgency = '',
    int photoCount = 0,
    bool hasAudio = false,
    bool hasVideo = false,
    String specialty = '',
    int interestedCount = 0,
    ServiceSchedule? schedule,
    ServiceLocationSnapshot? serviceLocation,
    RequestKind kind = RequestKind.marketplace,
    Professional? professional,
    DirectStatus? directStatus,
    DateTime? requestedStart,
    DateTime? requestedEnd,
  }) {
    if (blocksNewSolicitud) {
      throw StateError('CREATE_SERVICE_TEMPORARILY_BLOCKED');
    }
    _id += 1;
    final request = ServiceRequest(
      id: 'r$_id',
      category: category,
      description: description,
      location: location,
      createdAt: DateTime.now(),
      urgency: urgency,
      photoCount: photoCount,
      hasAudio: hasAudio,
      hasVideo: hasVideo,
      specialty: specialty,
      interestedCount: interestedCount,
      schedule: schedule,
      serviceLocation: serviceLocation,
      kind: kind,
      directStatus: directStatus,
      targetProfessionalId: professional?.id,
      requestedStart: requestedStart,
      requestedEnd: requestedEnd,
      professional: professional,
    );
    requests.insert(0, request);
    notifyListeners();
    unawaited(_persistNewRequest(request));
    return request;
  }

  Future<void> _persistNewRequest(ServiceRequest request) async {
    await NeeRepository.insertRequest(this, request);
    if (request.isDirect && request.remoteId != null) {
      await HireRepository.notifyDirect(request.remoteId!);
    }
  }

  void ensureOffers(ServiceRequest request) {
    if (request.isDirect) return;
    if (request.remoteId != null) return;
    if (request.offers.isNotEmpty) return;
    if (request.status != RequestStatus.sent &&
        request.status != RequestStatus.professionalFound) {
      return;
    }
    final ready = readyToHelp(request.category.id);
    const notes = [
      'Puedo llegar aproximadamente a las 15:30.',
      'Tengo agenda hoy por la tarde.',
      'Puedo pasar mañana temprano si te viene bien.',
    ];
    const prices = [120.0, 150.0, 90.0];
    for (var i = 0; i < ready.length && i < 3; i++) {
      request.offers.add(
        ServiceOffer(
          id: '${request.id}-o$i',
          professional: ready[i],
          message: notes[i],
          priceBs: prices[i],
          availability: ready[i].available
              ? 'Disponible hoy'
              : 'Agenda limitada',
        ),
      );
    }
    if (request.offers.isNotEmpty) {
      request.interestedCount = request.offers.length;
      if (request.status == RequestStatus.sent) {
        request.status = RequestStatus.professionalFound;
      }
    }
  }

  void addOffer(ServiceRequest request, Professional professional) {
    if (request.offers.any((o) => o.professional.id == professional.id)) {
      return;
    }
    request.offers.add(
      ServiceOffer(
        id: '${request.id}-${professional.id}',
        professional: professional,
        message: 'Puedo ayudarte con este servicio.',
        priceBs: 120,
      ),
    );
    request.interestedCount = request.offers.length;
    request.status = RequestStatus.professionalFound;
    notifyListeners();
  }

  Future<void> selectProfessional(
    ServiceRequest request,
    ServiceOffer offer,
  ) async {
    if (blocksNewSolicitud) return;
    String? conversationId;
    if (request.remoteId != null) {
      conversationId = await ChatRepository.confirmProfessional(
        requestId: request.remoteId!,
        offerId: offer.id,
        professionalId: offer.professional.id,
      );
    }
    request
      ..professional = offer.professional
      ..status = RequestStatus.accepted;
    for (final thread in threads.where((t) => _sameRequest(t, request))) {
      if (thread.professionalId == offer.professional.id) {
        thread
          ..mode = ConversationMode.activeService
          ..status = ConversationStatus.active
          ..offerId = offer.id;
        if (conversationId != null && conversationId != thread.id) {
          _replaceThreadId(thread.id, conversationId);
        }
      } else if (thread.status == ConversationStatus.active) {
        thread.status = ConversationStatus.closedNotSelected;
      }
    }
    persist();
    notifyListeners();
    if (conversationId == null) {
      _ensureSelectionMessages(request, offer);
    }
    unawaited(hydrateChat());
  }

  void _ensureSelectionMessages(ServiceRequest request, ServiceOffer offer) {
    ServiceConversation? thread;
    for (final item in threads) {
      if (_sameRequest(item, request) &&
          item.professionalId == offer.professional.id) {
        thread = item;
        break;
      }
    }
    if (thread == null) return;
    final list = messagesByConversation.putIfAbsent(thread.id, () => []);
    if (list.any((m) => m.systemEvent == 'PROPOSAL_ACCEPTED')) return;
    final service = request.category.name.isEmpty
        ? request.description
        : request.category.name;
    ingestMessage(
      ChatMessage(
        id: 'sys-sel-${thread.id}',
        conversationId: thread.id,
        senderType: ChatSender.system,
        type: ChatMessageType.system,
        content:
            'Has elegido a ${offer.professional.name} para realizar el servicio.',
        systemEvent: 'PROFESSIONAL_SELECTED',
        audience: 'CUSTOMER',
      ),
    );
    ingestMessage(
      ChatMessage(
        id: 'sys-acc-${thread.id}',
        conversationId: thread.id,
        senderType: ChatSender.system,
        type: ChatMessageType.system,
        content: proposalAcceptedCopy(
          professionalName: offer.professional.name,
          customerName: user.fullName,
          service: service,
        ),
        systemEvent: 'PROPOSAL_ACCEPTED',
        audience: 'PROFESSIONAL',
      ),
    );
  }

  Future<void> reopenMatching(ServiceRequest request) async {
    final requestKey = request.remoteId?.toString() ?? request.id;
    await ChatRepository.appendSystemEvent(
      requestId: requestKey,
      event: 'MATCHING_REOPENED',
      content: 'Esta solicitud volvió a buscar otro profesional.',
      mode: 'COMPLETED',
      status: 'SERVICE_NOT_COMPLETED',
      professionalId: request.professional?.id,
    );
    request
      ..professional = null
      ..status = RequestStatus.sent
      ..offers.clear();
    ensureOffers(request);
    persist();
    notifyListeners();
    unawaited(hydrateChat());
  }

  Future<CancelOutcome> cancelAsCustomer(
    ServiceRequest request, {
    required CancelReason reason,
    required CancelPhase phase,
    String reasonText = '',
  }) async {
    final counts = countsTowardRapidCancel(reason);
    final atCancel = request.status;
    cancelEvents.add(
      CancelEvent(
        requestId: request.id,
        reason: reason,
        countsTowardRapidCancel: counts,
        createdAt: DateTime.now(),
        reasonText: reasonText,
      ),
    );
    if (reason == CancelReason.professionalCouldNotPerform) {
      request
        ..status = RequestStatus.notCompleted
        ..professional = null
        ..closedAt = DateTime.now()
        ..closeNote = reasonText.isNotEmpty
            ? reasonText
            : 'El profesional no pudo realizar el trabajo';
    } else {
      request
        ..status = RequestStatus.cancelledByCustomer
        ..closedAt = DateTime.now()
        ..closeNote = reasonText.isNotEmpty ? reasonText : labelForReason(reason);
    }
    final requestKey = request.remoteId?.toString() ?? request.id;
    if (reason == CancelReason.professionalCouldNotPerform) {
      await ChatRepository.appendSystemEvent(
        requestId: requestKey,
        event: 'SERVICE_CANCELLED',
        content: 'Este servicio fue cancelado.',
        mode: 'CANCELLED',
        status: 'SERVICE_NOT_COMPLETED',
      );
    } else {
      await ChatRepository.appendSystemEvent(
        requestId: requestKey,
        event: 'SERVICE_CANCELLED',
        content: 'Este servicio fue cancelado.',
        mode: 'CANCELLED',
        status: 'SERVICE_CANCELLED',
      );
    }
    await HireRepository.closeConversations(
      requestId: requestKey,
      reason: reason == CancelReason.professionalCouldNotPerform
          ? 'SERVICE_NOT_COMPLETED'
          : 'SERVICE_CANCELLED',
    );
    for (final thread in threads.where((t) => _sameRequest(t, request))) {
      thread
        ..status = reason == CancelReason.professionalCouldNotPerform
            ? ConversationStatus.serviceNotCompleted
            : ConversationStatus.serviceCancelled
        ..mode = ConversationMode.cancelled;
    }
    await NeeRepository.recordCancellation(
      this,
      request: request,
      reason: reason,
      countsTowardRapidCancel: counts,
      reasonText: reasonText,
      statusAtCancel: atCancel,
    );
    await NeeRepository.refreshCancellationContext(this);
    if (!NeeSupabase.ready && cancellationPolicy.rapidCancelEnabled && counts) {
      final window = DateTime.now().subtract(
        Duration(minutes: cancellationPolicy.windowMinutes),
      );
      final hits = cancelEvents
          .where(
            (e) => e.countsTowardRapidCancel && e.createdAt.isAfter(window),
          )
          .length;
      if (hits >= cancellationPolicy.limit) {
        createBlock = UserRestriction(
          expiresAt: DateTime.now().add(
            Duration(minutes: cancellationPolicy.restrictionMinutes),
          ),
        );
      }
    }
    persist();
    notifyListeners();
    return CancelOutcome(
      restriction: (createBlock?.isActive ?? false) ? createBlock : null,
    );
  }

  void attachProfessional(ServiceRequest request, Professional professional) {
    addOffer(request, professional);
  }

  void acceptAsProfessional(ServiceRequest request) {
    request
      ..professional = Professional(
        id: 'me',
        name: user.fullName,
        specialty: user.provider.title.isEmpty
            ? request.category.name
            : user.provider.title,
        categoryId: request.category.id,
        city: user.fullAddress,
        initials: user.initials,
        rating: 5.0,
        jobs: 0,
        available: true,
        isActive: true,
        documentsVerified: user.provider.documentVerified,
      )
      ..status = RequestStatus.accepted;
    notifyListeners();
  }

  void advanceStatus(ServiceRequest request) {
    switch (request.status) {
      case RequestStatus.sent:
        final ready = readyToHelp(request.category.id);
        if (ready.isNotEmpty) {
          attachProfessional(request, ready.first);
        }
        break;
      case RequestStatus.professionalFound:
        request.status = RequestStatus.accepted;
        break;
      case RequestStatus.accepted:
        request.status = RequestStatus.onTheWay;
        break;
      case RequestStatus.onTheWay:
        request.status = RequestStatus.inProgress;
        break;
      case RequestStatus.inProgress:
        request.status = RequestStatus.awaitingRating;
        break;
      case RequestStatus.awaitingRating:
      case RequestStatus.cancelledByCustomer:
      case RequestStatus.cancelledByProfessional:
      case RequestStatus.notCompleted:
      case RequestStatus.completed:
        break;
    }
    notifyListeners();
  }

  void confirmCompleted(ServiceRequest request) {
    request.status = RequestStatus.completed;
    final requestKey = request.remoteId?.toString() ?? request.id;
    unawaited(
      HireRepository.closeConversations(
        requestId: requestKey,
        reason: 'SERVICE_COMPLETED',
      ),
    );
    for (final thread in threads.where((t) => _sameRequest(t, request))) {
      thread
        ..status = ConversationStatus.serviceCompleted
        ..mode = ConversationMode.completed;
    }
    notifyListeners();
  }

  Future<HireResult> confirmDirectService(ServiceRequest request) async {
    if (request.remoteId != null) {
      final result = await HireRepository.confirm(request.remoteId!);
      if (!result.ok) return result;
      if (result.conversationId != null) {
        await hydrateChat();
      }
    }
    request
      ..directStatus = DirectStatus.confirmed
      ..status = RequestStatus.accepted;
    for (final thread in threads.where((t) => _sameRequest(t, request))) {
      thread
        ..mode = ConversationMode.activeService
        ..status = ConversationStatus.active;
    }
    notifyListeners();
    return const HireResult(ok: true);
  }

  Future<HireResult> acceptDirectToChat(ServiceRequest request) async {
    if (request.remoteId != null) {
      final result = await HireRepository.respond(
        requestId: request.remoteId!,
        accept: true,
      );
      if (!result.ok) return result;
    }
    request
      ..directStatus = DirectStatus.negotiation
      ..status = RequestStatus.professionalFound
      ..professional ??= Professional(
        id: user.supabaseUuid ?? 'me',
        name: user.fullName,
        specialty: user.provider.title,
        categoryId: request.category.id,
        city: user.fullAddress,
        initials: user.initials,
        rating: 5,
        jobs: 0,
      );
    notifyListeners();
    await hydrateChat();
    return const HireResult(ok: true);
  }

  Future<HireResult> sendFinalProposal(
    ServiceRequest request, {
    required DateTime start,
    required DateTime end,
    required double price,
    required int durationMinutes,
  }) async {
    if (request.remoteId != null) {
      final result = await HireRepository.propose(
        requestId: request.remoteId!,
        start: start,
        end: end,
        price: price,
        durationMinutes: durationMinutes,
      );
      if (!result.ok) return result;
    }
    request
      ..requestedStart = start
      ..requestedEnd = end
      ..agreedPrice = price
      ..agreedDurationMinutes = durationMinutes
      ..directStatus = DirectStatus.pendingConfirmation;
    notifyListeners();
    return const HireResult(ok: true);
  }

  Future<void> declineDirect(ServiceRequest request, String reason) async {
    if (request.remoteId != null) {
      await HireRepository.respond(
        requestId: request.remoteId!,
        accept: false,
        reason: reason,
      );
    }
    request
      ..directStatus = DirectStatus.declined
      ..declineReason = reason
      ..status = RequestStatus.cancelledByProfessional;
    incomingDirect.remove(request);
    notifyListeners();
  }

  Future<void> cancelDirectPending(ServiceRequest request) async {
    if (request.remoteId != null) {
      await HireRepository.cancelDirect(request.remoteId!);
    }
    request
      ..directStatus = DirectStatus.cancelled
      ..status = RequestStatus.cancelledByCustomer
      ..closedAt = DateTime.now();
    for (final thread in threads.where((t) => _sameRequest(t, request))) {
      thread
        ..status = ConversationStatus.serviceCancelled
        ..mode = ConversationMode.cancelled;
    }
    notifyListeners();
  }

  Map<String, dynamic> _toJson() {
    return {
      'step': step.name,
      'activeRole': activeRole?.name,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'phone': user.phone,
      'email': user.email,
      'sexo': user.sexo,
      'phoneVerified': user.phoneVerified,
      'birthDate': user.birthDate?.toIso8601String(),
      'roles': user.roles.map((e) => e.name).toList(),
      'prefs': user.preferredCategories.toList(),
      'current': _addressJson(user.currentLocation),
      'registered': _addressJson(user.registeredAddress),
      'title': user.provider.title,
      'bio': user.provider.bio,
      'years': user.provider.yearsExperience,
      'radius': user.provider.serviceRadiusKm,
      'primary': user.provider.primaryCategoryId,
      'specialties': user.provider.specialties.toList(),
      'published': user.provider.published,
      'worksAlone': user.provider.worksAlone,
      'emergency': user.provider.emergency,
      'weekends': user.provider.weekends,
      'invoices': user.provider.invoices,
      'residential': user.provider.residential,
      'commercial': user.provider.commercial,
      'supabaseUuid': user.supabaseUuid,
      'supabaseRowId': user.supabaseRowId,
      'places': places.map((e) => e.toJson()).toList(),
      'restrictionExpires': createBlock?.expiresAt.toIso8601String(),
      'policyWindow': cancellationPolicy.windowMinutes,
      'policyLimit': cancellationPolicy.limit,
      'policyMinutes': cancellationPolicy.restrictionMinutes,
      'policyEnabled': cancellationPolicy.rapidCancelEnabled,
      'users': UsersRow.toMap(user: user, step: step, activeRole: activeRole),
    };
  }

  void _fromJson(Map<String, dynamic> json) {
    step = OnboardingStep.values.firstWhere(
      (e) => e.name == json['step'],
      orElse: () => OnboardingStep.value,
    );
    if (json['step'] == 'loginPhone' || json['step'] == 'loginOtp') {
      step = OnboardingStep.login;
    }
    if (json['activeRole'] != null) {
      activeRole = AppRole.values.firstWhere(
        (e) => e.name == json['activeRole'],
        orElse: () => AppRole.customer,
      );
    }
    user
      ..firstName = json['firstName'] as String? ?? ''
      ..lastName = json['lastName'] as String? ?? ''
      ..phone = json['phone'] as String? ?? ''
      ..email = json['email'] as String? ?? ''
      ..sexo = json['sexo'] as String? ?? ''
      ..phoneVerified = json['phoneVerified'] as bool? ?? false
      ..supabaseUuid = json['supabaseUuid'] as String?
      ..supabaseRowId = json['supabaseRowId'] as int?;
    final birth = json['birthDate'] as String?;
    if (birth != null) user.birthDate = DateTime.tryParse(birth);
    user.roles
      ..clear()
      ..addAll(
        ((json['roles'] as List?) ?? []).map(
          (e) => AppRole.values.firstWhere((r) => r.name == e),
        ),
      );
    user.preferredCategories
      ..clear()
      ..addAll(((json['prefs'] as List?) ?? []).cast<String>());
    _readAddress(user.currentLocation, json['current']);
    _readAddress(user.registeredAddress, json['registered']);
    user.provider
      ..title = json['title'] as String? ?? ''
      ..bio = json['bio'] as String? ?? ''
      ..yearsExperience = json['years'] as int? ?? 1
      ..serviceRadiusKm = json['radius'] as int? ?? 10
      ..primaryCategoryId = json['primary'] as String?
      ..published = json['published'] as bool? ?? false
      ..worksAlone = json['worksAlone'] as bool? ?? true
      ..emergency = json['emergency'] as bool? ?? false
      ..weekends = json['weekends'] as bool? ?? false
      ..invoices = json['invoices'] as bool? ?? false
      ..residential = json['residential'] as bool? ?? true
      ..commercial = json['commercial'] as bool? ?? false;
    user.provider.specialties
      ..clear()
      ..addAll(((json['specialties'] as List?) ?? []).cast<String>());
    places
      ..clear()
      ..addAll(
        ((json['places'] as List?) ?? []).whereType<Map>().map(
          (e) => UserPlace.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    final expires = json['restrictionExpires'] as String?;
    if (expires != null) {
      final at = DateTime.tryParse(expires);
      if (at != null) createBlock = UserRestriction(expiresAt: at);
    }
    cancellationPolicy = CancellationPolicy(
      rapidCancelEnabled: json['policyEnabled'] as bool? ?? true,
      windowMinutes: json['policyWindow'] as int? ?? 5,
      limit: json['policyLimit'] as int? ?? 2,
      restrictionMinutes: json['policyMinutes'] as int? ?? 15,
    );
  }

  Map<String, dynamic> _addressJson(GeoAddress a) => {
    'lat': a.latitude,
    'lng': a.longitude,
    'country': a.country,
    'department': a.department,
    'city': a.city,
    'zone': a.zone,
    'street': a.street,
    'number': a.number,
    'reference': a.reference,
  };

  void _readAddress(GeoAddress a, dynamic raw) {
    if (raw is! Map) return;
    a
      ..latitude = (raw['lat'] as num?)?.toDouble()
      ..longitude = (raw['lng'] as num?)?.toDouble()
      ..country = raw['country'] as String? ?? 'Bolivia'
      ..department = raw['department'] as String? ?? ''
      ..city = raw['city'] as String? ?? ''
      ..zone = raw['zone'] as String? ?? ''
      ..street = raw['street'] as String? ?? ''
      ..number = raw['number'] as String? ?? ''
      ..reference = raw['reference'] as String? ?? '';
  }
}
