import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'auth_screen.dart';

class TermsAcceptanceArgs {
  final String nextRoute;
  final Object? nextArguments;
  const TermsAcceptanceArgs({required this.nextRoute, this.nextArguments});
}

class TermsAcceptanceScreen extends StatefulWidget {
  static const route = '/terms-acceptance';

  final String nextRoute;
  final Object? nextArguments;
  const TermsAcceptanceScreen({
    super.key,
    required this.nextRoute,
    this.nextArguments,
  });

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link. Please try again.')),
      );
    }
  }

  Future<void> _submitAcceptance() async {
    if (!_agreed || _saving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AuthScreen.route,
        (route) => false,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .set(
        {
          'acceptedTermsVersion': AppConfig.termsVersion,
          'acceptedTermsAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        widget.nextRoute,
        (route) => false,
        arguments: widget.nextArguments,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save your response. Please try again.'),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AuthScreen.route,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Connect Terms'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please confirm that you agree to the Vendor Connect Terms of '
              'Use and Privacy Policy. Our community guidelines make it clear '
              'that there is zero tolerance for harassment, hate speech, or '
              'other objectionable content.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What you are agreeing to',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Community standards prohibit abusive content.'),
                    const Text('• You will only post vendor-related updates.'),
                    const Text(
                      '• You understand reports are reviewed and enforced within '
                      '24 hours.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _openLink(AppConfig.termsOfUseUrl),
              icon: const Icon(Icons.article_outlined),
              label: const Text('View Terms of Use'),
            ),
            TextButton.icon(
              onPressed: () => _openLink(AppConfig.privacyPolicyUrl),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('View Privacy Policy'),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I agree to the Terms of Use (effective ${AppConfig.termsVersion}) '
                'and understand Vendor Connect’s no-tolerance policy.',
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _agreed ? _submitAcceptance : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Accept and continue'),
            ),
            TextButton(
              onPressed: _saving ? null : _signOut,
              child: const Text('Cancel and sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
