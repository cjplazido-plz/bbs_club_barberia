import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';

class InactivityWrapper extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey; // <-- NUEVO
  final Duration timeout;

  const InactivityWrapper({
    super.key,
    required this.child,
    required this.navigatorKey, // <-- NUEVO
    this.timeout = const Duration(hours: 8), // FIX: turno completo, no 10 min
  });

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;
  bool _yaCerrando = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _handleTimeout);
  }

  void _handleTimeout() async {
    if (_yaCerrando) return;
    _yaCerrando = true;
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      await Supabase.instance.client.auth.signOut();
      
      // FIX: Navegamos usando la llave global
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX F5 / INACTIVIDAD: antes solo contaba el mouse. Si el cajero solo
    // tecleaba (cobraba con teclado), el wrapper creía que estaba inactivo
    // y hacía signOut a los 10 min. Ahora el teclado también resetea el timer.
    // F5 solo reinicia la app y reinicia este timer a 8h, NO cierra sesión.
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_) => _startTimer(),
      child: Listener(
        onPointerDown: (_) => _startTimer(),
        onPointerMove: (_) => _startTimer(),
        onPointerSignal: (_) => _startTimer(),
        child: widget.child,
      ),
    );
  }
}