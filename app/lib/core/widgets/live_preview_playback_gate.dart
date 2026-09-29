import 'package:flutter/foundation.dart';

/// A small, owned gate for feed-preview playback.
///
/// Home turns this off immediately while its vertical scroll is moving. Live
/// cards listen to the value and fully release their decoder/platform view;
/// once scrolling has settled, only the most eligible card can acquire the
/// app-wide decoder slot again. Keeping the gate separate from card state
/// prevents a scroll notification from rebuilding every card in the feed.
class LivePreviewPlaybackGate extends ValueNotifier<bool> {
  LivePreviewPlaybackGate() : super(true);

  void pause() {
    if (value) value = false;
  }

  void resume() {
    if (!value) value = true;
  }
}
