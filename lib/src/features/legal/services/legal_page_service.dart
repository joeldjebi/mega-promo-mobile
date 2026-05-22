import 'package:supabase_flutter/supabase_flutter.dart';

class LegalPage {
  const LegalPage({
    required this.key,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String key;
  final String title;
  final String content;
  final DateTime? updatedAt;

  factory LegalPage.fromJson(Map<String, dynamic> json) {
    return LegalPage(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? 'MegaPromo',
      content: json['content'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class LegalPageService {
  const LegalPageService._();

  static Future<LegalPage> fetch(String key) async {
    final response = await Supabase.instance.client
        .from('legal_pages')
        .select('key, title, content, updated_at')
        .eq('key', key)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return _fallback(key);
    }

    return LegalPage.fromJson(response);
  }

  static LegalPage _fallback(String key) {
    if (key == 'privacy') {
      return const LegalPage(
        key: 'privacy',
        title: 'Politique de confidentialité',
        content:
            'MegaPromo collecte les informations nécessaires au fonctionnement du service, à la sécurité des concours et au traitement des gains.',
        updatedAt: null,
      );
    }

    return const LegalPage(
      key: 'terms',
      title: 'Conditions générales d’utilisation',
      content:
          'En utilisant MegaPromo, tu acceptes les règles des concours affichées dans l’application et l’usage personnel de ton compte joueur.',
      updatedAt: null,
    );
  }
}
