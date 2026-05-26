import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';

const fallbackPaymentOperatorOptions = [
  PaymentOperatorOption('orange_money', 'Orange Money'),
  PaymentOperatorOption('mtn_money', 'MTN Money'),
  PaymentOperatorOption('moov_money', 'Moov Money'),
  PaymentOperatorOption('wave', 'Wave'),
];

const fallbackPaymentCountry = PaymentCountryOption(
  id: 'ci',
  name: 'Côte d’Ivoire',
  dialCode: '+225',
  phoneDigits: 10,
  flag: 'ci',
);

class PaymentOperatorOption {
  final String key;
  final String name;

  const PaymentOperatorOption(this.key, this.name);

  factory PaymentOperatorOption.fromJson(Map<String, dynamic> json) {
    return PaymentOperatorOption(
      json['operator_key'] as String? ?? '',
      json['name'] as String? ?? 'Mobile Money',
    );
  }
}

class PaymentCountryOption {
  final String id;
  final String name;
  final String dialCode;
  final int phoneDigits;
  final String flag;

  const PaymentCountryOption({
    required this.id,
    required this.name,
    required this.dialCode,
    required this.phoneDigits,
    required this.flag,
  });

  String get label => '$name ($dialCode)';

  factory PaymentCountryOption.fromJson(Map<String, dynamic> json) {
    return PaymentCountryOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Pays',
      dialCode: json['dial_code'] as String? ?? '+225',
      phoneDigits: json['phone_digits'] as int? ?? 10,
      flag: json['flag'] as String? ?? '',
    );
  }
}

class PlayerPaymentMethod {
  final String id;
  final String operatorKey;
  final String operatorName;
  final String phone;
  final String label;
  final bool isPrimary;
  final bool isWhatsapp;
  final String status;

  const PlayerPaymentMethod({
    required this.id,
    required this.operatorKey,
    required this.operatorName,
    required this.phone,
    required this.label,
    required this.isPrimary,
    required this.isWhatsapp,
    required this.status,
  });

  factory PlayerPaymentMethod.fromJson(Map<String, dynamic> json) {
    return PlayerPaymentMethod(
      id: json['id'] as String? ?? '',
      operatorKey: json['operator_key'] as String? ?? 'mobile_money',
      operatorName: json['operator_name'] as String? ?? 'Mobile Money',
      phone: json['phone'] as String? ?? '',
      label: json['label'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      isWhatsapp: json['is_whatsapp'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
    );
  }
}

class PlayerKycRequest {
  final String id;
  final String documentType;
  final String status;
  final String rejectionReason;

  const PlayerKycRequest({
    required this.id,
    required this.documentType,
    required this.status,
    required this.rejectionReason,
  });

  factory PlayerKycRequest.fromJson(Map<String, dynamic> json) {
    return PlayerKycRequest(
      id: json['id'] as String? ?? '',
      documentType: json['document_type'] as String? ?? 'national_id',
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String? ?? '',
    );
  }
}

class PlayerPaymentProfile {
  final List<PlayerPaymentMethod> methods;
  final PlayerKycRequest? latestKyc;

  const PlayerPaymentProfile({required this.methods, required this.latestKyc});

  bool get hasApprovedKyc => latestKyc?.status == 'approved';
  bool get hasPendingKyc => latestKyc?.status == 'pending';
}

final activePaymentCountriesProvider =
    FutureProvider<List<PaymentCountryOption>>((ref) async {
      final supabase = ref.watch(supabaseProvider);

      try {
        final response = await supabase
            .from('countries')
            .select('id, name, dial_code, phone_digits, flag, is_active')
            .eq('is_active', true)
            .order('name', ascending: true);

        final countries = (response as List)
            .whereType<Map>()
            .map((row) => PaymentCountryOption.fromJson(row.cast()))
            .where(
              (country) =>
                  country.id.isNotEmpty &&
                  country.dialCode.isNotEmpty &&
                  country.phoneDigits > 0,
            )
            .toList();

        return countries.isEmpty ? const [fallbackPaymentCountry] : countries;
      } catch (_) {
        return const [fallbackPaymentCountry];
      }
    });

final activePaymentOperatorsProvider =
    FutureProvider<List<PaymentOperatorOption>>((ref) async {
      final supabase = ref.watch(supabaseProvider);

      try {
        final response = await supabase
            .from('payment_methods')
            .select('name, operator_key, is_active, order_index')
            .eq('is_active', true)
            .order('order_index', ascending: true)
            .order('name', ascending: true);

        final operators = (response as List)
            .whereType<Map>()
            .map((row) => PaymentOperatorOption.fromJson(row.cast()))
            .where((operator) => operator.key.isNotEmpty)
            .toList();

        return operators.isEmpty ? fallbackPaymentOperatorOptions : operators;
      } catch (_) {
        return fallbackPaymentOperatorOptions;
      }
    });

final playerPaymentProfileProvider = FutureProvider<PlayerPaymentProfile>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const PlayerPaymentProfile(methods: [], latestKyc: null);
  }

