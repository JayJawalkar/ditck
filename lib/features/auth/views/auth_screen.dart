import 'package:ditck/features/home/views/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();

  // Form keys and controllers
  final _signUpFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _designationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginMobileController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Colors
  static const _primaryColor = Color(0xFF8B5CF6);
  static const _secondaryColor = Color(0xFF7C3AED);
  static const _textColor = Color(0xFF1F2937);
  static const _errorColor = Color(0xFFEF4444);
  static const _successColor = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();

    _checkLoginPersistence();
  }

  Future<void> _checkLoginPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn && FirebaseAuth.instance.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      });
    }
  }

  Future<void> _setLoginPersistence(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController.dispose();
    // Dispose all controllers
    for (var c in [
      _nameController,
      _companyController,
      _mobileController,
      _emailController,
      _designationController,
      _passwordController,
      _loginMobileController,
      _loginPasswordController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [_buildMainContent(), if (_isLoading) _buildLoadingOverlay()],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.5, -1),
          end: Alignment(1, 1),
          colors: [
            Color(0xFF4C1D95),
            Color(0xFF5B21B6),
            Color(0xFF7C3AED),
            Color(0xFF8B5CF6),
          ],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header section
              Expanded(
                flex: 2,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildHeader(),
                ),
              ),
              // Form section
              Expanded(
                flex: 5,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(35),
                        topRight: Radius.circular(35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 20,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 25),
                        _buildTabBar(),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                            child: TabBarView(
                              controller: _tabController,
                              physics: const BouncingScrollPhysics(),
                              children: [_buildSignUpForm(), _buildLoginForm()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withAlpha(170)),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Creating magic...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo with gradient background
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withAlpha(90),
                  Colors.white.withAlpha(22),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withAlpha(100), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha(50),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.explore_rounded,
              size: 45,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'DITCK',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
              shadows: [
                Shadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryColor, _secondaryColor],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withAlpha(85),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        tabs: const [
          Tab(
            height: 45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_rounded, size: 20),
                SizedBox(width: 6),
                Text('Sign Up'),
              ],
            ),
          ),
          Tab(
            height: 45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, size: 20),
                SizedBox(width: 6),
                Text('Login'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signUpFormKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Create Your Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join thousands of users tracking their journeys',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'John Doe',
              icon: Icons.person_rounded,
              validator: (v) =>
                  (v?.trim().length ?? 0) < 2 ? 'Name too short' : null,
            ),
            const SizedBox(height: 18),

            _buildTextField(
              controller: _mobileController,
              label: 'Mobile Number',
              hint: '9876543210',
              icon: Icons.smartphone_rounded,
              keyboardType: TextInputType.phone,
              prefix: '+91 ',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) =>
                  (v?.length ?? 0) != 10 ? 'Enter valid 10-digit number' : null,
              helperText: 'This will be your unique ID',
            ),
            const SizedBox(height: 18),

            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'john@company.com',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v ?? '')
                  ? 'Enter valid email'
                  : null,
            ),
            const SizedBox(height: 18),

            _buildTextField(
              controller: _companyController,
              label: 'Company Name',
              hint: 'Tech Solutions Inc.',
              icon: Icons.business_rounded,
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'Company name is required'
                  : null,
            ),
            const SizedBox(height: 18),

            _buildTextField(
              controller: _designationController,
              label: 'Your Role',
              hint: 'Sales Manager',
              icon: Icons.work_rounded,
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'Designation is required'
                  : null,
            ),
            const SizedBox(height: 18),

            _buildPasswordField(
              controller: _passwordController,
              label: 'Create Password',
              hint: 'Min. 6 characters',
              validator: (v) =>
                  (v?.length ?? 0) < 6 ? 'Password too short' : null,
            ),
            const SizedBox(height: 32),

            _buildActionButton(
              'Create Account',
              Icons.rocket_launch_rounded,
              _handleSignUp,
            ),
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 20),
            _buildGoogleSignInButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue your journey',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),

            _buildTextField(
              controller: _loginMobileController,
              label: 'Mobile Number',
              hint: '9876543210',
              icon: Icons.smartphone_rounded,
              keyboardType: TextInputType.phone,
              prefix: '+91 ',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) =>
                  (v?.length ?? 0) != 10 ? 'Enter valid 10-digit number' : null,
            ),
            const SizedBox(height: 18),

            _buildPasswordField(
              controller: _loginPasswordController,
              label: 'Password',
              hint: 'Enter your password',
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Password is required' : null,
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            _buildActionButton('Sign In', Icons.login_rounded, _handleLogin),
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 20),
            _buildGoogleSignInButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? prefix,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: (v) =>
                v?.isEmpty ?? true ? '$label is required' : validator?.call(v),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixText: prefix,
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primaryColor, size: 22),
              ),
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _errorColor, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _errorColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              labelStyle: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: const TextStyle(
                fontSize: 12,
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: _obscurePassword,
        validator: (v) =>
            v?.isEmpty ?? true ? '$label is required' : validator?.call(v),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(
          color: _textColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: _primaryColor,
              size: 22,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: const Color(0xFF9CA3AF),
              size: 22,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _errorColor, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _errorColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withAlpha(100),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: Image.network(
          'https://developers.google.com/identity/images/g-logo.png',
          width: 20,
          height: 20,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.g_mobiledata_rounded,
            color: Color(0xFF4285F4),
            size: 24,
          ),
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
      ],
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        company: _companyController.text.trim(),
        mobile: _mobileController.text.trim(),
        designation: _designationController.text.trim(),
      );
      await _setLoginPersistence(true);
      _showSnackbar('🎉 Account created successfully!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Registration failed', isError: true);
    } catch (e) {
      _showSnackbar('Failed to create account', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmailAndPassword(
        mobile: _loginMobileController.text.trim(),
        password: _loginPasswordController.text.trim(),
      );
      await _setLoginPersistence(true);
      _showSnackbar('🚀 Welcome back!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Login failed', isError: true);
    } catch (e) {
      _showSnackbar('Invalid credentials', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _authService.getUserProfile();
      String? company = profile['company'];
      String? designation = profile['designation'];

      if ((company == null || company.isEmpty) ||
          (designation == null || designation.isEmpty)) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final companyController = TextEditingController();
            final designationController = TextEditingController();
            return AlertDialog(
              title: const Text('Complete Your Profile'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: designationController,
                    decoration: const InputDecoration(labelText: 'Designation'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (companyController.text.trim().isEmpty ||
                        designationController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Company and Designation are required.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    await _authService.updateUserProfile(
                      company: companyController.text.trim(),
                      designation: designationController.text.trim(),
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      }
      await _setLoginPersistence(true);
      _showSnackbar('✨ Google sign-in successful!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Google sign-in failed', isError: true);
    } catch (e) {
      _showSnackbar('Google sign-in failed', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Forgot Password',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Password reset will be implemented with Firebase Auth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
