import 'dart:async';



import 'package:badges/badges.dart' as badges;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';



import '../config.dart';

import '../services/firestore_service.dart';

import '../services/notification_service.dart';

import '../services/auth_service.dart';

import 'articles_list_screen.dart';

import 'search_screen.dart';

import 'profile_screen.dart';

import 'auth_screen.dart';

import 'info_page.dart';



class HomeShell extends StatefulWidget {

  static const route = '/home';

  const HomeShell({super.key});



  @override

  State<HomeShell> createState() => _HomeShellState();

}



class _HomeShellState extends State<HomeShell> {

  int _index = 0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _pageTitles = const ['Articles', 'Search', 'Profile'];

  final _pages = const [ArticlesListScreen(), SearchScreen(), ProfileScreen()];



  @override

  Widget build(BuildContext context) {

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(

      key: _scaffoldKey,

      drawer: _AppDrawer(

        onNavigateToProfile: () {

          setState(() => _index = 2);

          Navigator.of(context).pop();

        },

      ),

      appBar: AppBar(

        elevation: 0,

        backgroundColor: Colors.white,

        foregroundColor: Colors.black87,

        title: Text(

          _pageTitles[_index],

          style: const TextStyle(fontWeight: FontWeight.w600),

        ),

        leading: IconButton(

          icon: const Icon(Icons.menu),

          onPressed: () => _scaffoldKey.currentState?.openDrawer(),

        ),

      ),

      body: IndexedStack(index: _index, children: _pages),

      bottomNavigationBar: Container(

        decoration: const BoxDecoration(

          color: Color(0xFF2BBFD4),

          borderRadius: BorderRadius.only(

            topLeft: Radius.circular(20),

            topRight: Radius.circular(20),

          ),

        ),

        child: ClipRRect(

          borderRadius: const BorderRadius.only(

            topLeft: Radius.circular(20),

            topRight: Radius.circular(20),

          ),

          child: BottomNavigationBar(

            type: BottomNavigationBarType.fixed,

            backgroundColor: Colors.transparent,

            elevation: 0,

            selectedItemColor: Colors.white,

            unselectedItemColor: Colors.white70,

            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),

            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),

            showUnselectedLabels: true,

            currentIndex: _index,

            onTap: (i) => setState(() => _index = i),

            items: [

              BottomNavigationBarItem(

                icon:

                    uid == null

                        ? const Icon(Icons.article)

                        : StreamBuilder<int>(

                          stream: FirestoreService().watchUnreadCount(uid),

                          builder: (context, snap) {

                            final count = snap.data ?? 0;

                            // Update app badge in background

                            context.read<NotificationService>().setBadgeCount(

                              count,

                            );

                            final icon = const Icon(Icons.article);

                            if (count <= 0) return icon;

                            return badges.Badge(

                              position: badges.BadgePosition.topEnd(

                                top: -12,

                                end: -12,

                              ),

                              badgeContent: Text(

                                count > 99 ? '99+' : '$count',

                                style: const TextStyle(

                                  color: Colors.white,

                                  fontSize: 10,

                                ),

                              ),

                              child: icon,

                            );

                          },

                        ),

                label: 'Articles',

              ),

              const BottomNavigationBarItem(

                icon: Icon(Icons.search),

                label: 'Search',

              ),

              const BottomNavigationBarItem(

                icon: Icon(Icons.person),

                label: 'Profile',

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _AppDrawer extends StatelessWidget {

  final VoidCallback onNavigateToProfile;

  const _AppDrawer({required this.onNavigateToProfile});



  static const List<String> _supportCopy = [

    'Support / Contact',

    'Need help with Vendor Connect? Visit https://vendorconnectapp.com/support/ for detailed guidance or reach us directly:',

    'Email: info@marketstreetcreatives.com',

    'Phone: 860-626-4500 (Mon-Fri, 10am-5pm ET)',

    'In-app: Profile -> Help & Support -> "Contact us" or tap the flag/report buttons on any article or comment.',

    'Mail: Vendor Connect App c/o Market Street Creatives, LLC, 100 Lawton Street, Torrington, CT 06790 USA',

  ];



  static const List<String> _privacyCopy = [

    'Privacy Policy (Vendor Connect)',

    'Effective date: October 24, 2025. Applies to the Vendor Connect mobile apps (iOS/Android) and vendorconnectapp.com.',

    'Who we are: Vendor Connect is operated by Market Street Creatives, LLC. We share announcements, articles, reminders, and discussions with approved vendors. Contact info@marketstreetcreatives.com or mail Market Street Creatives, LLC c/o Vendor Connect App, 100 Lawton Street, Torrington, CT 06790 USA.',

    'What this policy covers: the information we collect, how we use and share it, how long we keep it, your rights and choices, and how to reach us.',

    'Information we collect: account/profile details plus vendor verification fields; content you submit (comments, questions, attachments, feedback); app activity and device data (articles viewed, taps, device/OS, app version, approximate region, crash/diagnostic logs); notification tokens; support communications; and basic website cookies/analytics.',

    'How we use information: deliver announcements/reminders/discussions; verify and manage vendor accounts and approvals; provide support (email, phone, in-app requests, or flag/report buttons); maintain security, prevent spam/abuse, and enforce our Terms; perform analytics to improve the service; and meet legal, regulatory, and contractual obligations.',

    'Sharing & retention: we do not sell personal information. We share it only with trusted providers (e.g., Firebase/Google Cloud hosting, Apple/Google push services) or when required by law/safety or as part of a business transaction. Data is retained only as long as needed for these purposes, then deleted or anonymized unless law requires otherwise.',

    'Your choices & rights: manage push notifications in device settings; delete your account via Profile -> Account -> Delete Account or email us; email info@marketstreetcreatives.com with the subject "Privacy request" to access/correct/export data or exercise GDPR/UK GDPR/CPRA rights; use the in-app report buttons to flag content or request assistance.',

    'Children, security, transfers: Vendor Connect is intended for adult vendors and we do not knowingly collect data from children under 13. We use administrative, technical, and physical safeguards, but no system is perfectly secure—keep credentials confidential and report suspected unauthorized access. Data is hosted on Firebase/Google Cloud in the United States, so it may be processed outside your country with appropriate safeguards.',

    'Changes & contact: we will post updates here, revise the effective date, and provide in-app notice when changes are material. Contact info@marketstreetcreatives.com, mail 100 Lawton Street, Torrington, CT 06790 USA, or visit https://vendorconnectapp.com/support/.',

  ];



  static const List<String> _termsCopy = [

    'Vendor Connect Terms of Use (effective October 24, 2025)',

    'Eligibility: you must be at least 18 years old and an approved vendor/representative in good standing. Apple\'s Standard EULA (iOS) and Google Play terms also apply.',

    'Purpose: Vendor Connect is a private communication channel for announcements, articles, reminders, and vendor discussions—not a public forum.',

    'Acceptable use: no unlawful, threatening, harassing, hateful, infringing, or confidential content; no impersonation, spam, or attempts to probe/attack the Service. We may remove content or suspend accounts to maintain a safe community.',

    'User content & feedback: you retain ownership of your comments but grant Market Street Creatives, LLC a license to host/display them within the Service. Feedback may be used without restriction or compensation.',

    'Moderation & reporting: every article and comment has a "Report" button, or you can email info@marketstreetcreatives.com. Admins review reports promptly and may remove content or disable accounts.',

    'Termination & data: you may delete your account in-app (Profile -> Account -> Delete Account) or contact us by email. We may suspend access for violations or if we discontinue the Service.',

    'Governing law & disputes: these Terms are governed by the laws of the State of Connecticut, and disputes must be resolved in Connecticut state or federal courts. Each party may seek injunctive relief for misuse of IP or breaches of confidentiality.',

    'Full terms: https://vendorconnectapp.com/terms-of-use/.',

  ];



  @override

  Widget build(BuildContext context) {

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Drawer(

      child: SafeArea(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            if (uid != null)

              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(

                stream:

                    FirebaseFirestore.instance

                        .collection(AppConfig.usersCollection)

                        .doc(uid)

                        .snapshots(),

                builder: (context, snap) {

                  final data = snap.data?.data();

                  final name =

                      data?['name'] ??

                      FirebaseAuth.instance.currentUser?.email ??

                      'Vendor';

                  final email =

                      data?['email'] ??

                      FirebaseAuth.instance.currentUser?.email ??

                      '';

                  return UserAccountsDrawerHeader(

                    accountName: Text(name),

                    accountEmail: Text(email),

                    currentAccountPicture: CircleAvatar(

                      child: Text(

                        name.toString().substring(0, 1).toUpperCase(),

                      ),

                    ),

                    decoration: const BoxDecoration(

                      gradient: LinearGradient(

                        colors: [Color(0xFF2BBFD4), Color(0xFF6EA7E5)],

                        begin: Alignment.topLeft,

                        end: Alignment.bottomRight,

                      ),

                    ),

                  );

                },

              )

            else

              const DrawerHeader(

                decoration: BoxDecoration(

                  gradient: LinearGradient(

                    colors: [Color(0xFF2BBFD4), Color(0xFF6EA7E5)],

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                  ),

                ),

                child: Align(

                  alignment: Alignment.centerLeft,

                  child: Text(

                    'Vendor Connect',

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 20,

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                ),

              ),

            ListTile(

              leading: const Icon(Icons.person_outline),

              title: const Text('Profile'),

              onTap: onNavigateToProfile,

            ),

            ListTile(

              leading: const Icon(Icons.info_outline),

              title: const Text('About Us'),

              onTap: () {

                Navigator.of(context).pop();

                Navigator.of(context).push(

                  MaterialPageRoute(

                    builder:

                        (_) => const InfoPage(

                          title: 'About Us',

                          paragraphs: [

                            'About Vendor Connect\n\nVendor Connect is our direct line to the 180+ makers, artists, and small businesses that power our marketplace. Built for iPhone and Android, the app brings all vendor communications into one clear, reliable channel: no lost emails, no missed posts.',

                            'When we publish a new article or share time-sensitive information, you\'ll get notified immediately in the app. You can read, comment, and join the conversation right away. It is an easy, two-way connection designed to answer questions faster, reduce confusion, and make sure everyone has what they need to succeed.',

                            'Behind the scenes, Vendor Connect helps our team support you better by organizing updates, tracking engagement, and ensuring important announcements never slip through the cracks. We are committed to building a transparent, responsive, and supportive vendor experience, and this app is a big step toward that promise.',

                          ],

                        ),

                  ),

                );

              },

            ),

            ListTile(

              leading: const Icon(Icons.support_agent_outlined),

              title: const Text('Support'),

              onTap: () async {

                Navigator.of(context).pop();

                await _openExternalOrFallback(

                  context,

                  AppConfig.supportUrl,

                  fallbackTitle: 'Support / Contact',

                  fallbackParagraphs: _supportCopy,

                );

              },

            ),



            ListTile(

              leading: const Icon(Icons.lock_outline),

              title: const Text('Privacy Policy'),

              onTap: () async {

                Navigator.of(context).pop();

                await _openExternalOrFallback(

                  context,

                  AppConfig.privacyPolicyUrl,

                  fallbackTitle: 'Privacy Policy',

                  fallbackParagraphs: _privacyCopy,

                );

              },

            ),



            ListTile(

              leading: const Icon(Icons.article_outlined),

              title: const Text('Terms & Services'),

              onTap: () async {

                Navigator.of(context).pop();

                await _openExternalOrFallback(

                  context,

                  AppConfig.termsOfUseUrl,

                  fallbackTitle: 'Terms & Services',

                  fallbackParagraphs: _termsCopy,

                );

              },

            ),



            ListTile(

              leading: const Icon(Icons.logout),

              title: const Text('Sign out'),

              onTap: () async {

                final notificationService = context.read<NotificationService>();

                final authService = context.read<AuthService>();

                final navigator = Navigator.of(context);

                final previousUid = FirebaseAuth.instance.currentUser?.uid;

                try {

                  await authService.signOut();

                } on FirebaseAuthException catch (e) {

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(

                    SnackBar(

                      content: Text(

                        e.message ?? 'Unable to sign out. Please retry.',

                      ),

                    ),

                  );

                  return;

                } catch (_) {

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(

                    const SnackBar(

                      content: Text('Unable to sign out. Please retry.'),

                    ),

                  );

                  return;

                }

                unawaited(

                  notificationService.cleanupAfterSignOut(

                    uidOverride: previousUid,

                  ),

                );

                if (!context.mounted) return;

                navigator.pushNamedAndRemoveUntil(

                  AuthScreen.route,

                  (route) => false,

                );

              },

            ),

          ],

        ),

      ),

    );

  }

}

Future<void> _openExternalOrFallback(
  BuildContext context,
  String url, {
  String? fallbackTitle,
  List<String>? fallbackParagraphs,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (_) {}

  if (fallbackTitle != null && fallbackParagraphs != null) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InfoPage(
          title: fallbackTitle,
          paragraphs: fallbackParagraphs,
        ),
      ),
    );
  } else {
    messenger.showSnackBar(
      const SnackBar(content: Text('Unable to open link.')),
    );
  }
}
