import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(text: 'jane.smith@company.com');
  final _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final success = await provider.login(
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoggingIn = false;
      });

      if (!success) {
        setState(() {
          _errorMessage = 'Invalid credentials or user not found.';
        });
      }
    }
  }

  void _selectQuickUser(String email, String password) {
    setState(() {
      _identifierController.text = email;
      _passwordController.text = password;
      _errorMessage = null;
    });
  }

  void _simulateFaceAuth() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.face_rounded,
                size: 64,
                color: Color(0xFF2E65FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scanning Face...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Position your face within the frame',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Color(0xFF2E65FF),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      Navigator.pop(context); // Close scanning dialog
      if (provider.employees.isNotEmpty) {
        provider.loginAsEmployee(provider.employees.first);
      } else {
        provider.login(identifier: 'jane.smith@company.com', password: 'password123');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)]
                  : const [Color(0xFFF1F5F9), Color(0xFFE2E8F0), Color(0xFFEFF6FF)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header & Language selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildLanguageSelector(provider),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Logo & App Name Header
                      _buildLogoHeader(isDark),
                      const SizedBox(height: 32),

                      // Login Form Glass Card
                      GlassContainer(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.translate('welcome_back'),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sign in to manage your attendance & requests',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Error Message banner
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Username / Email input
                              Text(
                                provider.translate('email'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _identifierController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                keyboardType: TextInputType.emailAddress,
                                decoration: _buildInputDecoration(
                                  hintText: 'Enter your email or user ID',
                                  prefixIcon: Icons.email_outlined,
                                  isDark: isDark,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your email or user ID';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Password input
                              Text(
                                provider.translate('security'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                decoration: _buildInputDecoration(
                                  hintText: 'Enter your password',
                                  prefixIcon: Icons.lock_outline,
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please enter password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Remember me & Forgot Password
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: const Color(0xFF2E65FF),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _rememberMe = val ?? true;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Remember me',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Contact your HR department to reset password.'),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2E65FF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Sign In Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoggingIn ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E65FF),
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoggingIn
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Face Recognition Quick Sign-In Option
                              OutlinedButton.icon(
                                onPressed: _simulateFaceAuth,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  side: BorderSide(
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.face_rounded, color: Color(0xFF2E65FF)),
                                label: Text(
                                  'Sign In with Face ID',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Quick Demo Account Switcher Header
                      Text(
                        'QUICK DEMO ROLES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Role Pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildRoleChip(
                            label: 'HR Manager',
                            email: 'jane.smith@company.com',
                            icon: Icons.admin_panel_settings_outlined,
                            color: const Color(0xFF2E65FF),
                            isDark: isDark,
                          ),
                          _buildRoleChip(
                            label: 'Supervisor',
                            email: 'john.doe@company.com',
                            icon: Icons.supervisor_account_outlined,
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                          ),
                          _buildRoleChip(
                            label: 'Employee',
                            email: 'sarah.j@company.com',
                            icon: Icons.person_outline,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E65FF), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E65FF).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.access_time_filled_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'WorkPulse',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Attendance & Workforce Management',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(AttendanceProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.currentLanguage,
          isDense: true,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.language, size: 16, color: Color(0xFF2E65FF)),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
          ),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'ku', child: Text('Kurdish (Kurdî)')),
            DropdownMenuItem(value: 'ar', child: Text('Arabic (العربية)')),
          ],
          onChanged: (lang) {
            if (lang != null) {
              provider.setLanguage(lang);
            }
          },
        ),
      ),
    );
  }

  Widget _buildRoleChip({
    required String label,
    required String email,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _identifierController.text.toLowerCase() == email.toLowerCase();

    return ActionChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
        ),
      ),
      backgroundColor: isSelected
          ? color
          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white),
      side: BorderSide(
        color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _selectQuickUser(email, 'password123'),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
      prefixIcon: Icon(prefixIcon, size: 20, color: isDark ? Colors.white54 : Colors.black45),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E65FF), width: 1.5),
      ),
    );
  }
}
