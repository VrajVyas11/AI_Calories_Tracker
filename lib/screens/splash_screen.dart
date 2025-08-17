// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Duration displayDuration;
  final VoidCallback? onFinished; // callback after splash completes
  final bool autoNavigate;

  const SplashScreen({
    super.key,
    this.displayDuration = const Duration(milliseconds: 1400),
    this.autoNavigate = true,
    this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  Timer? _navTimer;

  @override
@override
void initState() {
  super.initState();
  _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
  );
  _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
  );

  _ctrl.forward();

  if (widget.autoNavigate) {
    _navTimer = Timer(widget.displayDuration + const Duration(milliseconds: 300),
      () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/auth');
      });
  }
}
  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final primaryContainer = theme.colorScheme.primaryContainer;
    final onPrimaryContainer = theme.colorScheme.onPrimaryContainer;
    final background = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: _GlintLogo(
                diameter: 140,
                primary: primary,
                primaryContainer: primaryContainer,
                iconColor: onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular logo with shimmering glint.
class _GlintLogo extends StatefulWidget {
  final double diameter;
  final Color primary;
  final Color primaryContainer;
  final Color iconColor;

  const _GlintLogo({
    required this.diameter,
    required this.primary,
    required this.primaryContainer,
    required this.iconColor,
  });

  @override
  State<_GlintLogo> createState() => _GlintLogoState();
}

class _GlintLogoState extends State<_GlintLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.diameter;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [widget.primary, widget.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.primary.withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Icon(
            Icons.restaurant_menu,
            size: diameter * 0.42,
            color: widget.iconColor,
          ),
          // Moving glint
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (context, child) {
                final progress = (_shimmerCtrl.value * 2.4) - 1.2;
                return ClipOval(
                  child: Transform.translate(
                    offset: Offset(progress * diameter, 0),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: diameter * 1.4,
                        height: diameter,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.18),
                              Colors.white.withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
