import 'dart:async';
import 'package:flutter/material.dart';

/// Native carousel used by the published ARK Designer banner section.
class ArkDesignerBannerCarousel extends StatefulWidget {
  const ArkDesignerBannerCarousel({
    super.key,
    required this.slides,
    required this.height,
    this.radius = 16,
    this.autoplay = true,
    this.interval = const Duration(seconds: 4),
    this.pauseOnInteraction = true,
    this.showDots = true,
    this.showArrows = true,
    this.fade = false,
    this.viewFraction = 1,
    this.onTap,
  });

  final List<Map<String, dynamic>> slides;
  final double height;
  final double radius;
  final bool autoplay;
  final Duration interval;
  final bool pauseOnInteraction;
  final bool showDots;
  final bool showArrows;
  final bool fade;
  final double viewFraction;
  final VoidCallback? onTap;

  @override
  State<ArkDesignerBannerCarousel> createState() => _ArkDesignerBannerCarouselState();
}

class _ArkDesignerBannerCarouselState extends State<ArkDesignerBannerCarousel> {
  late PageController _controller;
  Timer? _timer;
  int _index = 0;
  bool _interactionPaused = false;
  Offset? _pointerStart;
  int? _activePointer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewFraction.clamp(.4, 1));
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ArkDesignerBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoplay != widget.autoplay ||
        oldWidget.interval != widget.interval ||
        oldWidget.slides.length != widget.slides.length ||
        oldWidget.pauseOnInteraction != widget.pauseOnInteraction) {
      _startTimer();
    }
    if (oldWidget.viewFraction != widget.viewFraction) {
      final next = PageController(
        initialPage: _index,
        viewportFraction: widget.viewFraction.clamp(.4, 1),
      );
      final previous = _controller;
      _controller = next;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    if (_index >= widget.slides.length) {
      _index = widget.slides.isEmpty ? 0 : widget.slides.length - 1;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.autoplay || widget.slides.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || (widget.pauseOnInteraction && _interactionPaused)) return;
      final next = (_index + 1) % widget.slides.length;
      _goTo(next);
    });
  }

  void _goTo(int index) {
    if (!mounted || widget.slides.isEmpty) return;
    setState(() => _index = index);
    if (widget.fade) {
      _controller.animateToPage(index, duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
    } else {
      _controller.animateToPage(index, duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
    }
  }

  void _touchPause(bool paused) {
    if (!widget.pauseOnInteraction) return;
    setState(() => _interactionPaused = paused);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return SizedBox(height: widget.height);
    final viewport = PageView.builder(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.slides.length,
      onPageChanged: (value) => setState(() => _index = value),
      itemBuilder: (context, index) {
        final slide = widget.slides[index];
        final image = (slide['image_url'] ?? slide['source_url'] ?? slide['url'] ?? '').toString();
        final title = (slide['title'] ?? '').toString();
        final radius = BorderRadius.circular(widget.radius);
        final body = ClipRRect(
          borderRadius: radius,
          child: Stack(fit: StackFit.expand, children: [
            image.isEmpty
                ? const ColoredBox(color: Color(0xFFECE8F3))
                : Image.network(image, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFECE8F3),
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    )),
            if (title.isNotEmpty)
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.black.withValues(alpha: .38),
                  child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        );
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.viewFraction < 1 ? 5 : 8),
          child: widget.fade
              ? AnimatedOpacity(opacity: index == _index ? 1 : .55, duration: const Duration(milliseconds: 240), child: body)
              : body,
        );
      },
    );
    // Pointer listeners do not enter Flutter's gesture arena. The previous
    // GestureDetector consumed tap gestures before the parent Designer card's
    // InkWell could open the component property editor.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _activePointer = event.pointer;
        _pointerStart = event.position;
        _touchPause(true);
      },
      onPointerUp: (event) {
        final start = _pointerStart;
        if (_activePointer == event.pointer && start != null) {
          final delta = event.position - start;
          if (delta.dx.abs() > 32 && delta.dx.abs() > delta.dy.abs() && widget.slides.length > 1) {
            final step = delta.dx < 0 ? 1 : -1;
            _goTo((_index + step + widget.slides.length) % widget.slides.length);
          } else if (delta.distance < 12) {
            widget.onTap?.call();
          }
        }
        _activePointer = null;
        _pointerStart = null;
        _touchPause(false);
      },
      onPointerCancel: (event) {
        if (_activePointer == event.pointer) {
          _activePointer = null;
          _pointerStart = null;
        }
        _touchPause(false);
      },
      child: SizedBox(
        height: widget.height,
        child: Stack(children: [
          Positioned.fill(child: viewport),
          if (widget.showArrows && widget.slides.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filledTonal(
                onPressed: () => _goTo((_index - 1 + widget.slides.length) % widget.slides.length),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            ),
          if (widget.showArrows && widget.slides.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                onPressed: () => _goTo((_index + 1) % widget.slides.length),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          if (widget.showDots && widget.slides.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.slides.length, (index) => GestureDetector(
                  onTap: () => _goTo(index),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _index ? Colors.white : Colors.white.withValues(alpha: .45),
                      shape: BoxShape.circle,
                    ),
                  ),
                )),
              ),
            ),
          ]),
        ),
    );
  }
}
