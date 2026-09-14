// GENERATED CODE — DO NOT EDIT.
// Source: packages/contracts/openapi/v1.json
// Regenerate: bun run generate:dart-client

abstract interface class V1JsonTransport {
  Future<Map<String, dynamic>> get(String path);

  Future<Map<String, dynamic>> post(String path, Map<String, Object?> body);
}

class V1ApiClient {
  const V1ApiClient(this._transport);

  final V1JsonTransport _transport;

  Future<V1MeResponseDto> getMe() async =>
      V1MeResponseDto.fromJson(await _transport.get('/v1/me'));

  Future<V1ClassroomListResponseDto> listClassrooms() async =>
      V1ClassroomListResponseDto.fromJson(
        await _transport.get('/v1/classrooms'),
      );

  Future<V1AuthContextResponseDto> getAuthContext() async =>
      V1AuthContextResponseDto.fromJson(
        await _transport.get('/v1/auth/context'),
      );

  Future<V1AuthDeviceListResponseDto> listAuthDevices() async =>
      V1AuthDeviceListResponseDto.fromJson(
        await _transport.get('/v1/auth/devices'),
      );

  Future<V1AuthDeviceRevokeResponseDto> revokeAuthDevice(
    V1AuthDeviceRevokeRequestDto request,
  ) async => V1AuthDeviceRevokeResponseDto.fromJson(
    await _transport.post('/v1/auth/devices/revoke', request.toJson()),
  );

  Future<V1AuthSignOutResponseDto> signOut(
    V1AuthSignOutRequestDto request,
  ) async => V1AuthSignOutResponseDto.fromJson(
    await _transport.post('/v1/auth/sign-out', request.toJson()),
  );

  Future<V1ReauthChallengeResponseDto> challengeReauth(
    V1ReauthChallengeRequestDto request,
  ) async => V1ReauthChallengeResponseDto.fromJson(
    await _transport.post('/v1/auth/reauth/challenge', request.toJson()),
  );

  Future<V1ReauthVerifyResponseDto> verifyReauth(
    V1ReauthVerifyRequestDto request,
  ) async => V1ReauthVerifyResponseDto.fromJson(
    await _transport.post('/v1/auth/reauth/verify', request.toJson()),
  );

  Future<V1IdentityLinkResponseDto> linkIdentity(
    V1IdentityLinkRequestDto request,
  ) async => V1IdentityLinkResponseDto.fromJson(
    await _transport.post('/v1/auth/identities/link', request.toJson()),
  );

  Future<V1IdentityUnlinkResponseDto> unlinkIdentity(
    V1IdentityUnlinkRequestDto request,
  ) async => V1IdentityUnlinkResponseDto.fromJson(
    await _transport.post('/v1/auth/identities/unlink', request.toJson()),
  );

  Future<V1DeletionImpactResponseDto> getDeletionImpact() async =>
      V1DeletionImpactResponseDto.fromJson(
        await _transport.get('/v1/account/deletion-impact'),
      );

  Future<V1DeletionRequestResponseDto> requestAccountDeletion(
    V1DeletionRequestRequestDto request,
  ) async => V1DeletionRequestResponseDto.fromJson(
    await _transport.post('/v1/account/deletion-request', request.toJson()),
  );

  Future<V1DeletionCancelResponseDto> cancelAccountDeletion() async =>
      V1DeletionCancelResponseDto.fromJson(
        await _transport.post(
          '/v1/account/deletion-cancel',
          const <String, Object?>{},
        ),
      );
}

class V1MembershipDto {
  const V1MembershipDto({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.role,
    required this.active,
  });

  factory V1MembershipDto.fromJson(Map<String, dynamic> json) =>
      V1MembershipDto(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        schoolName: json['school_name'] as String,
        role: json['role'] as String,
        active: json['active'] as bool,
      );

  final String id;
  final String schoolId;
  final String schoolName;
  final String role;
  final bool active;

  Map<String, Object?> toJson() => {
    'id': id,
    'school_id': schoolId,
    'school_name': schoolName,
    'role': role,
    'active': active,
  };
}

