import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LiveQuizLiveActivityService {
  LiveQuizLiveActivityService._();

  static const MethodChannel _channel = MethodChannel(
    'mega_promo/live_quiz_activity',
  );

  static Future<void> startOrUpdateWaiting({
    required String contestId,
    required String title,
    required DateTime startsAt,
    String prizeLabel = 'Récompense surprise',
    int registeredCount = 0,
    int connectedCount = 0,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      await _channel.invokeMethod<void>('startOrUpdateWaiting', {
        'contestId': contestId,
        'title': title,
        'prizeLabel': prizeLabel,
        'startsAtMillis': startsAt.millisecondsSinceEpoch,
        'registeredCount': registeredCount,
        'connectedCount': connectedCount,
      });
    } on MissingPluginException catch (error) {
      debugPrint('[LiveQuizActivity] native bridge unavailable: $error');
    } on PlatformException catch (error) {
      debugPrint('[LiveQuizActivity] start/update failed: ${error.message}');
    } catch (error, stackTrace) {
      debugPrint('[LiveQuizActivity] unexpected start/update error: $error');
      debugPrint('$stackTrace');
    }
  }

  static Future<void> end(String contestId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      await _channel.invokeMethod<void>('end', {'contestId': contestId});
    } on MissingPluginException catch (error) {
      debugPrint('[LiveQuizActivity] native bridge unavailable: $error');
    } on PlatformException catch (error) {
      debugPrint('[LiveQuizActivity] end failed: ${error.message}');
    } catch (error, stackTrace) {
      debugPrint('[LiveQuizActivity] unexpected end error: $error');
      debugPrint('$stackTrace');
    }
  }
}
