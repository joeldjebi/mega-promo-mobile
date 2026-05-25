import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../contests/models/contest.dart';

const _shareBaseUrl = 'https://megapromo.app';

String contestShareUrl(String contestId) => '$_shareBaseUrl/c/$contestId';

String formatPrizeValue(num value) {
  final rounded = value.round();
  if (rounded <= 0) return 'Prix surprise';
  return '$rounded FCFA';
}

String formatRemainingText(DateTime endsAt) {
  final remaining = endsAt.difference(DateTime.now());
  if (remaining.isNegative) return 'Terminé';

  final days = remaining.inDays;
  final hours = remaining.inHours.remainder(24);
  final minutes = remaining.inMinutes.remainder(60);
  final seconds = remaining.inSeconds.remainder(60);

  if (remaining.inHours < 1) return '${minutes}min ${seconds}s';
  if (days > 0) return '${days}j ${hours}h ${minutes}min';
  return '${hours}h ${minutes}min';
}

Future<void> shareContest({
  required Contest contest,
  required int participantsCount,
}) async {
  final supabase = Supabase.instance.client;
  await supabase
      .from('contests')
      .update({'shares_count': contest.sharesCount + 1})
      .eq('id', contest.id);

  final text =
      '''*${contest.title}*
Gagne *${contest.prizeValue.round()} FCFA* sur MegaPromo !

Il reste ${formatRemainingText(contest.endsAt)}
$participantsCount joueurs participent déjà

Joue maintenant : ${contestShareUrl(contest.id)}''';

  await SharePlus.instance.share(ShareParams(text: text));
}

Future<void> shareScore({
  required String contestTitle,
  required int correctAnswers,
  required int totalQuestions,
  required int points,
}) async {
  final text =
      '''Mon score sur MegaPromo
$contestTitle

J’ai fait *$correctAnswers / $totalQuestions* et gagné *$points points* !

Joue maintenant : $_shareBaseUrl/contests''';

  await SharePlus.instance.share(ShareParams(text: text));
}
