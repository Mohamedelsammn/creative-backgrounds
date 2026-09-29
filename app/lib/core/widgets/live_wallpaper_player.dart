import 'dart:async';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'media_player_preview.dart';
import 'live_preview_playback_gate.dart';

/// App-wide cap on how many [LiveWallpaperPlayer]s may be actively decoding
/// (or holding a paused-but-retained decoder) at once, independent of which
/// carousel/list they live in.
///
/// [VisibilityDetector] already gates a single card's own playback to when it
/// is on screen, but that is a per-card decision - nothing previously stopped
/// every carousel on Home (Trending peek + one per category) from each having
/// a card cross the visibility threshold at the same moment, each spinning up
/// its own hardware decoder. Mid-range devices only have a handful of decoder
/// instances at all; this registry is the cross-widget cap that decision was
/// missing. A card that cannot get a slot simply stays on its poster and
/// retries the next time its visibility (or another card's release) changes.
///
/// ## A held slot survives a pause
///
/// A slot represents "this card owns the one decoder," not "this card is
/// currently playing." A card that scrolls away (or the feed scrolls) still
/// HOLDS its slot for [_releaseGraceDuration] after becoming ineligible - it
/// is paused, not evicted - so a quick scroll-direction reversal that brings
/// it straight back finds its own decoder still warm and just resumes
/// `play()`, never a fresh `MediaCodec.configure()`. Only when the grace
/// period elapses with the card still ineligible does it actually release the
/// slot (see [_LiveWallpaperPlayerState._armReleaseTimer]).
///
/// ## Priority holders (Details)
///
/// Every ordinary Home card acquires a plain (non-priority) slot. The
/// Wallpaper Details screen's video is the one clip the user is actually
/// looking at full-screen, unlike Home's background cards - so it acquires a
/// *priority* slot: if none is free, the registry forcibly evicts the oldest
/// plain holder (calling that holder's own release callback, so it tears
/// down exactly the way it would if its grace period had elapsed) rather than
/// making Details wait in the FIFO queue behind a decoder nobody is watching
/// anymore.
class _ActiveVideoRegistry {
  _ActiveVideoRegistry._();

  /// Conservative even for a low-end device's decoder pool, and comfortably
  /// covers "the one centered Trending card" as the common case.
  // A single decoder is the conservative production default. It avoids both
  // codec contention and multiple independently-updating video textures on
  // older devices; Details can still take that one slot with priority.
  static const int maxConcurrent = 1;

  static final List<VoidCallback> _waiters = [];

  /// One entry per currently-held slot, in acquisition order (oldest first).
  /// The callback tears down that specific holder's active resource when
  /// called - the same teardown it would perform on its own if its grace
  /// period had elapsed, just triggered by eviction instead.
  static final List<VoidCallback> _holders = [];

  static bool get hasFreeSlot => _holders.length < maxConcurrent;

  static void acquire(VoidCallback onEvicted) => _holders.add(onEvicted);

  /// [release] is frequently called from a disposing widget's [State.dispose]
  /// (see `_releaseSlot`), which can itself run while Flutter's element tree
  /// is locked (mid-rebuild, tearing down an old subtree). The freed slot's
  /// waiter callback often ends in `setState()` on a DIFFERENT, still-live
  /// widget - calling it synchronously here would then throw "setState()...
  /// widget tree was locked" on that unrelated widget. Deferring to the next
  /// frame makes this always safe regardless of what called [release].
  static void release(VoidCallback onEvicted) {
    _holders.remove(onEvicted);
    if (_waiters.isEmpty) return;
    final next = _waiters.removeAt(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => next());
  }

  /// Calls [onSlotAvailable] once a slot is free - immediately if one already
  /// is, otherwise the next time any card releases one. [remove] lets a
  /// disposed/no-longer-interested caller drop out of the queue.
  static VoidCallback waitForSlot(VoidCallback onSlotAvailable) {
    if (hasFreeSlot) {
      onSlotAvailable();
      return () {};
    }
    _waiters.add(onSlotAvailable);
    return () => _waiters.remove(onSlotAvailable);
  }

