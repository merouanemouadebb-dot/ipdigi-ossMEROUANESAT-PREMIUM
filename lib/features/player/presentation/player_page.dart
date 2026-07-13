import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/orientation_lock.dart';
import '../../library/providers/library_provider.dart';
import '../../recommendations/related_provider.dart';
import '../../sources/domain/media_item.dart';
import '../data/black_bar_detector.dart';
import '../data/download_service.dart';
import '../domain/series_queue.dart';
import '../providers/player_controller.dart';
import '../providers/quality_provider.dart';
import '../providers/subtitle_settings_provider.dart';
import '../providers/track_prefs_provider.dart';
import '../providers/video_zoom_provider.dart';
import 'controls_overlay.dart';
import 'download_toast.dart';
import 'downloading_overlay.dart';
import 'episode_picker_sheet.dart';
import 'info_panel.dart';
import 'player_settings_panel.dart';
import 'screenshot_toast.dart';
import 'up_next_overlay.dart';

class PlayerArgs {
  final MediaItem item;
  final bool isLive;
  final Duration startAt;
  final SeriesQueue? seriesQueue;
  const PlayerArgs({
    required this.item,
    required this.isLive,
    required this.startAt,
    this.seriesQueue,
  });
}

class PlayerPage extends ConsumerStatefulWidget {
  final PlayerArgs args;
  const PlayerPage({super.key, required this.args});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WindowListener, WidgetsBindingObserver {
  late final PlayerSession _session;
  late PlayerArgs _args;
  final FocusNode _focusNode = FocusNode();
  // Tablet flag to restore orientation correctly when leaving the player.
  // Captured from MediaQuery in didChangeDependencies (not in dispose).
  bool _isTablet = false;
  Timer? _hideTimer;
  Timer? _historyTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _compSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<String>? _errSub;
  StreamSubscription<bool>? _playingSub;
  bool _autoTrackApplied = false;
  String? _zoomHudLabel;
  Timer? _zoomHudTimer;

  /// Whether the settings cog is exposed. The Quality tab works on
  /// every stream (it's a no-op for non-HLS sources, but the panel
  /// still surfaces speed / style controls), so we just keep the cog
  /// on. Reactive updates from the track stream are no longer
  /// needed; kept the field for the existing wiring rather than
  /// touching every call site.
  bool _canShowSettings = true;

  bool _controlsVisible = true;
  // True while the user drags the seek bar. Prevents the auto-hide timer
  // firing mid-drag and destroying the controls (and drag recognizer).
  bool _scrubbing = false;
  bool _isFullscreen = false;
  bool _showUpNext = false;
  bool _upNextAutoTriggered = false;

  /// Whether the up-next countdown (automatic next-episode transition) is
  /// active. The compact card that opens before the episode's end starts
  /// only as a notification; the countdown fires only after mpv reports
  /// `completed` (i.e. when the episode actually ended). Otherwise the
  /// countdown filled up during the credits and jumped to the next early.
  bool _upNextAutoplay = false;

  /// After mpv fires `completed`, the `keep-open=always` behavior sometimes
  /// drops position to 0 and emits arbitrary position events. While this
  /// flag is active the position listener doesn't update `_position`, so
  /// the slider freezes at the end position - the user isn't misled into
  /// thinking "the episode is rewinding". Resets on a new `open` call.
  bool _episodeEnded = false;
  bool _showInfo = false;
  bool _showSettings = false;

  /// Live-specific status overlay state. VOD never enters anything
  /// other than [ok]. Live transitions to [reconnecting] when mpv
  /// fires `completed` mid-broadcast (cache underrun, panel socket
  /// drop, real end-of-stream - all observationally identical) and
  /// then either snaps back to [ok] once playback resumes or settles
  /// in [ended] after a few failed reconnect attempts.
  _LiveStatus _liveStatus = _LiveStatus.ok;
  int _liveReconnectAttempt = 0;
  Timer? _liveReconnectTimer;
  static const _maxLiveReconnectAttempts = 2;
  static const _liveReconnectWindow = Duration(seconds: 5);
  bool get _isAndroidTv => Platform.isAndroid && PlatformInfo.isTv;
  int get _maxLiveReconnectAttemptsForPlatform =>
      _isAndroidTv ? 1 : _maxLiveReconnectAttempts;
  Duration get _liveReconnectWindowForPlatform =>
      _isAndroidTv ? const Duration(seconds: 8) : _liveReconnectWindow;

  /// Time of the last `_tryLiveReconnect` call. If mpv briefly signals
  /// playing=true then immediately throws an error (the panel accepts the
  /// stream but no data flows), the status keeps cycling between
  /// `ok <-> reconnecting` and each transition triggers a new
  /// `player.open()`. This creates a reconnect storm that quickly exhausts
  /// the FD limit. A 3-second throttle prevents repeated reopens on the
  /// same channel.
  DateTime? _lastReconnectAt;
  static const _reconnectThrottle = Duration(seconds: 3);

  /// Wait time to verify "is it stable?" after mpv reports playing=true.
  /// If it stays in the playing state for 1.5s, drop to status=ok;
  /// otherwise trusting only the "momentary" playing signal to change
  /// status triggers the reconnect loop.
  Timer? _liveStableTimer;
  static const _liveStableWindow = Duration(milliseconds: 1500);

  /// When mpv throws `completed`/`error` on live we don't show the banner
  /// and reopen IMMEDIATELY: on IPTV most of these are micro-glitches that
  /// recover on their own within 1-2s via mpv's cache + ffmpeg reconnect.
  /// First we allow a silent tolerance window; if the position advances
  /// again within the window we continue without any banner; if it doesn't
  /// we treat it as a real drop and fall to [_tryLiveReconnect]. This is
  /// the real fix for the banner appearing "too often".
  // 6s: wait until ffmpeg's own silent reconnect (stream-lavf-o
  // reconnect_delay_max=5) completes. At 2.5s the app forced the stream
  // to reopen via goLive() before ffmpeg had reconnected, and that was
  // exactly the VISIBLE glitch. Pulling the window above ffmpeg's backoff
  // lets most transient drops recover without the banner ever appearing.
  Timer? _liveGraceTimer;
  static const _liveGraceWindow = Duration(milliseconds: 6000);
  Duration get _liveGraceWindowForPlatform =>
      _isAndroidTv ? const Duration(milliseconds: 9000) : _liveGraceWindow;

  /// VOD-specific open watchdog. Distinct from the live state above
  /// because the failure modes are different: VOD failures are
  /// usually mpv's disk cache having corrupted bytes from a previous
  /// session, not a fresh socket drop.
  ///
  /// Starts in [opening] so the user always sees a loading
  /// animation during the initial open. Cleared to [ok] the moment
  /// mpv reports a non-zero duration (the file was probed) - that
  /// happens before the first painted frame, so the spinner gives
  /// way to the video itself instead of lingering. If the duration
  /// never arrives the watchdog escalates to retry, eventually
  /// surfacing the failure card.
  _VodStatus _vodStatus = _VodStatus.opening;
  int _vodAttempt = 0;
  Timer? _vodWatchdog;
  static const _vodOpenTimeout = Duration(seconds: 15);
  static const _maxVodAttempts = 3;
  Duration get _vodOpenTimeoutForPlatform =>
      _isAndroidTv ? const Duration(seconds: 35) : _vodOpenTimeout;
  int get _maxVodAttemptsForPlatform => _isAndroidTv ? 1 : _maxVodAttempts;

  /// Closing credits aren't tagged anywhere in Xtream / TMDB / IMDb. As a
  /// streaming-app convention we treat the last 60 s of an episode as the
  /// "credits zone" and auto-open the up-next overlay there, so the 8 s
  /// countdown to the next episode runs over the credits instead of after.
  static const _autoUpNextLeadIn = Duration(seconds: 60);
  ScreenshotToastData? _screenshotToast;
  DownloadToastData? _downloadToast;
  bool _downloadActive = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// Seek tracking - for the "skimmed" signal. The position stream emits a
  /// new position every tick; if the delta from the previous tick is small
  /// (~seconds) it counts as real watching, if large it counts as a
  /// user/scrubber seek. If `_lastTickPos` is null we haven't received the
  /// first tick yet and don't compare.
  Duration? _lastTickPos;
  DateTime? _lastTickAt;
  int _seekFwdSinceFlush = 0;
  int _seekBwdSinceFlush = 0;
  Duration _seekFwdJumpSinceFlush = Duration.zero;
  Duration _seekBwdJumpSinceFlush = Duration.zero;
  Duration _actualWatchSinceFlush = Duration.zero;

  bool get _desktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get _anyOverlay => _showInfo || _showSettings || _showUpNext;

  /// Cache the history notifier captured at mount time. Riverpod 3 marks
  /// `ref.read` from inside `dispose()` as unsafe (the BuildContext is
  /// already deactivated) - calling it for the final `_saveHistory()`
  /// then crashes the unmount with a "Using ref when a widget is about
  /// to or has been unmounted is unsafe" StateError. Stashing the
  /// notifier reference up front sidesteps the lookup entirely.
  HistoryNotifier? _historyNotifier;
  /// Resolved-once future for the persisted audio/subtitle picks. We
  /// snapshot it at mount time because the `tracks` stream usually fires
  /// before `trackPrefsProvider`'s AsyncNotifier has finished its first
  /// async build - `ref.read(...).value` was returning null in that
  /// window, which silently skipped `_applyTrackPrefs` and left the
  /// stream default in place. Awaiting `.future` waits for the load to
  /// settle, so the user's saved language always wins.
  late final Future<TrackPrefs> _trackPrefsFuture;

  @override
  void initState() {
    super.initState();
    _args = widget.args;
    _historyNotifier = ref.read(historyProvider.notifier);
    _trackPrefsFuture = ref.read(trackPrefsProvider.future);
    if (_desktop) windowManager.addListener(this);
    // To pause playback when going to the background (issue #2/3).
    // didChangeAppLifecycleState has a _desktop guard; we add the observer
    // unconditionally and remove it unconditionally in dispose.
    WidgetsBinding.instance.addObserver(this);
    _session = PlayerSession.create();
    _session.enableAutoResume();
    // Focus race fix: autofocus:true only runs on the first mount and
    // overlays/other widgets can steal focus while mounting. AFTER the
    // first frame is drawn, give focus firmly to the player so keyboard
    // shortcuts (Space/Esc/Z/F) always work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      // Zoom is per-file by design: if the global fill mode/detection
      // result carries over from the previous video, the panel shows fill
      // as selected but setting the same value again produces no notify, so
      // detection never fires (fill looks dead). Start from auto each time.
      ref.read(videoZoomProvider.notifier).set(VideoZoomMode.auto);
      ref.read(dynamicFillResultProvider.notifier).clear();
    });
    // In the player all orientations are free on every device (so landscape
    // video can be watched on phone too). On exit app.dart's browsing lock
    // returns; we also explicitly restore it in dispose.
    OrientationLock.player();
    // On mobile the player is fullscreen: the top status bar (clock/battery)
    // is hidden, the bottom (home indicator) stays. The notch/Dynamic Island
    // physical inset is preserved in viewPadding, controls start below it
    // (see controls_overlay top bar). It returns via edgeToEdge in dispose.
    // Except TV: Android TV has no system bar, and manual mode can trigger
    // the leanback overlay; don't touch that at all.
    if (!_desktop && !PlatformInfo.isTv) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.bottom],
      );
    }
    // Seed the quality cap before the first open so the very first
    // segment mpv pulls already respects the user's pick. Reads the
    // cached AsyncNotifier value; if prefs haven't resolved yet
    // we'll get QualityCap.auto which is the safe default.
    final initialQuality = ref.read(qualityProvider).value ?? QualityCap.auto;
    unawaited(_session.applyQualityCap(initialQuality.mpvValue));
    _session.open(
      _args.item.streamUrl,
      startAt: _args.startAt,
      isLive: _args.isLive,
    );
    // Kick off black-bar detection in the background right away. Sampling
    // starts after 5 seconds. When the user picks "Fill Screen" the result
    // is usually ready -> instant apply instead of an 8-12 second wait.
    _kickOffBackgroundDetection();
    if (!_args.isLive) _startVodWatchdog(initial: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        ref.read(subtitleSettingsProvider.notifier).resetToPersisted();
    });
    _scheduleHide();
    _historyTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveHistory(),
    );
    _posSub = _session.player.stream.position.listen((p) {
      if (!mounted) return;
      // After the episode completes, mpv's keep-open=always behavior
      // sometimes throws a noise event like position=0; we swallow these
      // events to keep the slider frozen at the end position.
      if (_episodeEnded) return;
      _accumulateWatchOrSeek(p);
      if (_shouldAutoOpenUpNext(p)) {
        _upNextAutoTriggered = true;
        // The compact up-next card opens as a notification in the
        // bottom-right corner. The countdown doesn't start here - it only
        // runs after mpv reports `completed`, so we don't move to the next
        // episode early before the credits finish.
        setState(() {
          _position = p;
          _showUpNext = true;
          _upNextAutoplay = false;
        });
        return;
      }
      setState(() => _position = p);
    });
    _durSub = _session.player.stream.duration.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
      // Duration arriving is the cleanest "mpv successfully opened
      // the file" signal - it lands before the first frame and
      // doesn't go back to zero when the user pauses, unlike
      // `playing`. Drop the loading overlay as soon as mpv reports
      // a non-zero duration so the spinner gives way the moment
      // mpv has anything ready, not when playback actually starts.
      if (d > Duration.zero && !_args.isLive && _vodStatus != _VodStatus.ok) {
        _vodWatchdog?.cancel();
        _vodAttempt = 0;
        setState(() => _vodStatus = _VodStatus.ok);
      }
    });
    _compSub = _session.player.stream.completed.listen((c) {
      if (!mounted || !c) return;
      if (_args.isLive) {
        // Live streams have no real "end of file" we want the
        // up-next overlay for. mpv firing `completed` here is
        // almost always a socket drop or cache underrun on the IPTV
        // side. Kick the recovery loop instead of showing replay
        // / close buttons that don't make sense for a live channel.
        // ignore: avoid_print
        print('[Player] live completion fired - tolerans penceresi');
        _scheduleLiveRecovery(reason: 'completed');
        return;
      }
      // Mid-file completion is a false EOF (cache underrun on IPTV).
      // Don't roll up-next there: with keep-open=always mpv stays on the
      // last frame, and as soon as the demuxer recovers and toggles
      // buffering=false, the PlayerSession's auto-resume listener
      // presses play at exactly that moment. Anything heavier than
      // "ignore" caused the visible double-seek the user complained
      // about.
      final pos = _session.player.state.position;
      final dur = _session.player.state.duration;
      final remaining = dur > Duration.zero ? dur - pos : Duration.zero;
      final reachedEnd =
          dur > Duration.zero && remaining <= const Duration(seconds: 15);
      if (!reachedEnd) {
        // ignore: avoid_print
        print(
          '[Player] completion fired mid-file '
          '(pos=${pos.inSeconds}s of ${dur.inSeconds}s, '
          'remaining=${remaining.inSeconds}s) - leaving mpv to recover; '
          'auto-resume will press play when the buffer settles.',
        );
        return;
      }
      // If the user seeked recently we swallow the completion: most likely
      // they dragged the scrubber too far forward and mpv reported EOF as
      // "this is the end" - not a natural playback finish. Showing the
      // "Finished watching" overlay in that case is misleading. Let the
      // user rewind and keep watching.
      final lastSeek = _session.lastSeekAt;
      if (lastSeek != null &&
          DateTime.now().difference(lastSeek) < const Duration(seconds: 5)) {
        // ignore: avoid_print
        print(
          '[Player] completion fired within 5s of user seek - treating as seek overshoot, suppressing up-next overlay',
        );
        return;
      }
      _saveHistory();
      // Freeze the slider at the end position - subsequent position events
      // (mpv keep-open=always artifacts) will be ignored.
      final endPos = dur;
      // Direct pause: DON'T use pauseByUser - if it sets the `_userPaused`
      // flag, then when the user seeks to another movie after the episode
      // ends and mpv self-pauses, auto-unpause goes silent. The `_nearEof`
      // guard (inside the pause observer and retry timer) already prevents
      // the EOF loop - there's no need to touch user intent during
      // completion.
      unawaited(_session.player.pause());
      // The episode really ended -> always show the fullscreen "next
      // episode + recommendations". Even if the user closed the compact
      // card 60s before the end, don't leave them alone with the last frame
      // at the real end; let them go to the next episode or close and exit.
      setState(() {
        _episodeEnded = true;
        if (endPos > Duration.zero) _position = endPos;
        _showUpNext = true;
        _upNextAutoTriggered = true;
        _upNextAutoplay = true;
        _controlsVisible = false;
      });
    });
    _errSub = _session.player.stream.error.listen((e) {
      // ignore: avoid_print
      print('[Player] error: $e');
      if (!mounted) return;
      if (_args.isLive && _liveStatus == _LiveStatus.ok) {
        // Live + an error string usually means the HTTP socket died
        // (panel rebooted, network drop, etc.). Treat it the same as
        // a completion mid-broadcast: try to reconnect, show the
        // recovery overlay, fall through to the "ended" card if the
        // panel stays unreachable. First a tolerance window: transient
        // socket hiccups mostly recover via ffmpeg reconnect + cache.
        _scheduleLiveRecovery(reason: 'error: $e');
        return;
      }
      // VOD: leave this alone. mpv emits non-fatal warning strings
      // during normal startup (codec selection, track probing) and
      // tripping recovery on any of those tore down a healthy
      // initial open before it could finish. The watchdog will
      // catch the genuinely-stuck case on its own timer.
    });
    _playingSub = _session.player.stream.playing.listen((playing) {
      if (!mounted) return;
      // An mpv playing=true signal alone doesn't mean "the channel
      // opened": on some IPTV streams the panel returns SYN-ACK and drops
      // the socket without sending data; mpv emits playing=true with a 1-2
      // frame buffer and immediately throws an error. If we pull the status
      // to ok instantly, the next error event triggers a new
      // _tryLiveReconnect -> reconnect storm -> FD leak. So we do a 1.5s
      // "stable playing" verification.
      if (playing && _args.isLive && _liveStatus == _LiveStatus.reconnecting) {
        _liveStableTimer?.cancel();
        _liveStableTimer = Timer(_liveStableWindow, () {
          if (!mounted) return;
          if (!_session.player.state.playing) return;
          if (_liveStatus != _LiveStatus.reconnecting) return;
          // mpv can be core-idle=yes even though it toggled pause=no (the
          // panel returned SYN-ACK but no data flows). In that case
          // playing=true is emitted but position never advances - we must
          // never drop to status=ok, otherwise the counter resets and
          // attempt 1 repeats forever. Position > 0 = mpv actually decoded
          // a frame.
          if (_session.player.state.position <= Duration.zero) return;
          _liveReconnectTimer?.cancel();
          _liveReconnectAttempt = 0;
          setState(() => _liveStatus = _LiveStatus.ok);
        });
      } else if (!playing && _args.isLive) {
        // If playing dropped again, cancel the stability wait.
        _liveStableTimer?.cancel();
        _liveStableTimer = null;
      }
      // Same for VOD: as soon as mpv is rolling, clear the "opening"
      // status so the retry overlay disappears without waiting for
      // the watchdog to fire its 12s tick.
      if (playing && !_args.isLive && _vodStatus != _VodStatus.ok) {
        _vodWatchdog?.cancel();
        _vodAttempt = 0;
        setState(() => _vodStatus = _VodStatus.ok);
      }
    });
    _tracksSub = _session.player.stream.tracks.listen((t) {
      // Strip the synthetic `auto` / `no` entries before the track
      // prefs auto-apply check below - they would lock the flag
      // before the real audio/subtitle list has settled.
      final realAudio = t.audio
          .where((a) => a.id != 'auto' && a.id != 'no')
          .toList();
      final realSubs = t.subtitle
          .where((s) => s.id != 'auto' && s.id != 'no')
          .toList();
      // ignore: avoid_print
      print(
        '[Tracks] event audio=${t.audio.length} (real=${realAudio.length}) '
        'subs=${t.subtitle.length} (real=${realSubs.length}) '
        'applied=$_autoTrackApplied',
      );
      if (_autoTrackApplied) return;
      // Wait until mpv has surfaced at least one *real* track - earlier
      // bursts may contain only the `auto`/`no` pseudo-entries, which
      // would lock the flag without ever applying the user's pick.
      if (realAudio.isNotEmpty || realSubs.isNotEmpty) {
        _autoTrackApplied = true;
        _applyTrackPrefs(t);
      }
    });
  }

  Future<void> _applyTrackPrefs(Tracks tracks) async {
    final TrackPrefs prefs;
    try {
      // Await the first-load future captured in initState; once it
      // resolves Riverpod keeps the value cached so subsequent reads
      // are cheap. We can't rely on `ref.read(...).value` directly
      // because tracks frequently arrive before that async load
      // settles, which used to wipe the saved audio language on every
      // restart.
      prefs = await _trackPrefsFuture;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    // ignore: avoid_print
    print(
      '[Tracks] apply prefs(lang=${prefs.audioLang}, title=${prefs.audioTitle}, idx=${prefs.audioIndex})',
    );
    final audio = _pickAudio(tracks.audio, prefs);
    // ignore: avoid_print
    print(
      '[Tracks] audio pick=${audio == null ? "null" : "${audio.id}:${audio.language}/${audio.title}"}',
    );
    if (audio != null) {
      try {
        await _session.player.setAudioTrack(audio);
        // ignore: avoid_print
        print('[Tracks] setAudioTrack ok id=${audio.id}');
      } catch (e) {
        // ignore: avoid_print
        print('[Tracks] setAudioTrack FAILED: $e');
      }
    }
    final sub = _pickSubtitle(tracks.subtitle, prefs);
    if (sub != null) {
      try {
        await _session.player.setSubtitleTrack(sub);
      } catch (_) {}
    }
  }

  /// Loose language match. mpv reports languages in mixed formats -
  /// ISO 639-1 ("tr"), ISO 639-2 ("tur"), or sometimes the display name
  /// ("Turkish"). Compare lowercased and accept a prefix in either
  /// direction so "tur" and "tr" pair up.
  bool _langMatches(String? a, String? b) {
    if (a == null || b == null) return false;
    final la = a.toLowerCase().trim();
    final lb = b.toLowerCase().trim();
    if (la.isEmpty || lb.isEmpty) return false;
    return la == lb || la.startsWith(lb) || lb.startsWith(la);
  }

  bool _titleMatches(String? a, String? b) {
    if (a == null || b == null) return false;
    return a.toLowerCase().trim() == b.toLowerCase().trim();
  }

  AudioTrack? _pickAudio(List<AudioTrack> tracks, TrackPrefs prefs) {
    if (prefs.audioLang == null &&
        prefs.audioTitle == null &&
        prefs.audioIndex == null) {
      return null;
    }
    for (final t in tracks) {
      if (_langMatches(t.language, prefs.audioLang)) return t;
    }
    for (final t in tracks) {
      if (_titleMatches(t.title, prefs.audioTitle)) return t;
    }
    // Last-resort positional fallback for streams whose tracks come
    // through with null language and title - common on Xtream sources.
    final idx = prefs.audioIndex;
    if (idx != null && idx >= 0 && idx < tracks.length) return tracks[idx];
    return null;
  }

  SubtitleTrack? _pickSubtitle(List<SubtitleTrack> tracks, TrackPrefs prefs) {
    // User explicitly turned subtitles off / set to auto.
    if (prefs.subtitleId != null) {
      for (final t in tracks) {
        if (t.id == prefs.subtitleId) return t;
      }
    }
    if (prefs.subtitleLang == null &&
        prefs.subtitleTitle == null &&
        prefs.subtitleIndex == null) {
      return null;
    }
    for (final t in tracks) {
      if (_langMatches(t.language, prefs.subtitleLang)) return t;
    }
    for (final t in tracks) {
      if (_titleMatches(t.title, prefs.subtitleTitle)) return t;
    }
    final idx = prefs.subtitleIndex;
    if (idx != null && idx >= 0 && idx < tracks.length) return tracks[idx];
    return null;
  }

  @override
  void dispose() {
    if (_desktop) windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _historyTimer?.cancel();
    _liveReconnectTimer?.cancel();
    _liveStableTimer?.cancel();
    _liveGraceTimer?.cancel();
    _vodWatchdog?.cancel();
    _zoomHudTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    _tracksSub?.cancel();
    _errSub?.cancel();
    _playingSub?.cancel();
    _saveHistory();
    _focusNode.dispose();
    // Restore the browsing orientation lock when leaving the player
    // (phone -> portrait, tablet -> free). Uses _isTablet captured in
    // didChangeDependencies (MediaQuery is unreliable in dispose).
    OrientationLock.browsing(isTablet: _isTablet);
    // Exit the player's fullscreen mode: bring back the system bars
    // (edgeToEdge = the modern default, the status bar is visible again).
    // Symmetric with the hide in initState: on TV nothing was touched.
    if (!_desktop && !PlatformInfo.isTv) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (_isFullscreen && _desktop) {
      unawaited(windowManager.setFullScreen(false));
    }
    // Cut audio synchronously on the same micro-task so the user never hears
    // the player past the back button while disposeAsync finishes tearing
    // the mpv instances down.
    unawaited(_session.silence());
    unawaited(_session.disposeAsync());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Issue #2/3: the video audio kept playing when the app went to the
    // background. On desktop, switching windows shouldn't cut audio
    // (second-screen viewing); this behavior is mobile + TV only.
    if (_desktop) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // pauseByUser: sets _userPaused=true, so the auto-resume listener
      // counts this as a user pause and won't auto-resume on return to
      // foreground - it stays paused until the user presses play.
      unawaited(_session.pauseByUser());
    }
  }

  /// Shared back behavior for both the ESC key and the Android/TV hardware
  /// back button: if an overlay is open close it first, otherwise leave the
  /// player. On Android the back button reaches here via PopScope; else it
  /// just popped and skipped the history save/orientation restore (_onBack).
  void _handleBackIntent() {
    if (_showSettings) {
      setState(() => _showSettings = false);
      return;
    }
    if (_showInfo) {
      setState(() => _showInfo = false);
      return;
    }
    if (_showUpNext) {
      setState(() {
        _showUpNext = false;
        _upNextAutoTriggered = true;
        _upNextAutoplay = false;
      });
      return;
    }
    _onBack();
  }

  Future<void> _onBack() async {
    _saveHistory();
    await _session.silence();
    // Return to portrait BEFORE popping (phone) - so the target page renders
    // vertically already, no landscape flash. The restore in dispose stays
    // as a backup for alternative exits like swipe-back.
    await OrientationLock.browsing(isTablet: _isTablet);
    if (!mounted) return;
    context.pop();
  }

  bool _shouldAutoOpenUpNext(Duration p) {
    if (_upNextAutoTriggered || _showUpNext) return false;
    if (_args.isLive) return false;
    if (_args.seriesQueue?.hasNext != true) return false;
    final dur = _session.player.state.duration;
    if (dur.inMilliseconds == 0) return false;
    final remaining = dur - p;
    return remaining > Duration.zero && remaining <= _autoUpNextLeadIn;
  }

  /// Counts real watch time and seek events by looking at the position
  /// difference between ticks. The expected tick interval is around 0-1
  /// seconds; a delta larger than that range means a jump (seek), smaller
  /// means natural flow.
  void _accumulateWatchOrSeek(Duration current) {
    final now = DateTime.now();
    final lastPos = _lastTickPos;
    final lastAt = _lastTickAt;
    _lastTickPos = current;
    _lastTickAt = now;
    if (lastPos == null || lastAt == null) return;
    // Real elapsed time between two ticks. If the player was paused or
    // suspended in the background this is large; don't count watch then.
    final wallDelta = now.difference(lastAt);
    if (wallDelta > const Duration(seconds: 2)) return;
    final posDelta = current - lastPos;
    // Forward seek: the position advanced far more than the real elapsed
    // time. Threshold: wallDelta + 1.5s buffer (assuming playback speed
    // 1.0).
    final forwardThreshold = wallDelta + const Duration(milliseconds: 1500);
    if (posDelta > forwardThreshold) {
      _seekFwdSinceFlush += 1;
      _seekFwdJumpSinceFlush += posDelta;
      return;
    }
    // Backward seek: the position went backward.
    if (posDelta < const Duration(milliseconds: -500)) {
      _seekBwdSinceFlush += 1;
      _seekBwdJumpSinceFlush += -posDelta;
      return;
    }
    // Negative/zero/small positive delta: natural flow. Add the wall-clock
    // delta to real watch time (position delta depends on playback speed,
    // wall-clock doesn't; someone playing at 2x watches half the real
    // time).
    if (posDelta >= Duration.zero) {
      _actualWatchSinceFlush += wallDelta;
    }
  }

  void _saveHistory() {
    final notifier = _historyNotifier;
    if (notifier == null) return;
    if (_args.isLive) {
      // Live streams have no meaningful position/duration. Use zero/zero as a
      // sentinel: VOD `progress > 0.02` filters exclude these rows from
      // "Devam Et", while Live TV's contentId-only check still matches them.
      notifier.save(
        sourceId: _args.item.sourceId,
        contentId: _args.item.id,
        position: Duration.zero,
        duration: Duration.zero,
      );
      return;
    }
    final pos = _session.player.state.position;
    final dur = _session.player.state.duration;
    if (dur.inMilliseconds == 0) return;
    final q = _args.seriesQueue;
    final parentId = q != null
        ? MediaItem.makeId(q.seriesSourceId, q.seriesId)
        : null;
    // Short episode label for series ("S1E3"). Stays null for movies.
    String? episodeLabel;
    if (q != null) {
      final ep = q.current;
      episodeLabel = 'S${ep.season}E${ep.episode}';
    }
    // Category: item.categoryName for movies; for series we have no access
    // via the queue - the history page falls back to showing the parent
    // series' category name.
    final categoryName = _args.item.categoryName;
    // Pull the save delta - notifier.save ACCUMULATES this delta onto the
    // existing row; we reset it here after the flush.
    final actualWatchDelta = _actualWatchSinceFlush;
    final fwdCount = _seekFwdSinceFlush;
    final bwdCount = _seekBwdSinceFlush;
    final fwdJump = _seekFwdJumpSinceFlush;
    final bwdJump = _seekBwdJumpSinceFlush;
    _actualWatchSinceFlush = Duration.zero;
    _seekFwdSinceFlush = 0;
    _seekBwdSinceFlush = 0;
    _seekFwdJumpSinceFlush = Duration.zero;
    _seekBwdJumpSinceFlush = Duration.zero;
    notifier.save(
      sourceId: _args.item.sourceId,
      contentId: _args.item.id,
      parentId: parentId,
      position: pos,
      duration: dur,
      actualWatch: actualWatchDelta,
      seekForwardCount: fwdCount,
      seekBackwardCount: bwdCount,
      seekForwardJump: fwdJump,
      seekBackwardJump: bwdJump,
      episodeLabel: episodeLabel,
      categoryName: categoryName,
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_anyOverlay && !_scrubbing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    if (!_desktop) {
      // Mobile: rotate the video to landscape even when locked to portrait
      // (issue #2/1). We force orientation programmatically to beat the
      // system rotation lock; pressing again frees all orientations (device
      // returns to its physical position, falling to portrait if auto-rotate is off).
      setState(() => _isFullscreen = next);
      if (next) {
        await OrientationLock.forceLandscape();
      } else {
        await OrientationLock.player();
      }
      return;
    }
    setState(() => _isFullscreen = next);
    try {
      await windowManager.setFullScreen(next);
    } catch (_) {}
    // Native fullscreen transitions confuse Flutter's HardwareKeyboard
    // state on macOS: the OS swallows the keyUp for Cmd/Meta while
    // toggling, then dispatches a fresh keyDown when focus returns and
    // the assertion `!_pressedKeys.containsKey(event.physicalKey)`
    // explodes in the log. Clearing the cached state fixes it. Also
    // re-grab focus so ESC keeps reaching `_onKey` after the transition.
    HardwareKeyboard.instance.clearState();
    if (mounted) _focusNode.requestFocus();
  }

  // window_manager fires these when the user uses macOS's green
  // traffic-light button (or Mission Control gesture) - bypassing our
  // own `_toggleFullscreen`. Without syncing here, `_isFullscreen` would
  // go stale and ESC would think it should call `_onBack` instead of
  // leaving fullscreen.
  @override
  void onWindowEnterFullScreen() {
    if (!mounted) return;
    if (!_isFullscreen) setState(() => _isFullscreen = true);
    HardwareKeyboard.instance.clearState();
    _focusNode.requestFocus();
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted) return;
    if (_isFullscreen) setState(() => _isFullscreen = false);
    HardwareKeyboard.instance.clearState();
    _focusNode.requestFocus();
  }

  void _toggleInfo() {
    setState(() {
      _showInfo = !_showInfo;
      if (_showInfo) _showSettings = false;
      _controlsVisible = true;
    });
    if (!_showInfo) _scheduleHide();
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      if (_showSettings) _showInfo = false;
      _controlsVisible = true;
    });
    if (!_showSettings) _scheduleHide();
  }

  Future<void> _captureScreenshot() async {
    final result = await _session.screenshots.capture(title: _args.item.name);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _screenshotToast = const ScreenshotToastData(
          fileName: 'error',
          isError: true,
        );
      });
      return;
    }
    setState(() {
      _screenshotToast = ScreenshotToastData(
        fileName: result.file.uri.pathSegments.last,
        dirPath: result.file.parent.path,
      );
    });
  }

  void _dismissScreenshotToast() {
    if (!mounted) return;
    setState(() => _screenshotToast = null);
  }

  Future<void> _toggleDownload() async {
    if (_args.isLive) return;
    final service = _session.downloads;
    if (_downloadActive) {
      service.cancel();
      return;
    }

    // The vast majority of IPTV servers don't allow a second parallel HTTP
    // connection to the same stream - while mpv is reading, dio gets "HTTP
    // 403" or "Connection closed". Before downloading, close the mpv stream,
    // and reopen it from the same position when done.
    final resumeAt = _session.player.state.position;
    final wasPlaying = _session.player.state.playing;
    bool playerWasStopped = false;
    try {
      await _session.player.stop();
      playerWasStopped = true;
    } catch (_) {}

    setState(() {
      _downloadActive = true;
      _downloadToast = const DownloadToastData(
        state: DownloadToastState.progress,
      );
    });

    DownloadResult? result;
    Object? failure;
    try {
      result = await service.download(
        url: _args.item.streamUrl,
        title: _args.item.displayName,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _downloadToast = DownloadToastData(
              state: DownloadToastState.progress,
              fraction: p.fraction,
              received: p.received,
              total: p.total,
              bytesPerSecond: p.bytesPerSecond,
            );
          });
        },
      );
    } catch (e) {
      failure = e;
    }

    // Reopen the player in every case - success, cancel and error.
    if (playerWasStopped) {
      try {
        await _session.open(
          _args.item.streamUrl,
          startAt: resumeAt,
          isLive: false,
        );
        if (!wasPlaying) {
          // Restore the pre-download pause as a user-intent pause so the
          // auto-resume listener doesn't override it the moment mpv
          // settles after reopening.
          await _session.pauseByUser();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    if (result != null) {
      final r = result;
      setState(() {
        _downloadActive = false;
        _downloadToast = DownloadToastData(
          state: DownloadToastState.success,
          fileName: r.file.uri.pathSegments.last,
          dirPath: r.file.parent.path,
          filePath: r.file.path,
        );
      });
      return;
    }

    if (failure is DownloadException) {
      final e = failure;
      final DownloadToastState next;
      if (e.cancelled) {
        next = DownloadToastState.cancelled;
      } else if (e.unsupportedFormat) {
        next = DownloadToastState.unsupported;
      } else {
        next = DownloadToastState.error;
      }
      setState(() {
        _downloadActive = false;
        _downloadToast = DownloadToastData(
          state: next,
          detail: next == DownloadToastState.error ? e.message : null,
        );
      });
    } else {
      setState(() {
        _downloadActive = false;
        _downloadToast = const DownloadToastData(
          state: DownloadToastState.error,
        );
      });
    }
  }

  void _dismissDownloadToast() {
    if (!mounted) return;
    setState(() => _downloadToast = null);
  }

  bool get _shouldShowNextEpisodePill {
    if (_args.isLive) return false;
    final q = _args.seriesQueue;
    if (q == null || q.next == null) return false;
    if (_duration.inSeconds == 0) return false;
    final remaining = _duration - _position;
    return remaining > Duration.zero &&
        remaining <= const Duration(seconds: 20);
  }

  Future<void> _playEpisode(SeriesQueue queue) async {
    final ep = queue.current;
    final newItem = MediaItem(
      id: queue.contentIdFor(ep),
      sourceId: queue.seriesSourceId,
      streamId: ep.id,
      name: '${queue.seriesName} • S${ep.season}E${ep.episode} ${ep.title}',
      streamUrl: ep.streamUrl,
      kind: MediaKind.movie,
    );
    final newArgs = PlayerArgs(
      item: newItem,
      isLive: false,
      startAt: Duration.zero,
      seriesQueue: queue,
    );
    // Persist progress for the current episode and switch the session in
    // place - pushing a new route would leave the previous player alive for
    // the duration of dispose() and produce overlapping audio.
    _saveHistory();
    try {
      await _session.player.stop();
    } catch (e) {
      // ignore: avoid_print
      print('[Player] _playEpisode stop failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _args = newArgs;
      _showUpNext = false;
      _upNextAutoTriggered = false;
      _upNextAutoplay = false;
      _episodeEnded = false;
      _showInfo = false;
      _showSettings = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _controlsVisible = true;
      _autoTrackApplied = false;
      _vodStatus = _VodStatus.opening;
    });
    _scheduleHide();
    ref.read(subtitleSettingsProvider.notifier).resetToPersisted();
    // Zoom and bar detection belong to the previous episode: if the future
    // isn't reset, picking fill in the new episode applied the old episode's
    // result. Return to auto, clear it, re-kick detection with the new URL.
    _detectionFuture = null;
    ref.read(videoZoomProvider.notifier).set(VideoZoomMode.auto);
    ref.read(dynamicFillResultProvider.notifier).clear();
    try {
      await _session.open(
        newArgs.item.streamUrl,
        startAt: newArgs.startAt,
        isLive: false,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[Player] _playEpisode open failed: $e\n$st');
      if (!mounted) return;
      // Keep the watchdog overlay so the user can say "try again".
      setState(() => _vodStatus = _VodStatus.opening);
    }
    _kickOffBackgroundDetection();
    _startVodWatchdog(initial: true);
  }

  void _playNextEpisode() {
    final q = _args.seriesQueue;
    if (q == null || !q.hasNext) return;
    _playEpisode(q.advance());
  }

  void _playPrevEpisode() {
    final q = _args.seriesQueue;
    if (q == null || !q.hasPrevious) return;
    _playEpisode(q.back());
  }

  void _replay() {
    setState(() {
      _showUpNext = false;
      _upNextAutoTriggered = false;
      _upNextAutoplay = false;
      // Replaying starts a new position stream; lift the slider
      // freeze.
      _episodeEnded = false;
    });
    _session.player.seek(Duration.zero);
    _session.playByUser();
  }

  /// First one called when mpv throws `completed`/`error` on live. It
  /// doesn't show the banner immediately: it starts a short silent
  /// tolerance window. If at the end of the window mpv is actually decoding
  /// frames (position past the start), it treats this as a self-recovering
  /// micro-glitch and shows nothing; otherwise it counts a real drop and
  /// falls to [_tryLiveReconnect]. It prevents the "broadcast interrupted"
  /// banner from appearing too often on IPTV.
  void _scheduleLiveRecovery({required String reason}) {
    if (!_args.isLive || !mounted) return;
    if (_liveStatus != _LiveStatus.ok) return;
    if (_liveGraceTimer?.isActive ?? false) return;
    final startPos = _session.player.state.position;
    // ignore: avoid_print
    print(
      '[Player] live glitch ($reason) - '
      '${_liveGraceWindowForPlatform.inMilliseconds}ms '
      'tolerans tanınıyor, mpv/ffmpeg kendini toparlasın',
    );
    _liveGraceTimer = Timer(_liveGraceWindowForPlatform, () {
      if (!mounted || !_args.isLive) return;
      if (_liveStatus != _LiveStatus.ok) return;
      final s = _session.player.state;
      final recovered = s.playing && s.position > startPos;
      if (recovered) {
        // ignore: avoid_print
        print(
          '[Player] live glitch kendiliğinden toparlandı '
          '(${startPos.inSeconds}s -> ${s.position.inSeconds}s) - banner yok',
        );
        return;
      }
      // ignore: avoid_print
      print('[Player] live glitch toparlanmadı - reconnect');
      _tryLiveReconnect(reason: reason);
    });
  }

  /// Reopen the live URL and wait [_liveReconnectWindow] for mpv to
  /// produce a playing state. Loops up to [_maxLiveReconnectAttempts]
  /// times - that covers the common transient cases (panel restart,
  /// brief network hiccup) without making the user stare at a
  /// spinner forever when the channel is really gone. Idempotent: a
  /// second call while one is already in flight is a no-op so a
  /// completion event + an error event at the same time don't
  /// stomp each other.
  void _tryLiveReconnect({required String reason}) {
    if (!_args.isLive || !mounted) return;
    if (_liveStatus == _LiveStatus.reconnecting) return;
    if (_liveStatus == _LiveStatus.ended) return;
    // Throttle: rapidly repeated reconnect attempts on the same channel
    // (the mpv playing=true -> error -> playing=true -> error ... loop)
    // lead us into an FD leak. If less than 3 seconds passed since the last
    // reconnect, drop straight to ended and let the user leave the channel
    // with the back button. This both stops the reconnect storm and signals
    // "the channel is faulty" to the user.
    final last = _lastReconnectAt;
    if (last != null && DateTime.now().difference(last) < _reconnectThrottle) {
      // ignore: avoid_print
      print(
        '[Player] reconnect throttled (last=${DateTime.now().difference(last).inMilliseconds}ms ago) - ending',
      );
      setState(() => _liveStatus = _LiveStatus.ended);
      return;
    }
    _lastReconnectAt = DateTime.now();
    _liveReconnectAttempt = 1;
    setState(() => _liveStatus = _LiveStatus.reconnecting);
    // ignore: avoid_print
    print('[Player] live reconnect attempt 1 (reason=$reason)');
    unawaited(_session.goLive());
    _liveReconnectTimer?.cancel();
    _liveReconnectTimer = Timer(
      _liveReconnectWindowForPlatform,
      _checkLiveReconnect,
    );
  }

  void _checkLiveReconnect() {
    if (!mounted || !_args.isLive) return;
    // playing=true alone isn't enough: mpv can be core-idle even in the
    // pause=no state. For real proof of decode, position > 0.
    final state = _session.player.state;
    final playing = state.playing && state.position > Duration.zero;
    if (playing) {
      // mpv is rolling again - drop the overlay and reset for the
      // next outage so a single momentary glitch doesn't burn one
      // of our retry slots.
      // ignore: avoid_print
      print('[Player] live reconnect succeeded');
      setState(() => _liveStatus = _LiveStatus.ok);
      _liveReconnectAttempt = 0;
      return;
    }
    if (_liveReconnectAttempt >= _maxLiveReconnectAttemptsForPlatform) {
      // ignore: avoid_print
      print('[Player] live reconnect exhausted - marking ended');
      setState(() => _liveStatus = _LiveStatus.ended);
      return;
    }
    _liveReconnectAttempt++;
    // ignore: avoid_print
    print('[Player] live reconnect attempt $_liveReconnectAttempt');
    unawaited(_session.goLive());
    _liveReconnectTimer = Timer(
      _liveReconnectWindowForPlatform,
      _checkLiveReconnect,
    );
  }

  /// Arm the VOD open watchdog. Called right after the initial
  /// open and again from [_checkVodOpen] between retry attempts.
  /// [initial] resets the attempt counter so a fresh PlayerPage
  /// starts at attempt 0; the overlay only appears once the
  /// watchdog has actually detected a stuck open and switched the
  /// status to [_VodStatus.opening] inside [_checkVodOpen].
  void _startVodWatchdog({bool initial = false}) {
    if (_args.isLive || !mounted) return;
    _vodWatchdog?.cancel();
    if (initial) {
      _vodAttempt = 0;
    }
    _vodWatchdog = Timer(_vodOpenTimeoutForPlatform, _checkVodOpen);
  }

  /// Verdict on whether mpv ever managed to start the VOD. Healthy
  /// playback requires both a non-zero duration (file was probed)
  /// and a `playing` state. A buffering=true mid-progress is fine -
  /// only "never moved" is treated as a stuck open.
  void _checkVodOpen() {
    if (!mounted || _args.isLive) return;
    final state = _session.player.state;
    // Open succeeded if mpv has probed the file and knows its
    // duration. Playback state is separate: a user who hit pause
    // during loading is still on a "healthy" open and we must not
    // tear it down to retry.
    final healthy = state.duration > Duration.zero;
    if (healthy) {
      // ignore: avoid_print
      print('[Player] VOD open watchdog: healthy, clearing');
      if (_vodStatus != _VodStatus.ok) {
        setState(() => _vodStatus = _VodStatus.ok);
      }
      _vodAttempt = 0;
      return;
    }
    if (_vodAttempt >= _maxVodAttemptsForPlatform) {
      // ignore: avoid_print
      print('[Player] VOD open exhausted after $_vodAttempt attempts');
      setState(() => _vodStatus = _VodStatus.failed);
      return;
    }
    _vodAttempt++;
    final resumeAt = state.position > Duration.zero
        ? state.position
        : _args.startAt;
    // First retry: plain reopen (probably a slow socket or panel
    // hiccup). Second retry onward: nuke mpv's disk cache before
    // reopening - that catches the "corrupt cache entry locks out
    // one URL while another player works fine" case the user
    // reported. We hold off on cache-wipe for the first retry
    // because it interrupts every other open in flight and is
    // overkill for transient failures.
    final wipeCache = !_isAndroidTv && _vodAttempt >= 2;
    // ignore: avoid_print
    print(
      '[Player] VOD retry attempt $_vodAttempt '
      '(wipeCache=$wipeCache, resumeAt=${resumeAt.inSeconds}s)',
    );
    // Now that we're sure recovery is happening (not a healthy
    // startup that just took a second longer), show the overlay so
    // the user knows we're working on it.
    setState(() => _vodStatus = _VodStatus.opening);
    if (wipeCache) {
      unawaited(
        _session.reopenWithFreshCache(_args.item.streamUrl, startAt: resumeAt),
      );
    } else {
      unawaited(
        _session.open(_args.item.streamUrl, startAt: resumeAt, isLive: false),
      );
    }
    _vodWatchdog = Timer(_vodOpenTimeoutForPlatform, _checkVodOpen);
  }

  /// Briefly show what zoom mode was just selected - same affordance
  /// most TVs have when you cycle aspect ratios via the remote.
  /// Auto-clears after 1.5s so it doesn't linger over the picture.
  void _showZoomHud(String label) {
    _zoomHudTimer?.cancel();
    setState(() => _zoomHudLabel = label);
    _zoomHudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _zoomHudLabel = null);
    });
  }

  /// Compute the active zoom scale. In "Fill Screen" mode, if there's a
  /// detector result it computes the **real** scale for the current
  /// viewport size; otherwise it returns the fallback from the enum.
  ///
  /// Window size matters: if the codec frame is 16:9 but the window is
  /// 16:10, BoxFit.contain adds an extra (player-level) letterbox around
  /// the video. Removing only the hardcoded band isn't enough, those extra
  /// bands must be accounted for too. The rule is "until the first gap
  /// closes": it stops at whichever axis with content gap it touches first.
  double _resolveZoomScale(Size viewport) {
    final mode = ref.watch(videoZoomProvider);
    final fillResult = ref.watch(dynamicFillResultProvider);
    if (mode != VideoZoomMode.fill) {
      return mode.scale;
    }
    // Fill mode selected but detection not ready yet -> 1.0 (no zoom).
    // Applying a fixed fallback (1.2x) created a race: a wrong scale showed
    // for a moment, then jumped to the correct one. Waiting with 1.0 solves
    // the double-change problem at the root; when detection arrives it makes
    // a single transition to the correct value.
    if (fillResult == null) {
      return 1.0;
    }
    final vw = viewport.width;
    final vh = viewport.height;
    final fw = fillResult.frameWidth.toDouble();
    final fh = fillResult.frameHeight.toDouble();
    if (vw <= 0 || vh <= 0 || fw <= 0 || fh <= 0) return mode.scale;

    // Asymmetry filter: real hardcoded letterbox/pillarbox bands are
    // symmetric (top ~= bottom, left ~= right). A one-sided band detection
    // means a false positive caused by a dark object in the scene. Min
    // threshold 2%: if both sides aren't at least this much, that axis is
    // zeroed. Also cancel if the ratio of band fractions exceeds 3:1.
    bool symmetricPair(double a, double b) {
      if (a < 0.02 || b < 0.02) return false;
      final lo = a < b ? a : b;
      final hi = a > b ? a : b;
      return hi / lo <= 3.0;
    }

    final useVert = symmetricPair(fillResult.top, fillResult.bottom);
    final useHoriz = symmetricPair(fillResult.left, fillResult.right);
    final top = useVert ? fillResult.top : 0.0;
    final bottom = useVert ? fillResult.bottom : 0.0;
    final left = useHoriz ? fillResult.left : 0.0;
    final right = useHoriz ? fillResult.right : 0.0;

    // The scale at which the codec frame fits into the viewport with
    // BoxFit.contain. Whichever axis is the bottleneck fills the viewport
    // fully there, leaving a gap (letterbox/pillarbox) on the other axis.
    final sFitW = vw / fw;
    final sFitH = vh / fh;
    final sFit = sFitW < sFitH ? sFitW : sFitH;

    // The size the content occupies on screen (once the black bands that
    // passed the filter are removed).
    final contentW = fw * sFit * (1.0 - left - right);
    final contentH = fh * sFit * (1.0 - top - bottom);
    if (contentW <= 0 || contentH <= 0) return 1.0;

    // The "until the first gap closes" rule: for each axis compute the
    // scale that makes the content touch the viewport on that axis, then
    // pick the smaller of the scales of the axes that HAVE a gap. Black on
    // all four sides: content stops at the first axis it touches (like
    // contain, no crop); gap on a single axis: it grows until that axis
    // fills and ClipRect crops the overflow on the other. Aspect ratio is
    // preserved with uniform scale, content isn't distorted.
    final sW = vw / contentW;
    final sH = vh / contentH;
    final candidates = [if (sW > 1.001) sW, if (sH > 1.001) sH];
    if (candidates.isEmpty) return 1.0;
    final scale = candidates.reduce((a, b) => a < b ? a : b);
    return scale.clamp(1.0, 2.5);
  }

  /// URL-based detection cache. Shared for the process lifetime
  /// (`static`), so the detector doesn't run again when reopening the same
  /// content / on mode changes.
  static final Map<String, BlackBarResult> _detectionCache = {};

  /// The detection Future running in the background. Once kicked off
  /// (~5s after the video opens) sampling begins; by the time the user
  /// picks Fill Screen the result is either ready or awaited with `await`.
  /// It avoids the 12s wait on a manual pick.
  Future<BlackBarResult?>? _detectionFuture;

  /// Called as soon as the video opens. If not in the cache it starts the
  /// detector in the background. The first 5s is waited out so the
  /// credits / pre-roll pass, then 10 samples are taken.
  void _kickOffBackgroundDetection() {
    final url = _args.item.streamUrl;
    if (_detectionCache.containsKey(url)) return;
    if (_detectionFuture != null) return;
    _detectionFuture = _doDetection(url);
  }

  Future<BlackBarResult?> _doDetection(String url) async {
    // Wait for the player to start rendering a real video frame. While mpv
    // is opening it can briefly show an empty 4K canvas (splash); if we take
    // a screenshot at that stage the whole frame comes out "black" and the
    // detector returns nonsense. The moment the player's codec width is
    // greater than zero, real video frames have started flowing.
    try {
      await _session.player.stream.width
          .firstWhere((w) => w != null && w > 0)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Even if width never arrived (8s) let's still try - the sanity
      // check will reject a wrong result.
    }
    if (!mounted) return null;
    // Extra 1s warmup: when the first frame arrives the decoder sometimes
    // waits for a few more keyframes; this much is enough for a stable image.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return null;
    const detector = BlackBarDetector();
    final result = await detector.detect(_session.player);
    // ignore: avoid_print
    print('[BlackBarDetector] background detection done: $result');

    // Sanity check: the real content must be at least 50% of the frame.
    // Below that = either a splash/loading screen was caught or the
    // detector is miscalibrated. Or the content really is small (PiP,
    // network logo) - trying to close it would blow up the picture.
    if (result != null && result.hasBars) {
      final contentFraction =
          (1 - result.top - result.bottom) * (1 - result.left - result.right);
      if (contentFraction < 0.5) {
        // ignore: avoid_print
        print(
          '[BlackBarDetector] rejecting unreasonable result '
          '(content=${(contentFraction * 100).toStringAsFixed(0)}% of frame)',
        );
        _detectionCache[url] = const BlackBarResult(
          top: 0,
          bottom: 0,
          left: 0,
          right: 0,
          frameWidth: 0,
          frameHeight: 0,
          samples: 0,
        );
        return null;
      }
      _detectionCache[url] = result;
    } else {
      // Cache the negative result too: no re-waiting on a second pick.
      _detectionCache[url] = const BlackBarResult(
        top: 0,
        bottom: 0,
        left: 0,
        right: 0,
        frameWidth: 0,
        frameHeight: 0,
        samples: 0,
      );
    }
    return result;
  }

  /// Called when the "Fill Screen" mode is selected.
  /// Cache hit -> apply instantly.
  /// Cache miss + background future -> await it (usually returns within seconds).
  /// Cache miss + no future -> start the detector now.
  Future<void> _runFillAutoDetect() async {
    final url = _args.item.streamUrl;

    // 1) Cache hit: instant.
    final cached = _detectionCache[url];
    if (cached != null) {
      // ignore: avoid_print
      print('[BlackBarDetector] CACHE HIT: $cached');
      if (cached.hasBars) {
        ref.read(dynamicFillResultProvider.notifier).set(cached);
        String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
        _showZoomHud(
          'Bantlar (cache):\n'
          'Üst ${pct(cached.top)}  Alt ${pct(cached.bottom)}\n'
          'Sol ${pct(cached.left)}  Sağ ${pct(cached.right)}',
        );
      } else {
        ref.read(dynamicFillResultProvider.notifier).clear();
        _showZoomHud(ref.tr('player.zoomNoBandsCache'));
      }
      return;
    }

    // 2) Cache miss: start now if there's no background future.
    if (_detectionFuture == null) {
      _detectionFuture = _doDetection(url);
    }
    // ignore: avoid_print
    print('[BlackBarDetector] CACHE MISS, awaiting background future');
    _showZoomHud(ref.tr('player.zoomDetecting'));
    final result = await _detectionFuture;
    if (!mounted) return;
    if (result == null || !result.hasBars) {
      _showZoomHud(ref.tr('player.zoomNoBandsFound'));
      ref.read(dynamicFillResultProvider.notifier).clear();
      return;
    }
    ref.read(dynamicFillResultProvider.notifier).set(result);
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    _showZoomHud(
      'Bantlar:\n'
      'Üst ${pct(result.top)}  Alt ${pct(result.bottom)}\n'
      'Sol ${pct(result.left)}  Sağ ${pct(result.right)}',
    );
  }

  /// Debug: samples a few frames and detects hardcoded black bands. Writes
  /// the result to both the console and the on-screen zoom HUD - so the
  /// user can see the values visually.
  bool _detectingBars = false;
  Future<void> _detectBlackBarsDebug() async {
    if (_detectingBars) return;
    _detectingBars = true;
    _showZoomHud('Siyah bant tespiti...');
    try {
      const detector = BlackBarDetector();
      final result = await detector.detect(_session.player);
      // ignore: avoid_print
      print('[BlackBarDetector] result: $result');
      if (!mounted) return;
      if (result == null) {
        _showZoomHud('Tespit başarısız');
        return;
      }
      String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
      final label = result.hasBars
          ? 'Üst ${pct(result.top)}  Alt ${pct(result.bottom)}\n'
                'Sol ${pct(result.left)}  Sağ ${pct(result.right)}\n'
                'İçerik AR ${result.contentAspectRatio.toStringAsFixed(2)}'
          : 'Siyah bant yok';
      _showZoomHud(label);
      // HUD timer 1.5s; show the detection result longer.
      _zoomHudTimer?.cancel();
      _zoomHudTimer = Timer(const Duration(milliseconds: 5000), () {
        if (!mounted) return;
        setState(() => _zoomHudLabel = null);
      });
    } finally {
      _detectingBars = false;
    }
  }

  /// User-triggered manual retry from the failure overlay. Resets the
  /// attempt counter and walks the recovery sequence from scratch,
  /// starting with a cache wipe because by the time the user sees
  /// the "failed" card we already exhausted plain reopens.
  void _retryVodFromOverlay() {
    if (!mounted || _args.isLive) return;
    _vodAttempt = 1;
    setState(() => _vodStatus = _VodStatus.opening);
    unawaited(
      _session.reopenWithFreshCache(
        _args.item.streamUrl,
        startAt: _args.startAt,
      ),
    );
    _vodWatchdog?.cancel();
    _vodWatchdog = Timer(_vodOpenTimeoutForPlatform, _checkVodOpen);
  }

  Future<void> _showEpisodePicker() async {
    final q = _args.seriesQueue;
    if (q == null) return;
    _showControls();
    await EpisodePickerSheet.show(
      context: context,
      queue: q,
      onSelect: (index) {
        if (index == q.currentIndex) return;
        _playEpisode(q.at(index));
      },
    );
  }

  void _navigateToItem(MediaItem item) {
    switch (item.kind) {
      case MediaKind.movie:
        context.pushReplacement('/movie/${item.sourceId}/${item.streamId}');
        break;
      case MediaKind.series:
        context.pushReplacement('/series/${item.sourceId}/${item.streamId}');
        break;
      case MediaKind.live:
        context.pushReplacement(
          '/player',
          extra: PlayerArgs(item: item, isLive: true, startAt: Duration.zero),
        );
        break;
    }
  }

  RelatedQuery get _relatedQuery {
    final q = _args.seriesQueue;
    if (q != null) {
      return RelatedQuery(sourceId: q.seriesSourceId, streamId: q.seriesId);
    }
    return RelatedQuery(
      sourceId: _args.item.sourceId,
      streamId: _args.item.streamId,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // For the arrow keys we also catch repeat events; when the user holds
    // the right/left arrow, a jump happens on each OS auto-repeat fire. The
    // other shortcuts (Space, F, M, ...) fire only on KeyDown, otherwise
    // holding a key down over-toggles.
    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (!isDown && !isRepeat) return KeyEventResult.ignored;
    _showControls();
    final player = _session.player;
    final pos = player.state.position;
    final dur = player.state.duration;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final seekDelta = isShift
        ? const Duration(seconds: 30)
        : const Duration(seconds: 10);

    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.arrowLeft) {
      final next = pos - seekDelta;
      _session.seekByUser(next < Duration.zero ? Duration.zero : next);
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.arrowRight) {
      final next = pos + seekDelta;
      final clamped = dur.inMilliseconds == 0
          ? next
          : (next > dur ? dur : next);
      _session.seekByUser(clamped);
      return KeyEventResult.handled;
    }
    // The shortcuts below only run on the first press.
    if (!isDown) return KeyEventResult.ignored;
    if (logical == LogicalKeyboardKey.space ||
        logical == LogicalKeyboardKey.select) {
      player.state.playing ? _session.pauseByUser() : _session.playByUser();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.arrowUp) {
      final v = (player.state.volume + 5).clamp(0.0, 100.0);
      player.setVolume(v);
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.arrowDown) {
      final v = (player.state.volume - 5).clamp(0.0, 100.0);
      player.setVolume(v);
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyM) {
      final muted = player.state.volume == 0;
      player.setVolume(muted ? 100 : 0);
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyI) {
      _toggleInfo();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyS) {
      _captureScreenshot();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyZ) {
      // Cycle Auto -> Cinema 21:9 -> 4:3 -> Fill -> Auto.
      final next = ref.read(videoZoomProvider.notifier).cycle();
      _showZoomHud(ref.tr(next.labelKey));
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyB) {
      // Debug: hardcoded black band detection. Samples a few frames, writes
      // the result to the HUD.
      unawaited(_detectBlackBarsDebug());
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyN &&
        _args.seriesQueue?.hasNext == true) {
      _playNextEpisode();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.keyP &&
        _args.seriesQueue?.hasPrevious == true) {
      _playPrevEpisode();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.escape) {
      if (_showSettings) {
        setState(() => _showSettings = false);
        return KeyEventResult.handled;
      }
      if (_showInfo) {
        setState(() => _showInfo = false);
        return KeyEventResult.handled;
      }
      if (_showUpNext) {
        setState(() {
          _showUpNext = false;
          _upNextAutoTriggered = true;
          _upNextAutoplay = false;
        });
        return KeyEventResult.handled;
      }
      if (_isFullscreen) {
        _toggleFullscreen();
      } else {
        _onBack();
      }
      return KeyEventResult.handled;
    }
    final digitMap = <LogicalKeyboardKey, double>{
      LogicalKeyboardKey.digit0: 0,
      LogicalKeyboardKey.digit1: 0.1,
      LogicalKeyboardKey.digit2: 0.2,
      LogicalKeyboardKey.digit3: 0.3,
      LogicalKeyboardKey.digit4: 0.4,
      LogicalKeyboardKey.digit5: 0.5,
      LogicalKeyboardKey.digit6: 0.6,
      LogicalKeyboardKey.digit7: 0.7,
      LogicalKeyboardKey.digit8: 0.8,
      LogicalKeyboardKey.digit9: 0.9,
    };
    final frac = digitMap[logical];
    if (frac != null && dur.inMilliseconds > 0) {
      _session.seekByUser(
        Duration(milliseconds: (dur.inMilliseconds * frac).round()),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Capture the tablet flag here so orientation is restored correctly on
    // player exit (build has safe access to MediaQuery).
    _isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final subtitleSettings = ref.watch(subtitleSettingsProvider);
    final relatedAsync = ref.watch(relatedItemsProvider(_relatedQuery));
    final cursorVisible = _controlsVisible || _anyOverlay;
    // Push quality changes into the running session as soon as the
    // user picks a new tier in the settings panel. mpv applies the
    // new `hls-bitrate` value on the next segment fetch, so this is
    // smooth for HLS and a no-op for plain TS/MP4 - exactly the
    // behaviour the UI implies.
    ref.listen<AsyncValue<QualityCap>>(qualityProvider, (prev, next) {
      final cap = next.value;
      if (cap == null) return;
      if (prev?.value == cap) return;
      unawaited(_session.applyQualityCap(cap.mpvValue));
    });
    // When switching to "Fill Screen" mode, trigger the detector and write
    // the computed scale to dynamicFillScaleProvider. If returning to other
    // modes, clear the override so detection runs again on the next "fill"
    // pick (the content / channel may have changed).
    ref.listen<VideoZoomMode>(videoZoomProvider, (prev, next) {
      if (prev == next) return;
      if (next == VideoZoomMode.fill) {
        unawaited(_runFillAutoDetect());
      } else {
        ref.read(dynamicFillResultProvider.notifier).clear();
      }
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackIntent();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          child: MouseRegion(
            cursor: cursorVisible ? MouseCursor.defer : SystemMouseCursors.none,
            onHover: (_) => _showControls(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_showUpNext) return;
                if (_showInfo || _showSettings) {
                  setState(() {
                    _showInfo = false;
                    _showSettings = false;
                  });
                  _showControls();
                  return;
                }
                // Mobile (iOS/Android): a tap toggles the controls
                // (issue #2/2). Tapping while visible hides instantly, shows
                // while hidden. We don't toggle play/pause; the user uses the
                // overlay button so an accidental tap doesn't stop playback.
                if (!_desktop) {
                  if (_controlsVisible) {
                    _hideTimer?.cancel();
                    setState(() => _controlsVisible = false);
                  } else {
                    _showControls();
                  }
                  return;
                }
                // Desktop: a single click both shows the controls and
                // toggles play/pause.
                _showControls();
                if (!_args.isLive && _vodStatus != _VodStatus.ok) return;
                if (_session.player.state.duration <= Duration.zero) return;
                final playing = _session.player.state.playing;
                if (playing) {
                  _session.pauseByUser();
                } else {
                  _session.playByUser();
                }
              },
              // We don't wire onDoubleTap on mobile: waiting for a
              // double-tap delays the single-tap by ~300ms, breaking the
              // "instant" control toggle. On mobile rotation is a button.
              onDoubleTap: _desktop ? _toggleFullscreen : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Zoom is driven at the Flutter compositor level via
                  // Transform.scale; multiplier the user picks (1.35 for
                  // Sinema, etc.) lands regardless of the underlying mpv
                  // backend. ClipRect crops the overflow.
                  //
                  // Built-in subtitle is rendered invisible so it does
                  // not scale with the picture (the actual subtitle
                  // layer below sits outside the Transform and stays
                  // pinned to the player viewport).
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final viewport = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return ClipRect(
                        child: Transform.scale(
                          scale: _resolveZoomScale(viewport),
                          child: Video(
                            controller: _session.controller,
                            controls: NoVideoControls,
                            fit: BoxFit.contain,
                            subtitleViewConfiguration:
                                const SubtitleViewConfiguration(
                                  style: TextStyle(
                                    color: Colors.transparent,
                                    fontSize: 0,
                                    height: 0,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Subtitle layer pinned to the viewport, not the
                  // zoomed video. media_kit exposes the active subtitle
                  // lines as `player.stream.subtitle`; rendering them
                  // here keeps the text legible and on-screen even
                  // when the Sinema zoom would push the built-in
                  // renderer outside the visible area.
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 36,
                    child: IgnorePointer(
                      child: StreamBuilder<List<String>>(
                        stream: _session.player.stream.subtitle,
                        initialData: _session.player.state.subtitle,
                        builder: (context, snap) {
                          final lines = (snap.data ?? const <String>[])
                              .where((l) => l.trim().isNotEmpty)
                              .toList();
                          if (lines.isEmpty) return const SizedBox.shrink();
                          return Text(
                            lines.join('\n'),
                            textAlign: TextAlign.center,
                            style: subtitleSettings.toTextStyle(),
                          );
                        },
                      ),
                    ),
                  ),
                  ControlsOverlay(
                    player: _session.player,
                    thumbnails: _session.thumbnails,
                    visible:
                        _controlsVisible && !_showUpNext && !_downloadActive,
                    isLive: _args.isLive,
                    isFullscreen: _isFullscreen,
                    title: _args.item.displayName,
                    onBack: _onBack,
                    onToggleFullscreen: _toggleFullscreen,
                    seriesQueue: _args.seriesQueue,
                    onPrevEpisode: _args.seriesQueue?.hasPrevious == true
                        ? _playPrevEpisode
                        : null,
                    onNextEpisode: _args.seriesQueue?.hasNext == true
                        ? _playNextEpisode
                        : null,
                    onShowEpisodes: _args.seriesQueue != null
                        ? _showEpisodePicker
                        : null,
                    onToggleInfo: _toggleInfo,
                    onToggleSettings: _canShowSettings ? _toggleSettings : null,
                    onScreenshot: _args.isLive ? null : _captureScreenshot,
                    onDownload: _args.isLive ? null : _toggleDownload,
                    downloadInProgress: _downloadActive,
                    downloadFraction: _downloadToast?.fraction,
                    onGoLive: _args.isLive ? _session.goLive : null,
                    favItem: _args.item,
                    infoOpen: _showInfo,
                    settingsOpen: _showSettings,
                    onSetPlaying: (play) =>
                        play ? _session.playByUser() : _session.pauseByUser(),
                    onUserSeek: _session.seekByUser,
                    onScrubbing: (active) {
                      // DON'T CHANGE visibility when a drag starts. The bar
                      // was already visible (hittable) so the finger could
                      // land; flipping _controlsVisible with setState here
                      // rebuilt AnimatedOpacity + IgnorePointer mid-drag and
                      // destroyed the active drag recognizer (the first seek
                      // stalled halfway). Only stop/restart the auto-hide timer.
                      _scrubbing = active;
                      if (active) {
                        _hideTimer?.cancel();
                      } else {
                        _scheduleHide();
                      }
                    },
                  ),
                  // If the user closed the compact overlay
                  // (`_upNextAutoTriggered`) suppress the pill too -
                  // the dismiss intent covers all up-next prompts.
                  if (_shouldShowNextEpisodePill &&
                      !_showUpNext &&
                      !_upNextAutoTriggered)
                    Positioned(
                      right: 28,
                      bottom: 130,
                      child: NextEpisodePill(
                        queue: _args.seriesQueue!,
                        onTap: _playNextEpisode,
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 30),
                    curve: Curves.easeOutCubic,
                    top: 0,
                    bottom: 0,
                    right: _showInfo ? 0 : -400,
                    child: InfoPanel(
                      playingItem: _args.item,
                      seriesQueue: _args.seriesQueue,
                      onClose: _toggleInfo,
                    ),
                  ),
                  // Settings panel: a full-height drawer from the RIGHT. When
                  // open it rests against the right edge at full height; when
                  // closed it slides right (-width). Scrollable content in the panel.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    top: 0,
                    bottom: 0,
                    right: _showSettings ? 0 : -420,
                    child: PlayerSettingsPanel(
                      player: _session.player,
                      onClose: _toggleSettings,
                    ),
                  ),
                  if (_args.isLive && _liveStatus != _LiveStatus.ok)
                    _LiveStatusOverlay(status: _liveStatus, onBack: _onBack),
                  if (!_args.isLive && _vodStatus != _VodStatus.ok) ...[
                    // Initial open: subtle centered spinner over the
                    // (still black) video texture. No big blur card
                    // because we're not in recovery yet - just a
                    // "we're working on it" affordance for the 10-15s
                    // some IPTV servers need to ship the first frame.
                    if (_vodAttempt == 0 && _vodStatus == _VodStatus.opening)
                      const _VodInitialLoader()
                    else
                      _VodStatusOverlay(
                        status: _vodStatus,
                        attempt: _vodAttempt,
                        maxAttempts: _maxVodAttemptsForPlatform,
                        onBack: _onBack,
                        onRetry: _retryVodFromOverlay,
                      ),
                  ],
                  if (_showUpNext)
                    UpNextOverlay(
                      seriesQueue: _args.seriesQueue,
                      relatedItems: relatedAsync.value ?? const [],
                      autoplayActive: _upNextAutoplay,
                      endedItem: _args.item,
                      onPlayNextEpisode: _playNextEpisode,
                      onPlayItem: _navigateToItem,
                      onReplay: _replay,
                      onClose: () {
                        // The close button only removes the overlay; it
                        // doesn't leave the player. Don't force the user if
                        // they want to watch the last scene / credits.
                        setState(() {
                          _showUpNext = false;
                          _upNextAutoTriggered = true;
                          _upNextAutoplay = false;
                        });
                      },
                    ),
                  if (_zoomHudLabel != null)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _zoomHudLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 20,
                    top: 64,
                    child: ScreenshotToast(
                      data: _screenshotToast,
                      onDismiss: _dismissScreenshotToast,
                    ),
                  ),
                  Positioned(
                    right: 20,
                    // If there's a screenshot toast, sit below it; otherwise
                    // take its position - so the two notifications don't overlap.
                    top: _screenshotToast != null ? 160 : 64,
                    // We hide the toast while downloading; the full-screen
                    // DownloadingOverlay shows the same info large.
                    child: DownloadToast(
                      data: _downloadToast?.state == DownloadToastState.progress
                          ? null
                          : _downloadToast,
                      onDismiss: _dismissDownloadToast,
                      onCancel: _toggleDownload,
                    ),
                  ),
                  if (_downloadActive)
                    DownloadingOverlay(
                      item: _args.item,
                      toast: _downloadToast,
                      onCancel: _toggleDownload,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// VOD recovery state. Mirrors [_LiveStatus] but is driven by an
/// open-watchdog rather than mpv's `completed` stream because the
/// VOD failure mode the user keeps hitting is "open succeeds but
/// playback never starts" - usually a corrupt mpv disk-cache entry
/// for that one URL.
enum _VodStatus {
  /// Healthy playback (or the user explicitly paused).
  ok,

  /// The initial open is in flight, or a retry is. The overlay shows
  /// a spinner + attempt counter. Auto-cleared the instant
  /// `playing=true` arrives on the stream.
  opening,

  /// Three retries exhausted. The overlay surfaces a back button and
  /// a manual "Try again" so the user can force a fresh attempt
  /// later without leaving the route.
  failed,
}

/// Discrete state machine for the live-tv recovery overlay. Kept at
/// the file level so the surrounding widgets and tests can name the
/// states explicitly instead of juggling booleans.
enum _LiveStatus {
  /// Normal playback (or user-initiated pause). No overlay.
  ok,

  /// mpv reported `completed` mid-broadcast or the buffer ran dry;
  /// we are calling [PlayerSession.goLive] in a loop hoping for a
  /// fresh socket. Overlay shows a spinner + "Reconnecting".
  reconnecting,

  /// Reconnect attempts exhausted. Overlay shows a static error
  /// card with a back button so the user can drop back to the
  /// channel list.
  ended,
}

/// Full-screen overlay used exclusively for live channels. Renders
/// either a buffering-style spinner or an "ended" error card with a
/// back button, replacing the VOD-only [UpNextOverlay] that used to
/// pop up here with replay / close buttons that don't apply to live.
class _LiveStatusOverlay extends StatelessWidget {
  final _LiveStatus status;
  final VoidCallback onBack;
  const _LiveStatusOverlay({required this.status, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: status == _LiveStatus.reconnecting
                ? const _LiveReconnectingCard()
                : _LiveEndedCard(onBack: onBack),
          ),
        ),
      ),
    );
  }
}

class _LiveReconnectingCard extends StatelessWidget {
  const _LiveReconnectingCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3.5,
          ),
        ),
        SizedBox(height: 18),
        Text(
          'Yeniden bağlanılıyor…',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Yayın akışı kısa süreliğine kesildi.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _LiveEndedCard extends ConsumerWidget {
  final VoidCallback onBack;
  const _LiveEndedCard({required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.signal_wifi_off_rounded,
              color: Colors.redAccent,
              size: 44,
            ),
            const SizedBox(height: 14),
            Text(
              ref.tr('player.liveEndedTitle'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ref.tr('player.liveEndedMsg'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(ref.tr('player.backToChannelList')),
            ),
          ],
        ),
      ),
    );
  }
}

/// VOD-only failure overlay. While [_VodStatus.opening] it just shows
/// the same blurred spinner the live overlay does (the user already
/// recognises that as "the player is doing something, hang on"); on
/// [_VodStatus.failed] it switches to a card with manual retry +
/// back, so the user does not have to leave the page to try again.
class _VodStatusOverlay extends StatelessWidget {
  final _VodStatus status;
  final int attempt;
  final int maxAttempts;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  const _VodStatusOverlay({
    required this.status,
    required this.attempt,
    required this.maxAttempts,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: status == _VodStatus.opening
                ? _VodOpeningCard(attempt: attempt, max: maxAttempts)
                : _VodFailedCard(onBack: onBack, onRetry: onRetry),
          ),
        ),
      ),
    );
  }
}

/// Light-touch "we're loading" indicator used during the very first
/// open of a VOD before the watchdog escalates. Just a centered
/// spinner over a faint dark wash - no blur, no card - so it reads
/// as "wait a moment" rather than "something is wrong". As soon as
/// mpv reports a duration the parent rebuilds without this widget,
/// uncovering the actual video frames.
class _VodInitialLoader extends StatelessWidget {
  const _VodInitialLoader();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Color(0x33000000),
          child: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 3.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VodOpeningCard extends StatelessWidget {
  final int attempt;
  final int max;
  const _VodOpeningCard({required this.attempt, required this.max});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3.5,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Açılıyor…',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (attempt > 1)
          Text(
            'Yeniden deneniyor ($attempt/$max)',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          )
        else
          const Text(
            'Stream başlatılıyor.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
      ],
    );
  }
}

class _VodFailedCard extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback onRetry;
  const _VodFailedCard({required this.onBack, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 44,
            ),
            const SizedBox(height: 14),
            Text(
              ref.tr('player.vodFailedTitle'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ref.tr('player.vodFailedMsg'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    ref.tr('common.back'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(ref.tr('common.retry')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
