import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/contest.dart';

class ContestAssetPreloadService {
  static final Set<String> _preloadedUrls = <String>{};

  const ContestAssetPreloadService._();

  static void preloadContestImages(
    BuildContext context,
    Iterable<Contest> contests, {
    int limit = 12,
  }) {
    final urls = <String>[];
    for (final contest in contests) {
      _addUrl(urls, contest.imageUrl);
      _addUrl(urls, contest.brandLogoUrl);
      if (urls.length >= limit * 2) break;
    }

    for (final url in urls.take(limit * 2)) {
      if (_preloadedUrls.contains(url)) continue;
      _preloadedUrls.add(url);
      unawaited(
        precacheImage(NetworkImage(url), context).catchError((_) {
          _preloadedUrls.remove(url);
        }),
      );
    }
  }

  static void preloadContestImage(BuildContext context, Contest contest) {
    preloadContestImages(context, <Contest>[contest], limit: 1);
  }

  static void _addUrl(List<String> urls, String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty || _isSvg(url) || urls.contains(url)) {
      return;
    }
    urls.add(url);
  }

  static bool _isSvg(String url) {
    return url.split('?').first.toLowerCase().endsWith('.svg');
  }
}
