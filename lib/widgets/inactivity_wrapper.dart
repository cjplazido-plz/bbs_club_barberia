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
    this.timeout = const Duration(minutes: 10),
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

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _handleTimeout);
  }

  void _handleTimeout() async {
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
    return Listener(
      onPointerDown: (_) => _startTimer(),
      onPointerMove: (_) => _startTimer(),
      onPointerSignal: (_) => _startTimer(),
      child: widget.child,
    );
  }
}