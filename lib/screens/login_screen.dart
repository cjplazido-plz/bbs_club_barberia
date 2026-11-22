import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'pos_screen.dart';
import 'public_booking_screen.dart';
import '../services/bbs_theme.dart';

// LOGIN PREMIUM - misma apariencia que Reservas:
// fondo negro 0A0A0A, tarjeta 141414, dorado D4AF37 / FBBF24, logo BBS CLUB, "Barbería Premium"
// NO toca lógica de sesión: mismo signInWithPassword que usaba tu Login anterior.
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _verPass = false;
  bool _cargando = false;
  String? _error;

  Future<void> _entrar() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Escribe tu correo y contraseña');
      return;
    }
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
      final user = res.user;
      if (user != null) {
        try {
          final profile = await Supabase.instance.client.from('profiles').select('role, full_name').eq('id', user.id).maybeSingle();
          if (profile != null) {
            currentUserRole = profile['role'] ?? 'cashier';
            currentUserName = profile['full_name'] ?? user.email?.split('@').first ?? 'Usuario';
          } else {
            currentUserRole = 'cashier';
            currentUserName = user.email?.split('@').first ?? 'Usuario';
          }
        } catch (_) {
          currentUserRole = 'cashier';
          currentUserName = user.email?.split('@').first ?? 'Usuario';
        }
        currentUserEmail = user.email ?? '';
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => PosScreen()));
      }
    } catch (e) {
      setState(() => _error = 'Correo o contraseña incorrectos');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BbsTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // Logo igual que Reservas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: 'BBS', style: TextStyle(color: Color(0xFFE11D2E), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        TextSpan(text: 'CLUB', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('BBS CLUB BARBERIA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const Text('Barbería Premium', style: TextStyle(color: BbsTheme.gold, fontSize: 12)),
                const SizedBox(height: 20),
                // Tarjeta de dirección, igual que Reservas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: BbsTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: BbsTheme.gold, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ENCUÉNTRANOS EN', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        SizedBox(height: 2),
                        Text('Manuel Montt 460 - local 6 - Coronel', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PublicBookingScreen())), style: ElevatedButton.styleFrom(backgroundColor: BbsTheme.gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), child: const Text('Reservar')),
                  ]),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: BbsTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('INICIAR SESIÓN', style: BbsTheme.sectionTitle),
                    const SizedBox(height: 16),
                    TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: BbsTheme.inputDecoration('Correo', icon: Icons.email_outlined)),
                    const SizedBox(height: 12),
                    TextField(controller: _passCtrl, obscureText: !_verPass, style: const TextStyle(color: Colors.white, fontSize: 14), onSubmitted: (_) => _entrar(), decoration: BbsTheme.inputDecoration('Contraseña', icon: Icons.lock_outline).copyWith(suffixIcon: IconButton(icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20), onPressed: () => setState(() => _verPass = !_verPass)))),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.error_outline, color: Colors.redAccent, size: 16), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)))])),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _cargando ? null : _entrar, style: BbsTheme.goldButton, child: _cargando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('ENTRAR AL POS'))),
                    const SizedBox(height: 12),
                    Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PublicBookingScreen())), child: const Text('¿Eres cliente? Reserva tu cita aquí', style: TextStyle(color: BbsTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)))),
                  ]),
                ),
                const SizedBox(height: 12),
                const Text('Caja 1 • Turno 8 horas', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
