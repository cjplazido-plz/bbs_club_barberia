import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import 'pos_screen.dart';
import 'public_booking_screen.dart';
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  
  late AnimationController _mainController;
  late AnimationController _glowController;
  late AnimationController _shakeController;
  late AnimationController _bgController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _fieldsFade;
  late Animation<Offset> _fieldsSlide;
  late Animation<double> _buttonFade;
  late Animation<double> _glowAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _bgAnimation;

  static const String developerEmail = 'cjplazido@gmail.com';

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.8, curve: Curves.elasticOut)),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
    
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );
    
    _logoRotate = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _fieldsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );
    
    _fieldsSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic)),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    
    _bgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOut),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    _shakeController.dispose();
    _bgController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        String role = 'admin';
        String userName = 'Usuario';
        String userEmail = response.user?.email ?? '';

        try {
          if (userEmail.toLowerCase() == developerEmail.toLowerCase()) {
            role = 'admin';
            userName = 'Desarrollador (Acceso Total)';
          } else if (userEmail.isNotEmpty) {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('email', userEmail)
                .maybeSingle();
            if (profile != null) {
              role = profile['role'] ?? 'admin';
              userName = profile['full_name'] ?? profile['name'] ?? userEmail.split('@').first;
            } else {
              role = 'user';
              userName = userEmail.split('@').first;
            }
          }
        } catch (e) {
          role = 'admin';
          userName = userEmail.split('@').first;
        }

        currentUserRole = role;
        currentUserName = userName;
        currentUserEmail = userEmail;

        // Animación de salida suave antes de ir al POS
        await _mainController.reverse();
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (context, animation, secondaryAnimation) => PosScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                    ),
                    child: child,
                  ),
                );
              },
            ),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
      _triggerShake();
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
      _triggerShake();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Stack(
        children: [
          // FONDO ANIMADO PREMIUM
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Color.lerp(const Color(0xFF0F172A), const Color(0xFF1E1B4B), _bgAnimation.value)!,
                            Color.lerp(const Color(0xFF1E293B), const Color(0xFF312E81), _bgAnimation.value)!,
                            Color.lerp(const Color(0xFF312E81), const Color(0xFF4C1D95), _bgAnimation.value)!,
                          ]
                        : [
                            Color.lerp(Colors.indigo[800]!, Colors.indigo[900]!, _bgAnimation.value)!,
                            Color.lerp(Colors.indigo[700]!, const Color(0xFF1E1B4B), _bgAnimation.value)!,
                          ],
                  ),
                ),
              );
            },
          ),
          
          // Partículas / Iconos flotantes sutiles
          ...List.generate(6, (index) {
            return AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                final offset = (math.sin(_bgAnimation.value * math.pi * 2 + index) * 20);
                return Positioned(
                  left: (index * screenWidth / 6) + offset,
                  top: 100 + (index * 80) + math.cos(_bgAnimation.value * math.pi + index) * 15,
                  child: Opacity(
                    opacity: 0.05 + (_bgAnimation.value * 0.05),
                    child: Text(
                      ['✂️', '💈', '✨', '🔥', '💈', '✂️'][index],
                      style: TextStyle(fontSize: 20 + index * 2.0),
                    ),
                  ),
                );
              },
            );
          }),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final shake = math.sin(_shakeAnimation.value * math.pi * 4) * 8;
                  return Transform.translate(
                    offset: Offset(_shakeController.isAnimating ? shake : 0, 0),
                    child: child,
                  );
                },
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: isMobile ? screenWidth * 0.92 : 420,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          color: isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Borde con glow animado
                                AnimatedBuilder(
                                  animation: _glowAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: const Color(0xFF6366F1).withOpacity(_glowAnimation.value * 0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // LOGO CON ANIMACIÓN PREMIUM
                                      FadeTransition(
                                        opacity: _logoFade,
                                        child: ScaleTransition(
                                          scale: _logoScale,
                                          child: RotationTransition(
                                            turns: _logoRotate,
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.indigo[900] : Colors.indigo[50],
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF6366F1).withOpacity(0.3),
                                                        blurRadius: 20,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Text('💈', style: TextStyle(fontSize: 48)),
                                                ),
                                                const SizedBox(height: 16),
                                                ShaderMask(
                                                  shaderCallback: (bounds) => const LinearGradient(
                                                    colors: [Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFFA5B4FC)],
                                                  ).createShader(bounds),
                                                  child: const Text(
                                                    'BBS CLUB',
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 2,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Barbería Premium',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    letterSpacing: 3,
                                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 32),
                                      
                                      // CAMPOS CON STAGGER
                                      FadeTransition(
                                        opacity: _fieldsFade,
                                        child: SlideTransition(
                                          position: _fieldsSlide,
                                          child: Column(
                                            children: [
                                              _buildPremiumField(
                                                controller: _emailController,
                                                label: 'Correo electrónico',
                                                icon: '📧',
                                                keyboardType: TextInputType.emailAddress,
                                                isDark: isDark,
                                                delay: 0,
                                              ),
                                              const SizedBox(height: 16),
                                              _buildPremiumField(
                                                controller: _passwordController,
                                                label: 'Contraseña',
                                                icon: '🔒',
                                                isPassword: true,
                                                obscureText: _obscurePassword,
                                                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                                                isDark: isDark,
                                                delay: 100,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 24),
                                      
                                      // BOTÓN PREMIUM CON SHINE
                                      FadeTransition(
                                        opacity: _buttonFade,
                                        child: _buildPremiumButton(isDark),
                                      ),
                                      
                                      if (_errorMessage.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Text('⚠️', style: TextStyle(fontSize: 16)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage,
                                                  style: TextStyle(color: Colors.red[300], fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      
                                      const SizedBox(height: 24),
                                      Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      
                                      FadeTransition(
                                        opacity: _buttonFade,
                                        child: Column(
                                          children: [
                                            Text(
                                              '¿Eres cliente?',
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (_) => PublicBookingScreen()),
                                                  );
                                                },
                                                icon: const Text('📅'),
                                                label: const Text('Reservar una cita'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF818CF8),
                                                  side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String label,
    required String icon,
    required bool isDark,
    int delay = 0,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '$icon  ',
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A).withOpacity(0.8) : Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: onToggleVisibility,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPremiumButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'INICIAR SESIÓN',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(width: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(math.sin(value * math.pi * 2) * 2, 0),
                        child: const Icon(Icons.arrow_forward_rounded, size: 18),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
