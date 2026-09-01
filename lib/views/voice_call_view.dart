import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';

// The agent's side of this is real: every agent transcript line is actually
// spoken aloud through the device speaker via on-device TTS (flutter_tts) —
// that's genuine audio output, not simulated. Everything else is still a
// stand-in for LiveKit: the customer side has no real mic capture or STT
// (the "customer" transcript lines are canned demo text), turn-taking is a
// local timer rather than LiveKit's speaking/audio-level events, and the
// speaker/earpiece toggle is visual only (flutter_tts has no portable
// audio-route API). Nothing here touches LibreChat — this is a second,
// independent entry point next to the existing text chat, not a replacement
// for it.
enum _AgentActivity { connecting, listening, speaking }

class _TranscriptLine {
  final bool isCustomer;
  final String text;
  const _TranscriptLine({required this.isCustomer, required this.text});
}

class VoiceCallView extends StatefulWidget {
  final String agentName;
  final IconData agentIcon;
  final String? conversationId;
  final String? businessId;

  const VoiceCallView({
    super.key,
    required this.agentName,
    required this.agentIcon,
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

  // Placeholder exchange — one (customer, agent) pair added per tap on the
  // orb, purely so the transcript UI has something to show while reviewing
  // the layout. Real lines will arrive as LiveKit transcription events.
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
    _initTts();

    // Demo-only: simulate the connect handshake, then start a duration
    // clock as if the call were live. Replace with the real LiveKit
    // room.connect() / participant-connected callback.
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
      // _demoBusy/_activity revert back to listening via _onSpeechDone,
      // once flutter_tts actually finishes speaking turn.agent.
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
    // Three rings staggered by phase so they pulse outward one after another
    // rather than in lockstep — speaking pulses faster and brighter than the
    // idle "listening" breathing effect.
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
