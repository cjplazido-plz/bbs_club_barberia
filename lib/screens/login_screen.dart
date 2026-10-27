import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import 'pos_screen.dart';
import 'public_booking_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const String developerEmail = 'cjplazido@gmail.com';

  @override
  void initState() {
    super.initState();
    // ✅ Animaciones de entrada
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

      print('✅ Login exitoso: ${response.user?.email}');

      if (mounted) {
        String role = 'admin';
        String userName = 'Usuario';
        String userEmail = response.user?.email ?? '';

        try {
          if (userEmail.toLowerCase() == developerEmail.toLowerCase()) {
            role = 'admin';
            userName = 'Desarrollador (Acceso Total)';
            print(' Acceso de desarrollador activado');
          } else if (userEmail.isNotEmpty) {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('email', userEmail)
                .maybeSingle();

            if (profile != null) {
              role = profile['role'] ?? 'admin';
              userName = profile['full_name'] ??
                  profile['name'] ??
                  profile['username'] ??
                  userEmail.split('@').first;
            } else {
              role = 'user';
              userName = userEmail.split('@').first;
            }
          }
        } catch (e) {
          print('⚠️ Error al obtener perfil: $e');
          role = 'admin';
          userName = userEmail.split('@').first;
        }

        currentUserRole = role;
        currentUserName = userName;
        currentUserEmail = userEmail;

        print('✅ Rol: $role | Nombre: $userName | Email: $userEmail');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PosScreen()),
        );
      }
    } on AuthApiException catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.message}';
      });
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;

    final logoSize = isSmallMobile ? 100.0 : (isMobile ? 120.0 : 160.0);
    final titleFontSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final cardPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 32.0);
    final cardWidth = isMobile ? screenWidth * 0.92 : 420.0;
    final buttonHeight = isSmallMobile ? 44.0 : 48.0;

    return Scaffold(
      body: Container(
        // ✅ Fondo con gradiente que cambia según modo
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF312E81)]
                : [Colors.indigo[700]!, Colors.indigo[900]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: 20,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Card(
                  elevation: 16,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: SizedBox(
                      width: cardWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ Logo con glow effect en modo oscuro
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color: Colors.indigo.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SettingsService.shopLogoUrl.isNotEmpty
                                  ? Image.network(
                                      SettingsService.shopLogoUrl,
                                      width: logoSize,
                                      height: logoSize * 0.75,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildDefaultLogo(logoSize, isDark);
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return _buildDefaultLogo(logoSize, isDark);
                                      },
                                    )
                                  : _buildDefaultLogo(logoSize, isDark),
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 12 : 16),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              SettingsService.shopName,
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.indigo,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inicia sesión para continuar',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: isSmallMobile ? 12 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallMobile ? 16 : 24),
                          // ✅ Campo email
                          TextField(
                            controller: _emailController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'ej: carlos@barber.com',
                              labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                              prefixIcon: Icon(Icons.email, color: isDark ? Colors.indigo[300] : Colors.indigo),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: isSmallMobile ? 10 : 14,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: isSmallMobile ? 10 : 16),
                          // ✅ Campo contraseña
                          TextField(
                            controller: _passwordController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              prefixIcon: Icon(Icons.lock, color: isDark ? Colors.indigo[300] : Colors.indigo),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: isSmallMobile ? 10 : 14,
                              ),
                            ),
                            obscureText: true,
                          ),
                          SizedBox(height: isSmallMobile ? 10 : 16),
                          // ✅ Mensaje de error
                          if (_errorMessage.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Text('⚠️', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(
                                          color: Colors.red[400],
                                          fontSize: isSmallMobile ? 11 : 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: isSmallMobile ? 12 : 16),
                          // ✅ Botón INICIAR SESIÓN con efecto glow
                          Container(
                            width: double.infinity,
                            height: buttonHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isDark
                                  ? [
                                      BoxShadow(
                                        color: Colors.indigo.withOpacity(0.4),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF6366F1) : Colors.indigo[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'INICIAR SESIÓN',
                                      style: TextStyle(
                                          fontSize: isSmallMobile ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                            ),
                          ),
                          SizedBox(height: isSmallMobile ? 16 : 24),
                          Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                          SizedBox(height: isSmallMobile ? 10 : 16),
Text(
  '¿Eres cliente?',
  style: TextStyle(
    color: isDark ? Colors.grey[400] : Colors.grey[600],
    fontSize: isSmallMobile ? 12 : 14,
  ),
),
SizedBox(height: isSmallMobile ? 10 : 12),
// ✅ Botón "Reservar una cita" con estilo de botón real
Container(
  width: double.infinity,
  height: buttonHeight,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    boxShadow: isDark
        ? [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ]
        : null,
  ),
  child: ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PublicBookingScreen()),
      );
    },
    icon: const Text('📅', style: TextStyle(fontSize: 18)),
    label: Text(
      'Reservar una cita',
      style: TextStyle(
        fontSize: isSmallMobile ? 14 : 15,
        fontWeight: FontWeight.bold,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: isDark ? Colors.transparent : Colors.indigo[50],
      foregroundColor: isDark ? const Color(0xFF818CF8) : Colors.indigo[700],
      side: BorderSide(
        color: isDark ? const Color(0xFF6366F1) : Colors.indigo[300]!,
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallMobile ? 12 : 16,
        vertical: 10,
      ),
      minimumSize: const Size(double.infinity, 44),
    ),
  ),
),
SizedBox(height: isSmallMobile ? 8 : 0),                        ],
                      ),
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

  Widget _buildDefaultLogo(double size, bool isDark) {
    return Container(
      width: size,
      height: size * 0.75,
      decoration: BoxDecoration(
        color: isDark ? Colors.indigo[900] : Colors.indigo[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 15,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text('💈', style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}