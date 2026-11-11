// lib/screens/login_screen.dart - FIX LateInitializationError _bgAnimation - SIN late _bgAnimation - Logo como pantalla publica
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../main.dart';
import '../services/ticket_config_service.dart';
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
  Uint8List? _logoBytes;
  bool _logoLoading = true;

  // FIX: no usar late para animaciones que pueden fallar - inicializar en initState y usar nullable donde sea necesario
  AnimationController? _mainController;
  AnimationController? _glowController;
  AnimationController? _shakeController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _slideAnimation;

  static const String developerEmail = 'cjplazido@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _mainController!, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _mainController!, curve: const Interval(0.0, 0.8, curve: Curves.elasticOut)));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _mainController!, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)));
    _mainController!.forward();
  }

  Future<void> _loadLogo() async {
    await TicketConfigService.load();
    final url = TicketConfigService.appLogoUrl;
    if (url.isEmpty) { if(mounted) setState(()=> _logoLoading=false); return; }
    try {
      final clean = url.replaceAll(' ', '%20').replaceAll('(', '%28').replaceAll(')', '%29').replaceAll('%2520', '%20');
      final resp = await http.get(Uri.parse(clean), headers: {'User-Agent':'Mozilla/5.0'}).timeout(const Duration(seconds: 5));
      if (resp.statusCode==200) _logoBytes = resp.bodyBytes;
    } catch(e){}
    if(mounted) setState(()=> _logoLoading=false);
  }

  @override
  void dispose() {
    _mainController?.dispose();
    _glowController?.dispose();
    _shakeController?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(()=> _errorMessage='Ingresa correo y contraseña');
      _shakeController?.forward(from: 0);
      return;
    }
    setState((){ _isLoading=true; _errorMessage=''; });
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: _emailController.text.trim(), password: _passwordController.text);
      String role='admin'; String userName='Usuario'; String userEmail=res.user?.email??'';
      try {
        if (userEmail.toLowerCase()==developerEmail.toLowerCase()) { role='admin'; userName='Desarrollador (Acceso Total)'; }
        else if (userEmail.isNotEmpty) {
          // Usar el ID de la sesión del usuario es más seguro
          final profile = await Supabase.instance.client.from('profiles').select().eq('id', res.user!.id).maybeSingle();
          if (profile!=null) { role=profile['role']??'admin'; userName=profile['full_name']??profile['name']??userEmail.split('@').first; }
        }
      } catch(_){}
      currentUserRole=role; currentUserName=userName; currentUserEmail=userEmail;
      if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> PosScreen()));
    } catch(e){
      setState(()=> _errorMessage='Correo o contraseña incorrectos');
      _shakeController?.forward(from: 0);
    } finally { if(mounted) setState(()=> _isLoading=false); }
  }

  @override
  Widget build(BuildContext context) {
    // Si animaciones aun no listas, mostrar sin animacion para no crashear
    final fade = _fadeAnimation ?? const AlwaysStoppedAnimation<double>(1.0);
    final scale = _scaleAnimation ?? const AlwaysStoppedAnimation<double>(1.0);
    final slide = _slideAnimation ?? const AlwaysStoppedAnimation<Offset>(Offset.zero);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F0F3A), Color(0xFF1E1B4B), Color(0xFF312E81)]),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: ScaleTransition(
                  scale: scale,
                  child: Container(
                    width: 420,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.08)), boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24, offset: const Offset(0,12))]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LOGO COMO PANTALLA PUBLICA image_f87761.png
                        Container(
                          width: 160, height: 84,
                          decoration: BoxDecoration(color: const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12)]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _logoLoading ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))) :
                            _logoBytes!=null ? Image.memory(_logoBytes!, fit: BoxFit.contain) :
                            const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('BBSCLUB', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 16)), Text('BARBERIA', style: TextStyle(color: Colors.white, fontSize: 8, letterSpacing: 3))])),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(TicketConfigService.nombreLocal.isEmpty?'BBS CLUB':TicketConfigService.nombreLocal, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        const Text('Barbería Premium', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2)),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(hintText: 'Correo electrónico', hintStyle: const TextStyle(color: Colors.white38, fontSize: 13), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          onSubmitted: (_)=> _handleLogin(),
                          decoration: InputDecoration(hintText: 'Contraseña', hintStyle: const TextStyle(color: Colors.white38, fontSize: 13), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), suffixIcon: IconButton(icon: Icon(_obscurePassword?Icons.visibility_off:Icons.visibility, color: Colors.white38, size: 20), onPressed: ()=> setState(()=> _obscurePassword=!_obscurePassword))),
                        ),
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          AnimatedBuilder(animation: _shakeController ?? const AlwaysStoppedAnimation<double>(0), builder: (c, child){ final v = _shakeController?.value ?? 0; final off = math.sin(v*math.pi*6)*6; return Transform.translate(offset: Offset(off,0), child: child); }, child: Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.3))), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center))),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity, height: 52,
                          child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 12, offset: const Offset(0,4))]), child: ElevatedButton(onPressed: _isLoading?null:_handleLogin, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading?const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)):const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('INICIAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), SizedBox(width: 6), Icon(Icons.arrow_forward, size: 16)]))),
                        ),
                        const SizedBox(height: 20),
                        Container(height: 1, color: Colors.white.withOpacity(0.08)),
                        const SizedBox(height: 16),
                        const Text('¿Eres cliente?', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> PublicBookingScreen())); }, icon: const Text('📅'), label: const Text('Reservar una cita', style: TextStyle(color: Color(0xFF818CF8), fontSize: 12)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6366F1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)))),
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
