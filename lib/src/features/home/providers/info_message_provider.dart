import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app_update/services/app_update_service.dart';
import '../../auth/providers/auth_provider.dart';

class InfoMessage {
  final String id;
  final String title;
  final String body;
  final String imageUrl;
  final String ctaLabel;
  final String ctaUrl;
  final String backgroundColor;
  final String textColor;

  const InfoMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.ctaLabel,
    required this.ctaUrl,
    required this.backgroundColor,
    required this.textColor,
  });

  factory InfoMessage.fromJson(Map<String, dynamic> json) {
    return InfoMessage(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      ctaLabel: json['cta_label'] as String? ?? '',
      ctaUrl: json['cta_url'] as String? ?? '',
      backgroundColor: json['background_color'] as String? ?? '#F7C4AD',
      textColor: json['text_color'] as String? ?? '#4B1609',
    );
  }
}

final infoMessagesProvider = FutureProvider<List<InfoMessage>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return const <InfoMessage>[];

  final responses = await Future.wait<List<dynamic>>([
    supabase
        .from('mobile_info_messages')
        .select(
          'id, title, body, image_url, cta_label, cta_url, background_color, text_color',
        )
        .eq('is_active', true)
        .order('order_index', ascending: true)
        .order('created_at', ascending: false),
    supabase
        .from('mobile_info_message_dismissals')
        .select('message_id')
        .eq('user_id', user.id),
  ]);

  final dismissedIds = responses[1]
      .map((row) => (row as Map<String, dynamic>)['message_id'] as String?)
      .whereType<String>()
      .toSet();

  final messages = responses[0]
      .map((row) => InfoMessage.fromJson(row as Map<String, dynamic>))
      .where((message) => message.id.isNotEmpty)
      .where((message) => !dismissedIds.contains(message.id))
      .toList();

  final updateMessage = await _recommendedUpdateMessage();
  if (updateMessage != null && !dismissedIds.contains(updateMessage.id)) {
    return [updateMessage, ...messages];
  }

  return messages;
});

Future<void> dismissInfoMessage(WidgetRef ref, String messageId) async {
  final supabase = ref.read(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return;

  await supabase.from('mobile_info_message_dismissals').upsert({
    'message_id': messageId,
    'user_id': user.id,
    'dismissed_at': DateTime.now().toIso8601String(),
  });
  ref.invalidate(infoMessagesProvider);
}

Future<InfoMessage?> _recommendedUpdateMessage() async {
  final status = await AppUpdateService.check();
  final config = status.config;
  if (!status.shouldUpdate || status.mustUpdate || config == null) return null;

  final packageInfo = await PackageInfo.fromPlatform();
  return InfoMessage(
    id: 'app-update-${packageInfo.buildNumber}-${config.latestBuild}',
    title: config.title,
    body: config.message,
    imageUrl: '',
    ctaLabel: 'Mettre à jour',
    ctaUrl: config.storeUrl,
    backgroundColor: '#DCD8FF',
    textColor: '#20145C',
  );
}
