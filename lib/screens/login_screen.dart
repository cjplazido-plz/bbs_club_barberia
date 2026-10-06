import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/settings_service.dart';
import 'pos_screen.dart';
import 'public_booking_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  static const String developerEmail = 'cjplazido@gmail.com';

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
            print('🔑 Acceso de desarrollador activado');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;

    // ✅ Tamaños adaptativos según pantalla
    final logoSize = isSmallMobile ? 100.0 : (isMobile ? 120.0 : 160.0);
    final titleFontSize = isSmallMobile ? 20.0 : (isMobile ? 24.0 : 28.0);
    final cardPadding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 32.0);
    final cardWidth = isMobile ? screenWidth * 0.92 : 420.0;
    final buttonHeight = isSmallMobile ? 44.0 : 48.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo[700]!, Colors.indigo[900]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallMobile ? 12 : 16,
              vertical: 20,
            ),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ Logo adaptativo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SettingsService.shopLogoUrl.isNotEmpty
                            ? Image.network(
                                SettingsService.shopLogoUrl,
                                width: logoSize,
                                height: logoSize * 0.75,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultLogo(logoSize);
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return _buildDefaultLogo(logoSize);
                                },
                              )
                            : _buildDefaultLogo(logoSize),
                      ),
                      SizedBox(height: isSmallMobile ? 12 : 16),
                      // ✅ Nombre de la barbería (sin partir en líneas feas)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          SettingsService.shopName,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inicia sesión para continuar',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isSmallMobile ? 12 : 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallMobile ? 16 : 24),
                      // ✅ Campo email
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          hintText: 'ej: carlos@barber.com',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
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
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
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
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Text('⚠️', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: isSmallMobile ? 11 : 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: isSmallMobile ? 12 : 16),
                      // ✅ Botón INICIAR SESIÓN
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
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
                      const Divider(),
                      SizedBox(height: isSmallMobile ? 10 : 16),
                      Text(
                        '¿Eres cliente?',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isSmallMobile ? 12 : 14,
                        ),
                      ),
                      SizedBox(height: isSmallMobile ? 6 : 8),
                      // ✅ Botón Reservar una cita (completo, no cortado)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PublicBookingScreen()),
                          );
                        },
                        icon: const Text('📅', style: TextStyle(fontSize: 20)),
                        label: Text(
                          'Reservar una cita',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallMobile ? 8 : 0),
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

  Widget _buildDefaultLogo(double size) {
    return Container(
      width: size,
      height: size * 0.75,
      decoration: BoxDecoration(
        color: Colors.indigo[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text('💈', style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}