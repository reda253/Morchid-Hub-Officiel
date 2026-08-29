import 'dart:async';

import 'package:flutter/material.dart';

/// Système de mouvement de Morchid Hub.
///
/// Trois règles tiennent tout le fichier :
///
///  1. **Une animation doit avoir un rôle.** Retour au toucher, ou éviter
///     qu'un bloc apparaisse brutalement. « C'est joli » n'en est pas un :
///     ce qu'on voit cinquante fois par jour ne s'anime pas.
///  2. **Moins de 300 ms.** Au-delà, l'interface paraît lente même quand elle
///     ne l'est pas.
///  3. **`easeOut` pour ce qui entre.** `easeIn` démarre lentement, donc
///     précisément au moment où l'œil regarde — l'écran paraît mou.
///
/// Les courbes intégrées de Flutter (`Curves.easeOut`) sont trop molles ; ces
/// deux-là sont les variantes fortes utilisées par la plupart des interfaces
/// soignées.
class AppMotion {
  const AppMotion._();

  /// Enfoncement d'un élément pressable.
  static const Duration press = Duration(milliseconds: 120);

  /// Entrée d'un bloc à l'ouverture d'un écran.
  static const Duration enter = Duration(milliseconds: 260);

  /// Décalage entre deux blocs d'une même séquence. Court volontairement :
  /// au-delà de ~80 ms la cascade se voit et l'écran paraît lent.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve easeOut = Cubic(0.23, 1.0, 0.32, 1.0);
  static const Curve easeInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  /// Respecte « Réduire les animations » du système. Réduire ne veut pas dire
  /// supprimer : on garde l'opacité, on retire le déplacement et l'échelle,
  /// qui sont ce qui provoque le mal des transports.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// Enveloppe un élément tappable d'un retour tactile par mise à l'échelle.
///
/// Remplace `InkWell` sur les cartes : l'ondulation Material bave sur une
/// carte blanche à bordure claire, alors qu'un enfoncement de 2,5 % se lit
/// instantanément et sur toutes les plateformes.
///
/// [onTap] à `null` désactive à la fois le geste et l'animation — un élément
/// inerte ne doit pas répondre au doigt.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Rester entre 0.95 et 0.98 : en dessous l'élément a l'air de sauter.
  final double pressedScale;

  const Pressable({
    Key? key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
  }) : super(key: key);

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final scale =
        (_down && enabled && !AppMotion.reduced(context)) ? widget.pressedScale : 1.0;

    return Semantics(
      button: enabled,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: AppMotion.press,
          curve: AppMotion.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fait entrer un bloc en fondu + léger glissement vers le haut.
///
/// [index] décale le départ pour produire une cascade quand plusieurs blocs
/// arrivent ensemble. Le rôle est d'éviter qu'un écran de données surgisse
/// d'un coup une fois le profil chargé — pas de décorer.
///
/// L'animation ne bloque jamais l'interaction : le contenu est tappable dès
/// la première frame.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final double offset;

  const FadeSlideIn({
    Key? key,
    required this.child,
    this.index = 0,
    this.offset = 10,
  }) : super(key: key);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // Construits dans `initState`, jamais en initialiseur `late` paresseux :
  // un bloc dont le délai n'a pas encore expiré n'aurait touché aucun des deux,
  // et `dispose()` les aurait alors créés — donc réclamé un `Ticker` — sur un
  // élément déjà détaché de l'arbre. Quitter l'écran dans les ~200 premières
  // millisecondes suffisait à faire lever « Looking up a deactivated widget's
  // ancestor is unsafe ».
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.enter);
    _curved = CurvedAnimation(parent: _controller, curve: AppMotion.easeOut);

    final delay = AppMotion.stagger * widget.index;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return widget.child;

    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final t = _curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}