class V1MeResponseDto {
  const V1MeResponseDto({
    required this.id,
    required this.displayName,
    required this.email,
    required this.memberships,
    required this.environment,
    required this.activeTermId,
  });

  factory V1MeResponseDto.fromJson(Map<String, dynamic> json) =>
      V1MeResponseDto(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        email: json['email'] as String,
        memberships: [
          for (final item in json['memberships'] as List<dynamic>)
            V1MembershipDto.fromJson(item as Map<String, dynamic>),
        ],
        environment: json['environment'] as String,
        activeTermId: json['active_term_id'] as String?,
      );

  final String id;
  final String displayName;
  final String email;
  final List<V1MembershipDto> memberships;
  final String environment;
  final String? activeTermId;

  Map<String, Object?> toJson() => {
    'id': id,
    'display_name': displayName,
    'email': email,
    'memberships': [for (final item in memberships) item.toJson()],
    'environment': environment,
    'active_term_id': activeTermId,
  };
}

class V1ClassroomDto {
  const V1ClassroomDto({
    required this.id,
    required this.name,
    required this.grade,
    required this.section,
    required this.room,
    required this.studentCount,
    required this.weeklySessions,
    required this.termName,
  });

  factory V1ClassroomDto.fromJson(Map<String, dynamic> json) => V1ClassroomDto(
    id: json['id'] as String,
    name: json['name'] as String,
    grade: json['grade'] as String,
    section: json['section'] as String,
    room: json['room'] as String?,
    studentCount: json['student_count'] as int,
    weeklySessions: json['weekly_sessions'] as int?,
    termName: json['term_name'] as String?,
  );

  final String id;
  final String name;
  final String grade;
  final String section;
  final String? room;
  final int studentCount;
  final int? weeklySessions;
  final String? termName;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'grade': grade,
    'section': section,
    'room': room,
    'student_count': studentCount,
    'weekly_sessions': weeklySessions,
    'term_name': termName,
  };
}

class V1ClassroomListResponseDto {
  const V1ClassroomListResponseDto({required this.classrooms});

  factory V1ClassroomListResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomListResponseDto(
        classrooms: [
          for (final item in json['classrooms'] as List<dynamic>)
            V1ClassroomDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1ClassroomDto> classrooms;

  Map<String, Object?> toJson() => {
    'classrooms': [for (final item in classrooms) item.toJson()],
  };
}

class V1ContextMembershipDto {
  const V1ContextMembershipDto({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.schoolTimezone,
    required this.role,
    required this.activeTermId,
  });

  factory V1ContextMembershipDto.fromJson(Map<String, dynamic> json) =>
      V1ContextMembershipDto(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        schoolName: json['school_name'] as String,
        schoolTimezone: json['school_timezone'] as String,
        role: json['role'] as String,
        activeTermId: json['active_term_id'] as String?,
      );

  final String id;
  final String schoolId;
  final String schoolName;
  final String schoolTimezone;
  final String role;
  final String? activeTermId;

  Map<String, Object?> toJson() => {
    'id': id,
    'school_id': schoolId,
    'school_name': schoolName,
    'school_timezone': schoolTimezone,
    'role': role,
    'active_term_id': activeTermId,
  };
}

class V1AuthContextResponseDto {
  const V1AuthContextResponseDto({
    required this.userId,
    required this.displayName,
    required this.locale,
    required this.memberships,
    required this.membershipVersion,
    required this.assuranceLevel,
    required this.mfaEnrolled,
    required this.mfaRequired,
    required this.pendingDeletion,
  });

  factory V1AuthContextResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthContextResponseDto(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        locale: json['locale'] as String,
        memberships: [
          for (final item in json['memberships'] as List<dynamic>)
            V1ContextMembershipDto.fromJson(item as Map<String, dynamic>),
        ],
        membershipVersion: json['membership_version'] as String,
        assuranceLevel: json['assurance_level'] as String,
        mfaEnrolled: json['mfa_enrolled'] as bool,
        mfaRequired: json['mfa_required'] as bool,
        pendingDeletion: json['pending_deletion'] as bool,
      );

  final String userId;
  final String displayName;
  final String locale;
  final List<V1ContextMembershipDto> memberships;
  final String membershipVersion;
  final String assuranceLevel;
  final bool mfaEnrolled;
  final bool mfaRequired;
  final bool pendingDeletion;

  Map<String, Object?> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'locale': locale,
    'memberships': [for (final item in memberships) item.toJson()],
    'membership_version': membershipVersion,
    'assurance_level': assuranceLevel,
    'mfa_enrolled': mfaEnrolled,
    'mfa_required': mfaRequired,
    'pending_deletion': pendingDeletion,
  };
}

class V1AuthDeviceDto {
  const V1AuthDeviceDto({
    required this.id,
    required this.platform,
    required this.appVersion,
    required this.displayLabel,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.current,
  });

