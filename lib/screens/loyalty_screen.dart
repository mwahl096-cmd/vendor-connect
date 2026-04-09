import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/loyalty_partner.dart';
import '../services/loyalty_service.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();

  Future<void> _launchExternal(Uri uri, {String? fallbackMessage}) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fallbackMessage ?? 'Unable to open that link on this device.',
        ),
      ),
    );
  }

  Future<void> _openWebsite(String website) async {
    final trimmed = website.trim();
    if (trimmed.isEmpty) return;
    final hasScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    final normalized = hasScheme ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await _launchExternal(uri, fallbackMessage: 'Unable to open website.');
  }

  Future<void> _openPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    await _launchExternal(uri, fallbackMessage: 'Unable to open dialer.');
  }

  Future<void> _openEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.parse('mailto:$trimmed');
    await _launchExternal(uri, fallbackMessage: 'Unable to open email app.');
  }

  Future<void> _openGoogleMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    await _launchExternal(uri, fallbackMessage: 'Unable to open Google Maps.');
  }

  Future<void> _openMapsApp(String address) async {
    final encoded = Uri.encodeComponent(address);
    final candidates = <Uri>[
      Uri.parse('geo:0,0?q=$encoded'),
      Uri.parse('https://maps.apple.com/?q=$encoded'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'),
    ];
    for (final uri in candidates) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open maps on this device.')),
    );
  }

  Future<void> _showMapOptions(String address) async {
    if (address.trim().isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Open in maps app'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _openMapsApp(address);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Open in Google Maps'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _openGoogleMaps(address);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPartnerDetails(LoyaltyPartner partner) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partner.businessName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (partner.offerHeadline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Vendor Offer',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    partner.offerHeadline,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (partner.offerDescription.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      partner.offerDescription,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                if (partner.fullAddress.trim().isNotEmpty)
                  _DetailActionTile(
                    icon: Icons.location_on_outlined,
                    title: 'Address',
                    value: partner.fullAddress,
                    buttonText: 'Directions',
                    onPressed: () => _showMapOptions(partner.fullAddress),
                  ),
                if (partner.email.trim().isNotEmpty)
                  _DetailActionTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: partner.email,
                    buttonText: 'Email',
                    onPressed: () => _openEmail(partner.email),
                  ),
                if (partner.phone.trim().isNotEmpty)
                  _DetailActionTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: partner.phone,
                    buttonText: 'Call',
                    onPressed: () => _openPhone(partner.phone),
                  ),
                if (partner.website.trim().isNotEmpty)
                  _DetailActionTile(
                    icon: Icons.public,
                    title: 'Website',
                    value: partner.website,
                    buttonText: 'Visit',
                    onPressed: () => _openWebsite(partner.website),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _displayName(Map<String, dynamic> data, String fallback) {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final businessName = (data['businessName'] ?? '').toString().trim();
    if (businessName.isNotEmpty) return businessName;
    final email = (data['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: Text('Please sign in to view your loyalty card.'),
      );
    }

    final userDoc = FirebaseFirestore.instance
        .collection(AppConfig.usersCollection)
        .doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData &&
            userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = userSnap.data?.data() ?? <String, dynamic>{};
        final fallbackName =
            FirebaseAuth.instance.currentUser?.email?.trim().isNotEmpty == true
                ? FirebaseAuth.instance.currentUser!.email!.trim()
                : 'Vendor';
        final name = _displayName(userData, fallbackName);

        return StreamBuilder<List<LoyaltyPartner>>(
          stream: _loyaltyService.watchActivePartners(),
          builder: (context, partnerSnap) {
            final loading =
                partnerSnap.connectionState == ConnectionState.waiting &&
                !partnerSnap.hasData;
            final partners = partnerSnap.data ?? const <LoyaltyPartner>[];
            final role =
                (userData['role'] ?? 'vendor').toString().trim().toLowerCase();
            final isAdmin = role == 'admin';
            final visiblePartners =
                isAdmin
                    ? partners
                    : partners
                        .where(
                          (partner) =>
                              partner.eligibleVendorIds.isEmpty ||
                              partner.eligibleVendorIds.contains(uid),
                        )
                        .toList(growable: false);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _LoyaltyCard(name: name),
                const SizedBox(height: 20),
                Text(
                  'Participating Businesses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  visiblePartners.isNotEmpty
                      ? 'Tap a business to view the offer and contact details.'
                      : isAdmin
                      ? 'No listings yet. Add them in Admin Dashboard > Loyalty Benefits.'
                      : 'No listings yet. Ask admin to add participating businesses.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!loading && visiblePartners.isEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        isAdmin
                            ? 'No loyalty benefits are available right now. Add one from Admin Dashboard > Loyalty Benefits.'
                            : 'No loyalty benefits are available right now.',
                      ),
                    ),
                  ),
                for (final partner in visiblePartners) ...[
                  _PartnerListTile(
                    partner: partner,
                    onTap: () => _showPartnerDetails(partner),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _LoyaltyCard extends StatelessWidget {
  final String name;

  const _LoyaltyCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 1.8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/loyalty_card.jpeg',
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    color: const Color(0xFFE8F9FB),
                    alignment: Alignment.center,
                    child: const Text('Loyalty card image missing'),
                  ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 62,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final responsiveSize = (constraints.maxWidth * 0.12).clamp(
                    14.0,
                    22.0,
                  );
                  final overlayText = name.toUpperCase();
                  return SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Stack(
                        children: [
                          Text(
                            overlayText,
                            textScaler: TextScaler.noScaling,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: responsiveSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              foreground:
                                  Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 2
                                    ..color = Colors.white.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            overlayText,
                            textScaler: TextScaler.noScaling,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: responsiveSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: const Color(0xFF222222),
                              shadows: const [
                                Shadow(
                                  color: Color(0x55000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerListTile extends StatelessWidget {
  final LoyaltyPartner partner;
  final VoidCallback onTap;

  const _PartnerListTile({required this.partner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          partner.businessName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (partner.offerHeadline.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                partner.offerHeadline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              partner.offerDescription.trim().isNotEmpty
                  ? partner.offerDescription.trim()
                  : 'MSC offer not set',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _DetailActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String buttonText;
  final VoidCallback onPressed;

  const _DetailActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2BBFD4)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(value),
                ],
              ),
            ),
            TextButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}
