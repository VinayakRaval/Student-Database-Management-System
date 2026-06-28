import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/features/auth/screens/login_page.dart';
import 'package:frontend/features/admissions/screens/student_registration_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  final List<Map<String, String>> _slides = [
    {
      'title': 'Build Your Future',
      'sub': 'World-class Technical Education in Karnataka',
    },
    {
      'title': 'Innovate & Excel',
      'sub': 'Research-driven learning with industry exposure',
    },
    {
      'title': 'Shape Tomorrow',
      'sub': 'AICTE Approved · VTU Affiliated · Govt. of Karnataka',
    },
  ];
  final List<String> _assets = [
    'assets/images/carousel1.jpg',
    'assets/images/carousel2.jpg',
    'assets/images/carousel3.jpg',
  ];
  late final PageController _pageCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late Timer _autoSlide;
  int _page = 0;

  final ScrollController _scrollCtrl = ScrollController();
  bool _showScrollTop = false;

  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _deptsKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  bool _hAbout = false, _hDept = false, _hContact = false;
  bool _hReg = false, _hLog = false;
  bool _hFB = false, _hMail = false, _hLink = false;
  bool _hFAbout = false, _hFAdm = false, _hFDept = false, _hFCon = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _autoSlide = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_page + 1) % _slides.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });

    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 400;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
    });
  }

  @override
  void dispose() {
    _autoSlide.cancel();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final mobile = w < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black12,
                toolbarHeight: mobile ? 89 : 97,
                title: _NavBar(
                  mobile: mobile,
                  hAbout: _hAbout,
                  hDept: _hDept,
                  hContact: _hContact,
                  hReg: _hReg,
                  hLog: _hLog,
                  onAbout: () => _scrollTo(_aboutKey),
                  onDept: () => _scrollTo(_deptsKey),
                  onContact: () => _scrollTo(_contactKey),
                  onReg: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentRegistrationScreen(),
                    ),
                  ),
                  onLogin: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  setHover: (k, v) => setState(() {
                    if (k == 'about') {
                      _hAbout = v;
                    } else if (k == 'dept') {
                      _hDept = v;
                    } else if (k == 'contact') {
                      _hContact = v;
                    } else if (k == 'reg') {
                      _hReg = v;
                    } else if (k == 'log') {
                      _hLog = v;
                    }
                  }),
                  onMenuSelect: (v) {
                    if (v == 'about') {
                      _scrollTo(_aboutKey);
                    } else if (v == 'departments') {
                      _scrollTo(_deptsKey);
                    } else if (v == 'contact') {
                      _scrollTo(_contactKey);
                    } else if (v == 'register') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentRegistrationScreen(),
                        ),
                      );
                    } else if (v == 'login') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    }
                  },
                ),
                automaticallyImplyLeading: false,
              ),

              SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        _buildTopBanner(mobile),
                        _buildHero(mobile),
                        _buildAbout(mobile),
                        _buildDepts(mobile),
                        _buildFacilities(mobile),
                        _buildFooter(mobile),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),

          if (_showScrollTop)
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                mini: true,
                onPressed: () => _scrollCtrl.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                ),
                backgroundColor: const Color(0xFF0D2158),
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFFFFD700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBanner(bool mobile) => Container(
    color: const Color(0xFF080E1E),
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
    child: mobile
        ? const Center(
            child: Text(
              '🏛 Govt. of Karnataka · VTU Affiliated · AICTE Approved',
              style: TextStyle(color: Color(0xFF7A9CC4), fontSize: 10),
            ),
          )
        : const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏛 Government of Karnataka',
                style: TextStyle(
                  color: Color(0xFFB8C8E8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Established 2007  ·  AICTE Approved  ·  VTU Affiliated',
                style: TextStyle(color: Color(0xFF7A9CC4), fontSize: 11),
              ),
            ],
          ),
  );

  Widget _buildHero(bool mobile) {
    final height = mobile ? 320.0 : 520.0;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _assets.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _HeroSlide(
              assetPath: _assets[i],
              title: _slides[i]['title']!,
              sub: _slides[i]['sub']!,
              mobile: mobile,
              onApply: () {},
            ),
          ),
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowBtn(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  final prev = (_page - 1 + _slides.length) % _slides.length;
                  _pageCtrl.animateToPage(
                    prev,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowBtn(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  final next = (_page + 1) % _slides.length;
                  _pageCtrl.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return GestureDetector(
                  onTap: () => _pageCtrl.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 26 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFFFD700) : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbout(bool mobile) => Container(
    key: _aboutKey,
    color: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: mobile ? 48 : 80),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            _label('ABOUT US'),
            const SizedBox(height: 18),
            Text(
              'Government Engineering College, Chamarajanagara',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF0D2158),
                fontSize: mobile ? 22 : 34,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Established in 2007 under the Government of Karnataka, GEC Chamarajanagara offers quality '
              'technical education to students from the region. Affiliated to Visvesvaraya Technological '
              'University (VTU) and approved by AICTE, our institution is committed to academic excellence, '
              'research, and the holistic development of every student.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: mobile ? 13.5 : 15.5,
                height: 1.75,
              ),
            ),
            const SizedBox(height: 36),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _chip('2007', 'Established'),
                _chip('4', 'Departments'),
                _chip('VTU', 'Affiliated'),
                _chip('AICTE', 'Approved'),
                _chip('1000+', 'Students'),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _chip(String v, String l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D2158), Color(0xFF1565C0)],
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0D2158).withValues(alpha: 0.2),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v,
          style: GoogleFonts.poppins(
            color: const Color(0xFFFFD700),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(l, style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
      ],
    ),
  );

  Widget _buildDepts(bool mobile) {
    final depts = [
      _Dept(
        'CSE',
        'Computer Science\n& Engineering',
        Icons.computer_rounded,
        const Color(0xFF1565C0),
        const Color(0xFFE3F2FD),
        ['AI & ML', 'Data Structures', 'Cloud Computing', 'Cybersecurity'],
        'Build the future with code. Software engineering, AI, networks, and modern computing technologies.',
      ),
      _Dept(
        'ECE',
        'Electronics &\nCommunication Engg.',
        Icons.electrical_services_rounded,
        const Color(0xFF6A1B9A),
        const Color(0xFFF3E5F5),
        ['VLSI Design', 'Signal Processing', 'Embedded Systems', 'IoT'],
        'Design circuits that power the world. Bridging hardware and communication technologies.',
      ),
      _Dept(
        'ME',
        'Mechanical\nEngineering',
        Icons.settings_rounded,
        const Color(0xFFE65100),
        const Color(0xFFFFF3E0),
        ['Thermodynamics', 'CAD/CAM', 'Robotics', 'Automobile'],
        'Engineer real-world machines. Develop problem-solvers who design, build, and improve.',
      ),
      _Dept(
        'CIVIL',
        'Civil\nEngineering',
        Icons.architecture_rounded,
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
        [
          'Structural Engg.',
          'Environmental',
          'Construction Mgmt.',
          'Surveying',
        ],
        'Shape infrastructure of tomorrow. Roads, bridges, dams and foundations of society.',
      ),
    ];

    return Container(
      key: _deptsKey,
      color: const Color(0xFFF8FAFE),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: mobile ? 48 : 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _label('OUR DEPARTMENTS'),
              const SizedBox(height: 16),
              Text(
                'Programmes Offered',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF0D2158),
                  fontSize: mobile ? 24 : 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'B.E. (4 Years)  ·  Lateral Entry (3 Years)',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: mobile ? 12 : 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (_, c) {
                  final cols = c.maxWidth >= 760 ? 2 : 1;
                  final cardW = (c.maxWidth - (cols - 1) * 20) / cols;
                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: depts
                        .map(
                          (d) => SizedBox(
                            width: cardW,
                            child: _DeptCard(dept: d),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacilities(bool mobile) {
    final items = [
      _Fac(
        Icons.work_outline_rounded,
        const Color(0xFF1565C0),
        'Placement Cell',
        'Industry tie-ups, campus drives, and career counselling for all students.',
      ),
      _Fac(
        Icons.model_training_rounded,
        const Color(0xFF6A1B9A),
        'Training & Development',
        'Aptitude coaching, technical workshops, and industry expert sessions.',
      ),
      _Fac(
        Icons.science_outlined,
        const Color(0xFF00838F),
        'Modern Laboratories',
        'Well-equipped labs across all departments.',
      ),
      _Fac(
        Icons.verified_outlined,
        const Color(0xFF2E7D32),
        'AICTE Approved',
        'Fully accredited by AICTE and affiliated to VTU, Belagavi.',
      ),
      _Fac(
        Icons.groups_outlined,
        const Color(0xFFE65100),
        'NSS Unit',
        'Community service, camps, and social awareness programmes.',
      ),
      _Fac(
        Icons.sports_soccer_outlined,
        const Color(0xFFC62828),
        'Sports & Athletics',
        'Indoor and outdoor sports with university-level participation.',
      ),
      _Fac(
        Icons.menu_book_outlined,
        const Color(0xFF4527A0),
        'Central Library',
        'Digital and physical library with e-resources and technical journals.',
      ),
      _Fac(
        Icons.wifi_outlined,
        const Color(0xFF00695C),
        'Wi-Fi Campus',
        'High-speed internet across campus for digital learning and research.',
      ),
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: mobile ? 48 : 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _label('CAMPUS LIFE'),
              const SizedBox(height: 16),
              Text(
                'Facilities & Infrastructure',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF0D2158),
                  fontSize: mobile ? 24 : 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everything you need to excel — inside the campus',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: mobile ? 12 : 15,
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (_, c) {
                  final cols = c.maxWidth >= 900
                      ? 4
                      : c.maxWidth >= 560
                      ? 2
                      : 1;
                  final cardW = (c.maxWidth - (cols - 1) * 14) / cols;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: items
                        .map(
                          (f) => SizedBox(
                            width: cardW,
                            child: _FacCard(f: f),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool mobile) => Container(
    key: _contactKey,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF080E1E), Color(0xFF0D2158)],
      ),
    ),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: mobile ? 40 : 60),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            if (!mobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _footerBrand()),
                  const SizedBox(width: 40),
                  Expanded(flex: 2, child: _footerLinks()),
                  const SizedBox(width: 40),
                  Expanded(flex: 2, child: _footerContact()),
                ],
              )
            else ...[
              _footerBrand(),
              const SizedBox(height: 32),
              _footerLinks(),
              const SizedBox(height: 32),
              _footerContact(),
            ],
            const SizedBox(height: 36),
            const Divider(color: Color(0xFF1C3058)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialBtn(Icons.facebook, 0, _hFB),
                const SizedBox(width: 14),
                _socialBtn(Icons.mail_outline_rounded, 1, _hMail),
                const SizedBox(width: 14),
                _socialBtn(Icons.language_rounded, 2, _hLink),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '© 2025 Government Engineering College, Chamarajanagara. All Rights Reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF4A6A8A),
                fontSize: mobile ? 10 : 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _footerBrand() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0D2158), Color(0xFF1565C0)],
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'GEC',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campus Flow',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'GEC Chamarajanagara',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7A9CC4),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        'Government Engineering College\nChamarajanagara – 571313\nKarnataka, India',
        style: const TextStyle(
          color: Color(0xFF7A9CC4),
          fontSize: 13,
          height: 1.7,
        ),
      ),
    ],
  );

  Widget _footerLinks() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Quick Links',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 14),
      ...[
        ('About Us', () => _scrollTo(_aboutKey), _hFAbout, 'fabout'),
        ('Departments', () => _scrollTo(_deptsKey), _hFDept, 'fdept'),
        ('Contact Us', () => _scrollTo(_contactKey), _hFCon, 'fcon'),
        (
          'Login',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
          _hFAdm,
          'fadm',
        ),
      ].map(
        (e) => MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() {
            if (e.$4 == 'fabout') {
              _hFAbout = true;
            } else if (e.$4 == 'fadm') {
              _hFAdm = true;
            } else if (e.$4 == 'fdept') {
              _hFDept = true;
            } else {
              _hFCon = true;
            }
          }),
          onExit: (_) => setState(() {
            if (e.$4 == 'fabout') {
              _hFAbout = false;
            } else if (e.$4 == 'fadm') {
              _hFAdm = false;
            } else if (e.$4 == 'fdept') {
              _hFDept = false;
            } else {
              _hFCon = false;
            }
          }),
          child: GestureDetector(
            onTap: e.$2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: e.$3
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF7A9CC4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.$1,
                    style: TextStyle(
                      color: e.$3
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF7A9CC4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _footerContact() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Contact',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 14),
      ...[
        (Icons.phone_rounded, '+91-8226-123456'),
        (Icons.mail_outline_rounded, 'principal@gecc.edu.in'),
        (Icons.language_rounded, 'www.gecc.edu.in'),
        (Icons.location_on_outlined, 'Chamarajanagara – 571313'),
      ].map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(e.$1, size: 15, color: const Color(0xFFFFD700)),
              const SizedBox(width: 10),
              Text(
                e.$2,
                style: const TextStyle(color: Color(0xFF7A9CC4), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _socialBtn(IconData icon, int idx, bool hovered) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() {
      if (idx == 0) {
        _hFB = true;
      } else if (idx == 1) {
        _hMail = true;
      } else {
        _hLink = true;
      }
    }),
    onExit: (_) => setState(() {
      if (idx == 0) {
        _hFB = false;
      } else if (idx == 1) {
        _hMail = false;
      } else {
        _hLink = false;
      }
    }),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: hovered ? const Color(0xFFFFD700) : const Color(0xFF1C3058),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: hovered ? const Color(0xFF0D2158) : const Color(0xFF7A9CC4),
        size: 18,
      ),
    ),
  );

  Widget _label(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        color: const Color(0xFF1565C0),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    ),
  );
}

