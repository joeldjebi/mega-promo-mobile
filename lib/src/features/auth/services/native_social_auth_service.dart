import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/auth_debug_logger.dart';

enum NativeSocialProvider { google, apple }

const String kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '655703790459-sjhbu1mts6gleboq2hbmlpmj3ergea2k.apps.googleusercontent.com',
);
const String kGoogleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
  defaultValue:
      '655703790459-a90bghjns0g38caph1p6tjl6bvclgspp.apps.googleusercontent.com',
);

class NativeSocialAuthService {
  NativeSocialAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleInitialization;
  static final String _googleRawNonce = Supabase.instance.client.auth
      .generateRawNonce();
  static final String _googleHashedNonce = _sha256String(_googleRawNonce);

  static Future<AuthResponse> signIn(NativeSocialProvider provider) {
    return switch (provider) {
      NativeSocialProvider.google => signInWithGoogle(),
      NativeSocialProvider.apple => signInWithApple(),
    };
  }

  static Future<AuthResponse> link(NativeSocialProvider provider) {
    return switch (provider) {
      NativeSocialProvider.google => linkWithGoogle(),
      NativeSocialProvider.apple => linkWithApple(),
    };
  }

  static Future<AuthResponse> signInWithGoogle() async {
    final supabase = Supabase.instance.client;
    final token = await _getGoogleToken();

    return supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token.idToken,
      accessToken: token.accessToken,
      nonce: token.rawNonce,
    );
  }

  static Future<AuthResponse> signInWithApple() async {
    final supabase = Supabase.instance.client;
    final token = await _getAppleToken();

    return supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: token.idToken,
      nonce: token.rawNonce,
    );
  }

  static Future<AuthResponse> linkWithGoogle() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      throw const AuthException('Connexion requise pour lier Google.');
    }

    final token = await _getGoogleToken(logPrefix: 'nativeGoogleLink');
    return supabase.auth.linkIdentityWithIdToken(
      provider: OAuthProvider.google,
      idToken: token.idToken,
      accessToken: token.accessToken,
      nonce: token.rawNonce,
    );
  }

  static Future<AuthResponse> linkWithApple() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      throw const AuthException('Connexion requise pour lier Apple.');
    }

    final token = await _getAppleToken(logPrefix: 'nativeAppleLink');
    return supabase.auth.linkIdentityWithIdToken(
      provider: OAuthProvider.apple,
      idToken: token.idToken,
      nonce: token.rawNonce,
    );
  }

  static Future<_NativeSocialToken> _getGoogleToken({
    String logPrefix = 'nativeGoogleSignIn',
  }) async {
    if (kGoogleWebClientId.trim().isEmpty) {
      throw const AuthException(
        'Configuration Google manquante: GOOGLE_WEB_CLIENT_ID.',
      );
    }
    if (Platform.isIOS && kGoogleIosClientId.trim().isEmpty) {
      throw const AuthException(
        'Configuration Google iOS manquante: GOOGLE_IOS_CLIENT_ID.',
      );
    }

    _googleInitialization ??= _googleSignIn.initialize(
      clientId: Platform.isIOS ? kGoogleIosClientId : null,
      serverClientId: kGoogleWebClientId,
      nonce: _googleHashedNonce,
    );
    await _googleInitialization;

    authLogPayload(logPrefix, {
      'hasWebClientId': kGoogleWebClientId.trim().isNotEmpty,
      'hasIosClientId': kGoogleIosClientId.trim().isNotEmpty,
      'platform': Platform.operatingSystem,
      'hasNonce': true,
    });

    await _googleSignIn.signOut();

    final account = await _googleSignIn.authenticate();
    final authentication = account.authentication;
    final authorization = await account.authorizationClient
        .authorizationForScopes(const <String>[]);

    final idToken = authentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw const AuthException('Google n’a pas retourné de jeton ID.');
    }
    final tokenNonce = _jwtPayloadStringValue(idToken, 'nonce');

    authLogResponse(logPrefix, {
      'email': account.email,
      'hasIdToken': true,
      'hasAccessToken': authorization?.accessToken != null,
      'idTokenHasNonce': tokenNonce != null,
      'idTokenNonceMatchesLocalHash': tokenNonce == _googleHashedNonce,
    });

    return _NativeSocialToken(
      idToken: idToken,
      accessToken: authorization?.accessToken,
      rawNonce: _googleRawNonce,
    );
  }

  static Future<_NativeSocialToken> _getAppleToken({
    String logPrefix = 'nativeAppleSignIn',
  }) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw const AuthException(
        'Connexion Apple disponible uniquement sur appareil Apple.',
      );
    }

    final supabase = Supabase.instance.client;
    final rawNonce = supabase.auth.generateRawNonce();
    final hashedNonce = _sha256String(rawNonce);

    authLogPayload(logPrefix, {
      'platform': Platform.operatingSystem,
      'hasNonce': true,
    });

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw const AuthException('Apple n’a pas retourné de jeton ID.');
    }

    authLogResponse(logPrefix, {
      'email': credential.email,
      'userIdentifier': credential.userIdentifier,
      'hasIdToken': true,
    });

    return _NativeSocialToken(idToken: idToken, rawNonce: rawNonce);
  }

  static String? _jwtPayloadStringValue(String token, String key) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final normalizedPayload = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalizedPayload));
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;

      final value = decoded[key];
      if (value is! String || value.trim().isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  static String _sha256String(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }
}

class _NativeSocialToken {
  final String idToken;
  final String? accessToken;
  final String? rawNonce;

  const _NativeSocialToken({
    required this.idToken,
    this.accessToken,
    this.rawNonce,
  });
}
