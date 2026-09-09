import 'package:flutter/material.dart';

/// Glovo-style "slide to confirm" — the courier's big action for status
/// changes. Impossible to trigger by an accidental tap, works in RTL too
/// (the thumb travels toward the text end).
class SlideToConfirm extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onConfirmed;

  const SlideToConfirm({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onConfirmed,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _progress = 0; // 0 → 1 across the track
  bool _running = false;

  static const _height = 58.0;
  static const _thumb = 46.0;

  void _onDrag(DragUpdateDetails d, double width) {
    if (_running) return;
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final travel = width - _thumb - 8;
    setState(() {
      _progress += (d.delta.dx * dir) / travel;
      _progress = _progress.clamp(0.0, 1.0);
    });
  }

  Future<void> _onEnd(double width) async {
    if (_running) return;
    if (_progress >= 0.82) {
      setState(() {
        _progress = 1;
        _running = true;
      });
      try {
        await widget.onConfirmed();
      } finally {
        if (mounted) {
          setState(() {
            _running = false;
            _progress = 0;
          });
        }
      }
    } else {
      setState(() => _progress = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = width - _thumb - 8;
        final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
        final thumbOffset = _progress * travel;
        final fill = 12 + (_progress * (width - 12)).clamp(0.0, width);

        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDrag(d, width),
          onHorizontalDragEnd: (_) => _onEnd(width),
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(_height / 2),
              border: Border.all(color: widget.color.withValues(alpha: 0.35)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Progress fill
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedContainer(
                    duration: _progress == 0
                        ? const Duration(milliseconds: 250)
                        : Duration.zero,
                    width: fill,
                    height: _height,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
                ),
                // Label with subtle arrow hints
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dir > 0
                            ? Icons.keyboard_double_arrow_right_rounded
                            : Icons.keyboard_double_arrow_left_rounded,
                        color: widget.color,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.label,
                        style: TextStyle(
                            color: widget.color,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5),
                      ),
                    ],
                  ),
                ),
                // Thumb
                PositionedDirectional(
                  start: 4 + thumbOffset,
                  top: 5,
                  child: AnimatedScale(
                    scale: _running ? 1.06 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: _thumb,
                      height: _height - 10,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius:
                            BorderRadius.circular((_height - 10) / 2),
                        boxShadow: [
                          BoxShadow(
                              color: widget.color.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: _running
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white),
                            )
                          : Icon(widget.icon,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
