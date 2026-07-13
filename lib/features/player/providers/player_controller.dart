import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/platform_info.dart';
import '../../../core/shutdown/shutdown_coordinator.dart';
import '../data/download_service.dart';
import '../data/screenshot_service.dart';
import '../data/thumbnail_service.dart';

class PlayerSession {
  final Player player;
  final VideoController controller;
  final Player _thumbPlayer;
  final ThumbnailService thumbnails;
  final ScreenshotService screenshots;
  final DownloadService downloads;

  /// Last URL passed to `open`, kept so `goLive` can re-open the same
  /// stream and snap mpv back to the broadcast edge.
  String? _lastUrl;

  /// Latest quality cap pushed in from the UI. `null` means "auto" -
  /// don't touch the property. Cached on the session so the per-open
  /// re-application has a value without a Riverpod round-trip.
  String? _pendingQualityCap;

  /// Tracks the user's most recent play/pause intent so the auto-resume
  /// listener can tell mpv-initiated pauses apart from "the user actually
  /// wants this paused". Flipped by [pauseByUser] / [playByUser].
  bool _userPaused = false;

  StreamSubscription<bool>? _playingSub;
  Timer? _resumeRetryTimer;

  /// Cached future for the in-flight (or completed) dispose. A second
  /// call rides along on the same future instead of kicking off a parallel
  /// teardown, which matters when route-pop fires `disposeAsync` and the
  /// user then quits the app before mpv has finished closing.
  Future<void>? _disposeFuture;

  /// Captured so [ShutdownCoordinator] can hand back the exact closure
  /// for unregistration on a clean dispose.
  late final Future<void> Function() _shutdownTask = disposeAsync;

  PlayerSession._(
    this.player,
    this.controller,
    this._thumbPlayer,
    this.thumbnails,
    this.screenshots,
    this.downloads,
  );

  /// Memoized: cache config is applied once per Player instance, just
  /// before the first `open` call. Setting it again is cheap but pointless.
  bool _cacheConfigured = false;

  factory PlayerSession.create() {
    // media_kit produces no audio on the iOS Simulator. The Mpv.xcframework
    // binary in the media_kit_libs_ios_video 1.1.4 package is compiled for
    // the iOS simulator slice with `-Daudiounit=disabled
    // -Dcoreaudio=disabled -Dopensles=disabled`; that is, libmpv has no
    // audio output backend at all for the iOS sim target. The result shows
    // up in the mpv error stream as "Could not open/initialize audio device
    // -> no sound", and the AVAudioSession settings in AppDelegate cannot
    // fix this (there is simply no audio backend compiled in to attach).
    //
    // On a real iPad/iPhone (arm64) build `audiounit=enabled`, so audio
    // plays fine on device. When testing, target a physical iPad on the Mac
    // rather than the iOS simulator.
    if (!kReleaseMode && Platform.isIOS) {
      // ignore: avoid_print
      print(
        '[${AppConfig.I.appName}] iOS audio: simulator build of media_kit '
        'ships without audio backends; if you are running on a simulator, '
        'audio will be silent. Test playback audio on a physical device.',
      );
    }
    // Modest 64 MB RAM buffer - the heavy lifting goes onto disk via
    // mpv's `cache-on-disk=yes` (see `_configureCache`). That keeps app
    // memory low while giving us several minutes of back-seekable
    // playback and, more importantly, lets an audio-track swap reuse
    // the existing bytes instead of opening a second HTTP request to a
    // server that only allows one.
    final p = Player(
      configuration: const PlayerConfiguration(bufferSize: 64 * 1024 * 1024),
    );
    // NOTE: On the Android emulator (AVD) media_kit video cannot be rendered
    // correctly by any means - the default vo=gpu cannot set up an EGL
    // context (EGL_BAD_ATTRIBUTE) => black; vo=mediacodec_embed was tried but
    // corrupts the colors (blue/purple tint) and stalls playback on some VOD
    // codecs. A known media_kit emulator limitation (media-kit/media-kit#1343).
    // Since vo=gpu works fine on a REAL device we use the default everywhere;
    // no emulator-specific hack (zero risk of color/stall issues).
    final vc = VideoController(p);
    // Thumbnail companion stays at the media_kit default - it just
    // seeks to snapshot frames, no need for buffering past mpv's own.
    final tp = Player();
    final ts = ThumbnailService(tp);
    final sc = ScreenshotService(p);
    final ds = DownloadService();
    final session = PlayerSession._(p, vc, tp, ts, sc, ds);
    // Hand the mpv teardown to the app-level shutdown coordinator. If the
    // user quits the app while a video is still open, `didRequestAppExit`
    // awaits this before letting AppKit terminate; otherwise mpv's core
    // thread races AppKit's window deallocation and SEGFAULTs on a freed
    // wakeup callback.
    ShutdownCoordinator.instance.register(session._shutdownTask);
    return session;
  }

