import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'models/loyalty_partner.dart';
import 'services/admin_management_service.dart';
import 'services/loyalty_service.dart';
import 'services/vendor_admin_service.dart';
import 'utils/role_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminWebApp());
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendor Connect Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F9FB5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7F8),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Color(0xFF121A1F),
          ),
          titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 15),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (user == null) return const AdminLoginScreen();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConfig.usersCollection)
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            final data = profileSnap.data?.data();
            if (normalizedRole(data) != 'admin') {
              return _AccessDenied(email: user.email ?? '');
            }
            return AdminDashboardShell(userData: data ?? const {});
          },
        );
      },
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'arsalanlehri01@gmail.com');
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not sign in.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vendor Connect Admin',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!email.contains('@')) return 'Enter admin email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'Enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key, required this.userData});

  final Map<String, dynamic> userData;

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardOverview(onOpenSection: _openSection),
      const _CommentsAdminPage(),
      const _LoyaltyAdminPage(),
      const _UsersAdminPage(),
      const _AdminsPage(),
    ];
    final navItems = const [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.comment_outlined),
        selectedIcon: Icon(Icons.comment),
        label: Text('Comments'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.card_membership_outlined),
        selectedIcon: Icon(Icons.card_membership),
        label: Text('Loyalty'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('Users'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.admin_panel_settings_outlined),
        selectedIcon: Icon(Icons.admin_panel_settings),
        label: Text('Admins'),
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFFF8FBFC),
            minWidth: 120,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            useIndicator: true,
            indicatorColor: const Color(0xFFBFEFF3),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            selectedIconTheme: const IconThemeData(
              color: Color(0xFF063D47),
              size: 32,
            ),
            unselectedIconTheme: const IconThemeData(
              color: Color(0xFF344449),
              size: 28,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF1B2A30),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Color(0xFF33434A),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Image.asset(
                'assets/images/vendor_connect_logo.png',
                width: 70,
                height: 70,
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: IconButton(
                tooltip: 'Sign out',
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
              ),
            ),
            destinations: navItems,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }

  void _openSection(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.onOpenSection});

  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              _HeaderActionButton(
                icon: Icons.tune,
                label: 'Filter',
                onPressed: () {},
              ),
              const SizedBox(width: 14),
              _HeaderActionButton(
                icon: Icons.account_circle_outlined,
                label: 'Profile',
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFC7DADD),
                    Color(0xFFEAF1F2),
                    Color(0xFF8FAFB5),
                  ],
                ),
                border: Border.all(color: const Color(0xFF9AB8BE)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330A2A30),
                    blurRadius: 20,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final cardWidth = width >= 1180
                            ? (width - 54) / 4
                            : width >= 880
                                ? (width - 18) / 2
                                : width;
                        return Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          children: [
                            _CountTile(
                              title: 'New Comments',
                              collection: 'comments',
                              isCollectionGroup: true,
                              last24HoursOnly: true,
                              icon: Icons.comment,
                              accent: const Color(0xFFE6A77D),
                              width: cardWidth,
                              onTap: () => onOpenSection(1),
                            ),
                            _CountTile(
                              title: 'Loyalty Benefits',
                              collection: AppConfig.loyaltyPartnersCollection,
                              icon: Icons.card_membership,
                              accent: const Color(0xFFC8F58A),
                              width: cardWidth,
                              onTap: () => onOpenSection(2),
                            ),
                            _CountTile(
                              title: 'Users',
                              collection: AppConfig.usersCollection,
                              icon: Icons.people,
                              accent: const Color(0xFF7FD2DF),
                              width: cardWidth,
                              onTap: () => onOpenSection(3),
                            ),
                            _CountTile(
                              title: 'Active Admins',
                              collection: AppConfig.usersCollection,
                              icon: Icons.admin_panel_settings,
                              accent: const Color(0xFFF1D08A),
                              width: cardWidth,
                              whereField: 'role',
                              whereValue: 'admin',
                              onTap: () => onOpenSection(4),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1040;
                        if (!wide) {
                          return const Column(
                            children: [
                              _AdoptionPanel(),
                              SizedBox(height: 18),
                              _RecentActivityPanel(),
                              SizedBox(height: 18),
                              _SideInsightColumn(),
                            ],
                          );
                        }
                        return const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _AdoptionPanel()),
                            SizedBox(width: 18),
                            Expanded(flex: 6, child: _RecentActivityPanel()),
                            SizedBox(width: 18),
                            Expanded(flex: 4, child: _SideInsightColumn()),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.title,
    required this.collection,
    required this.icon,
    required this.onTap,
    required this.accent,
    required this.width,
    this.isCollectionGroup = false,
    this.last24HoursOnly = false,
    this.whereField,
    this.whereValue,
  });

  final String title;
  final String collection;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final double width;
  final bool isCollectionGroup;
  final bool last24HoursOnly;
  final String? whereField;
  final Object? whereValue;

  @override
  Widget build(BuildContext context) {
    final cutoff = Timestamp.fromDate(
      DateTime.now().toUtc().subtract(const Duration(hours: 24)),
    );
    Query<Map<String, dynamic>> query = isCollectionGroup
        ? FirebaseFirestore.instance.collectionGroup(collection)
        : FirebaseFirestore.instance.collection(collection);
    if (last24HoursOnly) {
      query = query
          .where('createdAtClient', isGreaterThanOrEqualTo: cutoff)
          .orderBy('createdAtClient', descending: true);
    }
    if (whereField != null) {
      query = query.where(whereField!, isEqualTo: whereValue);
    }
    return SizedBox(
      width: width,
      height: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF073D46), Color(0xFF0B5662)],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.65)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF062A30).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length;
                  return Stack(
                    children: [
                      Positioned(
                        right: 0,
                        bottom: 0,
                        left: 0,
                        child: SizedBox(
                          height: 52,
                          child: CustomPaint(
                            painter: _SparklinePainter(color: accent),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: accent, size: 32),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  count == null ? '-' : count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF142228),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        side: const BorderSide(color: Color(0xFFB5C1C6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.child,
    this.height,
  });

  final String title;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF083B45), Color(0xFF0A5864)],
        ),
        border: Border.all(color: const Color(0xFF2C7C86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062C33).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdoptionPanel extends StatelessWidget {
  const _AdoptionPanel();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Loyalty Program Adoption Rate',
      height: 360,
      child: CustomPaint(
        painter: _BarChartPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Recent User Activity',
      height: 360,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(AppConfig.usersCollection)
            .limit(6)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Text(
              'No recent users available.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            );
          }
          return Column(
            children: [
              const _ActivityHeader(),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final name = (data['businessName'] ?? data['name'] ?? data['email'] ?? 'User')
                        .toString();
                    final approved = truthy(data['approved']);
                    final disabled = truthy(data['disabled']);
                    final status = disabled
                        ? 'Disabled'
                        : approved
                            ? 'Approved'
                            : 'Pending';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFBDEEF3),
                            child: Text(
                              name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF063B44),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 3,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              status,
                              style: TextStyle(
                                color: approved && !disabled
                                    ? const Color(0xFFC8F58A)
                                    : const Color(0xFFE6A77D),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('User', style: TextStyle(color: Colors.white)),
          ),
          Expanded(
            flex: 2,
            child: Text('Status', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SideInsightColumn extends StatelessWidget {
  const _SideInsightColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _OffersPanel(),
        SizedBox(height: 18),
        _CommentVolumePanel(),
        SizedBox(height: 18),
        _SystemHealthPanel(),
      ],
    );
  }
}

class _OffersPanel extends StatelessWidget {
  const _OffersPanel();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Top Loyalty Offers',
      height: 132,
      child: Row(
        children: const [
          _OfferIcon(icon: Icons.card_giftcard, color: Color(0xFFE6A77D)),
          _OfferIcon(icon: Icons.percent, color: Color(0xFFC8F58A)),
          _OfferIcon(icon: Icons.payments_outlined, color: Color(0xFFF1D08A)),
          _OfferIcon(icon: Icons.local_offer_outlined, color: Color(0xFFBDEEF3)),
        ],
      ),
    );
  }
}

class _OfferIcon extends StatelessWidget {
  const _OfferIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: const Color(0xFF063B44), size: 28),
    );
  }
}