  final responses = await Future.wait([
    supabase
        .from('player_payment_methods')
        .select(
          'id, operator_key, operator_name, phone, label, is_primary, is_whatsapp, status',
        )
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('is_primary', ascending: false)
        .order('created_at', ascending: true),
    supabase
        .from('player_kyc_requests')
        .select('id, document_type, status, rejection_reason, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(10),
  ]);

  final methods = (responses[0] as List)
      .whereType<Map>()
      .map((row) => PlayerPaymentMethod.fromJson(row.cast()))
      .toList();
  final kycRows = (responses[1] as List).whereType<Map>().toList();
  final approvedKyc = kycRows.cast<Map>().where(
    (row) => row['status'] == 'approved',
  );
  final visibleKyc = approvedKyc.isNotEmpty
      ? approvedKyc.first
      : kycRows.cast<Map>().firstOrNull;

  return PlayerPaymentProfile(
    methods: methods,
    latestKyc: visibleKyc == null
        ? null
        : PlayerKycRequest.fromJson(visibleKyc.cast()),
  );
});

Future<void> savePlayerPaymentMethod({
  String? methodId,
  required String operatorKey,
  required String operatorName,
  required String phone,
  required bool isWhatsapp,
  String? label,
}) async {
  await Supabase.instance.client.rpc(
    'upsert_player_payment_method',
    params: {
      'p_method_id': methodId,
      'p_operator_key': operatorKey,
      'p_operator_name': operatorName,
      'p_phone': phone,
      'p_is_whatsapp': isWhatsapp,
      'p_label': label,
    },
  );
}

Future<String> uploadPlayerKycDocument({
  required Uint8List bytes,
  required String fileName,
  required String side,
}) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Utilisateur non connecté.');
  }

  final extension = fileName.split('.').last.toLowerCase();
  final safeExtension = extension.length > 5 ? 'jpg' : extension;
  final path =
      '$userId/${DateTime.now().millisecondsSinceEpoch}_${side.replaceAll(RegExp(r'[^a-z0-9_]'), '')}.$safeExtension';

  await supabase.storage
      .from('kyc-documents')
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: _contentTypeForExtension(safeExtension),
          upsert: true,
        ),
      );

  return supabase.storage.from('kyc-documents').getPublicUrl(path);
}

String _contentTypeForExtension(String extension) {
  if (extension == 'png') return 'image/png';
  if (extension == 'webp') return 'image/webp';
  if (extension == 'pdf') return 'application/pdf';
  return 'image/jpeg';
}

Future<void> submitPlayerKycRequest({
  required String documentType,
  required String documentFrontUrl,
  String? documentBackUrl,
}) async {
  await Supabase.instance.client.rpc(
    'submit_player_kyc_request',
    params: {
      'p_document_type': documentType,
      'p_document_front_url': documentFrontUrl,
      'p_document_back_url': documentBackUrl,
    },
  );
}
