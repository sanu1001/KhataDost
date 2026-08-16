import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../navigation/navigation_cubit.dart';
import '../theme/app_theme.dart';

/// ── Shell tweak knobs ─────────────────────────────────────────────────────
/// The bar and the scan button are siblings; sizes meet here.
const double _kBarHeight = 70; // glass bar height
const double _kScanSize = 62; // scan circle diameter (≤ bar height)
const double _kBlurSigma = 22; // backdrop frost strength

/// Floating shell: a frosted glass capsule carries the four tabs, and the
/// scan action floats beside it as a compact gradient circle. The body
/// EXTENDS BEHIND both (extendBody) so lists visibly scroll beneath the
/// glass — the blur finally has something to refract.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The whole point of the glass: content scrolls under the bar.
      // Scaffold injects the bar's height as the body's bottom
      // MediaQuery padding, so pages can clear it with
      // MediaQuery.paddingOf(context).bottom.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _FloatingGlassNav(
                  currentIndex: navigationShell.currentIndex,
                  onSelect: (i) => context
                      .read<NavigationCubit>()
                      .goToTab(navigationShell, i),
                ),
              ),
              const SizedBox(width: 10),
              // Scan on-ramp: jump to the bill builder (Bills branch) with
              // the capture sheet auto-opened. The shell only NAVIGATES —
              // it never touches the billing bloc itself.
              _ScanButton(
                onTap: () =>
                    context.read<NavigationCubit>().goToScanBill(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating glass nav ────────────────────────────────────────────────────────
//
// iOS liquid-glass behavior on a LIGHT bar (KhataDost canvas, not Blinkit
// dark):
//  · Truly translucent: white frosted fill over a real backdrop blur — the
//    list underneath stays readable as it scrolls past.
//  · A violet-tinted glass OVAL permanently marks the selected tab. Its
//    width HUGS THE CONTENT (constant _pillTargetW) — it does NOT scale
//    with slot width, so portrait and landscape read identically.
//  · At rest it is flat glass — no magnification, icon + label fully legible.
//  · While it travels (finger drag, or the glide after a tap) it becomes a
//    LENS (RawMagnifier) and gently magnifies whatever it passes — including
//    the content scrolling beneath the bar — then settles flat on arrival.
//  · Drag anywhere on the bar to ride the pill; release snaps to the
//    nearest tab. Re-tapping the active tab still routes through
//    NavigationCubit.goToTab, so the refreshTick re-tap refetch contract
//    is untouched.

class _NavSpec {
  const _NavSpec(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _kNavItems = [
  _NavSpec(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavSpec(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Bills'),
  _NavSpec(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Items'),
  _NavSpec(Icons.people_outline_rounded, Icons.people_alt_rounded, 'People'),
];

class _FloatingGlassNav extends StatefulWidget {
  const _FloatingGlassNav({
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_FloatingGlassNav> createState() => _FloatingGlassNavState();
}

class _FloatingGlassNavState extends State<_FloatingGlassNav> {
  static const double _barH = _kBarHeight;
  static const double _hPad = 8; // inset between bar edge and first slot

  /// ── Selection-oval tweak knobs ──────────────────────────────────────────
  /// Height of the oval (bar is 70 — smaller height = flatter oval).
  static const double _pillH = 62;

  /// THE width knob: the oval's preferred width, orientation-independent.
  /// Sized to hug icon + label with even air on both sides — it stays this
  /// wide in landscape instead of stretching with the slot.
  static const double _pillTargetW = 80;

  /// On NARROW screens (portrait compact phones) a slot can be smaller than
  /// _pillTargetW; the oval may then use at most slot + this overflow,
  /// spilling a little over the neighbors, iOS liquid style.
  static const double _pillExtraW = 10;

  /// Optical vertical nudge (px). Negative lifts the oval; useful because
  /// the violet-bottom gradient can read bottom-heavy. 0 = geometric center.
  static const double _pillVNudge = 0;

  /// Lens strength while the pill is moving. Rest = 1.0 (flat glass).
  static const double _lensZoom = 0.18;

  /// Finger-following center while dragging (null = not dragging).
  double? _dragCenter;

  /// True briefly after a tap so the glide is lensed too.
  bool _pulsing = false;

  /// Invalidates stale pulse-ends.
  int _gen = 0;

  bool get _interacting => _dragCenter != null || _pulsing;

  double _slotW(double w) => (w - 2 * _hPad) / 4;

  double _slotCenter(double w, int i) => _hPad + _slotW(w) * (i + 0.5);

  int _nearestSlot(double w, double x) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < 4; i++) {
      final d = (x - _slotCenter(w, i)).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _pulse() {
    final g = ++_gen;
    setState(() => _pulsing = true);
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted && g == _gen) setState(() => _pulsing = false);
    });
  }

  void _onTap(int i) {
    HapticFeedback.selectionClick();
    _pulse(); // lens up while the capsule glides
    widget.onSelect(i); // navigation is instant; the glass glides after it
  }

  void _onDragStart(double w, DragStartDetails d) {
    _gen++;
    setState(() {
      _pulsing = false;
      _dragCenter =
          d.localPosition.dx.clamp(_slotCenter(w, 0), _slotCenter(w, 3));
    });
  }

  void _onDragUpdate(double w, DragUpdateDetails d) {
    setState(() {
      _dragCenter =
          d.localPosition.dx.clamp(_slotCenter(w, 0), _slotCenter(w, 3));
    });
  }

  void _onDragEnd(double w) {
    final x = _dragCenter;
    if (x == null) return;
    final target = _nearestSlot(w, x);
    HapticFeedback.selectionClick();
    setState(() => _dragCenter = null);
    if (target != widget.currentIndex) widget.onSelect(target);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final slotW = _slotW(w);

          // Responsive oval width:
          //  · roomy slots (landscape, tablets) → constant _pillTargetW,
          //    hugging the content instead of stretching with the slot;
          //  · narrow slots (compact portrait) → shrink to slot + overflow.
          final pillW = math.max(_pillTargetW, slotW + _pillExtraW);

          // The oval keeps the SAME breathing room against the bar's
          // rounded ends as it has above/below — symmetric corners read
          // as "perfectly centered"; a tighter right gap reads as shifted.
          const edgeGap = (_barH - _pillH) / 2;

          // Resting home = the selected slot; dragging = the finger.
          final center =
              _dragCenter ?? _slotCenter(w, widget.currentIndex);
          final pillLeft = math.max(
            edgeGap,
            math.min(center - pillW / 2, w - edgeGap - pillW),
          );
          final previewIndex = _dragCenter != null
              ? _nearestSlot(w, center)
              : widget.currentIndex;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (d) => _onDragStart(w, d),
            onHorizontalDragUpdate: (d) => _onDragUpdate(w, d),
            onHorizontalDragEnd: (_) => _onDragEnd(w),
            onHorizontalDragCancel: () => _onDragEnd(w),
            // Shadow lives OUTSIDE the clip — inside, ClipRRect crops it
            // and the bar loses its float.
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_barH / 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2E17131F),
                    blurRadius: 26,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_barH / 2),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _kBlurSigma,
                    sigmaY: _kBlurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_barH / 2),
                      // Truly translucent white glass — Blinkit frost,
                      // KhataDost light. Content must show through.
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xC9FFFFFF), Color(0x9CFFFFFF)],
                      ),
                      border: Border.all(
                        color: const Color(0xB8FFFFFF),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // ── Items (painted FIRST so the lens refracts them)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: _hPad),
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Expanded(
                                  child: _NavItem(
                                    spec: _kNavItems[i],
                                    active: i == previewIndex,
                                    onTap: () => _onTap(i),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // ── The glass oval (persistent; lenses in motion)
                        AnimatedPositioned(
                          duration: _dragCenter != null
                              ? const Duration(milliseconds: 80)
                              : const Duration(milliseconds: 340),
                          curve: _dragCenter != null
                              ? Curves.linear
                              : Curves.easeOutCubic,
                          left: pillLeft,
                          top: (_barH - _pillH) / 2 + _pillVNudge,
                          width: pillW,
                          height: _pillH,
                          child: IgnorePointer(
                            // t: 0 = resting flat glass · 1 = traveling lens.
                            child: TweenAnimationBuilder<double>(
                              tween:
                                  Tween<double>(end: _interacting ? 1 : 0),
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              builder: (context, t, _) {
                                return RawMagnifier(
                                  size: Size(pillW, _pillH),
                                  magnificationScale: 1.0 + _lensZoom * t,
                                  decoration: MagnifierDecoration(
                                    shape: StadiumBorder(
                                      side: BorderSide(
                                        color: AppColors.primaryBorder
                                            .withOpacity(.55 + .45 * t),
                                        width: 1.1,
                                      ),
                                    ),
                                    // Symmetric halo at REST (no offset —
                                    // a permanent downward shadow made the
                                    // oval read as sitting low); the drop
                                    // only appears while the lens travels.
                                    shadows: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED)
                                            .withOpacity(.10 + .20 * t),
                                        blurRadius: 8 + 10 * t,
                                        offset: Offset(0, 3 * t),
                                      ),
                                    ],
                                  ),
                                  // Violet glass film: quiet at rest,
                                  // brighter while the lens travels.
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(_pillH / 2),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white
                                              .withOpacity(.45 + .15 * t),
                                          AppColors.primarySurface
                                              .withOpacity(.30 + .15 * t),
                                          AppColors.primaryLight
                                              .withOpacity(.16 + .14 * t),
                                        ],
                                        stops: const [0, .55, 1],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Nav item — violet-on-light, no boxes ──────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textHint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Icon(
                  active ? spec.activeIcon : spec.icon,
                  key: ValueKey(active),
                  color: color,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
              child: Text(spec.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan button — compact floating gradient circle ───────────────────────────
//
// No frosted shell, no rim — just the vivid violet circle with its bloom,
// sized a touch under the bar so the pair still reads as one system.

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kScanSize,
      height: _kScanSize,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x4D7C3AED),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            customBorder: const CircleBorder(),
            child: const Center(
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