  factory V1AuthDeviceDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceDto(
        id: json['id'] as String,
        platform: json['platform'] as String,
        appVersion: json['app_version'] as String?,
        displayLabel: json['display_label'] as String?,
        firstSeenAt: json['first_seen_at'] as String,
        lastSeenAt: json['last_seen_at'] as String,
        revokedAt: json['revoked_at'] as String?,
        current: json['current'] as bool,
      );

  final String id;
  final String platform;
  final String? appVersion;
  final String? displayLabel;
  final String firstSeenAt;
  final String lastSeenAt;
  final String? revokedAt;
  final bool current;

  Map<String, Object?> toJson() => {
    'id': id,
    'platform': platform,
    'app_version': appVersion,
    'display_label': displayLabel,
    'first_seen_at': firstSeenAt,
    'last_seen_at': lastSeenAt,
    'revoked_at': revokedAt,
    'current': current,
  };
}

class V1AuthDeviceListResponseDto {
  const V1AuthDeviceListResponseDto({required this.devices});

  factory V1AuthDeviceListResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceListResponseDto(
        devices: [
          for (final item in json['devices'] as List<dynamic>)
            V1AuthDeviceDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1AuthDeviceDto> devices;

  Map<String, Object?> toJson() => {
    'devices': [for (final item in devices) item.toJson()],
  };
}

class V1AuthDeviceRevokeRequestDto {
  const V1AuthDeviceRevokeRequestDto({required this.deviceId});

  factory V1AuthDeviceRevokeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceRevokeRequestDto(deviceId: json['device_id'] as String);

  final String deviceId;

  Map<String, Object?> toJson() => {'device_id': deviceId};
}

class V1AuthDeviceRevokeResponseDto {
  const V1AuthDeviceRevokeResponseDto({required this.revoked});

  factory V1AuthDeviceRevokeResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceRevokeResponseDto(revoked: json['revoked'] as bool);

  final bool revoked;

  Map<String, Object?> toJson() => {'revoked': revoked};
}

class V1AuthSignOutRequestDto {
  const V1AuthSignOutRequestDto({required this.scope});

  factory V1AuthSignOutRequestDto.fromJson(Map<String, dynamic> json) =>
      V1AuthSignOutRequestDto(scope: json['scope'] as String);

  final String scope;

  Map<String, Object?> toJson() => {'scope': scope};
}

class V1AuthSignOutResponseDto {
  const V1AuthSignOutResponseDto({
    required this.scope,
    required this.revokedBefore,
  });

  factory V1AuthSignOutResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthSignOutResponseDto(
        scope: json['scope'] as String,
        revokedBefore: json['revoked_before'] as String?,
      );

  final String scope;
  final String? revokedBefore;

  Map<String, Object?> toJson() => {
    'scope': scope,
    'revoked_before': revokedBefore,
  };
}

class V1ReauthChallengeRequestDto {
  const V1ReauthChallengeRequestDto({required this.purpose});

  factory V1ReauthChallengeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthChallengeRequestDto(purpose: json['purpose'] as String);

  final String purpose;

  Map<String, Object?> toJson() => {'purpose': purpose};
}

class V1ReauthChallengeResponseDto {
  const V1ReauthChallengeResponseDto({
    required this.purpose,
    required this.requiredAssurance,
    required this.expiresAt,
  });

  factory V1ReauthChallengeResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthChallengeResponseDto(
        purpose: json['purpose'] as String,
        requiredAssurance: json['required_assurance'] as String,
        expiresAt: json['expires_at'] as String,
      );

  final String purpose;
  final String requiredAssurance;
  final String expiresAt;

  Map<String, Object?> toJson() => {
    'purpose': purpose,
    'required_assurance': requiredAssurance,
    'expires_at': expiresAt,
  };
}

class V1ReauthVerifyRequestDto {
  const V1ReauthVerifyRequestDto({required this.purpose});

  factory V1ReauthVerifyRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthVerifyRequestDto(purpose: json['purpose'] as String);

  final String purpose;

  Map<String, Object?> toJson() => {'purpose': purpose};
}

class V1ReauthVerifyResponseDto {
  const V1ReauthVerifyResponseDto({
    required this.purpose,
    required this.grant,
    required this.expiresAt,
  });

  factory V1ReauthVerifyResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthVerifyResponseDto(
        purpose: json['purpose'] as String,
        grant: json['grant'] as String,
        expiresAt: json['expires_at'] as String,
      );

  final String purpose;
  final String grant;
  final String expiresAt;

  Map<String, Object?> toJson() => {
    'purpose': purpose,
    'grant': grant,
    'expires_at': expiresAt,
  };
}

class V1IdentityLinkRequestDto {
  const V1IdentityLinkRequestDto({
    required this.provider,
    required this.idToken,
    required this.makePrimary,
  });

  factory V1IdentityLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityLinkRequestDto(
        provider: json['provider'] as String,
        idToken: json['id_token'] as String,
        makePrimary: json['make_primary'] as bool,
      );

  final String provider;
  final String idToken;
  final bool makePrimary;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'id_token': idToken,
    'make_primary': makePrimary,
  };
}

class V1IdentityLinkResponseDto {
  const V1IdentityLinkResponseDto({required this.outcome});

