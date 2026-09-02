import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../constants/server_urls.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/livekit_token_service.dart';
import '../theme/app_theme.dart';

String _generateNonce() {
  final timePart = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final random = math.Random();
  final randomPart =
      List.generate(5, (_) => random.nextInt(36).toRadixString(36)).join();
  return '$timePart$randomPart';
}

String _generateRoomName({
  required String tenantId,
  required String identity,
  required String agentId,
  required String nonce,
}) {
  final base = 'aidouble-$tenantId-$identity-$agentId';
  final truncated = base.length > 100 ? base.substring(0, 100) : base;
  return '$truncated-$nonce';
}

int _generateNowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

const Map<String, String> _jwtHeader = {'alg': 'HS256', 'typ': 'JWT'};

Map<String, dynamic> _generateClaims({
  required String apiKey,
  required String identity,
  required String room,
  required int now,
  Map<String, dynamic> metadata = const {},
}) {
  return {
    'iss': apiKey,
    'sub': identity,
    'name': identity,
    'nbf': now - 10,
    'exp': now + 60 * 60,
    'metadata': jsonEncode(metadata),
    'video': {
      'room': room,
      'roomJoin': true,
      'canPublish': true,
      'canSubscribe': true,
      'canPublishData': true,
    },
  };
}

String _base64UrlBytes(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _b64Url(String value) {
  return _base64UrlBytes(utf8.encode(value));
}

String _generateSigningInput({
  required Map<String, dynamic> header,
  required Map<String, dynamic> claims,
}) {
  return '${_b64Url(jsonEncode(header))}.${_b64Url(jsonEncode(claims))}';
}

enum _VoiceState { idle, connecting, listening, thinking, speaking, error }

class _TranscriptLine {
  final String id;
  final bool isCustomer;
  final String text;
  final bool isFinal;
  const _TranscriptLine({
    required this.id,
    required this.isCustomer,
    required this.text,
    required this.isFinal,
  });
}

class VoiceCallView extends StatefulWidget {
  final String agentName;
  final IconData agentIcon;
  final String? agentId;
  final String? conversationId;
  final String? businessId;
  final ValueChanged<String>? onConversationId;

  const VoiceCallView({
    super.key,
    required this.agentName,
    required this.agentIcon,
    this.agentId,
    this.conversationId,
    this.businessId,
    this.onConversationId,
  });

  @override
  State<VoiceCallView> createState() => _VoiceCallViewState();
}

class _VoiceCallViewState extends State<VoiceCallView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  final _scrollCtrl = ScrollController();
  final _tts = FlutterTts();
  final _callNonce = _generateNonce();
  late final String _room;

  Room? _rtcRoom;
  EventsListener<RoomEvent>? _listener;

  Timer? _durationTimer;
  _VoiceState _state = _VoiceState.idle;
  String? _errorMessage;
  bool _micMuted = false;
  bool _speakerOn = true;
  Duration _elapsed = Duration.zero;

  final _transcript = <_TranscriptLine>[];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _initTts();

    final identity = context.read<AuthRepository>().currentUser?.id ?? 'unknown';
    final apiClient = context.read<ApiClient>();
    _room = _generateRoomName(
      tenantId: ServerUrls.tenant,
      identity: identity,
      agentId: widget.agentId ?? 'unknown-agent',
      nonce: _callNonce,
    );
    final metadata = <String, dynamic>{
      'agentId': widget.agentId ?? '',
      'conversationId': widget.conversationId ?? '',
      'businessId': '',
      'tenantId': ServerUrls.tenant,
      'gosureUserId': identity,
      'gosureToken': apiClient.accessToken ?? '',
      'language': WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    };
    AppLogger.i('VoiceCallView', 'callNonce=$_callNonce');
    AppLogger.i('VoiceCallView', 'room=$_room');
    AppLogger.i('VoiceCallView',
        'call $_callNonce starting with agent "${widget.agentName}" (conversationId=${widget.conversationId}, businessId=${widget.businessId})');

    final now = _generateNowSeconds();
    final claims = _generateClaims(
      apiKey: '',
      identity: identity,
      room: _room,
      now: now,
      metadata: metadata,
    );
    final claimsForLog = {...claims, 'metadata': jsonEncode(redactJson(metadata))};
    final signingInputForLog =
        _generateSigningInput(header: _jwtHeader, claims: claimsForLog);
    AppLogger.i('VoiceCallView', 'now=$now header=$_jwtHeader');
    AppLogger.i('VoiceCallView', 'claims=${jsonEncode(claimsForLog)}');
    AppLogger.i('VoiceCallView', 'signingInput=$signingInputForLog   ....');
    AppLogger.i('VoiceCallView', 'connect() not called — diagnostic pass only');
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
  }

  Future<void> _connect({
    required ApiClient apiClient,
    required String identity,
    required Map<String, dynamic> metadata,
  }) async {
    setState(() => _state = _VoiceState.connecting);
    try {
      AppLogger.i('VoiceCallView', 'requesting token room=$_room identity=$identity');
      final token = await fetchLiveKitToken(
        apiClient,
        room: _room,
        identity: identity,
        metadata: metadata,
      );
      AppLogger.i('VoiceCallView', 'token minted length=${token.length}');

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _rtcRoom = room;
      _listener = room.createListener();
      _wireRoomEvents(_listener!, room);

      await room.connect(ServerUrls.livekitUrl, token);
      AppLogger.i('VoiceCallView',
          'room connected localParticipant=${room.localParticipant?.identity} remoteParticipants=${room.remoteParticipants.length}');

      await room.localParticipant?.setMicrophoneEnabled(true);
      Helper.setSpeakerphoneOn(_speakerOn);

      if (!mounted) return;
      setState(() => _state = _VoiceState.listening);
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e, st) {
      AppLogger.e('VoiceCallView', 'connect failed', e, st);
      if (!mounted) return;
      setState(() {
        _state = _VoiceState.error;
        _errorMessage = _describeError(e);
      });
    }
  }

  String _describeError(Object error) {
    final message = error.toString();
    if (message.contains('not connected to a token-minting backend')) {
      return "Voice mode isn't connected to a backend yet.";
    }
    if (message.toLowerCase().contains('permission')) {
      return 'Microphone access was blocked. Allow it and try again.';
    }
    return 'Could not start voice mode.';
  }

  void _wireRoomEvents(EventsListener<RoomEvent> listener, Room room) {
    listener.on<TrackSubscribedEvent>((e) {
      AppLogger.i('VoiceCallView', 'track subscribed kind=${e.track.kind}');
    });

    listener.on<LocalTrackSubscribedEvent>((e) {
      AppLogger.i('VoiceCallView', 'the agent subscribed to our track sid=${e.trackSid}');
    });

    listener.on<ParticipantConnectedEvent>((e) {
      AppLogger.i('VoiceCallView', 'participant joined ${e.participant.identity}');
    });

    listener.on<ParticipantDisconnectedEvent>((e) {
      AppLogger.i('VoiceCallView', 'participant left ${e.participant.identity}');
      if (!mounted) return;
      setState(() {
        _state = _VoiceState.error;
        _errorMessage = 'The voice agent left the call.';
      });
    });

    listener.on<TranscriptionEvent>((e) {
      final isCustomer = e.participant is LocalParticipant;
      for (final segment in e.segments) {
        _upsertTranscript(segment.id, isCustomer, segment.text, segment.isFinal);
      }
    });

    listener.on<DataReceivedEvent>((e) {
      _handleDataMessage(e.data);
    });

    listener.on<RoomDisconnectedEvent>((e) {
      AppLogger.i('VoiceCallView', 'room disconnected reason=${e.reason}');
      if (!mounted) return;
      if (_state != _VoiceState.idle) {
        setState(() {
          _state = _VoiceState.error;
          _errorMessage = 'The voice call dropped.';
        });
      }
    });
  }

  void _upsertTranscript(String id, bool isCustomer, String text, bool isFinal) {
    if (!mounted) return;
    setState(() {
      final idx = _transcript.indexWhere((t) => t.id == id);
      final line = _TranscriptLine(id: id, isCustomer: isCustomer, text: text, isFinal: isFinal);
      if (idx >= 0) {
        _transcript[idx] = line;
      } else {
        _transcript.add(line);
      }
    });
    _scrollToEnd();
  }

  void _handleDataMessage(List<int> data) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    AppLogger.i('VoiceCallView', 'data from worker: $msg');
    if (!mounted) return;
    final type = msg['type'] as String?;
    if (type == 'state') {
      final stateName = msg['state'] as String?;
      final mapped = _VoiceState.values.where((s) => s.name == stateName).firstOrNull;
      if (mapped != null) setState(() => _state = mapped);
    } else if (type == 'conversation') {
      final conversationId = msg['conversationId'] as String?;
      if (conversationId != null) widget.onConversationId?.call(conversationId);
    } else if (type == 'error') {
      setState(() {
        _state = _VoiceState.error;
        _errorMessage = (msg['text'] as String?) ?? 'The voice agent hit an error.';
      });
    }
  }

  @override
  void dispose() {
    AppLogger.i('VoiceCallView', 'call $_callNonce ended at ${_durationLabel()}');
    _pulseCtrl.dispose();
    _scrollCtrl.dispose();
    _tts.stop();
    _durationTimer?.cancel();
    _listener?.cancelAll();
    _rtcRoom?.disconnect();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent + 60,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  String _statusLabel() {
    switch (_state) {
      case _VoiceState.idle:
        return 'Idle';
      case _VoiceState.connecting:
        return 'Connecting…';
      case _VoiceState.listening:
        return _micMuted ? 'Mic muted' : 'Listening…';
      case _VoiceState.thinking:
        return '${widget.agentName} is thinking…';
      case _VoiceState.speaking:
        return '${widget.agentName} is speaking…';
      case _VoiceState.error:
        return _errorMessage ?? 'Something went wrong.';
    }
  }

  String _durationLabel() {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appPrimaryDarkColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _orbSection(),
            const SizedBox(height: 4),
            Expanded(child: _transcriptList()),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text('VOICE MODE',
              style: AppFonts.mono(
                  size: 11,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 2)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _orbSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _orb(),
          const SizedBox(height: 12),
          Text(widget.agentName,
              style: AppFonts.display(size: 17, color: Colors.white)),
          const SizedBox(height: 3),
          Text(
            _state == _VoiceState.connecting || _state == _VoiceState.error
                ? _statusLabel()
                : '${_statusLabel()} · ${_durationLabel()}',
            textAlign: TextAlign.center,
            style:
                AppFonts.body(size: 12.5, color: Colors.white.withOpacity(0.7)),
          ),
          if (_state == _VoiceState.error) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.4)),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _orb() {
    final speaking = _state == _VoiceState.speaking;
    final connecting = _state == _VoiceState.connecting;
    final error = _state == _VoiceState.error;
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!connecting && !error)
                for (final ringIndex in [0, 1, 2])
                  _ring(ringIndex, speaking: speaking),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: error ? null : AppColors.appPrimaryGradient,
                  color: error ? const Color(0xFFE94B4B) : null,
                  boxShadow: [
                    BoxShadow(
                      color: (error ? const Color(0xFFE94B4B) : AppColors.appPrimaryColor)
                          .withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: connecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : Icon(error ? Icons.mic_off : widget.agentIcon,
                        color: Colors.white, size: 28),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int index, {required bool speaking}) {
    final speed = speaking ? 0.62 : 1.0;
    final phase = index / 3;
    final t = ((_pulseCtrl.value / speed) + phase) % 1.0;
    final scale = 0.6 + t * (speaking ? 0.7 : 0.45);
    final opacity = (1 - t).clamp(0.0, 1.0) * (speaking ? 0.5 : 0.32);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: speaking ? AppColors.appSecondaryColor : Colors.white,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _transcriptList() {
    if (_transcript.isEmpty) {
      return Center(
        child: Text(
          _state == _VoiceState.error
              ? ''
              : "The conversation transcript will appear here once you're connected.",
          textAlign: TextAlign.center,
          style: AppFonts.body(size: 12, color: Colors.white.withOpacity(0.45))
              .copyWith(height: 1.5),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _transcript.length,
      itemBuilder: (context, i) => _transcriptRow(_transcript[i]),
    );
  }

  Widget _transcriptRow(_TranscriptLine line) {
    final align =
        line.isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = line.isCustomer
        ? AppColors.appPrimaryColor.withOpacity(0.85)
        : Colors.white.withOpacity(0.12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            line.isCustomer ? 'You' : widget.agentName,
            style: AppFonts.mono(
                size: 9.5, color: Colors.white.withOpacity(0.45)),
          ),
          const SizedBox(height: 2),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              line.text,
              style: AppFonts.body(
                  size: 13.5,
                  color: line.isFinal ? Colors.white : Colors.white.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    final connected = _rtcRoom != null && _state != _VoiceState.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: _micMuted ? Icons.mic_off : Icons.mic_none,
            label: _micMuted ? 'Unmute' : 'Mute',
            active: _micMuted,
            onTap: connected
                ? () async {
                    final next = !_micMuted;
                    await _rtcRoom?.localParticipant?.setMicrophoneEnabled(!next);
                    if (!mounted) return;
                    setState(() => _micMuted = next);
                  }
                : null,
          ),
          _endCallButton(),
          _controlButton(
            icon: _speakerOn ? Icons.volume_up_outlined : Icons.hearing,
            label: _speakerOn ? 'Speaker' : 'Earpiece',
            active: !_speakerOn,
            onTap: () {
              final next = !_speakerOn;
              Helper.setSpeakerphoneOn(next);
              setState(() => _speakerOn = next);
            },
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : Colors.white.withOpacity(enabled ? 0.14 : 0.06),
            ),
            alignment: Alignment.center,
            child: Icon(icon,
                color: active
                    ? AppColors.appPrimaryDarkColor
                    : Colors.white.withOpacity(enabled ? 1 : 0.4),
                size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: AppFonts.body(
                size: 11.5, color: Colors.white.withOpacity(0.75))),
      ],
    );
  }

  Widget _endCallButton() {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE94B4B),
            ),
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: math.pi * 0.75,
              child: const Icon(Icons.call, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('End',
            style: AppFonts.body(
                size: 11.5, color: Colors.white.withOpacity(0.75))),
      ],
    );
  }
}
