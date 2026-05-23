import 'dart:async';

enum ScrollActivityEvent { active, idle }

class ArtworkScrollDeferController {
  ArtworkScrollDeferController({
    this.idleDelay = const Duration(milliseconds: 120),
    this.onChanged,
  });

  final Duration idleDelay;
  final void Function()? onChanged;

  Timer? _idleTimer;
  bool _deferArtwork = false;

  bool get deferArtwork => _deferArtwork;

  bool onEvent(ScrollActivityEvent event) {
    switch (event) {
      case ScrollActivityEvent.active:
        _idleTimer?.cancel();
        if (_deferArtwork) return false;
        _deferArtwork = true;
        return true;
      case ScrollActivityEvent.idle:
        _idleTimer?.cancel();
        _idleTimer = Timer(idleDelay, () {
          if (!_deferArtwork) return;
          _deferArtwork = false;
          onChanged?.call();
        });
        return false;
    }
  }

  void dispose() {
    _idleTimer?.cancel();
  }
}
