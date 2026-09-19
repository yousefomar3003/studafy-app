import '../contracts/v1_client.generated.dart';
import '../../core/runtime_environment.dart';

String billingEnvironmentName(StudafyEnvironment environment) =>
    switch (environment) {
      StudafyEnvironment.synthetic => 'synthetic',
      StudafyEnvironment.development => 'development',
      StudafyEnvironment.staging => 'staging',
      StudafyEnvironment.production => 'production',
    };

class V1BillingProduct {
  const V1BillingProduct({
    required this.featureKey,
    required this.platform,
    required this.storeProductId,
  });

  final String featureKey;
  final String platform;
  final String storeProductId;

  factory V1BillingProduct.fromJson(Map<String, dynamic> json) =>
      V1BillingProduct(
        featureKey: json['featureKey'] as String,
        platform: json['platform'] as String,
        storeProductId: json['storeProductId'] as String,
      );
}

class V1BillingSelfPurchaseStatus {
  const V1BillingSelfPurchaseStatus({
    required this.schoolId,
    required this.selfPurchaseEnabled,
  });

  final String schoolId;
  final bool selfPurchaseEnabled;

  factory V1BillingSelfPurchaseStatus.fromJson(Map<String, dynamic> json) =>
      V1BillingSelfPurchaseStatus(
        schoolId: json['schoolId'] as String,
        selfPurchaseEnabled: json['selfPurchaseEnabled'] as bool,
      );
}

class V1BillingCatalogue {
  const V1BillingCatalogue({
    required this.purchaseAccountToken,
    required this.products,
    required this.selfPurchase,
  });

  /// Server-issued account binding. Sent to the store as the purchase's
  /// application user name, which becomes Apple's `appAccountToken` and
  /// Google's obfuscated account id; the server refuses any receipt that
  /// does not carry the authenticated account's token.
  final String purchaseAccountToken;
  final List<V1BillingProduct> products;
  final List<V1BillingSelfPurchaseStatus> selfPurchase;

  factory V1BillingCatalogue.fromJson(
    Map<String, dynamic> json,
  ) => V1BillingCatalogue(
    purchaseAccountToken: json['purchaseAccountToken'] as String,
    products: (json['products'] as List<dynamic>)
        .map((row) => V1BillingProduct.fromJson(row as Map<String, dynamic>))
        .toList(),
    selfPurchase: (json['selfPurchase'] as List<dynamic>)
        .map(
          (row) =>
              V1BillingSelfPurchaseStatus.fromJson(row as Map<String, dynamic>),
        )
        .toList(),
  );
}