  /// Acquires a slot for [onEvicted], evicting the oldest holder if every
  /// slot is already taken rather than waiting in the FIFO queue. Reserved
  /// for the one video the user is directly, full-screen looking at right now
  /// (Wallpaper Details) - never for an off-screen Home card, or eviction
  /// would just thrash between cards fighting over the same slots.
  ///
  /// The [_holders] bookkeeping (removing the oldest, adding the new caller)
  /// happens synchronously and atomically here, so a concurrent [acquire]/
  /// [acquirePriority] always sees the correct slot count. Only the evicted
  /// holder's callback itself - which typically ends in `setState()` - is
  /// deferred to the next frame: this can be called from deep inside another
  /// widget's build (a newly-visible priority player initialising), and
  /// evicting a holder synchronously at that point would call `setState()`
  /// on that holder while the framework is mid-build/locked. The queueing
  /// order (evicted card first, since it was already waiting longest) is
  /// preserved by capturing [oldest] now and running it before anything
  /// [waitForSlot] might have queued in the meantime.
  static void acquirePriority(VoidCallback onEvicted) {
    if (!hasFreeSlot) {
      final oldest = _holders.removeAt(0);
      _holders.add(onEvicted);
      WidgetsBinding.instance.addPostFrameCallback((_) => oldest());
    } else {
      _holders.add(onEvicted);
    }
  }
}

/// A card's lifecycle stage for its own decoder/native view.
///
/// Separates "should pixels be moving right now" (playback) from "does the
/// expensive native resource exist" (resource lifetime) - the two were
/// previously conflated (going off-screen/scrolling always meant a full
/// dispose), which is what caused repeated `MediaCodec.configure()`/
/// `release()` cycling on every quick scroll-direction reversal.
enum _PlaybackStage {
  /// No controller/native view exists yet.
  uninitialized,

  /// An async `initialize()`/file-resolve is in flight.
  initializing,

  /// A controller/native view exists and is prepared, but not currently
  /// playing - either genuinely paused (mid-grace-period) or momentarily
  /// ineligible. The decoder is still warm; resuming is just `play()`.
  readyPaused,

  /// A controller/native view exists and is actively playing.
  playing,

  /// Tearing the resource down. Transient - set immediately before disposal
  /// starts so no other code path can observe a controller that is about to
  /// stop existing and treat it as usable.
  disposing,
}

/// Plays a LIVE (video) wallpaper's looping clip, with the poster underneath.
///
/// ## Why the poster is always painted
///
/// The poster image is already in the shared image cache from the list, so it
/// paints instantly. The video is layered on top and fades in only once it has
/// real frames, which means there is never a black rectangle while the decoder
/// spins up - and if playback fails entirely, the poster simply stays.
///
/// ## Why visibility gates playback, not resource lifetime, on its own
///
/// Every playing video holds a hardware decoder, and mid-range devices have
/// very few. Leaving a decoder running for every card in a scrollable list is
/// what makes a feed stutter and drains battery, so playback stops the moment
/// a card is no longer eligible (off-screen, scrolling, backgrounded). But
/// tearing the decoder down on every such moment is its own, different cost -
/// a real `MediaCodec.configure()`/`release()` cycle measured to cause 25-30%
/// jank on a quick scroll-direction reversal, since that gesture pauses and
/// resumes eligibility within a few hundred milliseconds. This widget
/// therefore separates the two: [_PlaybackStage.readyPaused] keeps the
/// decoder alive and simply not playing; only [_armReleaseTimer]'s grace
/// period elapsing (still ineligible after ~1s) - or a genuine app
/// background/dispose - actually releases it.
///
/// ## Why there is a native MediaPlayer fallback
///
/// `video_player` (ExoPlayer/Media3) has been observed to fail hardware codec
/// initialization on some MediaTek chipsets for content this backend serves -
/// `MediaCodecRenderer$DecoderInitializationException` /
/// `IllegalArgumentException: start failed`, thrown from ExoPlayer's own
/// codec-configuration sequence, deterministically, inside `initialize()`
/// itself (not a timing/streaming issue - confirmed by device logs). The exact
/// same file decodes correctly through plain Android `MediaPlayer`, which is
/// what the already-working applied-wallpaper path (`VideoWallpaperService`)
/// has always used. When `video_player` reports that failure, this widget
/// retries once through [MediaPlayerPreview] - a native `MediaPlayer`-backed
/// platform view - before giving up to the poster. That fallback view has no
/// pause primitive of its own (its `AndroidView` is a plain create/destroy
/// lifecycle) - during its own grace period it stays mounted (so a quick
/// reversal doesn't re-download/re-prepare it), which is a smaller, bounded
/// cost than the `video_player`/ExoPlayer codec churn this fix targets, and
/// only applies on devices where that fallback is already active.
///
/// [autoplay] false keeps a controller from ever being created, for callers
/// that only want the poster.
class LiveWallpaperPlayer extends StatefulWidget {
  /// Set for the remainder of the app session the first time `video_player`
  /// fails to initialise a clip.
  ///
  /// On a device where ExoPlayer's codec init is broken, that failure is
  /// deterministic - every clip fails the same way. Without this flag, every
  /// single card pays the full cost of a doomed `initialize()` attempt
  /// (network start, ExoPlayer renderer/codec setup, failure propagation)
  /// before ever reaching the working native fallback, which is a large part
  /// of the reported startup delay. Once the first failure is observed this
  /// session, every later card skips `video_player` entirely and goes
  /// straight to the native [MediaPlayerPreview] path.
  static bool videoPlayerKnownBroken = false;

