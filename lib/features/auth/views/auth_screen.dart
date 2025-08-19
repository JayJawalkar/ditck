import 'package:ditck/features/auth/service/auth_service.dart';
import 'package:ditck/features/auth/views/sign_in_screen.dart';
import 'package:ditck/features/home/views/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _controllers = {
    'companyName': TextEditingController(),
    'companyEmail': TextEditingController(),
    'companyMobile': TextEditingController(),
    'ownerName': TextEditingController(),
    'ownerEmail': TextEditingController(),
    'ownerMobile': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
  };

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _sameAsCompany = false;

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- Validators ----------
  String? _required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  String? _email(String? v) {
    if (_required(v, 'Email') != null) return _required(v, 'Email');
    final r = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return r.hasMatch(v!.trim()) ? null : 'Enter a valid email';
  }

  String? _mobile(String? v) {
    if (_required(v, 'Mobile') != null) return _required(v, 'Mobile');
    final r = RegExp(r'^[+]?[0-9]{10,15}$');
    return r.hasMatch(v!.trim()) ? null : 'Enter a valid mobile number';
  }

  String? _password(String? v) {
    if (_required(v, 'Password') != null) return _required(v, 'Password');
    if (v!.length < 8) return 'Min 8 characters';
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(v)) {
      return 'Must contain upper, lower, and number';
    }
    return null;
  }

  String? _confirmPassword(String? v) =>
      v != _controllers['password']!.text ? 'Passwords do not match' : null;

  // ---------- UI Helper ----------
  Widget _field({
    required String label,
    required String keyName,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? helper,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: _controllers[keyName],
      keyboardType: type,
      obscureText: obscure,
      validator: validator,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: toggleObscure,
              )
            : null,
        helperText: helper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  // ---------- Signup Logic ----------
  Future<void> _signupOwner() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await AuthService().createCompanyAndSuperAdmin(
        companyName: _controllers['companyName']!.text.trim(),
        companyMobile: _controllers['companyMobile']!.text.trim(),
        companyEmail: _controllers['companyEmail']!.text.trim(),
        superAdminName: _controllers['ownerName']!.text.trim(),
        superAdminMobile: _controllers['ownerMobile']!.text.trim(),
        superAdminEmail: _controllers['ownerEmail']!.text.trim(),
        superAdminPassword: _controllers['password']!.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please verify your email.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (context) => HomePage()));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('email-already-in-use')
            ? 'Email already in use'
            : e.toString().contains('mobile-already-in-use')
            ? 'Mobile already in use'
            : e.toString().contains('weak-password')
            ? 'Weak password'
            : e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Company Account'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 600 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _field(
                          label: 'Company Name *',
                          keyName: 'companyName',
                          icon: Icons.business,
                          validator: (v) => _required(v, 'Company name'),
                        ),
                        const SizedBox(height: 16),
                        _field(
                          label: 'Company Email *',
                          keyName: 'companyEmail',
                          icon: Icons.email_outlined,
                          validator: _email,
                          type: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          label: 'Company Mobile *',
                          keyName: 'companyMobile',
                          icon: Icons.phone_outlined,
                          validator: _mobile,
                          type: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Owner Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        CheckboxListTile(
                          value: _sameAsCompany,
                          onChanged: (v) {
                            setState(() {
                              _sameAsCompany = v ?? false;
                              if (_sameAsCompany) {
                                _controllers['ownerName']!.text =
                                    _controllers['companyName']!.text;
                                _controllers['ownerEmail']!.text =
                                    _controllers['companyEmail']!.text;
                                _controllers['ownerMobile']!.text =
                                    _controllers['companyMobile']!.text;
                              } else {
                                _controllers['ownerName']!.clear();
                                _controllers['ownerEmail']!.clear();
                                _controllers['ownerMobile']!.clear();
                              }
                            });
                          },
                          title: const Text("Same as Company Details"),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),

                        _field(
                          label: 'Owner Name *',
                          keyName: 'ownerName',
                          icon: Icons.person_outline,
                          validator: (v) => _required(v, 'Owner name'),
                          readOnly: _sameAsCompany,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          label: 'Owner Email *',
                          keyName: 'ownerEmail',
                          icon: Icons.alternate_email,
                          validator: _email,
                          type: TextInputType.emailAddress,
                          readOnly: _sameAsCompany,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          label: 'Owner Mobile *',
                          keyName: 'ownerMobile',
                          icon: Icons.phone_android,
                          validator: _mobile,
                          type: TextInputType.phone,
                          readOnly: _sameAsCompany,
                        ),
                        const SizedBox(height: 16),

                        _field(
                          label: 'Password *',
                          keyName: 'password',
                          icon: Icons.lock_outline,
                          validator: _password,
                          obscure: _obscurePassword,
                          toggleObscure: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          helper: 'Min 8 chars with upper, lower & number',
                        ),
                        const SizedBox(height: 16),
                        _field(
                          label: 'Confirm Password *',
                          keyName: 'confirmPassword',
                          icon: Icons.lock_outline,
                          validator: _confirmPassword,
                          obscure: _obscureConfirmPassword,
                          toggleObscure: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                        const SizedBox(height: 16),

                        CheckboxListTile(
                          value: _agreedToTerms,
                          onChanged: (v) =>
                              setState(() => _agreedToTerms = v ?? false),
                          title: const Text(
                            'I agree to the Terms & Privacy Policy',
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signupOwner,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : const Text(
                                    'Create Company Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Center(
                          child: TextButton(
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const SignInScreen(),
                                  ),
                                ),
                            child: const Text(
                              'Already have an account? Sign in',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}