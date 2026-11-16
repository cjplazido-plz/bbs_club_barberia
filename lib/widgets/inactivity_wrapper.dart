import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart'; // Asegúrate de que esta ruta sea correcta

class InactivityWrapper extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const InactivityWrapper({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 10), // 10 minutos por defecto
  });

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Reinicia el contador cada vez que hay actividad
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _handleTimeout);
  }

  // Se ejecuta cuando pasan los 10 minutos sin tocar nada
  void _handleTimeout() async {
    final user = Supabase.instance.client.auth.currentUser;
    
    // Si hay un usuario logueado, lo sacamos
    if (user != null) {
      await Supabase.instance.client.auth.signOut();
      
      // Navegamos al Login eliminando todo el historial de pantallas
      if (mounted) {
        // Usamos el context actual para navegar
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
        );
        
        // Opcional: Mostrar un mensaje de por qué se cerró
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada por inactividad'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener detecta: toques, clics del mouse, scroll, etc.
    return Listener(
      onPointerDown: (_) => _startTimer(),
      onPointerMove: (_) => _startTimer(),
      onPointerSignal: (_) => _startTimer(),
      child: widget.child,
    );
  }
}