  const LiveWallpaperPlayer({
    super.key,
    this.videoUrl,
    this.resolveVideoUrl,
    required this.posterUrl,
    this.fit = BoxFit.cover,
    this.autoplay = true,
    this.placeholderColor,
    this.posterCacheWidth,
    this.posterCacheHeight,
    this.priority = false,
    this.playbackGate,
    this.deferUntil,
  });

  /// The clip URL, when the caller already has it (the details screen does).
  final String? videoUrl;

  /// Resolves the clip lazily, for callers that do not.
  ///
  /// The public feed omits the `video` object entirely, so a list card only
  /// learns its clip URL by asking the detail endpoint. That request is
  /// deferred until the card is actually about to play, so scrolling past a
  /// live wallpaper costs nothing.
  final Future<String?> Function()? resolveVideoUrl;

  final String posterUrl;
  final BoxFit fit;

  /// When false the clip is never initialised - only the poster is shown.
  final bool autoplay;

  final Color? placeholderColor;

  /// Caps the poster's decoded resolution to the card's actual pixel size,
  /// mirroring `WallpaperCard`'s non-live `CachedNetworkImage` branch (which
  /// sets this for the exact same URL). Left null (full-resolution decode)
  /// by callers that render full-bleed, like Details.
  ///
  /// Without this, a live card's poster decoded a second, independent
  /// full-resolution copy of an image a normal card elsewhere may have
  /// already decoded at the capped size - `CachedNetworkImage`'s resize
  /// cache key includes the target width, so two different `memCacheWidth`
  /// values for the same URL are two separate cache entries, not a shared
  /// bitmap.
  final int? posterCacheWidth;
  final int? posterCacheHeight;

  /// When true, this player never waits in `_ActiveVideoRegistry`'s FIFO
  /// queue - if every slot is taken, it evicts the oldest holder instead.
  /// Reserved for the Wallpaper Details screen: that video is the one clip
  /// the user is directly, full-screen looking at, unlike a Home card, which
  /// may still be occupying a slot only because `VisibilityDetector`'s
  /// throttle has not yet reported it invisible after a route transition.
  final bool priority;

  /// Feed-owned scroll/lifecycle gate. Null keeps the player suitable for
  /// full-screen Details, while Home passes one shared gate to every card.
  final LivePreviewPlaybackGate? playbackGate;

  /// When non-null, decoder initialisation waits for this future before ever
  /// starting - the poster paints immediately regardless. Used by the
  /// Wallpaper Details screen so the codec's `configure()`/first-frame cost
  /// never competes with the route's own push transition for GPU/UI-thread
  /// time; the caller resolves this once the transition animation reaches
  /// [AnimationStatus.completed]. Left null by Home cards, which have no
  /// comparable transition to wait for.
  final Future<void>? deferUntil;