  /// Resolves (and creates on first call) mpv's per-app disk cache
  /// directory. Kept as a method instead of a one-shot field because
  /// [reopenWithFreshCache] needs to walk it to wipe corrupt entries.
  Future<Directory> _cacheDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(support.path, AppConfig.I.storageSlug, 'mpv_cache'),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _configureCache() async {
    if (_cacheConfigured) return;
    _cacheConfigured = true;
    try {
      final dir = await _cacheDir();
      // `dynamic` keeps us off the media_kit internal `NativePlayer`
      // type - the property channel exists on every native platform
      // backend, and failing to set a property is non-fatal anyway.
      final pp = player.platform as dynamic;
      // mpv property observers.
      //
      // CRITICAL: on some HLS / IPTV streams mpv puts itself into
      // `pause=yes` after a seek (not because of cache -
      // paused-for-cache=no, cache 100% full, even though there is
      // 30s+ of data in the buffer). media_kit's
      // `isPlayingStateChangeAllowed` flag does not deliver this mpv
      // event to our `playing` stream, so our auto-resume listeners
      // never fire at all and the play button in the UI stays
      // visible forever.
      //
      // Solution: observe the pause property directly from mpv and
      // bypass media_kit's state machine. The moment we see pause=yes
      // (if the user hasn't paused and it isn't EOF) push it back to
      // mpv directly with setProperty('pause', 'no').
      Future<void> setMpvProp(String name, String value) async {
        try {
          // ignore: avoid_dynamic_calls
          await pp.setProperty(name, value);
        } catch (e) {
          // ignore: avoid_print
          print('[${AppConfig.I.appName}] setProperty $name=$value failed: $e');
        }
      }

      Future<void> observe(
        String name,
        Future<void> Function(String value) handler,
      ) async {
        try {
          // ignore: avoid_dynamic_calls
          await pp.observeProperty(name, handler);
        } catch (e) {
          // ignore: avoid_print
          print('[${AppConfig.I.appName}] observeProperty $name failed: $e');
        }
      }

      await observe('pause', (value) async {
        // ignore: avoid_print
        print(
          '[${AppConfig.I.appName}] mpv[pause]=$value (userPaused=$_userPaused, fileReady=$_fileReady, nearEof=$_nearEof)',
        );
        if (value != 'yes') return;
        if (_userPaused) {
          // ignore: avoid_print
          print(
            '[${AppConfig.I.appName}] mpv pause=yes but userPaused=true - leaving paused',
          );
          return;
        }
        if (!_fileReady) return;
        if (_nearEof) return;
        // ignore: avoid_print
        print(
          '[${AppConfig.I.appName}] mpv self-paused (cache=full, !userPaused, !EOF) - forcing pause=no via direct property',
        );
        await setMpvProp('pause', 'no');
      });
      await observe('core-idle', (value) async {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] mpv[core-idle]=$value');
      });
      await observe('paused-for-cache', (value) async {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] mpv[paused-for-cache]=$value');
      });
      await observe('cache-buffering-state', (value) async {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] mpv[cache-buffering-state]=$value');
      });
      await observe('demuxer-cache-time', (value) async {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] mpv[demuxer-cache-time]=$value');
      });
      await observe('eof-reached', (value) async {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] mpv[eof-reached]=$value');
      });
      // On live IPTV the HTTP socket drops briefly quite often (panel
      // jitter, CDN edge switch, etc.). By default libavformat returns
      // EOF/error on this, mpv throws `completed`/`error` and the UI would
      // show a "stream interrupted, reconnecting" banner + force a reopen -
      // very frequent and jarring. Turning on ffmpeg's own reconnect makes
      // these transient drops resolve SILENTLY by reconnecting inside
      // libavformat; they never surface to mpv as EOF/error. (stream-lavf-o
      // = HTTP protocol options.)
      // ignore: avoid_dynamic_calls
      await pp.setProperty(
        'stream-lavf-o',
        'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,'
            'reconnect_on_network_error=1,reconnect_delay_max=5',
      );
      // Don't hang forever on an unresponsive socket; drop after 30s so the
      // reconnect logic kicks in.
      // ignore: avoid_dynamic_calls
      await pp.setProperty('network-timeout', '30');
      // ignore: avoid_dynamic_calls
      await pp.setProperty('cache', 'yes');
      // On Android TV boxes internal storage can be slow and small. On these
      // devices mpv's disk cache writer can lock the frame stream while
      // playing VOD, creating a "froze, then closed" feeling. On TV stay
      // with the memory cache; keep the old behavior on desktop and mobile.
      if (Platform.isAndroid && PlatformInfo.isTv) {
        // ignore: avoid_dynamic_calls
        await pp.setProperty('cache-on-disk', 'no');
      } else {
        // ignore: avoid_dynamic_calls
        await pp.setProperty('cache-on-disk', 'yes');
        // ignore: avoid_dynamic_calls
        await pp.setProperty('cache-dir', dir.path);
      }
      // Cache window. On a multiplexed (ts/mkv) IPTV stream the demuxer
      // cache holds ALL tracks (audio languages + subtitles). Keeping the
      // window wide means that when the user switches audio/subtitle the new
      // track is decoded from cache WITHOUT GOING TO THE NETWORK; otherwise
      // the video FROZE for a few seconds while mpv re-read the data for the
      // new track. Because cache-pause=no the wide cache does not delay seek
      // start (no pause on underrun), it only uses RAM - within demuxer-max-bytes.
      // ignore: avoid_dynamic_calls
      await pp.setProperty('cache-secs', '30');
      // ignore: avoid_dynamic_calls
      await pp.setProperty('demuxer-max-bytes', '${128 * 1024 * 1024}');
      // ignore: avoid_dynamic_calls
      await pp.setProperty('demuxer-max-back-bytes', '${64 * 1024 * 1024}');
      // Read-ahead window. Keep it generous so that on a track change the
      // new audio/subtitle track is ready in cache around the current
      // position; at 1s the buffer ran short on a track switch and caused a
      // freeze. Thanks to cache-pause=no it does not delay start after a seek.
      // ignore: avoid_dynamic_calls
      await pp.setProperty('demuxer-readahead-secs', '8');
      // initial-audio-sync=yes (mpv default): aligns audio to the video
      // timestamp at the start of the file AND AFTER EVERY SEEK (adds silence
      // at the start or trims the first samples). With `no`, mpv started
      // audio and video from different timestamps and tried to correct sync
      // "gradually"; this led to the "audio comes from random places and
      // won't lock" (audio-video desync) problem on forward/back seeks.
      // Correct sync matters far more than a few hundred ms of startup gain.
      // ignore: avoid_dynamic_calls
      await pp.setProperty('initial-audio-sync', 'yes');
      // Some IPTV servers return HTTP responses without the proper
      // `Accept-Ranges`/`Content-Length` headers, so mpv refuses to
      // seek mid-file or - worse - declares the stream "ended" the
      // moment the user drags the scrubber. Force-seekable tells mpv
      // to attempt the seek anyway, and keep-open prevents the player
      // from tearing the file down if the demuxer briefly reports EOF
      // during a seek (we'd rather pause on the last frame than exit
      // back to the catalogue).
      // ignore: avoid_dynamic_calls
      await pp.setProperty('force-seekable', 'yes');
      // ignore: avoid_dynamic_calls
      await pp.setProperty('keep-open', 'always');
      // hr-seek=yes: land exactly on the second where the user lifts their
      // finger. Because hr-seek=no snaps to the nearest keyframe (5-10s
      // tolerance), the seek jumped past where you released; the "cuts off
      // halfway / goes somewhere else" feeling came from here. Accurate seek
      // adds a few hundred ms of delay, but position accuracy is more critical for UX.
      // ignore: avoid_dynamic_calls
      await pp.setProperty('hr-seek', 'yes');
      // NOTE: `cache-pause*` (rebuffer behavior on underrun) must differ for
      // live and VOD; so it is set NOT here but per-mode inside
      // [_applyStreamModePolicy] on every open.
    } catch (e, st) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] mpv cache config failed: $e\n$st');
    }
  }

  /// Live and VOD must behave differently on underrun (cache emptying), so
  /// it is applied per-mode on every [open]:
  ///
  /// - **Live**: `cache-pause=no` - never let mpv enter `paused-for-cache`.
  ///   The cache is always low; if it paused it would slide back from the
  ///   edge and, after a seek, stay silently paused and swallow `play()` calls.
  /// - **VOD**: `cache-pause=yes` (mpv default) - on a network underrun
  ///   rebuffer cleanly (brief buffering) and then continue. Otherwise
  ///   (cache-pause=no) mpv keeps the audio clock running and when video
  ///   frames run out the PICTURE FROZE but the AUDIO KEPT GOING (A/V desync).
  ///   Since VOD has no latency concern we also widen the read-ahead cushion
  ///   to lower the frequency of underruns.
  Future<void> _applyStreamModePolicy(bool isLive) async {
    if (!_cacheConfigured) return;
    final pp = player.platform as dynamic;
    Future<void> set(String name, String value) async {
      try {
        // ignore: avoid_dynamic_calls
        await pp.setProperty(name, value);
      } catch (e) {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] setProperty $name=$value failed: $e');
      }
    }

    if (isLive) {
      await set('cache-pause', 'no');
      await set('cache-pause-initial', 'no');
      await set('cache-pause-wait', '0');
      // On live keep the 8s read-ahead from _configureCache (stay near the edge).
      await set('demuxer-readahead-secs', '8');
    } else {
      await set('cache-pause', 'yes');
      await set('cache-pause-initial', 'no');
      await set('cache-pause-wait', '1');
      // Wider cushion → underruns (and therefore buffering/freezes) on
      // network jitter become much rarer.
      await set('demuxer-readahead-secs', '30');
    }
  }

  /// Push a fresh `hls-bitrate` cap into mpv. Accepts the string form
  /// from `QualityCap.mpvValue` (`null` / `'max'` / a bps number).
  /// Cleared by passing `null`. Safe to call before [_configureCache]
  /// has run - the value is cached and re-sent on the next [open].
  ///
  /// Non-HLS streams ignore the property silently, so the picker can
  /// stay visible everywhere without breaking direct-TS / MP4 playback.
  Future<void> applyQualityCap(String? mpvValue) async {
    _pendingQualityCap = mpvValue;
    if (!_cacheConfigured) return;
    try {
      final pp = player.platform as dynamic;
      // mpv treats an empty string as "no override" - equivalent to
      // unsetting the property. The wrapper accepts that without
      // throwing on every backend we ship on.
      // ignore: avoid_dynamic_calls
      await pp.setProperty('hls-bitrate', mpvValue ?? '');
      // ignore: avoid_print
      print(
        '[${AppConfig.I.appName}] hls-bitrate set to '
        '"${mpvValue ?? '(auto)'}"',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] applyQualityCap failed: $e');
    }
  }

  /// Reopen [url] after wiping mpv's disk cache. Used by the VOD
  /// recovery flow when the same episode refuses to start while a
  /// different player can play it just fine - the smoking gun is a
  /// corrupt cache entry that mpv keeps re-reading instead of going
  /// back to the network. Stopping the player first releases the
  /// file handles, then we nuke the whole `mpv_cache` directory (it
  /// is purely an optimisation, no user data) and reopen.
  ///
  /// [startAt] is preserved so a re-open mid-watch picks up where the
  /// user was rather than rewinding to zero.
  Future<void> reopenWithFreshCache(
    String url, {
    Duration startAt = Duration.zero,
    bool isLive = false,
  }) async {
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] reopenWithFreshCache start url=$url '
      'startAt=${startAt.inSeconds}s',
    );
    try {
      await player.stop();
    } catch (_) {}
    // Brief pause so mpv finishes releasing the cache file handle on
    // Windows / Linux. macOS would let us delete a live file, but the
    // delay is cheap and keeps the behaviour consistent.
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final dir = await _cacheDir();
      // Walk + delete contents instead of `dir.delete(recursive: true)`
      // so concurrent file handles (rare race on quick re-opens) don't
      // throw a "directory not empty" error that aborts the recovery.
      await for (final entry in dir.list(followLinks: false)) {
        try {
          await entry.delete(recursive: true);
        } catch (_) {
          /* skip individual failures, keep going */
        }
      }
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] reopenWithFreshCache wiped ${dir.path}');
    } catch (e) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] reopenWithFreshCache wipe failed: $e');
    }
    // open() pushes the quality cap and ensures cache is re-configured
    // on the next start; nothing more to do here.
    await open(url, startAt: startAt, isLive: isLive);
  }

  /// Jump to the live edge by re-opening the manifest. `player.seek` to a
  /// computed duration is unreliable on live HLS - mpv silently ignores
  /// the request on many servers because the target keeps moving. Closing
  /// and reopening the source forces the playlist to be re-fetched, which
  /// always lands on the newest segment.
  Future<void> goLive() async {
    final url = _lastUrl;
    if (url == null) return;
    // Close mpv's current Media and release the HTTP sockets and temp file
    // handles. Calling open() without a stop first lets FDs pile up on
    // failed reconnect attempts; after a few channels the process's file
    // descriptor limit filled up and no channel could be opened anymore
    // with "Too many open files".
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.open(Media(url));
    } catch (_) {
      /* leave the current position alone if reopening fails */
    }
  }

  Future<void> open(
    String url, {
    Duration startAt = Duration.zero,
    bool isLive = false,
  }) async {
    _lastUrl = url;
    // Opening new media is an implicit "play" intent. The user-pause flag
    // left over from the previous source (e.g. end-of-episode pause) is
    // reset, otherwise the auto-resume listener would not call play()
    // during a stall on the new episode.
    _userPaused = false;
    // Apply mpv cache config the first time we open something - disk
    // cache needs the path on hand, which is async, so we cannot do it
    // in the synchronous factory above.
    await _configureCache();
    // Apply the underrun/rebuffer behavior per live/VOD (BUG: on VOD the
    // picture froze while audio kept going - due to cache-pause=no).
    await _applyStreamModePolicy(isLive);
    // Re-apply the user's quality cap. mpv resets per-stream
    // properties on `Media.open`, so without this every fresh open
    // would fall back to "auto" even if the user picked a lower
    // tier. Applying right before open avoids a transient flash of
    // the wrong variant.
    await applyQualityCap(_pendingQualityCap);
    // Pass `start` to mpv so the demuxer seeks before playback begins,
    // avoids the race where a manual seek lands while the stream is not
    // yet ready and silently snaps back to 0.
    await player.open(
      Media(url, start: startAt > Duration.zero ? startAt : null),
    );
    if (startAt > Duration.zero) {
      // Backup seek: some HLS/m3u8 sources ignore the demuxer hint, so wait
      // until the player reports a valid duration and re-issue the seek.
      unawaited(_ensureSeekTo(startAt));
    }
    // Thumbnail companion disabled: most IPTV panels enforce a per-user
    // concurrent-connection limit. Opening a second mpv instance causes
    // HTTP 509 (Bandwidth Limit Exceeded) errors - on every seek the panel
    // says "not enough connections", the main player can't fill its buffer
    // and the video stops. Scrubber preview thumbnails are cute but not
    // worth the 509 loss.
    //
    // If a panel-specific "is the thumbnail player safe?" test is added
    // later, we can enable it conditionally here.
    //
    // if (!isLive) {
    //   unawaited(thumbnails.openSource(url));
    // }
  }

  Future<void> _ensureSeekTo(Duration target) async {
    try {
      await player.stream.duration
          .firstWhere((d) => d.inMilliseconds > 0)
          .timeout(const Duration(seconds: 8));
      // Only re-seek if mpv started near zero - the `start` hint may have
      // worked already, in which case position is already ahead.
      if (player.state.position < target - const Duration(seconds: 2)) {
        await player.seek(target);
      }
    } catch (_) {
      /* duration never arrived - give up silently */
    }
  }

  /// Wraps `player.pause()` so the auto-resume listener knows this was
  /// the user's choice and should not be undone. Use from UI handlers
  /// (play/pause button, double-click, space key). Internal calls during
  /// recovery / download teardown should keep using `player.pause()`
  /// directly so the user-intent flag is not flipped.
  Future<void> pauseByUser() async {
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] pauseByUser called - _userPaused becoming TRUE',
    );
    _userPaused = true;
    // Intentional user pause: cancel any auto-resume retry right away.
    if (_resumeRetryTimer != null) {
      _resumeRetryTimer!.cancel();
      _resumeRetryTimer = null;
    }
    try {
      await player.pause();
    } catch (_) {}
  }

  /// Counterpart of [pauseByUser]: marks the user as wanting playback
  /// then calls `player.play()`. Also clears the flag so auto-resume can
  /// take over again if mpv stalls later.
  Future<void> playByUser() async {
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] playByUser called - _userPaused becoming FALSE',
    );
    _userPaused = false;
    try {
      await player.play();
    } catch (_) {}
    // If mpv still stays paused even though the user asked to start
    // manually (which is exactly the user scenario), force-start the retry timer.
    if (!player.state.playing) {
      _maybeStartResumeRetry(reason: 'playByUser but state still paused');
    }
  }

  /// User-initiated seek wrapper. Scrubber / keyboard seeks use this
  /// instead of calling player.seek() directly.
  ///
  /// It does two things:
  /// 1. `_userPaused = false` → a seek is an "I want to keep watching"
  ///    intent, so the old user-pause flag is invalidated.
  /// 2. If mpv is still paused after the seek, proactively unpause it.
  ///    Important edge case: if mpv self-paused before the seek, the seek
  ///    does not produce a new pause event → the observer doesn't fire →
  ///    auto-unpause never fires. So after the seek we actively check the
  ///    state and push pause=no directly to mpv.
  Future<void> seekByUser(Duration target) async {
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] seekByUser(${target.inSeconds}s) - _userPaused becoming FALSE',
    );
    _userPaused = false;
    _lastSeekAt = DateTime.now();
    try {
      await player.seek(target);
    } catch (_) {}
    // If mpv is still paused after the seek, kick it. Both the media_kit
    // API (state stays in sync) and a direct mpv command (state machine
    // bypass).
    if (!player.state.playing) {
      try {
        await player.play();
      } catch (_) {}
      try {
        // ignore: avoid_dynamic_calls
        await (player.platform as dynamic).setProperty('pause', 'no');
      } catch (_) {}
    }
  }

  /// Time of the most recent `seekByUser` call. The completion handler
  /// reads this: if the user seeked recently and mpv reported
  /// eof-reached=yes, this is most likely a user seek overshoot (reached
  /// the end of the film unintentionally) - not a genuine "playback ended".
  DateTime? _lastSeekAt;
  DateTime? get lastSeekAt => _lastSeekAt;

  /// Auto-resume: the simple pattern the user asked for. Starts watching
  /// for the "mpv finished buffering but didn't actually resume" case.
  ///
  /// The moment playing=false, press play() once every second.
  /// The moment playing=true, cancel the timer. If the user paused it
  /// themselves or it is at EOF, don't start at all.
  ///
  /// If mpv rejects the first play() call (buffer too low, etc.) the
  /// retry timer tries again after 1s. Once the buffer fills it is
  /// accepted, mpv emits playing=true and the timer stops. No manual
  /// tap needed.
  void enableAutoResume() {
    if (_playingSub != null) return;
    _playingSub = player.stream.playing.listen(_handlePlayingChange);
    // On the first attach mpv may already be paused (initial state). In
    // that case no event arrives, so check it manually.
    if (!player.state.playing) {
      _handlePlayingChange(false);
    }
  }

  void _handlePlayingChange(bool playing) {
    if (playing) {
      // mpv started playing: cancel the timer. For the user the pause
      // button is visible ⏸ → the retry should end.
      if (_resumeRetryTimer != null) {
        // ignore: avoid_print
        print(
          '[${AppConfig.I.appName}] auto-resume: mpv resumed, stopping retry timer',
        );
        _resumeRetryTimer!.cancel();
        _resumeRetryTimer = null;
      }
      return;
    }
    // playing=false: start the retry if needed.
    _maybeStartResumeRetry(reason: 'playing=false event');
  }

  void _maybeStartResumeRetry({required String reason}) {
    if (_userPaused) return;
    if (!_fileReady) return;
    if (_nearEof) return;
    if (_resumeRetryTimer != null) return; // already running
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] auto-resume: starting 1s retry timer ($reason)',
    );
    _resumeRetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Every tick: are the conditions still met, press play().
      if (player.state.playing) {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] auto-resume: mpv playing - stop retry');
        _resumeRetryTimer?.cancel();
        _resumeRetryTimer = null;
        return;
      }
      if (_userPaused) {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] auto-resume: user paused - stop retry');
        _resumeRetryTimer?.cancel();
        _resumeRetryTimer = null;
        return;
      }
      if (_nearEof) {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] auto-resume: near EOF - stop retry');
        _resumeRetryTimer?.cancel();
        _resumeRetryTimer = null;
        return;
      }
      if (!_fileReady) {
        // duration not available yet; wait for the next tick, don't stop
        return;
      }
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] auto-resume retry: pressing play');
      try {
        player.play();
      } catch (_) {}
    });
  }

  /// Near the end of the episode? EOF guard - if the auto-resume / stall
  /// watchers fire here they would rewind mpv to the start and create a loop.
  bool get _nearEof {
    final pos = player.state.position;
    final dur = player.state.duration;
    return dur > Duration.zero && (dur - pos).inSeconds < 3;
  }

  /// Has mpv demuxed the file and reported a duration? While `false` the
  /// stall watchers must not fire - an aggressive play() call during the
  /// initial open / seek confuses mpv, and when the user seeked on first
  /// open it resulted in "the film closed".
  bool get _fileReady => player.state.duration > Duration.zero;

  /// Cuts audio output immediately. Safe to call repeatedly; used right
  /// before navigation so users never hear the player past the back button.
  Future<void> silence() async {
    try {
      await player.pause();
    } catch (_) {}
    try {
      await player.setVolume(0);
    } catch (_) {}
    try {
      await _thumbPlayer.pause();
    } catch (_) {}
    try {
      await _thumbPlayer.setVolume(0);
    } catch (_) {}
  }

  Future<void> disposeAsync() {
    return _disposeFuture ??= _doDisposeAsync();
  }

  Future<void> _doDisposeAsync() async {
    await _playingSub?.cancel();
    _playingSub = null;
    _resumeRetryTimer?.cancel();
    _resumeRetryTimer = null;
    downloads.cancel();
    thumbnails.dispose();
    await silence();
    // Call stop() before dispose(): it gives mpv a chance to close the
    // demuxer and release the HTTP sockets, temp file handles and disk
    // cache writer without leaking. A direct dispose() call, on some
    // versions, dies while ending the core thread without releasing the
    // file handles → the next PlayerSession could not open because the FD
    // limit was full.
    try {
      await _thumbPlayer.stop();
    } catch (_) {}
    try {
      await player.stop();
    } catch (_) {}
    try {
      await _thumbPlayer.dispose();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
    ShutdownCoordinator.instance.unregister(_shutdownTask);
  }
}

class ControlsVisibility extends ValueNotifier<bool> {
  ControlsVisibility() : super(true);
  void show() => value = true;
  void hide() => value = false;
}
