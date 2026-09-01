import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';

enum QuizReplayRequestStatus {
  none,
  pending,
  approved,
  rejected,
  used;

  static QuizReplayRequestStatus fromValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'pending' => QuizReplayRequestStatus.pending,
      'approved' => QuizReplayRequestStatus.approved,
      'rejected' => QuizReplayRequestStatus.rejected,
      'used' => QuizReplayRequestStatus.used,
      _ => QuizReplayRequestStatus.none,
    };
  }
}

class QuizReplayStatus {
  final bool replayEnabled;
  final int amount;
  final String paymentTarget;
  final String paymentUrl;
  final String instructions;
  final QuizReplayRequestStatus status;
  final String? requestId;
  final String? rejectionReason;

  const QuizReplayStatus({
    required this.replayEnabled,
    required this.amount,
    required this.paymentTarget,
    required this.paymentUrl,
    required this.instructions,
    required this.status,
    required this.requestId,
    required this.rejectionReason,
  });

  const QuizReplayStatus.unavailable()
    : replayEnabled = false,
      amount = 0,
      paymentTarget = '',
      paymentUrl = '',
      instructions = '',
      status = QuizReplayRequestStatus.none,
      requestId = null,
      rejectionReason = null;

  bool get canSubmitProof => replayEnabled && amount > 0;

  bool get canStartReplay =>
      replayEnabled && status == QuizReplayRequestStatus.approved;

  factory QuizReplayStatus.fromJson(Map<String, dynamic> json) {
    return QuizReplayStatus(
      replayEnabled: json['replay_enabled'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      paymentTarget: json['payment_target'] as String? ?? '',
      paymentUrl: json['payment_url'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      status: QuizReplayRequestStatus.fromValue(json['status'] as String?),
      requestId: json['request_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

class QuizReplayHomeRequest {
  final String id;
  final String contestId;
  final QuizReplayRequestStatus status;
  final int amount;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  const QuizReplayHomeRequest({
    required this.id,
    required this.contestId,
    required this.status,
    required this.amount,
    required this.createdAt,
    required this.approvedAt,
  });

  bool get canPlay => status == QuizReplayRequestStatus.approved;

  factory QuizReplayHomeRequest.fromJson(Map<String, dynamic> json) {
    return QuizReplayHomeRequest(
      id: json['id'] as String? ?? '',
      contestId: json['contest_id'] as String? ?? '',
      status: QuizReplayRequestStatus.fromValue(json['status'] as String?),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
    );
  }
}

final quizReplayStatusProvider =
    FutureProvider.family<QuizReplayStatus, String>((ref, contestId) async {
      ref.watch(authStateProvider);
      final supabase = ref.watch(supabaseProvider);
      return fetchQuizReplayStatus(supabase, contestId);
    });

final quizReplayHomeRequestsProvider =
    FutureProvider.autoDispose<List<QuizReplayHomeRequest>>((ref) async {
      ref.watch(authStateProvider);
      final supabase = ref.watch(supabaseProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return const <QuizReplayHomeRequest>[];

      try {
        final rows = await supabase
            .from('quiz_replay_requests')
            .select('id, contest_id, status, amount, created_at, approved_at')
            .eq('user_id', userId)
            .inFilter('status', ['pending', 'approved'])
            .order('created_at', ascending: false);

        return rows
            .map((row) => QuizReplayHomeRequest.fromJson(_asMap(row)))
            .where((request) => request.contestId.isNotEmpty)
            .toList(growable: false);
      } catch (_) {
        return const <QuizReplayHomeRequest>[];
      }
    });

Future<QuizReplayStatus> fetchQuizReplayStatus(
  dynamic supabase,
  String contestId,
) async {
  try {
    final payload = await supabase.rpc(
      'get_my_quiz_replay_status',
      params: {'p_contest_id': contestId},
    );
    if (payload is Map<String, dynamic>) {
      return QuizReplayStatus.fromJson(payload);
    }
    if (payload is Map) {
      return QuizReplayStatus.fromJson(payload.cast<String, dynamic>());
    }
  } catch (_) {
    return const QuizReplayStatus.unavailable();
  }
  return const QuizReplayStatus.unavailable();
}

Future<String> uploadQuizReplayProof({
  required String contestId,
  required Uint8List bytes,
  required String fileName,
}) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('Utilisateur non connecté.');
  }

  final extension = fileName.split('.').last.toLowerCase();
  final safeExtension = extension.length > 5 ? 'jpg' : extension;
  final safeContestId = contestId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  final path =
      '$userId/$safeContestId/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

  await supabase.storage
      .from('payment-proofs')
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: _contentTypeForExtension(safeExtension),
          upsert: true,
        ),
      );

  return supabase.storage.from('payment-proofs').getPublicUrl(path);
}

Future<QuizReplayStatus> submitQuizReplayProof({
  required String contestId,
  required String proofImageUrl,
}) async {
  final payload = await Supabase.instance.client.rpc(
    'submit_quiz_replay_request',
    params: {'p_contest_id': contestId, 'p_proof_image_url': proofImageUrl},
  );
  if (payload is Map<String, dynamic>) {
    return QuizReplayStatus.fromJson(payload);
  }
  if (payload is Map) {
    return QuizReplayStatus.fromJson(payload.cast<String, dynamic>());
  }
  return const QuizReplayStatus.unavailable();
}

String _contentTypeForExtension(String extension) {
  if (extension == 'png') return 'image/png';
  if (extension == 'webp') return 'image/webp';
  return 'image/jpeg';
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}
