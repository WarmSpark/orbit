import 'package:flutter/material.dart';

import '../theme.dart';

const String kOrbitContactEmail = 'divyansh82188@gmail.com';

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

class LegalDoc {
  final String title;
  final String updated;
  final String intro;
  final List<LegalSection> sections;
  const LegalDoc({
    required this.title,
    required this.updated,
    required this.intro,
    required this.sections,
  });
}

const LegalDoc orbitTermsDoc = LegalDoc(
  title: 'Terms of Use',
  updated: 'Last updated: 6 September 2026',
  intro:
      'Orbit is a new app for finding spontaneous hangouts around you in the '
      'Delhi NCR. By using Orbit you agree to these terms. Please read them.',
  sections: [
    LegalSection(
      'An early product',
      'Orbit is provided on an "as is" and "as available" basis. It is a young '
          'product and features may change, break, or be removed at any time.',
    ),
    LegalSection(
      'Who can use Orbit',
      'You must be a real person and sign in with your own Google account. You '
          'must be old enough to form a binding agreement where you live, and you '
          'agree to follow all laws that apply to you. One account per person.',
    ),
    LegalSection(
      'Be decent',
      'No harassment, hate speech, threats, sexual content, spam, scams, or '
          'illegal activity. Do not impersonate others or post anything false or '
          'misleading. Hosts may remove anyone from their own hangout, and we may '
          'suspend or remove accounts that abuse other people or these terms.',
    ),
    LegalSection(
      'Meeting people is at your own risk',
      'Orbit helps you discover hangouts and the people at them. We do not '
          'verify, vet, or run background checks on anyone. You are responsible '
          'for your own safety: meet in public places, do not share sensitive '
          'personal or financial information, tell a friend where you are going, '
          'and trust your instincts. Orbit is not responsible for the conduct of '
          'any user or for anything that happens before, during, or after a '
          'hangout.',
    ),
    LegalSection(
      'Your content',
      'You are responsible for what you post — hangout details, chat messages, '
          'and your profile. Only post content you have the right to share. You '
          'keep ownership of your content, and you grant Orbit permission to '
          'display it within the app so the service can work.',
    ),
    LegalSection(
      'Location and availability',
      'Orbit currently works only inside the Delhi NCR region and needs your '
          'device location to show nearby hangouts. If you turn off location or '
          'travel outside the covered area, parts of the app will not work.',
    ),
    LegalSection(
      'No warranty and limitation of liability',
      'To the fullest extent permitted by law, Orbit is provided without '
          'warranties of any kind, and we are not liable for any indirect, '
          'incidental, or consequential damages arising from your use of the app '
          'or from meetups arranged through it. Some laws do not allow these '
          'limits, so parts of this section may not apply to you.',
    ),
    LegalSection(
      'Ending your use',
      'You can stop using Orbit at any time. We may suspend or end access for '
          'anyone who breaks these terms or puts other users at risk.',
    ),
    LegalSection(
      'Changes to these terms',
      'We may update these terms as Orbit grows. If we make a significant '
          'change we will ask you to accept the new terms. Continuing to use the '
          'app after an update means you accept it.',
    ),
    LegalSection(
      'Contact',
      'Questions about these terms? Reach us at $kOrbitContactEmail.',
    ),
  ],
);

const LegalDoc orbitPrivacyDoc = LegalDoc(
  title: 'Privacy Policy',
  updated: 'Last updated: 6 September 2026',
  intro:
      'Orbit is built so you can meet people without giving up your data. We '
      'collect the minimum we need, blur the rest, and let plans expire on '
      'their own. This is what we collect and why.',
  sections: [
    LegalSection(
      'What we collect',
      'When you sign in with Google we receive your email address and basic '
          'profile (such as your name). In the app you set a username, display '
          'name, gender, short bio, and a preset avatar. We also process your '
          'approximate location and the hangouts and messages you create.',
    ),
    LegalSection(
      'Your location is fuzzed',
      'Before anyone else sees a hangout, its map pin is offset by roughly '
          '110 metres. Your exact location is never shown to other users.',
    ),
    LegalSection(
      'Your email stays hidden',
      'Other users never see your email address. Only the host of a hangout '
          'can see who has joined their own hangout.',
    ),
    LegalSection(
      'Everything expires',
      'Every hangout and its entire chat is automatically deleted about 24 '
          'hours after the hangout is created. Nothing lingers.',
    ),
    LegalSection(
      'We do not use preset photos from Google',
      'Orbit uses preset avatars you choose in the app. We do not store your '
          'Google profile photo.',
    ),
    LegalSection(
      'No tracking, no ads, no selling',
      'There are no ads, no follower graph, and no behavioural profiling. We '
          'do not sell your personal information to anyone.',
    ),
    LegalSection(
      'How we use what we collect',
      'We use your data only to run the service: to sign you in, show nearby '
          'hangouts, let you chat with people you meet, and keep the community '
          'safe. Your data is stored on secured servers.',
    ),
    LegalSection(
      'Your choices',
      'You control your device location permission and the profile details you '
          'share. To ask about or delete your data, contact us at '
          '$kOrbitContactEmail.',
    ),
    LegalSection(
      'Contact',
      'Questions about your privacy? Reach us at $kOrbitContactEmail.',
    ),
  ],
);

class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              doc.updated,
              style: TextStyle(fontSize: 13, color: context.cInkSoft),
            ),
            const SizedBox(height: 14),
            Text(
              doc.intro,
              style: TextStyle(fontSize: 15, height: 1.5, color: context.cInk),
            ),
            const SizedBox(height: 8),
            for (final s in doc.sections) _Section(section: s),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final LegalSection section;
  const _Section({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cInk),
          ),
          const SizedBox(height: 6),
          Text(
            section.body,
              style: TextStyle(fontSize: 14.5, height: 1.5, color: context.cInkSoft),
          ),
        ],
      ),
    );
  }
}
