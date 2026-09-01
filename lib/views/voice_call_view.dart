import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../constants/server_urls.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
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

enum _AgentActivity { connecting, listening, speaking }

class _TranscriptLine {
  final bool isCustomer;
  final String text;
  const _TranscriptLine({required this.isCustomer, required this.text});
}

class VoiceCallView extends StatefulWidget {
  final String agentName;
  final IconData agentIcon;
  final String? agentId;
  final String? conversationId;
  final String? businessId;

  const VoiceCallView({
    super.key,
    required this.agentName,
    required this.agentIcon,
    this.agentId,
    this.conversationId,
    this.businessId,
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
  late final int _tokenIssuedAt;
  late final Map<String, dynamic> _claims;
  Timer? _connectTimer;
  Timer? _durationTimer;
  Timer? _turnTimer;
  _AgentActivity _activity = _AgentActivity.connecting;
  bool _micMuted = false;
  bool _speakerOn = true;
  bool _demoBusy = false;
  Duration _elapsed = Duration.zero;
  int _demoStep = 0;

  final _transcript = <_TranscriptLine>[];

  static const _demoScript = [
    (
      customer: "I'd like to check my order status.",
      agent: "Sure — could you share your order number?",
    ),
    (
      customer: "It's ORD-48213.",
      agent: "Thanks, one moment while I look that up…",
    ),
    (
      customer: 'Also, can I change the delivery address?',
      agent: "Of course — what's the new address?",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    final identity = context.read<AuthRepository>().currentUser?.id ?? 'unknown';
    final apiClient = context.read<ApiClient>();
    _room = _generateRoomName(
      tenantId: ServerUrls.tenant,
      identity: identity,
      agentId: widget.agentId ?? 'unknown-agent',
      nonce: _callNonce,
    );
    _tokenIssuedAt = _generateNowSeconds();
    final metadata = <String, dynamic>{
      'agentId': widget.agentId ?? '',
      'conversationId': widget.conversationId ?? '',
      'businessId': '',
      'tenantId': ServerUrls.tenant,
      'gosureUserId': identity,
      'gosureToken': apiClient.accessToken ?? '',
      'language': WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    };
    _claims = _generateClaims(
      apiKey: '',
      identity: identity,
      room: _room,
      now: _tokenIssuedAt,
      metadata: metadata,
    );
    final claimsForLog = {..._claims, 'metadata': redactJson(metadata)};
    AppLogger.i('VoiceCallView', 'callNonce=$_callNonce');
    AppLogger.i('VoiceCallView', 'room=$_room');
    AppLogger.i('VoiceCallView', 'now=$_tokenIssuedAt header=$_jwtHeader');
    AppLogger.i('VoiceCallView', 'claims=${jsonEncode(claimsForLog)}');
    AppLogger.i('VoiceCallView',
        'call $_callNonce started with agent "${widget.agentName}" (conversationId=${widget.conversationId}, businessId=${widget.businessId})');
    _initTts();

    _connectTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      const greeting = "Hi! I'm ";
      final line =
          "$greeting${widget.agentName}. How can I help you today?";
      setState(() {
        _activity = _AgentActivity.speaking;
        _transcript.add(_TranscriptLine(isCustomer: false, text: line));
      });
      _speak(line);
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(_onSpeechDone);
    _tts.setErrorHandler((msg) => _onSpeechDone());
    _tts.setCancelHandler(_onSpeechDone);
  }

  void _onSpeechDone() {
    if (!mounted) return;
    setState(() {
      _activity = _AgentActivity.listening;
      _demoBusy = false;
    });
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  void dispose() {
    AppLogger.i('VoiceCallView', 'call $_callNonce ended at ${_durationLabel()}');
    _pulseCtrl.dispose();
    _scrollCtrl.dispose();
    _tts.stop();
    _connectTimer?.cancel();
    _durationTimer?.cancel();
    _turnTimer?.cancel();
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

  void _simulateDemoTurn() {
    if (_activity == _AgentActivity.connecting || _demoBusy) return;
    final turn = _demoScript[_demoStep % _demoScript.length];
    _demoStep++;
    setState(() {
      _demoBusy = true;
      _activity = _AgentActivity.listening;
      _transcript.add(_TranscriptLine(isCustomer: true, text: turn.customer));
    });
    _scrollToEnd();
    _turnTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _activity = _AgentActivity.speaking;
        _transcript.add(_TranscriptLine(isCustomer: false, text: turn.agent));
      });
      _scrollToEnd();
      _speak(turn.agent);
    });
  }

  String _statusLabel() {
    switch (_activity) {
      case _AgentActivity.connecting:
        return 'Connecting…';
      case _AgentActivity.listening:
        return _micMuted ? 'Mic muted' : 'Listening…';
      case _AgentActivity.speaking:
        return '${widget.agentName} is speaking…';
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
          GestureDetector(onTap: _simulateDemoTurn, child: _orb()),
          const SizedBox(height: 12),
          Text(widget.agentName,
              style: AppFonts.display(size: 17, color: Colors.white)),
          const SizedBox(height: 3),
          Text(
            _activity == _AgentActivity.connecting
                ? _statusLabel()
                : '${_statusLabel()} · ${_durationLabel()}',
            style:
                AppFonts.body(size: 12.5, color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _orb() {
    final speaking = _activity == _AgentActivity.speaking;
    final connecting = _activity == _AgentActivity.connecting;
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final ringIndex in [0, 1, 2])
                _ring(ringIndex, speaking: speaking, connecting: connecting),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.appPrimaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.appPrimaryColor.withOpacity(0.5),
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
                    : Icon(widget.agentIcon, color: Colors.white, size: 28),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int index, {required bool speaking, required bool connecting}) {
    if (connecting) return const SizedBox.shrink();
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
          'Tap the orb to preview a demo exchange —\nreal transcription arrives once LiveKit is wired in.',
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
              style: AppFonts.body(size: 13.5, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: _micMuted ? Icons.mic_off : Icons.mic_none,
            label: _micMuted ? 'Unmute' : 'Mute',
            active: _micMuted,
            onTap: () => setState(() => _micMuted = !_micMuted),
          ),
          _endCallButton(),
          _controlButton(
            icon: _speakerOn ? Icons.volume_up_outlined : Icons.hearing,
            label: _speakerOn ? 'Speaker' : 'Earpiece',
            active: !_speakerOn,
            onTap: () => setState(() => _speakerOn = !_speakerOn),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
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
              color: active ? Colors.white : Colors.white.withOpacity(0.14),
            ),
            alignment: Alignment.center,
            child: Icon(icon,
                color: active ? AppColors.appPrimaryDarkColor : Colors.white,
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
