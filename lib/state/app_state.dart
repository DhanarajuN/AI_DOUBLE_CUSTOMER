import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/convo.dart';
import '../models/pro.dart';
import '../data/pros_data.dart';
import '../data/scripts_data.dart';

/// Simple in-memory equivalent of the `state` object + all the top-level
/// functions in customer.html's <script> tag (pushMe, advanceIntake,
/// finishIntake, handleFollowup, sendMsg, chatWithPro, toggleSave,
/// confirmBooking, persist, etc). No local persistence layer is wired up
/// (the HTML used localStorage) — swap in shared_preferences/hive here if
/// you want the chats to survive an app restart.
class AppState extends ChangeNotifier {
  final Map<String, Pro> pros = kPros;
  final Map<String, CategoryScript> scripts = kScripts;
  final Map<String, CategoryMeta> categoryMeta = kCategoryMeta;

  late List<Convo> convos;
  List<String> savedProIds = ['ramesh'];
  List<Booking> bookings = [];

  Convo? activeConvo;
  String? currentProId;
  String? selectedSlot;

  /// Whether the AI "typing…" indicator should show in the active thread.
  bool isTyping = false;

  /// Quick-reply chips currently shown above the composer (mirrors #qr).
  List<String> chips = [];
  bool get showChips => chips.isNotEmpty;

  /// hideQR() — used by the UI when the person taps 'Type my own' or
  /// 'New request', both of which are intercepted before quickReplyTap().
  void hideChips() {
    chips = [];
    notifyListeners();
  }

  AppState() {
    convos = _seedConvos();
  }

  // ---------------------------------------------------------------------
  // Derived lists
  // ---------------------------------------------------------------------
  List<Convo> get visibleConvos => convos.where((c) => !c.archived).toList();
  List<Convo> get archivedConvos => convos.where((c) => c.archived).toList();
  int get archivedCount => archivedConvos.length;

  String get nowLabel {
    final d = DateTime.now();
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------
  // Opening conversations
  // ---------------------------------------------------------------------

  /// openConvo(id) — open an existing chat (AI thread or pro thread).
  void openConvo(String id) {
    final c = convos.firstWhere((x) => x.id == id);
    activeConvo = c;
    if (c.unread > 0) {
      c.unread = 0;
    }
    if (c.isAI && c.complete) {
      final s = scripts[c.category]!;
      chips = [...s.after, 'New request'];
    } else {
      chips = [];
    }
    notifyListeners();
  }

  /// startIntake(cat) — "New request" -> pick a category -> begin a fresh
  /// AI-guided intake conversation.
  void startIntake(String category) {
    final id = 'n${DateTime.now().millisecondsSinceEpoch}';
    final c = Convo(
      id: id,
      category: category,
      title: 'AI Double',
      isAI: true,
      time: 'now',
      preview: '…',
      complete: false,
      live: true,
      step: -1,
    );
    convos.insert(0, c);
    activeConvo = c;
    chips = [];
    notifyListeners();

    final script = scripts[category]!;
    _aiSay(c, script.greet, onDone: () {
      c.step = 0;
      chips = [...script.steps[0].chips, 'Type my own'];
      notifyListeners();
    });
  }

  /// chatWithPro(id) — open (or create) a direct 1:1 chat with a professional.
  void chatWithPro(String proId) {
    final p = pros[proId]!;
    Convo? c;
    for (final x in convos) {
      if (x.proId == proId && !x.isAI) {
        c = x;
        break;
      }
    }
    if (c == null) {
      c = Convo(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        category: 'insurance',
        title: p.name,
        isAI: false,
        time: 'now',
        preview: 'You: Hi, I found you via AI Double',
        proId: proId,
      );
      c.messages.add(const ChatMessage.dayMark('TODAY'));
      c.messages.add(ChatMessage.text(
        text: 'Hi, I found you via AI Double 👋',
        isMe: true,
        time: nowLabel,
      ));
      convos.insert(0, c);
    }
    activeConvo = c;
    chips = [];
    notifyListeners();

    Timer(const Duration(milliseconds: 700), () {
      _aiSay(c!, 'Hi! Thanks for reaching out. How can I help you today?');
    });
  }

  void closeChat() {
    activeConvo = null;
    chips = [];
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Sending messages / intake flow
  // ---------------------------------------------------------------------

  /// Called when the user taps a quick-reply chip. The UI intercepts the
  /// special 'Type my own' and 'New request' chips before calling this
  /// (mirrors the top of qrTap() in customer.html).
  void quickReplyTap(String label) {
    final c = activeConvo;
    if (c == null) return;
    if (c.complete) {
      handleFollowup(label);
      return;
    }
    _pushMe(c, label);
    _advanceIntake(c);
  }

  /// sendMsg() — free-text message from the composer.
  void sendMsg(String text) {
    final t = text.trim();
    final c = activeConvo;
    if (t.isEmpty || c == null) return;
    _pushMe(c, t);
    if (c.live && !c.complete) {
      _advanceIntake(c);
    } else if (!c.isAI) {
      Timer(const Duration(milliseconds: 400), () {
        _aiSay(c, "Thanks, noted! I'll get back to you shortly. 🙂");
      });
    } else {
      Timer(const Duration(milliseconds: 400), () {
        _aiSay(c, 'Got it — anything else I can help you find?');
      });
    }
  }

  void _pushMe(Convo c, String text) {
    c.messages.add(ChatMessage.text(text: text, isMe: true, time: nowLabel));
    c.preview = text;
    c.lastFromMe = true;
    c.time = 'now';
    chips = []; // hideQR()
    notifyListeners();
  }

  void _advanceIntake(Convo c) {
    final s = scripts[c.category]!;
    final step = (c.step >= 0 && c.step < s.steps.length) ? s.steps[c.step] : null;
    if (step != null && step.ask != null) {
      _aiSay(c, step.ask!, onDone: () {
        c.step++;
        if (c.step < s.steps.length) {
          chips = [...s.steps[c.step].chips, 'Type my own'];
          notifyListeners();
        } else {
          _finishIntake(c);
        }
      });
    } else {
      _finishIntake(c);
    }
  }

  void _finishIntake(Convo c) {
    final s = scripts[c.category]!;
    _aiSayProList(c, s.reveal, s.proIds, onDone: () {
      c.complete = true;
      c.live = false;
      c.preview = '${s.reveal.substring(0, s.reveal.length > 42 ? 42 : s.reveal.length)}…';
      c.lastFromMe = false;
      chips = [...s.after, 'New request'];
      notifyListeners();
    });
  }

  /// handleFollowup(x) — once pros are revealed, user taps a follow-up chip.
  void handleFollowup(String x) {
    final c = activeConvo;
    if (c == null) return;
    _pushMe(c, x);
    Timer(const Duration(milliseconds: 300), () {
      _aiSay(
        c,
        'Sure — tap either professional above to see details, compare or book. Want me to draft your requirement to send them?',
        onDone: () {
          chips = ['Yes, draft it', 'No thanks', 'New request'];
          notifyListeners();
        },
      );
    });
  }

  /// Simulates the AI "typing…" delay, then appends a plain text bubble.
  void _aiSay(Convo c, String text, {VoidCallback? onDone, String? time}) {
    isTyping = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 850), () {
      isTyping = false;
      c.messages.add(ChatMessage.text(text: text, isMe: false, time: time ?? nowLabel));
      c.preview = text.length > 42 ? '${text.substring(0, 42)}…' : text;
      c.lastFromMe = false;
      c.time = 'now';
      notifyListeners();
      onDone?.call();
    });
  }