/// A student self-purchase approval (DL-048). Students see their own
/// requests; guardians see those of children they are verified for.
class V1PurchaseApproval {
  const V1PurchaseApproval({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.featureKey,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    this.decidedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String featureKey;

  /// requested, approved, declined, consumed or expired.
  final String status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final DateTime expiresAt;

  bool get isPending => status == 'requested';
  bool get isApproved => status == 'approved';

  factory V1PurchaseApproval.fromJson(Map<String, dynamic> json) =>
      V1PurchaseApproval(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        featureKey: json['featureKey'] as String,
        status: json['status'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        decidedAt: json['decidedAt'] == null
            ? null
            : DateTime.parse(json['decidedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class V1SubmitPurchaseOutcome {
  const V1SubmitPurchaseOutcome({
    required this.featureKey,
    required this.derivation,
  });

  final String featureKey;
  final String derivation;

  factory V1SubmitPurchaseOutcome.fromJson(Map<String, dynamic> json) =>
      V1SubmitPurchaseOutcome(
        featureKey: json['featureKey'] as String,
        derivation: json['derivation'] as String,
      );
}

class V1RestoreOutcome {
  const V1RestoreOutcome({
    required this.restored,
    this.featureKey,
    this.derivation,
  });

  final bool restored;
  final String? featureKey;
  final String? derivation;

  factory V1RestoreOutcome.fromJson(Map<String, dynamic> json) =>
      V1RestoreOutcome(
        restored: json['restored'] as bool? ?? false,
        featureKey: json['featureKey'] as String?,
        derivation: json['derivation'] as String?,
      );
}

class V1EntitlementRow {
  const V1EntitlementRow({
    required this.featureKey,
    required this.status,
    required this.startsAt,
    this.endsAt,
    this.beneficiaryStudentId,
  });

  final String featureKey;
  final String status;
  final DateTime startsAt;
  final DateTime? endsAt;

  /// Null for the caller's own entitlement; the linked child's student id
  /// when a guardian reads the Parent Insights access attached to that child.
  final String? beneficiaryStudentId;

  bool get grantsAccess => status == 'active' || status == 'grace_period';

  factory V1EntitlementRow.fromJson(Map<String, dynamic> json) =>
      V1EntitlementRow(
        featureKey: json['featureKey'] as String,
        status: json['status'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt'] as String),
        beneficiaryStudentId: json['beneficiaryStudentId'] as String?,
      );
}

/// Typed client for the /v1/billing/* endpoints (PAY-071). Separate from the
/// generated `/v1` client because the OpenAPI spec is regenerated by a
/// Dart-formatter step that this build environment does not run; the two
/// clients share the same [V1JsonTransport] so there is exactly one HTTP
/// path, one auth refresh, one idempotency policy.
class V1BillingApi {
  V1BillingApi(this._transport, {required this.environment});

  final V1JsonTransport _transport;
  final String environment;

  Future<V1BillingCatalogue> catalogue() async => V1BillingCatalogue.fromJson(
    await _transport.get('/v1/billing/catalogue'),
  );

  Future<V1SubmitPurchaseOutcome> submitPurchase({
    required String platform,
    required String storeProductId,
    required String featureKey,
    required String verificationPayload,
    String? beneficiaryStudentId,
    required String idempotencyKey,
  }) async {
    final response = await _transport.post(
      '/v1/billing/purchases',
      {
        'platform': platform,
        'environment': environment,
        'storeProductId': storeProductId,
        'productFeatureKey': featureKey,
        'verificationPayload': verificationPayload,
        'beneficiaryStudentId': ?beneficiaryStudentId,
      },
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    );
    return V1SubmitPurchaseOutcome.fromJson(response);
  }

  Future<V1RestoreOutcome> restorePurchase({
    required String platform,
    required String storeProductId,
    required String featureKey,
    required String verificationPayload,
    String? beneficiaryStudentId,
    required String idempotencyKey,
  }) async {
    final response = await _transport.post(
      '/v1/billing/restore',
      {
        'platform': platform,
        'environment': environment,
        'storeProductId': storeProductId,
        'productFeatureKey': featureKey,
        'verificationPayload': verificationPayload,
        'beneficiaryStudentId': ?beneficiaryStudentId,
      },
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    );
    return V1RestoreOutcome.fromJson(response);
  }

  /// Student: ask linked guardians to approve a self-purchase.
  Future<V1PurchaseApproval> requestPurchaseApproval({
    required String featureKey,
    required String idempotencyKey,
  }) async => V1PurchaseApproval.fromJson(
    await _transport.post(
      '/v1/billing/purchase-approvals',
      {'featureKey': featureKey},
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<List<V1PurchaseApproval>> purchaseApprovals() async {
    final response = await _transport.get('/v1/billing/purchase-approvals');
    return (response['approvals'] as List<dynamic>)
        .map((row) => V1PurchaseApproval.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Guardian: approve or decline. The caller must first complete
  /// `SessionRepository.confirmRecentAuth(ReauthPurpose.billingPurchaseApproval)`
  /// so the shared transport attaches that one-time grant to this request.
  Future<V1PurchaseApproval> decidePurchaseApproval({
    required String approvalId,
    required bool approve,
    required String idempotencyKey,
  }) async => V1PurchaseApproval.fromJson(
    await _transport.post(
      '/v1/billing/purchase-approvals/$approvalId/decision',
      {'approve': approve},
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<List<V1EntitlementRow>> entitlements() async {
    final response = await _transport.get('/v1/billing/entitlements');
    return (response['entitlements'] as List<dynamic>)
        .map((row) => V1EntitlementRow.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
