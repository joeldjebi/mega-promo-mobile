import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/app_logger.dart';
import '../../../services/app_telemetry_service.dart';
import '../../../services/network_status_service.dart';

class QuizResultSyncService {
  QuizResultSyncService._();

  static const _storageKey = 'pending_quiz_results_v1';
  static bool _isSyncing = false;

  static Future<void> enqueue({
    required String userId,
    required String contestId,
    required String participationId,
    required int points,
    required int durationMs,
    required int correctCount,
    required int totalQuestions,
    required List<Map<String, dynamic>> answers,
    bool backendScoring = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await _readPending(prefs);
    final key = _entryKey(
      userId: userId,
      contestId: contestId,
      participationId: participationId,
    );

    pending.removeWhere((entry) => entry['key'] == key);
    pending.add(<String, dynamic>{
      'key': key,
      'user_id': userId,
      'contest_id': contestId,
      'participation_id': participationId,
      'points': points,
      'duration_ms': durationMs,
      'correct_count': correctCount,
      'total_questions': totalQuestions,
      'answers': answers,
      'backend_scoring': backendScoring,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    });

    await prefs.setString(_storageKey, jsonEncode(pending));
  }

  static Future<void> syncPending() async {
    if (_isSyncing) return;
    if (!await NetworkStatusService.instance.ensureOnline()) return;

    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    _isSyncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = await _readPending(prefs);
      if (pending.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];
      for (final entry in pending) {
        final userId = entry['user_id'] as String? ?? '';
        if (userId != currentUserId) {
          remaining.add(entry);
          continue;
        }

        try {
          await _syncEntry(supabase, entry);
          unawaited(
            AppLogger.info(
              'quiz',
              'pending_result_synced',
              'Resultat quiz local resynchronise.',
              entityType: 'contest',
              entityId: entry['contest_id'] as String?,
              metadata: {'attempts': (entry['attempts'] as num?)?.toInt() ?? 0},
            ),
          );
        } catch (error, stackTrace) {
          final attempts = ((entry['attempts'] as num?)?.toInt() ?? 0) + 1;
          remaining.add({...entry, 'attempts': attempts});

          if (!AppTelemetryService.isRetryableNetworkError(error)) {
            unawaited(
              AppLogger.warning(
                'quiz',
                'pending_result_sync_failed',
                'Resynchronisation resultat quiz impossible.',
                entityType: 'contest',
                entityId: entry['contest_id'] as String?,
                metadata: {
                  'attempts': attempts,
                  'error': error.toString(),
                  'stack': stackTrace.toString(),
                },
              ),
            );
          } else {
            debugPrint('[QUIZ_SYNC][network_retry] $error');
          }
        }
      }

      await prefs.setString(_storageKey, jsonEncode(remaining));
    } finally {
      _isSyncing = false;
    }
  }

  static Future<List<Map<String, dynamic>>> _readPending(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _syncEntry(
    SupabaseClient supabase,
    Map<String, dynamic> entry,
  ) async {
    final userId = entry['user_id'] as String;
    final contestId = entry['contest_id'] as String;
    final participationId = entry['participation_id'] as String? ?? '';
    final points = (entry['points'] as num?)?.toInt() ?? 0;
    final durationMs = (entry['duration_ms'] as num?)?.toInt() ?? 0;
    final correctCount = (entry['correct_count'] as num?)?.toInt() ?? 0;
    final totalQuestions = (entry['total_questions'] as num?)?.toInt() ?? 0;
    final answersPayload = ((entry['answers'] as List?) ?? const [])
        .whereType<Map>()
        .map((answer) => Map<String, dynamic>.from(answer))
        .toList();

    final backendScoring = entry['backend_scoring'] == true;

    if (backendScoring && participationId.isNotEmpty) {
      await supabase.rpc(
        'submit_quiz_result',
        params: {
          'p_participation_id': participationId,
          'p_answers': answersPayload,
        },
      );
      return;
    }

    final participationAlreadyCompleted = await _participationAlreadyCompleted(
      supabase,
      userId: userId,
      contestId: contestId,
      participationId: participationId,
      points: points,
    );

    if (!participationAlreadyCompleted) {
      if (participationId.isNotEmpty) {
        await supabase
            .from('participations')
            .update({
              'score': points,
              'answers': _answersPayload(
                durationMs: durationMs,
                correctCount: correctCount,
                totalQuestions: totalQuestions,
                items: answersPayload,
              ),
              'completed': true,
            })
            .eq('id', participationId)
            .eq('user_id', userId);
      } else {
        await supabase.from('participations').insert({
          'user_id': userId,
          'contest_id': contestId,
          'score': points,
          'answers': _answersPayload(
            durationMs: durationMs,
            correctCount: correctCount,
            totalQuestions: totalQuestions,
            items: answersPayload,
          ),
          'completed': true,
        });
      }

      final userRow = await supabase
          .from('users')
          .select('points_total, participations_today')
          .eq('id', userId)
          .single();
      final pointsTotal = (userRow['points_total'] as num?)?.toInt() ?? 0;
      final participationsToday =
          (userRow['participations_today'] as num?)?.toInt() ?? 0;

      await supabase
          .from('users')
          .update({
            'points_total': pointsTotal + points,
            if (participationId.isEmpty)
              'participations_today': participationsToday + 1,
            if (participationId.isEmpty)
              'last_participation_date': DateTime.now().toIso8601String().split(
                'T',
              )[0],
          })
          .eq('id', userId);
    }
  }

  static Future<bool> _participationAlreadyCompleted(
    SupabaseClient supabase, {
    required String userId,
    required String contestId,
    required String participationId,
    required int points,
  }) async {
    dynamic row;
    if (participationId.isNotEmpty) {
      row = await supabase
          .from('participations')
          .select('id, score, completed')
          .eq('id', participationId)
          .eq('user_id', userId)
          .maybeSingle();
    } else {
      row = await supabase
          .from('participations')
          .select('id, score, completed')
          .eq('contest_id', contestId)
          .eq('user_id', userId)
          .eq('completed', true)
          .order('participated_at', ascending: false)
          .limit(1)
          .maybeSingle();
    }

    if (row is! Map) return false;
    final completed = row['completed'] == true;
    final score = (row['score'] as num?)?.toInt() ?? 0;
    return completed && score == points;
  }

  static Map<String, dynamic> _answersPayload({
    required int durationMs,
    required int correctCount,
    required int totalQuestions,
    required List<Map<String, dynamic>> items,
  }) {
    return {
      'type': 'quiz',
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'duration_ms': durationMs,
      'correct_count': correctCount,
      'total_questions': totalQuestions,
      'items': items,
      'synced_from_local_queue': true,
    };
  }

  static String _entryKey({
    required String userId,
    required String contestId,
    required String participationId,
  }) {
    if (participationId.isNotEmpty) return '$userId::$participationId';
    return '$userId::$contestId';
  }
}
