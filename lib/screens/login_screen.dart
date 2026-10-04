import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/settings_service.dart';
import 'pos_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

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
          if (userEmail.isNotEmpty) {
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
            }
          }
        } catch (e) {
          print('️ Error al obtener perfil: $e');
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
            padding: const EdgeInsets.all(32),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ LOGO DE LA BARBERÍA (140x140)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SettingsService.shopLogoUrl.isNotEmpty
                            ? Image.network(
                                SettingsService.shopLogoUrl,
                                width: 160,
                                height: 160,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultLogo();
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return _buildDefaultLogo();
                                },
                              )
                            : _buildDefaultLogo(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        SettingsService.shopName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión para continuar',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      // ✅ Campo de correo SIN icono
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          hintText: 'ej: carlos@barber.com',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      // ✅ Campo de contraseña SIN icono
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Text('️🪒', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                      color: Colors.red[700], fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[700],
                            foregroundColor: Colors.white, // ✅ Letras blancas
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
                              : const Text(
                                  'INICIAR SESIÓN',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white), // ✅ Letras blancas
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
    );
  }

  // ✅ Logo por defecto (140x140, emoji 72px)
  Widget _buildDefaultLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.indigo[100],
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text('💈', style: TextStyle(fontSize: 72)),
      ),
    );
  }
}