// ═══ NAV BAR ═══
class _NavBar extends StatelessWidget {
  final bool mobile;
  final bool hAbout, hDept, hContact, hReg, hLog;
  final VoidCallback onAbout, onDept, onContact, onReg, onLogin;
  final void Function(String, bool) setHover;
  final void Function(String) onMenuSelect;

  const _NavBar({
    required this.mobile,
    required this.hAbout,
    required this.hDept,
    required this.hContact,
    required this.hReg,
    required this.hLog,
    required this.onAbout,
    required this.onDept,
    required this.onContact,
    required this.onReg,
    required this.onLogin,
    required this.setHover,
    required this.onMenuSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: mobile ? 40 : 50,
              height: mobile ? 40 : 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D2158), Color(0xFF1565C0)],
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'GEC',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campus Flow',
                  style: GoogleFonts.poppins(
                    fontSize: mobile ? 15 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D2158),
                  ),
                ),
                if (!mobile)
                  Text(
                    'GEC Chamarajanagara',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (mobile)
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF0D2158)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: onMenuSelect,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'about', child: Text('About')),
              PopupMenuItem(value: 'departments', child: Text('Departments')),
              PopupMenuItem(value: 'contact', child: Text('Contact')),
              PopupMenuItem(value: 'register', child: Text('Register')),
              PopupMenuItem(value: 'login', child: Text('Login')),
            ],
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _navLink('About', hAbout, 'about', onAbout, setHover),
              _navLink('Departments', hDept, 'dept', onDept, setHover),
              _navLink('Contact', hContact, 'contact', onContact, setHover),
              const SizedBox(width: 16),
              // Register Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setHover('reg', true),
                onExit: (_) => setHover('reg', false),
                child: OutlinedButton(
                  onPressed: onReg,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: hReg
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF0D2158),
                      width: 1.5,
                    ),
                    foregroundColor: hReg
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF0D2158),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Register',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Login Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setHover('log', true),
                onExit: (_) => setHover('log', false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: hLog
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF0D2158),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    onPressed: onLogin,
                    style: TextButton.styleFrom(
                      foregroundColor: hLog
                          ? const Color(0xFF0D2158)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Login',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _navLink(
    String label,
    bool hovered,
    String key,
    VoidCallback onTap,
    void Function(String, bool) setH,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setH(key, true),
      onExit: (_) => setH(key, false),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: hovered
                  ? const Color(0xFF0D2158)
                  : const Color(0xFF64748B),
              fontSize: 14,
              fontWeight: hovered ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══ HERO SLIDE ═══
class _HeroSlide extends StatelessWidget {
  final String assetPath, title, sub;
  final bool mobile;
  final VoidCallback onApply;
  const _HeroSlide({
    required this.assetPath,
    required this.title,
    required this.sub,
    required this.mobile,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF080E1E),
                  Color(0xFF0D2158),
                  Color(0xFF1565C0),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.65),
              ],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'GEC Chamarajanagara',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: mobile ? 26 : 52,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    shadows: [
                      const Shadow(color: Colors.black26, blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: mobile ? 13 : 17,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentRegistrationScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0D2158),
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 28 : 44,
                      vertical: mobile ? 13 : 17,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Apply Now  →',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: mobile ? 14 : 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══ ARROW BTN ═══
class _ArrowBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});
  @override
  State<_ArrowBtn> createState() => _ArrowBtnState();
}

