import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/google_oauth_config.dart';

class SocialIdentityException implements Exception {
  const SocialIdentityException(this.code);
  final String code;
}

class SocialIdentity {
  static Future<void>? _googleInitialization;
  static const googleServerId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: googleOAuthServerClientId,
  );
  static const googleIosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
  static const appleRedirect = String.fromEnvironment('APPLE_REDIRECT_URI');

  static Future<Map<String, dynamic>> authenticate(
    String provider, {
    String? nonce,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const SocialIdentityException('SOCIAL_PLATFORM_UNSUPPORTED');
    }
    if (provider == 'google') {
      if (googleServerId.isEmpty) {
        throw const SocialIdentityException('GOOGLE_CLIENT_ID_MISSING');
      }
      _googleInitialization ??= GoogleSignIn.instance.initialize(
        serverClientId: googleServerId,
        clientId: googleIosId.isEmpty ? null : googleIosId,
      );
      await _googleInitialization;
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const SocialIdentityException('SOCIAL_PLATFORM_UNSUPPORTED');
      }
      try {
        // Clear the provider's cached selection so a new tap can choose an account.
        await GoogleSignIn.instance.signOut();
        final account = await GoogleSignIn.instance.authenticate();
        final token = account.authentication.idToken;
        if (token == null) {
          throw const SocialIdentityException('SOCIAL_TOKEN_INVALID');
        }
        if (kDebugMode) debugPrint('Google sign-in: ID token received');
        return {
          'idToken': token,
          'displayName': account.displayName ?? 'Phụ huynh',
          'email': account.email,
        };
      } on GoogleSignInException catch (e) {
        if (kDebugMode) {
          // Provider descriptions/details may contain account data. Log only the code.
          debugPrint('Google sign-in failed: ${e.code.name}');
        }
        if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
            e.code == GoogleSignInExceptionCode.providerConfigurationError) {
          throw const SocialIdentityException('GOOGLE_OAUTH_CONFIGURATION_ERROR');
        }
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw const SocialIdentityException('SOCIAL_CANCELLED');
        }
        throw const SocialIdentityException('SOCIAL_SIGN_IN_FAILED');
      }
    }
    final browserFlow =
        kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    if (browserFlow &&
        (appleServiceId.isEmpty || !appleRedirect.startsWith('https://'))) {
      throw const SocialIdentityException('SOCIAL_AUTH_NOT_CONFIGURED');
    }
    if (!await SignInWithApple.isAvailable()) {
      throw const SocialIdentityException('SOCIAL_PLATFORM_UNSUPPORTED');
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        state: nonce,
        webAuthenticationOptions: browserFlow
            ? WebAuthenticationOptions(
                clientId: appleServiceId,
                redirectUri: Uri.parse(appleRedirect),
              )
            : null,
      );
      if (credential.identityToken == null) {
        throw const SocialIdentityException('SOCIAL_TOKEN_INVALID');
      }
      return {
        'idToken': credential.identityToken,
        'authorizationCode': credential.authorizationCode,
        'email': credential.email,
        'displayName': [
          credential.givenName,
          credential.familyName,
        ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
      };
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialIdentityException('SOCIAL_CANCELLED');
      }
      throw const SocialIdentityException('SOCIAL_SIGN_IN_FAILED');
    }
  }
}