class _CommentVolumePanel extends StatelessWidget {
  const _CommentVolumePanel();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Real-time Comment Volume',
      height: 170,
      child: CustomPaint(
        painter: const _SparklinePainter(color: Color(0xFF7FD2DF), filled: true),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SystemHealthPanel extends StatelessWidget {
  const _SystemHealthPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF083B45), Color(0xFF0A5864)],
        ),
        border: Border.all(color: const Color(0xFF2C7C86)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'System Health',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF83E6B5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF83E6B5).withValues(alpha: 0.6),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Online',
            style: TextStyle(color: Color(0xFFB6F3C8), fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CommentsAdminPage extends StatefulWidget {
  const _CommentsAdminPage();

  @override
  State<_CommentsAdminPage> createState() => _CommentsAdminPageState();
}

class _CommentsAdminPageState extends State<_CommentsAdminPage> {
  final _search = TextEditingController();
  final Map<String, String> _articleTitleCache = <String, String>{};
  String? _selectedArticleId;

  Future<String> _articleTitleFor(String articleId) async {
    final trimmedId = articleId.trim();
    if (trimmedId.isEmpty) return 'Unknown article';
    final cached = _articleTitleCache[trimmedId];
    if (cached != null) return cached;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConfig.articlesCollection)
        .doc(trimmedId)
        .get();
    final data = snapshot.data();
    final title = (data?['title'] ?? '').toString().trim();
    final resolved = title.isEmpty ? 'Article $trimmedId' : title;
    _articleTitleCache[trimmedId] = resolved;
    return resolved;
  }

  Future<void> _reply(DocumentReference<Map<String, dynamic>> ref) async {
    final controller = TextEditingController();
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to comment'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Reply'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save reply'),
          ),
        ],
      ),
    );
    if (reply == null || reply.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    await ref.set({
      'replyText': reply,
      'replyByUid': user?.uid ?? '',
      'replyByName': user?.displayName ?? user?.email ?? 'Admin',
      'replyCreatedAt': FieldValue.serverTimestamp(),
      'replyCreatedAtClient': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _delete(DocumentReference<Map<String, dynamic>> ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment'),
        content: const Text('This removes the comment from the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: 'Comments',
      actions: [
        _ArticleFilterDropdown(
          selectedArticleId: _selectedArticleId,
          onChanged: (articleId) {
            setState(() => _selectedArticleId = articleId);
          },
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 320,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search comments',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'New Comments (24h)'),
                Tab(text: 'All Article Comments'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCommentsList(
                    query: _newCommentsQuery(),
                    emptyText: 'No comments found in the last 24 hours.',
                  ),
                  _buildCommentsList(
                    query: _allCommentsQuery(),
                    emptyText: 'No comments found.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Query<Map<String, dynamic>> _newCommentsQuery() {
    final cutoff = Timestamp.fromDate(
      DateTime.now().toUtc().subtract(const Duration(hours: 24)),
    );
    final selectedArticleId = _selectedArticleId?.trim();
    if (selectedArticleId != null && selectedArticleId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection(AppConfig.articlesCollection)
          .doc(selectedArticleId)
          .collection(AppConfig.commentsSubcollection)
          .where('createdAtClient', isGreaterThanOrEqualTo: cutoff)
          .orderBy('createdAtClient', descending: true)
          .limit(300);
    }
    return FirebaseFirestore.instance
        .collectionGroup(AppConfig.commentsSubcollection)
        .where('createdAtClient', isGreaterThanOrEqualTo: cutoff)
        .orderBy('createdAtClient', descending: true)
        .limit(300);
  }

  Query<Map<String, dynamic>> _allCommentsQuery() {
    final selectedArticleId = _selectedArticleId?.trim();
    if (selectedArticleId != null && selectedArticleId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection(AppConfig.articlesCollection)
          .doc(selectedArticleId)
          .collection(AppConfig.commentsSubcollection)
          .orderBy('createdAtClient', descending: true)
          .limit(1000);
    }
    return FirebaseFirestore.instance
        .collectionGroup(AppConfig.commentsSubcollection)
        .orderBy('createdAtClient', descending: true)
        .limit(1000);
  }

  String _articleIdForComment(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final fromData = (doc.data()['articleId'] ?? '').toString().trim();
    if (fromData.isNotEmpty) return fromData;
    return doc.reference.parent.parent?.id ?? '';
  }

  Widget _buildCommentsList({
    required Query<Map<String, dynamic>> query,
    required String emptyText,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        final needle = _search.text.trim().toLowerCase();
        final docs = (snapshot.data?.docs ?? const [])
            .where((doc) {
              if (needle.isEmpty) return true;
              final data = doc.data();
              final haystack =
                  '${data['text']} ${data['authorName']} ${data['articleId']} ${data['replyText']}'
                      .toLowerCase();
              return haystack.contains(needle);
            })
            .toList(growable: false);
        if (docs.isEmpty) return Text(emptyText);
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final text = (data['text'] ?? '').toString();
            final reply = (data['replyText'] ?? '').toString();
            final author = (data['authorName'] ?? 'Vendor').toString();
            final articleId = _articleIdForComment(doc);
            return ListTile(
              title: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: _articleTitleFor(articleId),
                    builder: (context, titleSnapshot) {
                      final articleTitle =
                          titleSnapshot.data ?? 'Article $articleId';
                      return SelectableText(
                        '$author - $articleTitle',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    },
                  ),
                  if (reply.isNotEmpty)
                    SelectableText(
                      'Reply: $reply',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Copy comment text',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comment copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                  ),
                  IconButton(
                    tooltip: 'Reply',
                    onPressed: () => _reply(doc.reference),
                    icon: const Icon(Icons.reply),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _delete(doc.reference),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ArticleFilterDropdown extends StatelessWidget {
  const _ArticleFilterDropdown({
    required this.selectedArticleId,
    required this.onChanged,
  });

  final String? selectedArticleId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(AppConfig.articlesCollection)
            .orderBy('publishedAt', descending: true)
            .limit(250)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final ids = docs.map((doc) => doc.id).toSet();
          final value = selectedArticleId != null && ids.contains(selectedArticleId)
              ? selectedArticleId
              : null;
          return DropdownButtonFormField<String?>(
            value: value,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter by article',
              prefixIcon: Icon(Icons.article_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All articles'),
              ),
              ...docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] ?? '').toString().trim();
                return DropdownMenuItem<String?>(
                  value: doc.id,
                  child: Text(
                    title.isEmpty ? 'Article ${doc.id}' : title,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: onChanged,
          );
        },
      ),
    );
  }
}

class _LoyaltyAdminPage extends StatefulWidget {
  const _LoyaltyAdminPage();

  @override
  State<_LoyaltyAdminPage> createState() => _LoyaltyAdminPageState();
}

class _LoyaltyAdminPageState extends State<_LoyaltyAdminPage> {
  final _service = LoyaltyService();

  Future<void> _openEditor([LoyaltyPartner? partner]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _LoyaltyEditor(partner: partner),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loyalty benefit saved.')),
      );
    }
  }

  Future<void> _delete(LoyaltyPartner partner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete loyalty benefit'),
        content: Text('Delete ${partner.businessName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.deletePartner(partner.id);
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: 'Loyalty Benefits',
      actions: [
        FilledButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Add benefit'),
        ),
      ],
      child: StreamBuilder<List<LoyaltyPartner>>(
        stream: _service.watchAllPartners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          final partners = snapshot.data ?? const <LoyaltyPartner>[];
          if (partners.isEmpty) return const Text('No loyalty benefits yet.');
          return ListView.separated(
            itemCount: partners.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final partner = partners[index];
              return ListTile(
                title: Text(partner.businessName),
                subtitle: Text(
                  '${partner.offerHeadline} - ${partner.fullAddress}',
                ),
                leading: Icon(
                  partner.isActive
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => _openEditor(partner),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _delete(partner),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LoyaltyEditor extends StatefulWidget {
  const _LoyaltyEditor({this.partner});

  final LoyaltyPartner? partner;

  @override
  State<_LoyaltyEditor> createState() => _LoyaltyEditorState();
}

class _LoyaltyEditorState extends State<_LoyaltyEditor> {
  final _formKey = GlobalKey<FormState>();
  final _service = LoyaltyService();
  late final TextEditingController _business;
  late final TextEditingController _offerDescription;
  late final TextEditingController _offerAmount;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _sortOrder;
  String _offerUnit = r'$';
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final partner = widget.partner;
    _business = TextEditingController(text: partner?.businessName ?? '');
    _offerDescription = TextEditingController(
      text: partner?.offerDescription ?? '',
    );
    _offerAmount = TextEditingController(
      text: partner?.offerAmount?.toString() ?? '',
    );
    _address = TextEditingController(text: partner?.address ?? '');
    _city = TextEditingController(text: partner?.city ?? '');
    _state = TextEditingController(text: partner?.state ?? '');
    _zip = TextEditingController(text: partner?.zipCode ?? '');
    _phone = TextEditingController(text: partner?.phone ?? '');
    _email = TextEditingController(text: partner?.email ?? '');
    _website = TextEditingController(text: partner?.website ?? '');
    _sortOrder = TextEditingController(
      text: (partner?.sortOrder ?? 0).toString(),
    );
    _offerUnit = partner?.offerUnit ?? r'$';
    _isActive = partner?.isActive ?? true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.savePartner(
        id: widget.partner?.id,
        businessName: _business.text,
        address: _address.text,
        city: _city.text,
        state: _state.text,
        zipCode: _zip.text,
        phone: _phone.text,
        email: _email.text,
        website: _website.text,
        offerDescription: _offerDescription.text,
        offerAmount: double.tryParse(_offerAmount.text.trim()) ?? 0,
        offerUnit: _offerUnit,
        isActive: _isActive,
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
        eligibleVendorIds: widget.partner?.eligibleVendorIds ?? const [],
        eligibleVendorNames: widget.partner?.eligibleVendorNames ?? const [],
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.partner == null ? 'Add benefit' : 'Edit benefit'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(_business, 'Business name', required: true),
                _field(_offerDescription, 'Offer description', required: true),
                _field(_offerAmount, 'Offer amount', number: true),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _offerUnit,
                    decoration: const InputDecoration(labelText: 'Offer type'),
                    items: const [
                      DropdownMenuItem(value: r'$', child: Text(r'$ off')),
                      DropdownMenuItem(value: '%', child: Text('% off')),
                    ],
                    onChanged: (value) =>
                        setState(() => _offerUnit = value ?? r'$'),
                  ),
                ),
                _field(_address, 'Address'),
                _field(_city, 'City'),
                _field(_state, 'State'),
                _field(_zip, 'ZIP'),
                _field(_phone, 'Phone'),
                _field(_email, 'Email'),
                _field(_website, 'Website'),
                _field(_sortOrder, 'Sort order', number: true),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    title: const Text('Visible'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
  }) {
    return SizedBox(
      width: 220,
      child: TextFormField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (required && (value ?? '').trim().isEmpty) return 'Required';
          return null;
        },
      ),
    );
  }
}

enum _UserStatusFilter { pending, approved, disabled, all }

class _UsersAdminPage extends StatefulWidget {
  const _UsersAdminPage();

  @override
  State<_UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends State<_UsersAdminPage> {
  final _service = VendorAdminService();
  final _search = TextEditingController();
  _UserStatusFilter _filter = _UserStatusFilter.pending;
  String? _busyUid;

  Future<void> _setFlags(
    String uid, {
    required bool approved,
    required bool disabled,
    required String message,
  }) async {
    setState(() => _busyUid = uid);
    try {
      await _service.setVendorFlags(
        uid: uid,
        approved: approved,
        disabled: disabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _deleteUser(String uid, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove user'),
        content: Text('Remove $label from Vendor Connect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyUid = uid);
    try {
      await _service.deleteVendor(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User removed.')),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final role = normalizedRole(data);
    final approved = truthy(data['approved']);
    final disabled = truthy(data['disabled']);
    if (_filter == _UserStatusFilter.pending) {
      return role != 'admin' && !approved && !disabled;
    }
    if (_filter == _UserStatusFilter.approved) {
      return role != 'admin' && approved && !disabled;
    }
    if (_filter == _UserStatusFilter.disabled) {
      return role != 'admin' && disabled;
    }
    return true;
  }

  String _displayName(Map<String, dynamic> data, String fallback) {
    final business = (data['businessName'] ?? '').toString().trim();
    if (business.isNotEmpty) return business;
    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final email = (data['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;
    return fallback;
  }

  String _filterLabel(_UserStatusFilter filter) {
    switch (filter) {
      case _UserStatusFilter.pending:
        return 'Pending Users';
      case _UserStatusFilter.approved:
        return 'Approved Users';
      case _UserStatusFilter.disabled:
        return 'Disabled';
      case _UserStatusFilter.all:
        return 'All Users';
    }
  }

  Future<void> _repairMissingPendingUser() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final businessController = TextEditingController();
    final phoneController = TextEditingController();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add missing pending user'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Registered email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name optional'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: businessController,
                decoration: const InputDecoration(
                  labelText: 'Business name optional',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone optional'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'email': emailController.text.trim(),
              'name': nameController.text.trim(),
              'businessName': businessController.text.trim(),
              'phone': phoneController.text.trim(),
            }),
            child: const Text('Create pending profile'),
          ),
        ],
      ),
    );
    emailController.dispose();
    nameController.dispose();
    businessController.dispose();
    phoneController.dispose();

    if (!mounted) return;
    if (values == null) return;
    final email = values['email'] ?? '';
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid registered email.')),
      );
      return;
    }

    setState(() => _busyUid = '_repair_pending_user');
    try {
      await _service.createPendingVendorProfile(
        email: email,
        name: values['name'],
        businessName: values['businessName'],
        phone: values['phone'],
      );
      if (!mounted) return;
      setState(() => _filter = _UserStatusFilter.pending);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pending vendor profile created.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: 'Users',
      actions: [
        FilledButton.icon(
          onPressed:
              _busyUid == '_repair_pending_user' ? null : _repairMissingPendingUser,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add missing pending user'),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search users',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserFilterTabs(
            selected: _filter,
            labelFor: _filterLabel,
            onSelected: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(AppConfig.usersCollection)
                  .snapshots(),
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          final needle = _search.text.trim().toLowerCase();
          final docs = (snapshot.data?.docs ?? const [])
              .where((doc) {
                final data = doc.data();
                if (!_matchesFilter(data)) return false;
                if (needle.isEmpty) return true;
                final haystack =
                    '${data['name']} ${data['businessName']} ${data['email']} ${data['phone']}'
                        .toLowerCase();
                return haystack.contains(needle);
              })
              .toList(growable: false)
            ..sort((a, b) {
              final left = _displayName(a.data(), a.id).toLowerCase();
              final right = _displayName(b.data(), b.id).toLowerCase();
              return left.compareTo(right);
            });

          if (docs.isEmpty) {
            return Text('No ${_filterLabel(_filter).toLowerCase()} found.');
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final role = normalizedRole(data);
              final approved = truthy(data['approved']);
              final disabled = truthy(data['disabled']);
              final label = _displayName(data, doc.id);
              final email = (data['email'] ?? '').toString();
              final isAdmin = role == 'admin';
              final isCurrentUser =
                  FirebaseAuth.instance.currentUser?.uid == doc.id;
              final busy = _busyUid == doc.id;
              final status = isAdmin
                  ? 'Admin'
                  : disabled
                      ? 'Disabled'
                      : approved
                          ? 'Approved'
                          : 'Pending';

              return ListTile(
                leading: Icon(
                  isAdmin
                      ? Icons.admin_panel_settings
                      : approved && !disabled
                          ? Icons.verified_user_outlined
                          : Icons.pending_actions_outlined,
                ),
                title: Text(label),
                subtitle: Text('$email - $status'),
                trailing: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Wrap(
                        spacing: 8,
                        children: [
                          if (!isAdmin && !approved && !disabled)
                            TextButton.icon(
                              onPressed: () => _setFlags(
                                doc.id,
                                approved: true,
                                disabled: false,
                                message: 'Pending user accepted.',
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Accept'),
                            ),
                          if (!isAdmin && !approved && !disabled)
                            TextButton.icon(
                              onPressed: () => _setFlags(
                                doc.id,
                                approved: false,
                                disabled: true,
                                message: 'Pending user rejected.',
                              ),
                              icon: const Icon(Icons.block),
                              label: const Text('Reject'),
                            ),
                          if (!isAdmin && disabled)
                            TextButton.icon(
                              onPressed: () => _setFlags(
                                doc.id,
                                approved: true,
                                disabled: false,
                                message: 'User activated.',
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Activate'),
                            ),
                          if (!isAdmin && approved && !disabled)
                            TextButton.icon(
                              onPressed: () => _setFlags(
                                doc.id,
                                approved: false,
                                disabled: true,
                                message: 'User disabled.',
                              ),
                              icon: const Icon(Icons.block),
                              label: const Text('Disable'),
                            ),
                          if (!isAdmin && !isCurrentUser)
                            IconButton(
                              tooltip: 'Remove user',
                              onPressed: () => _deleteUser(doc.id, label),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserFilterTabs extends StatelessWidget {
  const _UserFilterTabs({
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final _UserStatusFilter selected;
  final String Function(_UserStatusFilter filter) labelFor;
  final ValueChanged<_UserStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _UserStatusFilter.values.map((filter) {
        final isSelected = filter == selected;
        return ChoiceChip(
          selected: isSelected,
          label: Text(labelFor(filter)),
          onSelected: (_) => onSelected(filter),
          labelStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF183139),
          ),
          selectedColor: const Color(0xFF0A5864),
          backgroundColor: const Color(0xFFEAF3F4),
          side: BorderSide(
            color: isSelected ? const Color(0xFF0A5864) : const Color(0xFFB8CDD1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
      }).toList(growable: false),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.color, this.filled = false});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      Offset(0, size.height * 0.72),
      Offset(size.width * 0.14, size.height * 0.45),
      Offset(size.width * 0.26, size.height * 0.58),
      Offset(size.width * 0.39, size.height * 0.35),
      Offset(size.width * 0.52, size.height * 0.64),
      Offset(size.width * 0.66, size.height * 0.12),
      Offset(size.width * 0.78, size.height * 0.52),
      Offset(size.width * 0.91, size.height * 0.30),
      Offset(size.width, size.height * 0.16),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(previous.dx, previous.dy, midpoint.dx, midpoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    if (filled) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size);
      canvas.drawPath(fillPath, fillPaint);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.86),
      fontSize: 13,
    );
    final chartTop = 18.0;
    final chartBottom = size.height - 34;
    final chartLeft = 34.0;
    final chartRight = size.width - 12;
    final chartHeight = chartBottom - chartTop;
    final chartWidth = chartRight - chartLeft;
    for (var i = 0; i <= 4; i++) {
      final y = chartTop + chartHeight * i / 4;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    const tier1 = [66.0, 76.0, 82.0, 86.0, 88.0, 92.0];
    const tier2 = [35.0, 70.0, 46.0, 58.0, 59.0, 54.0];
    final groupWidth = chartWidth / months.length;
    final barWidth = groupWidth * 0.18;
    for (var i = 0; i < months.length; i++) {
      final center = chartLeft + groupWidth * i + groupWidth / 2;
      _drawBar(
        canvas,
        Rect.fromLTWH(
          center - barWidth - 4,
          chartBottom - chartHeight * tier1[i] / 100,
          barWidth,
          chartHeight * tier1[i] / 100,
        ),
        const Color(0xFF8ED7DF),
      );
      _drawBar(
        canvas,
        Rect.fromLTWH(
          center + 4,
          chartBottom - chartHeight * tier2[i] / 100,
          barWidth,
          chartHeight * tier2[i] / 100,
        ),
        const Color(0xFFC8F58A),
      );
      final painter = TextPainter(
        text: TextSpan(text: months[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(center - painter.width / 2, chartBottom + 10),
      );
    }

    const legendItems = [
      (Color(0xFF8ED7DF), 'Tier 1'),
      (Color(0xFFC8F58A), 'Tier 2'),
    ];
    var legendX = chartLeft;
    for (final item in legendItems) {
      final dotPaint = Paint()..color = item.$1;
      canvas.drawCircle(Offset(legendX, 4), 5, dotPaint);
      final painter = TextPainter(
        text: TextSpan(text: item.$2, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(legendX + 10, -4));
      legendX += 76;
    }
  }

  void _drawBar(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.35)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdminsPage extends StatefulWidget {
  const _AdminsPage();

  @override
  State<_AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<_AdminsPage> {
  final _service = AdminManagementService();
  late Future<List<AdminAccount>> _future = _service.listAdmins();

  void _reload() {
    setState(() => _future = _service.listAdmins());
  }

  Future<void> _addAdmin() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add admin'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Admin email'),
              ),
              const SizedBox(height: 10),
              Text(
                'If this email does not have an account yet, one will be created and a password setup email will be sent.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add admin'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      final result = await _service.addAdmin(email);
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.createdUser
                  ? 'Admin account created. Password setup email sent to $email.'
                  : 'Admin added. Password setup email sent to $email.',
            ),
          ),
        );
      } on FirebaseAuthException catch (emailError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Admin added, but setup email was not sent: ${emailError.message ?? emailError.code}',
            ),
          ),
        );
      }
      if (mounted && result.setupLink.isNotEmpty) {
        await _showSetupLink(email, result.setupLink);
      }
      _reload();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add admin: $err')),
      );
    }
  }

  Future<void> _showSetupLink(String email, String setupLink) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin setup link'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If $email does not receive the password setup email, copy this link and send it manually.',
              ),
              const SizedBox(height: 12),
              SelectableText(setupLink),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: setupLink));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Setup link copied.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAdmin(AdminAccount admin) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (admin.uid == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot remove your own admin role.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove admin'),
        content: Text('Remove admin access for ${admin.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.removeAdmin(admin.uid);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPageFrame(
      title: 'Admins',
      actions: [
        FilledButton.icon(
          onPressed: _addAdmin,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add admin'),
        ),
      ],
      child: FutureBuilder<List<AdminAccount>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text('Could not load admins: ${snapshot.error}');
          }
          final admins = snapshot.data ?? const <AdminAccount>[];
          if (admins.isEmpty) return const Text('No admins found.');
          return ListView.separated(
            itemCount: admins.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final admin = admins[index];
              return ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(admin.email),
                subtitle: Text(admin.name.isEmpty ? admin.role : admin.name),
                trailing: IconButton(
                  tooltip: 'Remove admin',
                  onPressed: () => _removeAdmin(admin),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminPageFrame extends StatelessWidget {
  const _AdminPageFrame({
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            Text('$email does not have admin access.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