  /// Same as [_aiSay] but appends a matched-pro-cards bubble.
  void _aiSayProList(Convo c, String text, List<String> proIds, {VoidCallback? onDone}) {
    isTyping = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 850), () {
      isTyping = false;
      c.messages.add(ChatMessage.proList(text: text, time: nowLabel, proIds: proIds));
      notifyListeners();
      onDone?.call();
    });
  }

  // ---------------------------------------------------------------------
  // Archive
  // ---------------------------------------------------------------------
  void openArchived() {
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Profile / save / booking
  // ---------------------------------------------------------------------
  void openProfile(String proId) {
    currentProId = proId;
    notifyListeners();
  }

  bool get isCurrentProSaved => savedProIds.contains(currentProId);

  void toggleSave() {
    final id = currentProId;
    if (id == null) return;
    if (savedProIds.contains(id)) {
      savedProIds.remove(id);
    } else {
      savedProIds.add(id);
    }
    notifyListeners();
  }

  void pickSlot(String slot) {
    selectedSlot = slot;
    notifyListeners();
  }

  /// confirmBooking() — returns true if a slot was selected & booking made.
  bool confirmBooking() {
    final id = currentProId;
    if (id == null || selectedSlot == null) return false;
    bookings.insert(0, Booking(proId: id, slot: selectedSlot!));
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------
  // Seed data — mirrors the initial CONVOS array + buildCompletedThread()
  // ---------------------------------------------------------------------
  List<Convo> _seedConvos() {
    final insurance = scripts['insurance']!;
    final education = scripts['education']!;
    final home = scripts['home']!;

    final c1 = Convo(
      id: 'c1',
      category: 'insurance',
      title: 'AI Double',
      isAI: true,
      time: '9:24',
      preview: "Perfect — I've matched you with 2 advisors…",
      complete: true,
    );
    c1.messages.addAll([
      const ChatMessage.dayMark('TODAY'),
      ChatMessage.text(text: insurance.greet, isMe: false, time: '9:20'),
      ChatMessage.text(text: 'Home insurance', isMe: true, time: '9:21'),
      ChatMessage.text(text: insurance.steps[0].ask!, isMe: false, time: '9:21'),
      ChatMessage.text(text: 'Jubilee Hills', isMe: true, time: '9:22'),
      ChatMessage.text(text: insurance.steps[1].ask!, isMe: false, time: '9:22'),
      ChatMessage.text(text: 'Urgent — this week', isMe: true, time: '9:23'),
      ChatMessage.proList(text: insurance.reveal, time: '9:24', proIds: insurance.proIds),
    ]);

    final c2 = Convo(
      id: 'c2',
      category: 'education',
      title: 'AI Double',
      isAI: true,
      time: 'Yesterday',
      preview: 'Here are 2 tutors that fit — both have demo…',
      complete: true,
    );
    c2.messages.addAll([
      const ChatMessage.dayMark('YESTERDAY'),
      ChatMessage.text(text: education.greet, isMe: false, time: '18:02'),
      ChatMessage.text(text: 'Grade 10 Physics', isMe: true, time: '18:03'),
      ChatMessage.text(text: education.steps[0].ask!, isMe: false, time: '18:03'),
      ChatMessage.text(text: 'Telugu medium', isMe: true, time: '18:04'),
      ChatMessage.text(text: education.steps[1].ask!, isMe: false, time: '18:04'),
      ChatMessage.text(text: 'Online', isMe: true, time: '18:05'),
      ChatMessage.proList(text: education.reveal, time: '18:06', proIds: education.proIds),
    ]);

    final c3 = Convo(
      id: 'c3',
      category: 'health',
      title: 'Dr. Nisha, PT',
      isAI: false,
      unread: 2,
      time: '11:02',
      preview: "Great, see you Tuesday at 5:30. I'll bring…",
      proId: 'nisha',
    );
    c3.messages.addAll([
      const ChatMessage.dayMark('TODAY'),
      ChatMessage.text(
        text: "Hi! Thanks for reaching out through AI Double. I saw you're dealing with lower back pain — happy to help.",
        isMe: false,
        time: '10:40',
      ),
      ChatMessage.text(text: "Yes, it's been about two weeks now", isMe: true, time: '10:52'),
      ChatMessage.text(
        text: 'I can do a home visit. Does Tuesday 5:30pm work? First session is an assessment.',
        isMe: false,
        time: '10:58',
      ),
      ChatMessage.text(text: 'Perfect, Tuesday works', isMe: true, time: '11:01'),
      ChatMessage.text(
        text: "Great, see you Tuesday at 5:30. I'll bring what I need for the assessment. 🙂",
        isMe: false,
        time: '11:02',
      ),
    ]);

    final a1 = Convo(
      id: 'a1',
      category: 'home',
      title: 'AI Double',
      isAI: true,
      archived: true,
      time: 'Mon',
      preview: 'I found 2 verified professionals near you…',
      complete: true,
    );
    a1.messages.addAll([
      const ChatMessage.dayMark('MONDAY'),
      ChatMessage.text(text: home.greet, isMe: false, time: '14:10'),
      ChatMessage.text(text: 'Electrical', isMe: true, time: '14:11'),
      ChatMessage.text(text: home.steps[0].ask!, isMe: false, time: '14:11'),
      ChatMessage.text(text: 'Urgent — today', isMe: true, time: '14:12'),
      ChatMessage.text(text: home.steps[1].ask!, isMe: false, time: '14:12'),
      ChatMessage.text(text: 'Jubilee Hills', isMe: true, time: '14:13'),
      ChatMessage.proList(text: home.reveal, time: '14:14', proIds: home.proIds),
    ]);

    final a2 = Convo(
      id: 'a2',
      category: 'home',
      title: 'Suresh Electricals',
      isAI: false,
      archived: true,
      time: '2 wk ago',
      preview: 'Job done — thanks for choosing us!',
      proId: 'suresh',
    );
    a2.messages.addAll([
      const ChatMessage.dayMark('2 WEEKS AGO'),
      ChatMessage.text(text: 'On my way — ETA 30 minutes.', isMe: false, time: '6:10'),
      ChatMessage.text(text: 'Thank you!', isMe: true, time: '6:11'),
      ChatMessage.text(
        text: 'Job done — mains fixed and tested. 30-day warranty applies. Thanks for choosing us!',
        isMe: false,
        time: '7:05',
      ),
    ]);

    final a3 = Convo(
      id: 'a3',
      category: 'education',
      title: 'AI Double',
      isAI: true,
      archived: true,
      time: 'Jun',
      preview: 'Glad I could help. Anything else?',
      complete: true,
    );
    a3.messages.addAll([
      const ChatMessage.dayMark('12 JUNE'),
      ChatMessage.text(text: education.greet, isMe: false, time: '10:00'),
      ChatMessage.text(text: 'Grade 12 Maths', isMe: true, time: '10:01'),
      ChatMessage.proList(text: 'I found a great match for you.', time: '10:02', proIds: ['sri']),
      ChatMessage.text(text: 'Thanks!', isMe: true, time: '10:05'),
      ChatMessage.text(text: 'Glad I could help. Anything else?', isMe: false, time: '10:05'),
    ]);

    return [c1, c2, c3, a1, a2, a3];
  }
}