  /// Fraction of the widget that must be on screen before playback starts.
  static const double _visibilityThreshold = 0.6;

  @override
  State<LiveWallpaperPlayer> createState() => _LiveWallpaperPlayerState();
}

class _LiveWallpaperPlayerState extends State<LiveWallpaperPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  _PlaybackStage _stage = _PlaybackStage.uninitialized;
  bool _failed = false;

  /// Set once `video_player` has failed for this clip, so the widget switches
  /// to the native fallback instead of retrying the same failing path.
  String? _fallbackUrl;

  /// The resolved clip URL, remembered across a visibility round-trip so
  /// scrolling a card back into view does not need `resolveVideoUrl()` again.
  String? _resolvedUrl;

  /// True once `video_player` is known to have failed for THIS clip, so
  /// coming back into view skips straight to the native fallback instead of
  /// re-attempting the same doomed `initialize()`.
  bool _fellBackToNative = false;

  /// True once this instance holds a slot in [_ActiveVideoRegistry]. Held for
  /// the entire time this card has an active OR paused-but-retained decoder/
  /// native view, released only when [_stage] actually returns to
  /// [_PlaybackStage.uninitialized] - never left claimed once genuinely torn
  /// down, since "holding a slot with nothing behind it" is exactly the leak
  /// the registry exists to prevent.
  bool _slotHeld = false;

  /// Cancels a pending [_ActiveVideoRegistry.waitForSlot] registration if
  /// this card stops wanting to play before a slot actually frees up.
  VoidCallback? _cancelSlotWait;

  /// Whether the card is currently on-screen, per the last
  /// [_onVisibilityChanged] callback. `_ensureInitialised` re-checks eligibility
  /// after every `await` (URL resolution, network prepare) and abandons the
  /// attempt if it has gone false in the meantime - the card may still be
  /// mounted (just scrolled off-screen, not disposed) while a slow network
  /// call is in flight, and letting that call complete anyway would start
  /// decoding a clip nobody is looking at, and hold a slot another visible
  /// card is waiting on.
  bool _isVisible = false;
  bool _appIsActive = true;

  /// Bumped every time eligibility changes in a way that should invalidate an
  /// in-flight async operation (init, or the [widget.deferUntil] wait). Each
  /// async chain captures its own `_generation` at the start and checks it
  /// after every `await` - if it no longer matches, a NEWER intent (a later
  /// pause, a dispose, a different clip) has superseded this one, and the
  /// stale operation must not touch state, start playback, or claim a slot.
  /// This is what a scenario like "card A begins init, scroll reverses, A is
  /// no longer eligible, init completes later" needs: without this check the
  /// stale completion could still call `play()`/steal the slot.
  int _generation = 0;

  /// True whenever [_playbackAllowed] && [_isVisible] currently holds -
  /// playback is "wanted" right now. Tracked separately from [_stage] so
  /// [_onEligibilityChanged] can tell a genuine transition (wanted flipped)
  /// from a redundant re-notification (e.g. two visibility callbacks in a
  /// row with the same fraction) and avoid re-arming timers for no reason.
  bool _wasWanted = false;

  /// Debounce before RESUMING playback once eligibility returns - separate
  /// from [_releaseGraceDuration]. A short quiet window after scroll settles
  /// (or the card becomes visible) before actually calling `play()`/starting
  /// `initialize()`, so a scroll that is still decelerating (or a visibility
  /// flicker) doesn't start a decoder that gets paused again a frame later.
  static const Duration _resumeDebounce = Duration(milliseconds: 300);

  /// Grace period a paused-but-ineligible card keeps its decoder/native view
  /// BEFORE actually releasing it. This is the core fix for scroll-direction-
  /// reversal jank: a quick reversal becomes eligible again well within this
  /// window, so the SAME decoder resumes (`play()`) rather than a fresh
  /// `MediaCodec.configure()`. Chosen from the profiled range (800-1500ms);
  /// 1000ms comfortably covers a user rocking the feed back and forth a few
  /// times while staying short enough that genuinely leaving the section (or
  /// backgrounding, which bypasses this timer entirely - see
  /// [didChangeAppLifecycleState]) still releases promptly.
  static const Duration _releaseGraceDuration = Duration(milliseconds: 1000);

  Timer? _resumeTimer;
  Timer? _releaseTimer;

  bool get _playbackAllowed =>
      widget.autoplay && _appIsActive && (widget.playbackGate?.value ?? true);

  bool get _wanted => _playbackAllowed && _isVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.playbackGate?.addListener(_onPlaybackGateChanged);
  }

  @override
  void didUpdateWidget(covariant LiveWallpaperPlayer old) {
    super.didUpdateWidget(old);
    if (old.playbackGate != widget.playbackGate) {
      old.playbackGate?.removeListener(_onPlaybackGateChanged);
      widget.playbackGate?.addListener(_onPlaybackGateChanged);
      _onPlaybackGateChanged();
    }
    // A recycled list cell can be handed a different clip; tear the old one
    // down rather than showing the previous wallpaper's video. This is a
    // genuine identity change, not a transient eligibility flicker, so it
    // bypasses both debounces and releases immediately.
    if (old.videoUrl != widget.videoUrl) {
      _generation++;
      _cancelTimers();
      _disposeController();
      _releaseSlot();
      _stage = _PlaybackStage.uninitialized;
      _failed = false;
      _fallbackUrl = null;
      _resolvedUrl = null;
      _fellBackToNative = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appIsActive == active) return;
    _appIsActive = active;
    if (!active) {
      // Background/inactive/detached is NOT the grace-period path - release
      // promptly, exactly like the previous strict behaviour. The grace
      // period exists for brief foreground scroll gestures, never for the
      // app leaving the foreground.
      _generation++;
      _cancelTimers();
      _releaseNow();
    } else {
      _onEligibilityChanged();
    }
  }

  void _onPlaybackGateChanged() {
    if (!mounted) return;
    _onEligibilityChanged();
  }

  /// Central reaction to ANY eligibility input changing (gate, visibility,
  /// app-active). Debounces resume, arms/cancels the release-grace timer, and
  /// never conflates "not wanted right now" with "tear it down now."
  void _onEligibilityChanged() {
    final wanted = _wanted;
    if (wanted == _wasWanted) return;
    _wasWanted = wanted;

    if (wanted) {
      // Becoming eligible again: cancel any pending release (the whole point
      // of the grace period) and debounce the actual resume/init so a scroll
      // that is still settling doesn't immediately restart a decoder.
      _releaseTimer?.cancel();
      _releaseTimer = null;
      _resumeTimer?.cancel();
      _resumeTimer = Timer(_resumeDebounce, () {
        _resumeTimer = null;
        if (mounted && _wanted) _resume();
      });
    } else {
      // Becoming ineligible: pause immediately (cheap, keeps the decoder
      // warm) and arm the release timer - the ONLY thing that actually tears
      // the decoder down after this point, and only if nothing re-arms
      // eligibility before it fires.
      _resumeTimer?.cancel();
      _resumeTimer = null;
      _pauseKeepingDecoder();
      _releaseTimer?.cancel();
      _releaseTimer = Timer(_releaseGraceDuration, () {
        _releaseTimer = null;
        if (mounted && !_wanted) _releaseNow();
      });
    }
  }

  /// Pauses playback WITHOUT releasing the decoder/native view or the
  /// registry slot - the core of the churn fix. `video_player`'s
  /// `VideoPlayerController.pause()` is a real, cheap pause (the codec stays
  /// configured); the native `MediaPlayerPreview` fallback has no pause
  /// primitive of its own, so for that path this only stops issuing new
  /// playback intent - the existing mounted view is left as-is for the
  /// (bounded, short) grace window rather than torn down and rebuilt.
  void _pauseKeepingDecoder() {
    final c = _controller;
    if (c != null && c.value.isPlaying) {
      c.pause();
    }
    if (_stage == _PlaybackStage.playing) {
      setState(() => _stage = _PlaybackStage.readyPaused);
    }
  }

  /// Resumes an already-retained decoder (no re-`initialize()`), or starts a
  /// fresh one if none is currently held (e.g. the grace period already
  /// elapsed, or this is the very first time this card becomes eligible).
  void _resume() {
    if (!mounted || !_wanted) return;
    final c = _controller;
    if (c != null && _stage == _PlaybackStage.readyPaused) {
      // Decoder is warm - just resume, no configure/release cycle at all.
      setState(() => _stage = _PlaybackStage.playing);
      c.play();
      return;
    }
    if (_fallbackUrl != null && _stage == _PlaybackStage.readyPaused) {
      // Native fallback stayed mounted through the grace period; nothing
      // further to do, it never stopped decoding (see class doc).
      setState(() => _stage = _PlaybackStage.playing);
      return;
    }
    _ensureInitialised();
  }

  void _cancelTimers() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _releaseTimer?.cancel();
    _releaseTimer = null;
  }

  void _releaseSlot() {
    _cancelSlotWait?.call();
    _cancelSlotWait = null;
    if (_slotHeld) {
      _slotHeld = false;
      _ActiveVideoRegistry.release(_onEvicted);
    }
  }

  /// Actually tears down the active resource - the ONLY path that disposes
  /// the controller/native view (besides a genuine clip change or widget
  /// dispose). Reached from exactly two places: the release-grace [Timer]
  /// firing while still ineligible, and an immediate app-background/dispose.
  ///
  /// Also drops a pending [_ActiveVideoRegistry.waitForSlot] registration
  /// even when no resource was ever actually held - a card that went
  /// ineligible while still queued (never got a slot) must leave the FIFO
  /// queue too, or a slot that later frees up could still notify it instead
  /// of a genuinely-eligible card that has been waiting since.
  void _releaseNow() {
    _cancelSlotWait?.call();
    _cancelSlotWait = null;
    if (_stage == _PlaybackStage.uninitialized ||
        _stage == _PlaybackStage.disposing) {
      return;
    }
    _stage = _PlaybackStage.disposing;
    _disposeController();
    _releaseSlot();
    final hadVisual = _fallbackUrl != null;
    _fallbackUrl = null;
    _stage = _PlaybackStage.uninitialized;
    if (mounted && hadVisual) setState(() {});
  }

  /// Called by `_ActiveVideoRegistry` when a priority holder needs this
  /// instance's slot. Tears down the active resource exactly as [_releaseNow]
  /// would - but does NOT call back into the registry (it is the registry
  /// itself driving this, mid-eviction) and does not clear `_resolvedUrl`/
  /// `_fellBackToNative`, so this card still restarts quickly from where it
  /// left off.
  ///
  /// If this card is still genuinely wanted right now (unlike the common
  /// case - eviction usually targets a card whose eligibility just has not
  /// been re-checked yet), it would otherwise sit on its poster indefinitely
  /// - nothing else re-triggers initialisation for an already-eligible card.
  /// Joining the waiter queue here covers that case without needing a
  /// priority slot of its own.
  void _onEvicted() {
    _generation++;
    _cancelTimers();
    _stage = _PlaybackStage.disposing;
    _disposeController();
    _slotHeld = false;
    final hadVisual = _fallbackUrl != null;
    _fallbackUrl = null;
    _stage = _PlaybackStage.uninitialized;
    if (mounted && hadVisual) setState(() {});
    if (_wanted && mounted) {
      _cancelSlotWait?.call();
      _cancelSlotWait = _ActiveVideoRegistry.waitForSlot(() {
        _cancelSlotWait = null;
        if (mounted && _wanted) _ensureInitialised();
      });
    }
  }

  Future<void> _ensureInitialised() async {
    if (_stage == _PlaybackStage.initializing ||
        _controller != null ||
        _failed ||
        _fallbackUrl != null ||
        !_wanted) {
      return;
    }

    final generation = _generation;
    bool stale() => !mounted || generation != _generation;

    // Cross-carousel cap: several sections on Home can each have a card cross
    // the visibility threshold at the same moment. Only a bounded number may
    // actually hold a decoder at once; everyone else waits their turn and
    // simply stays on the poster in the meantime - never a hard failure.
    //
    // Details' video (widget.priority) never waits: if every slot is taken
    // it evicts the oldest holder immediately, since it is the one clip the
    // user is directly looking at right now, unlike a Home card that may
    // simply not have reported its own ineligibility yet.
    if (!_slotHeld) {
      if (widget.priority) {
        _ActiveVideoRegistry.acquirePriority(_onEvicted);
      } else {
        if (!_ActiveVideoRegistry.hasFreeSlot) {
          _cancelSlotWait?.call();
          _cancelSlotWait = _ActiveVideoRegistry.waitForSlot(() {
            _cancelSlotWait = null;
            if (mounted && _wanted) _ensureInitialised();
          });
          return;
        }
        _ActiveVideoRegistry.acquire(_onEvicted);
      }
      _slotHeld = true;
    }

    _stage = _PlaybackStage.initializing;

    // The Details screen defers the whole init sequence until its route's
    // push transition has actually completed, so the codec's configure()/
    // first-frame cost never competes with the transition animation for
    // GPU/UI-thread time. Re-checked for staleness after the wait exactly
    // like every other await below.
    final defer = widget.deferUntil;
    if (defer != null) {
      await defer;
      if (stale() || !_wanted) {
        _stage = _PlaybackStage.uninitialized;
        _releaseSlot();
        return;
      }
    }

    // Either the URL was handed to us, already resolved from a prior visible
    // spell, or it has to be resolved now.
    var url = widget.videoUrl ?? _resolvedUrl;
    if (url == null || url.isEmpty) {
      try {
        url = await widget.resolveVideoUrl?.call();
      } catch (_) {
        url = null;
      }
    }
    if (stale() || !_wanted) {
      // The card scrolled away (or was superseded) while the URL was
      // resolving - do not start decoding a clip nobody is looking at.
      _stage = _PlaybackStage.uninitialized;
      _releaseSlot();
      return;
    }
    if (url == null || url.isEmpty) {
      _stage = _PlaybackStage.uninitialized;
      _releaseSlot();
      // Remember the miss so a scrolling list does not retry every frame.
      setState(() => _failed = true);
      return;
    }
    _resolvedUrl = url;

    // A prior card (or an earlier eligible spell of this same card) already
    // proved video_player can't decode on this device - skip straight to the
    // native path instead of paying for another doomed initialize() attempt.
    if (LiveWallpaperPlayer.videoPlayerKnownBroken || _fellBackToNative) {
      _stage = _PlaybackStage.playing;
      setState(() => _fallbackUrl = url);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      // The card can go ineligible (or the widget be disposed) while
      // initialize() is in flight - cancel rather than start playback for a
      // card nobody is looking at, and give the slot back immediately
      // instead of holding it through a pointless play().
      if (stale() || !_wanted) {
        await controller.dispose();
        _stage = _PlaybackStage.uninitialized;
        _releaseSlot();
        return;
      }
      await controller.setLooping(true);
      // A wallpaper preview is decoration: muted so it never steals audio
      // focus from music or a call.
      await controller.setVolume(0);

      // Mount the texture BEFORE calling play().
      //
      // Flutter's video texture starts life at 1x1 and is only resized once
      // the `VideoPlayer` widget has been laid out. Starting playback first
      // makes the decoder target that 1x1 surface, and hardware decoders
      // reject it - on MediaTek this surfaces as:
      //   ACodec: setting nBufferCountActual to 14 failed: -22
      //   ACodec: Failed to allocate buffers after transitioning to IDLE
      // and no frame is ever produced. Rendering the widget for one frame
      // first gives the texture its real size, after which play() succeeds.
      _controller = controller;
      setState(() => _stage = _PlaybackStage.readyPaused);
      await WidgetsBinding.instance.endOfFrame;
      if (stale() || !_wanted) {
        await controller.dispose();
        _controller = null;
        _stage = _PlaybackStage.uninitialized;
        _releaseSlot();
        return;
      }
      await controller.play();
      controller.addListener(_onControllerUpdate);
      if (mounted) setState(() => _stage = _PlaybackStage.playing);
    } catch (e) {
      // Confirmed (device logs) that this is ExoPlayer's own codec-init
      // failure on some MediaTek chipsets, thrown synchronously out of
      // `initialize()` - not a streaming/timing issue, since the exact same
      // file plays correctly through plain `MediaPlayer`. Fall back to the
      // native MediaPlayer preview instead of giving up to a still poster.
      developer.log(
        'video_player failed to initialize, falling back to native '
        'MediaPlayer preview: $e',
        name: 'LiveWallpaper',
      );
      LiveWallpaperPlayer.videoPlayerKnownBroken = true;
      _fellBackToNative = true;
      await controller.dispose();
      if (!stale() && _wanted) {
        _stage = _PlaybackStage.playing;
        setState(() => _fallbackUrl = url);
      } else {
        // Still remember the failure (_fellBackToNative/videoPlayerKnownBroken
        // above) so a future eligible spell skips straight to the fallback,
        // but do not mount it now for a card nobody is looking at.
        _stage = _PlaybackStage.uninitialized;
        _releaseSlot();
      }
    }
  }

  /// Watches for a decoder error reported after playback has started.
  void _onControllerUpdate() {
    final c = _controller;
    if (c == null || !mounted) return;
    if (c.value.hasError) {
      developer.log(
        'video_player decode failed after starting playback, falling back '
        'to native MediaPlayer preview: ${c.value.errorDescription}',
        name: 'LiveWallpaper',
      );
      LiveWallpaperPlayer.videoPlayerKnownBroken = true;
      _fellBackToNative = true;
      final url = widget.videoUrl ?? c.dataSource;
      _resolvedUrl = url;
      _generation++;
      _disposeController();
      _stage = _PlaybackStage.playing;
      setState(() => _fallbackUrl = url);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final visible =
        info.visibleFraction >= LiveWallpaperPlayer._visibilityThreshold;
    _isVisible = visible;
    _onEligibilityChanged();
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    c?.removeListener(_onControllerUpdate);
    c?.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.playbackGate?.removeListener(_onPlaybackGateChanged);
    _generation++;
    _cancelTimers();
    _disposeController();
    _releaseSlot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = _Poster(
      url: widget.posterUrl,
      fit: widget.fit,
      placeholderColor: widget.placeholderColor,
      cacheWidth: widget.posterCacheWidth,
      cacheHeight: widget.posterCacheHeight,
    );

    if (!widget.autoplay) return poster;

    // A resource (native view or controller) exists and is retained during
    // BOTH playing and readyPaused - readyPaused is "decoder warm, not
    // disposed," not "gone." The video visual is only PAINTED OVER by the
    // poster while paused, never unmounted: the native fallback has no pause
    // primitive of its own, so keeping its widget alive (just hidden) is
    // what actually keeps it from re-preparing on a quick reversal; the
    // ExoPlayer texture is genuinely paused via the controller itself, so
    // hiding it is only a visual nicety there (no frozen last-frame flash).
    final hasResource = _stage == _PlaybackStage.playing ||
        _stage == _PlaybackStage.readyPaused;
    final showVideo = _stage == _PlaybackStage.playing;

    return VisibilityDetector(
      // Keyed by poster URL: unique per wallpaper and known up front, unlike
      // the clip URL which may still be unresolved.
      key: Key('live_player_${widget.posterUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Stack(
        fit: StackFit.expand,
        children: [
          poster,
          if (hasResource && _fallbackUrl != null)
            Opacity(
              opacity: showVideo ? 1 : 0,
              child: MediaPlayerPreview(videoUrl: _fallbackUrl!),
            )
          else if (hasResource && _controller != null)
            // Fades in over the poster once real frames exist, so the swap is
            // invisible rather than a hard cut.
            AnimatedOpacity(
              opacity: showVideo ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.url,
    required this.fit,
    this.placeholderColor,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String url;
  final BoxFit fit;
  final Color? placeholderColor;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final fallback = placeholderColor ?? const Color(0xFF15151A);
    if (url.isEmpty) return ColoredBox(color: fallback);
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      // Already cached by the list, so no fade is needed or wanted.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, url) => ColoredBox(color: fallback),
      errorWidget: (context, url, error) => ColoredBox(color: fallback),
    );
  }
}