  factory V1IdentityLinkResponseDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityLinkResponseDto(outcome: json['outcome'] as String);

  final String outcome;

  Map<String, Object?> toJson() => {'outcome': outcome};
}

class V1IdentityUnlinkRequestDto {
  const V1IdentityUnlinkRequestDto({
    required this.provider,
    required this.subject,
  });

  factory V1IdentityUnlinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityUnlinkRequestDto(
        provider: json['provider'] as String,
        subject: json['subject'] as String,
      );

  final String provider;
  final String subject;

  Map<String, Object?> toJson() => {'provider': provider, 'subject': subject};
}

class V1IdentityUnlinkResponseDto {
  const V1IdentityUnlinkResponseDto({required this.outcome});

  factory V1IdentityUnlinkResponseDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityUnlinkResponseDto(outcome: json['outcome'] as String);

  final String outcome;

  Map<String, Object?> toJson() => {'outcome': outcome};
}

class V1DeletionImpactMembershipDto {
  const V1DeletionImpactMembershipDto({
    required this.schoolName,
    required this.role,
  });

  factory V1DeletionImpactMembershipDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionImpactMembershipDto(
        schoolName: json['school_name'] as String,
        role: json['role'] as String,
      );

  final String schoolName;
  final String role;

  Map<String, Object?> toJson() => {'school_name': schoolName, 'role': role};
}

class V1DeletionRetainedRecordsDto {
  const V1DeletionRetainedRecordsDto({
    required this.attendance,
    required this.grades,
    required this.submissions,
    required this.wellbeing,
  });

  factory V1DeletionRetainedRecordsDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionRetainedRecordsDto(
        attendance: json['attendance'] as int,
        grades: json['grades'] as int,
        submissions: json['submissions'] as int,
        wellbeing: json['wellbeing'] as int,
      );

