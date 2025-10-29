import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                icon: uid == null
                    ? const Icon(Icons.article)
                    : StreamBuilder<int>(
                        stream: FirestoreService().watchUnreadCount(uid),
                        builder: (context, snap) {
                          final count = snap.data ?? 0;
                          // Update app badge in background
                          context.read<NotificationService>().setBadgeCount(count);
                          final icon = const Icon(Icons.article);
                          if (count <= 0) return icon;
                          return badges.Badge(
                            position: badges.BadgePosition.topEnd(top: -12, end: -12),
                            badgeContent: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                            child: icon,
                          );
                        },
                      ),
                label: 'Articles',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
                stream: FirebaseFirestore.instance
                    .collection(AppConfig.usersCollection)
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final name = data?['name'] ?? FirebaseAuth.instance.currentUser?.email ?? 'Vendor';
                  final email = data?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
                  return UserAccountsDrawerHeader(
                    accountName: Text(name),
                    accountEmail: Text(email),
                    currentAccountPicture: CircleAvatar(
                      child: Text(name.toString().substring(0, 1).toUpperCase()),
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
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
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
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InfoPage(
                    title: 'About Us',
                    paragraphs: [
                      'About Vendor Connect\n\nVendor Connect is our direct line to the 180+ makers, artists, and small businesses that power our marketplace. Built for iPhone and Android, the app brings all vendor communications into one clear, reliable channel: no lost emails, no missed posts.',
                      'When we publish a new article or share time-sensitive information, you\'ll get notified immediately in the app. You can read, comment, and join the conversation right away. It is an easy, two-way connection designed to answer questions faster, reduce confusion, and make sure everyone has what they need to succeed.',
                      'Behind the scenes, Vendor Connect helps our team support you better by organizing updates, tracking engagement, and ensuring important announcements never slip through the cracks. We are committed to building a transparent, responsive, and supportive vendor experience, and this app is a big step toward that promise.'
                    ],
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Support'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InfoPage(
                    title: 'Support / Contact',
                    paragraphs: [
                      'Support / Contact Page (short web copy)',
                      'Need help with Vendor Connect? We are here for you. Check our latest announcements in the app, or reach us directly:',
                      'Email: info@marketstreetcreatives.com',
                      'Phone: 860-626-4500 (Mon-Fri, 10am-5pm ET)',
                      'In-app: Profile -> Help & Support -> "Contact us"',
                      'Mail: Vendor Connect App c/o Market Street Creatives, LLC, 100 Lawton Street, Torrington, CT 06790 USA',
                      'For privacy questions or data requests (access/correction/deletion), email info@marketstreetcreatives.com. To delete your account and associated data, go to Profile -> Account -> Delete Account in the app.'
                    ],
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InfoPage(
                      title: 'Privacy Policy',
                      paragraphs: [
                        '''Privacy Policy (Vendor Connect)
Effective date: [Month Day, Year]
Applies to: the Vendor Connect mobile apps (iOS/Android) and the Vendor Connect pages on [www.vendorconnectapp.com].''',
                        '''Who we are
Vendor Connect ("we," "us," "our") is a subsidiary of Market Street Creatives, LLC, and it is a communication app used to share announcements, articles, and time-sensitive updates with our verified vendor community. You can reach us at [info@marketstreetcreatives.com] or [Market Street Creatives, c/o Vendor Connect App 100 Lawton Street, Torrington, CT 06790].''',
                        '''What this policy covers
This Privacy Policy explains what information we collect, how we use it, whom we share it with, and the choices you have. It also describes how to exercise your rights and how to contact us.''',
                        '''Information we collect
- Account & profile information: name, business name, email, phone, and any optional profile details you provide.
- Verification details (vendors): fields we use to confirm you are an approved vendor (e.g., booth number, rent plan, status).
- App activity & device data: app interactions (e.g., articles viewed, buttons tapped), device type/OS, app version, approximate region, crash/diagnostic logs.
- Notifications data: your device push token, so we can deliver notifications.
- Content you submit: comments, questions, attachments, and feedback.
- Support communications: information you send us when you request help.
- If you use our website, we may also collect cookies or similar technologies for basic site functionality and analytics.''',
                        '''How we use information
- Communication & support: deliver announcements, notify you about new posts, and respond to questions.
- Community features: enable commenting and conversation on posts.
- App operations & safety: maintain, improve, and secure the app; prevent spam, abuse, or violations of our Terms.
- Analytics: understand which content is useful so we can improve vendor support.
- Legal/compliance: comply with applicable laws and enforce our agreements.''',
                        '''Legal bases (EEA/UK users)
Where applicable, we rely on: performance of a contract (providing the app), legitimate interests (improving and securing our services), and consent (e.g., push notifications where required). You may withdraw consent in your device settings at any time.''',
                        '''Sharing of information
We do not sell your personal information. We share it only with:
- Service providers/Processors that help us run the app (e.g., hosting, push notifications, analytics, crash reporting). Examples may include Firebase/Google Cloud, Apple/Google push services, and similar providers.
- Legal and safety: if required by law or to protect rights, safety, or the integrity of our services.
- Business transfers: as part of a merger, acquisition, or asset sale (we'll notify you if that happens).''',
                        '''Data retention
We keep personal information only as long as needed for the purposes above, and then delete or anonymize it unless we must retain it to comply with legal obligations or to resolve disputes.''',
                        '''Your choices & rights
- Notifications: control push notifications in your device settings and (where provided) within the app.
- Access, correction, deletion: you may request access to, correction of, or deletion of your personal information by contacting [info@marketstreetcreatives.com].
- Account deletion: if you have an account, you can initiate deletion from within the app at: Profile -> Account -> Delete Account (or contact us at the email above). We will delete associated personal data unless we must retain some information for legal reasons (e.g., records, security, or accounting).
- Regional rights: If you are in a region with specific privacy laws (e.g., GDPR/UK GDPR/CPRA), you may have additional rights such as data portability or the right to object/restrict processing. Use the contact details below to exercise these rights. We will verify your request to protect your data.''',
                        '''Children's privacy
Vendor Connect is intended for adults involved in our vendor program. We do not knowingly collect personal information from children under 13 (or the relevant age in your jurisdiction). If you believe a child has provided personal data, contact us and we will take appropriate steps to remove it.''',
                        '''Security
We use reasonable administrative, technical, and physical safeguards to protect your information. No system is perfectly secure; please keep your account credentials confidential and notify us of any suspected unauthorized access.''',
                        '''International transfers
If we process data outside your country, we use appropriate safeguards as required by law. By using Vendor Connect, you understand your data may be processed in countries with privacy laws different from your own.''',
                        '''Changes to this policy
We may update this Privacy Policy from time to time. We'll post changes here and update the "Effective date." If changes are material, we will provide additional notice in the app.''',
                        '''Contact us
Email: [info@marketstreetcreatives.com]
Mail: Market Street Creatives, LLC. 100 Lawton Street, Torrington, CT 06790 USA'''
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Terms & Services'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InfoPage(
                    title: 'Terms & Services',
                    paragraphs: [
                      '''Terms of Use (Vendor Connect)
Effective date: October 24, 2025
Agreement between you and Vendor Connect App c/o Market Street Creatives, LLC
These Terms of Use ("Terms") govern your access to and use of the Vendor Connect apps and related websites (collectively, the "Service"). By using the Service, you agree to these Terms.''',
                      '''If you access Vendor Connect via iOS, Apple's Standard EULA also applies unless we have provided a custom EULA in App Store Connect. On Android, you are also bound by Google Play's terms.''',
                      '''1) Who may use the Service
You must be (a) at least 18 years old and (b) an approved vendor (or authorized representative) in good standing with us. We may require verification and may approve or reject access at our discretion.''',
                      '''2) Your account
You are responsible for your account credentials and all activity under your account. Notify us immediately of any unauthorized use. We may suspend or terminate accounts that violate these Terms.''',
                      '''3) Purpose of the Service
Vendor Connect provides a direct communication channel for announcements, articles, reminders, and vendor discussions. The Service is not a public forum; it is intended solely for our vendor community.''',
                      '''4) Community & acceptable use
You agree not to:
- Post unlawful, threatening, harassing, defamatory, hateful, or infringing content.
- Share private or confidential information without authorization.
- Impersonate others, misrepresent your affiliation, or spam.
- Attempt to probe, scan, or test system vulnerabilities; use bots or scrapers; or disrupt the Service.
We may remove content or suspend accounts to maintain a safe and productive environment.''',
                      '''5) Your content & feedback
You retain ownership of comments and other content you submit ("User Content"). You grant us a non-exclusive, worldwide, royalty-free license to host, store, display, and share your User Content within the Service for the purpose of operating and improving the Service. If you provide feedback or suggestions, you grant us the right to use them without restriction or compensation.''',
                      '''6) Notifications
By enabling push notifications, you consent to receive in-app notifications. You can turn notifications off in your device settings; doing so may limit the timely delivery of important updates.''',
                      '''7) Third-party services & links
The Service may rely on third-party services (for example, hosting, analytics, or push services) or link to third-party sites. We are not responsible for third-party content or practices.''',
                      '''8) Updates and availability
We may update or discontinue features at any time. The Service may be temporarily unavailable due to maintenance or events beyond our control.''',
                      '''9) Fees
Access to Vendor Connect may be provided as a benefit of your vendor relationship. If any fees apply now or in the future, we will disclose them separately.''',
                      '''10) Intellectual property
The Service, including logos, trademarks, and software, is owned by [Company Legal Name] or its licensors and is protected by law. Except for the limited rights expressly granted to you in these Terms, we reserve all rights.''',
                      '''11) Disclaimers
The Service is provided "AS IS" and "AS AVAILABLE." We disclaim all warranties to the fullest extent permitted by law, including implied warranties of merchantability, fitness for a particular purpose, and non-infringement. We do not warrant that the Service will be uninterrupted, secure, or error-free.''',
                      '''12) Limitation of liability
To the fullest extent permitted by law, Market Street Creatives, LLC and its affiliates will not be liable for indirect, incidental, special, consequential, or punitive damages, or for lost profits, revenues, or data, arising out of or related to your use of the Service. Our total liability for any claim will not exceed 100 USD or the amount you paid (if any) for the Service in the 12 months before the claim, whichever is greater.''',
                      '''13) Indemnification
You will indemnify and hold harmless [Company Legal Name], its affiliates, and personnel from and against claims, liabilities, damages, losses, and expenses (including reasonable attorneys' fees) arising from your use of the Service, your User Content, or your breach of these Terms.''',
                      '''14) Termination
You may stop using the Service at any time. You can delete your account in-app at Profile -> Account -> Delete Account (or contact us). We may suspend or terminate access if you violate these Terms or if we discontinue the Service. Sections intended to survive termination will survive (including intellectual property, disclaimers, limitations, indemnity, and governing law).''',
                      '''15) Governing law & disputes
These Terms are governed by the laws of the State of Connecticut, without regard to conflict-of-law rules. You agree to exclusive jurisdiction and venue in the state and federal courts located in Connecticut, USA. Each party may also seek injunctive relief for misuse of intellectual property or breach of confidentiality.''',
                      '''16) Changes to these Terms
We may update these Terms from time to time. We will post changes in the app or on our website and update the "Effective date." If changes are material, we will provide additional notice.''',
                      '''17) Contact
Email: info@marketstreetcreatives.com
Mail: Vendor Connect App c/o Market Street Creatives, LLC 100 Lawton Street, Torrington, CT 06790
In-app: Profile -> Help & Support'''
                    ],
                  ),
                ));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                await context.read<NotificationService>().subscribeAdmins(false);
                await context.read<AuthService>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(AuthScreen.route, (route) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}