class _ArrowBtnState extends State<_ArrowBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _h
              ? const Color(0xFFFFD700)
              : Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(
          widget.icon,
          color: _h ? const Color(0xFF0D2158) : Colors.white,
          size: 22,
        ),
      ),
    ),
  );
}

// ═══ DATA ═══
class _Dept {
  final String code, name, desc;
  final IconData icon;
  final Color color, accent;
  final List<String> highlights;
  const _Dept(
    this.code,
    this.name,
    this.icon,
    this.color,
    this.accent,
    this.highlights,
    this.desc,
  );
}

class _Fac {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _Fac(this.icon, this.color, this.title, this.desc);
}

// ═══ DEPT CARD ═══
class _DeptCard extends StatefulWidget {
  final _Dept dept;
  const _DeptCard({required this.dept});
  @override
  State<_DeptCard> createState() => _DeptCardState();
}

class _DeptCardState extends State<_DeptCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.dept;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        transform: Matrix4.translationValues(0, _h ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _h ? d.color : const Color(0xFFE8EEF4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _h
                  ? d.color.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: _h ? 22 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: d.accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [d.color, d.color.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: d.color.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(d.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: d.color,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            d.code,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.name,
                          style: GoogleFonts.poppins(
                            color: d.color,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.desc,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF546E7A),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: d.highlights
                        .map(
                          (h) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: d.accent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              h,
                              style: GoogleFonts.inter(
                                color: d.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ FACILITY CARD ═══
class _FacCard extends StatefulWidget {
  final _Fac f;
  const _FacCard({required this.f});
  @override
  State<_FacCard> createState() => _FacCardState();
}

class _FacCardState extends State<_FacCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _h ? f.color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _h ? f.color : const Color(0xFFE8EEF4)),
          boxShadow: [
            BoxShadow(
              color: _h
                  ? f.color.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _h ? 18 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _h
                    ? Colors.white.withValues(alpha: 0.18)
                    : f.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(f.icon, color: _h ? Colors.white : f.color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              f.title,
              style: GoogleFonts.poppins(
                color: _h ? Colors.white : const Color(0xFF0D2158),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              f.desc,
              style: GoogleFonts.inter(
                color: _h
                    ? Colors.white.withValues(alpha: 0.82)
                    : const Color(0xFF607D8B),
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