  final int attendance;
  final int grades;
  final int submissions;
  final int wellbeing;

  Map<String, Object?> toJson() => {
    'attendance': attendance,
    'grades': grades,
    'submissions': submissions,
    'wellbeing': wellbeing,
  };
}

class V1DeletionDeletedDataDto {
  const V1DeletionDeletedDataDto({
    required this.profile,
    required this.devices,
    required this.consents,
    required this.notifications,
  });

  factory V1DeletionDeletedDataDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionDeletedDataDto(
        profile: json['profile'] as int,
        devices: json['devices'] as int,
        consents: json['consents'] as int,
        notifications: json['notifications'] as int,
      );

  final int profile;
  final int devices;
  final int consents;
  final int notifications;

  Map<String, Object?> toJson() => {
    'profile': profile,
    'devices': devices,
    'consents': consents,
    'notifications': notifications,
  };
}

class V1DeletionImpactResponseDto {
  const V1DeletionImpactResponseDto({
    required this.memberships,
    required this.retainedSchoolRecords,
    required this.deletedPersonalData,
    required this.guardianLinks,
    required this.activeEntitlements,
    required this.gracePeriodDays,
  });

  factory V1DeletionImpactResponseDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionImpactResponseDto(
        memberships: [
          for (final item in json['memberships'] as List<dynamic>)
            V1DeletionImpactMembershipDto.fromJson(
              item as Map<String, dynamic>,
            ),
        ],
        retainedSchoolRecords: V1DeletionRetainedRecordsDto.fromJson(
          json['retained_school_records'] as Map<String, dynamic>,
        ),
        deletedPersonalData: V1DeletionDeletedDataDto.fromJson(
          json['deleted_personal_data'] as Map<String, dynamic>,
        ),
        guardianLinks: json['guardian_links'] as int,
        activeEntitlements: json['active_entitlements'] as int,
        gracePeriodDays: json['grace_period_days'] as int,
      );

  final List<V1DeletionImpactMembershipDto> memberships;
  final V1DeletionRetainedRecordsDto retainedSchoolRecords;
  final V1DeletionDeletedDataDto deletedPersonalData;
  final int guardianLinks;
  final int activeEntitlements;
  final int gracePeriodDays;

  Map<String, Object?> toJson() => {
    'memberships': [for (final item in memberships) item.toJson()],
    'retained_school_records': retainedSchoolRecords.toJson(),
    'deleted_personal_data': deletedPersonalData.toJson(),
    'guardian_links': guardianLinks,
    'active_entitlements': activeEntitlements,
    'grace_period_days': gracePeriodDays,
  };
}

class V1DeletionRequestRequestDto {
  const V1DeletionRequestRequestDto({
    required this.reasonCode,
    required this.confirmation,
  });

  factory V1DeletionRequestRequestDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionRequestRequestDto(
        reasonCode: json['reason_code'] as String,
        confirmation: json['confirmation'] as String,
      );

  final String reasonCode;
  final String confirmation;

  Map<String, Object?> toJson() => {
    'reason_code': reasonCode,
    'confirmation': confirmation,
  };
}

class V1DeletionRequestResponseDto {
  const V1DeletionRequestResponseDto({
    required this.id,
    required this.state,
    required this.executeAfter,
    required this.created,
  });

  factory V1DeletionRequestResponseDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionRequestResponseDto(
        id: json['id'] as String,
        state: json['state'] as String,
        executeAfter: json['execute_after'] as String,
        created: json['created'] as bool,
      );

  final String id;
  final String state;
  final String executeAfter;
  final bool created;

  Map<String, Object?> toJson() => {
    'id': id,
    'state': state,
    'execute_after': executeAfter,
    'created': created,
  };
}

class V1DeletionCancelResponseDto {
  const V1DeletionCancelResponseDto({required this.cancelled});

  factory V1DeletionCancelResponseDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionCancelResponseDto(cancelled: json['cancelled'] as bool);

  final bool cancelled;

  Map<String, Object?> toJson() => {'cancelled': cancelled};
}
