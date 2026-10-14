import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum SocialProvider { google, apple, facebook }

class SocialProviderIcon extends StatelessWidget {
  const SocialProviderIcon({required this.provider, super.key});

  final SocialProvider provider;

  static const _google = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.15v2.84C3.96 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.1c-.22-.66-.35-1.37-.35-2.1s.13-1.44.35-2.1V7.06H2.15C1.42 8.5 1 10.18 1 12s.42 3.5 1.15 4.94l3.69-2.84z"/>
  <path fill="#EA4335" d="M12 5.27c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 1.99 14.97 1 12 1 7.7 1 3.96 3.47 2.15 7.06l3.69 2.84c.87-2.6 3.3-4.63 6.16-4.63z"/>
</svg>''';

  static const _apple = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#111111" d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.07-.35C2.74 14.48 3.57 5.6 9.25 5.3c1.38.07 2.34.77 3.15.83 1.2-.24 2.35-.95 3.64-.85 1.55.12 2.72.74 3.5 1.86-3.2 1.92-2.44 6.11.5 7.29-.58 1.45-1.34 2.9-2.99 4.47zM12.03 5.23c-.15-2.15 1.61-3.93 3.62-4.1.28 2.48-2.26 4.35-3.62 4.1z"/>
</svg>''';

  static const _facebook = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="12" fill="#1877F2"/>
  <path fill="#FFFFFF" d="M13.4 21v-8.2h2.8l.4-3.2h-3.2V7.5c0-.9.3-1.5 1.6-1.5h1.7V3.1c-.3 0-1.3-.1-2.5-.1-2.5 0-4.2 1.5-4.2 4.3v2.3H7.2v3.2H10V21h3.4z"/>
</svg>''';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    switch (provider) {
      SocialProvider.google => _google,
      SocialProvider.apple => _apple,
      SocialProvider.facebook => _facebook,
    },
    width: 22,
    height: 22,
    semanticsLabel: switch (provider) {
      SocialProvider.google => 'Google',
      SocialProvider.apple => 'Apple',
      SocialProvider.facebook => 'Facebook',
    },
  );
}
