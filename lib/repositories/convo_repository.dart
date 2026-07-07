import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/chat_message.dart';
import '../models/convo.dart';
import '../models/pro.dart';
import 'script_repository.dart';

/// Single in-memory source of truth for conversations, bookings and saved
/// professionals — shared across every screen, since e.g. a message sent in
/// the thread view must update that conversation's preview in the list view.
///
/// No local persistence layer is wired up yet — swap in shared_preferences
/// /hive/a remote API behind this same interface if you want chats to
/// survive an app restart or come from a backend.
class ConvoRepository extends ChangeNotifier {
  final ScriptRepository scriptRepository;

  ConvoRepository(this.scriptRepository) {
    convos = _seedConvos();
  }

  late List<Convo> convos;
  List<String> savedProIds = ['ramesh'];
  final List<Booking> bookings = [];

  List<Convo> get visibleConvos => convos.where((c) => !c.archived).toList();
  List<Convo> get archivedConvos => convos.where((c) => c.archived).toList();
  int get archivedCount => archivedConvos.length;

  Convo getById(String id) => convos.firstWhere((c) => c.id == id);

  bool isSaved(String proId) => savedProIds.contains(proId);

  String get nowLabel {
    final d = DateTime.now();
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------
  // Opening / creating conversations
  // ---------------------------------------------------------------------

  /// Marks a conversation as read once its thread is opened.
  void markRead(String convoId) {
    final c = getById(convoId);
    if (c.unread > 0) {
      c.unread = 0;
      notifyListeners();
    }
  }

  /// Moves a conversation between the main list and Archived.
  void setArchived(String convoId, bool archived) {
    final c = getById(convoId);
    if (c.archived == archived) return;
    c.archived = archived;
    notifyListeners();
  }

  /// "New request" -> pick a category -> begin a fresh AI-guided intake
  /// conversation. Returns the new conversation's id so the caller can
  /// navigate to its thread.
  String startIntake(String category) {
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
    notifyListeners();

    final script = scriptRepository.getScript(category);
    _aiSay(c, script.greet, onDone: () {
      c.step = 0;
      c.chips = [...script.steps[0].chips, 'Type my own'];
      notifyListeners();
    });
    return id;
  }

  /// Opens (or creates) a direct 1:1 chat with a professional. Returns the
  /// conversation id so the caller can navigate to its thread.
  String chatWithPro(Pro pro) {
    Convo? c;
    for (final x in convos) {
      if (x.proId == pro.id && !x.isAI) {
        c = x;
        break;
      }
    }
    if (c == null) {
      c = Convo(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        category: 'insurance',
        title: pro.name,
        isAI: false,
        time: 'now',
        preview: 'You: Hi, I found you via AI Double',
        proId: pro.id,
      );
      c.messages.add(const ChatMessage.dayMark('TODAY'));
      c.messages.add(ChatMessage.text(
        text: 'Hi, I found you via AI Double 👋',
        isMe: true,
        time: nowLabel,
      ));
      convos.insert(0, c);
      notifyListeners();

      final convo = c;
      Timer(AppConstants.proGreetDelay, () {
        _aiSay(convo, 'Hi! Thanks for reaching out. How can I help you today?');
      });
    }
    return c.id;
  }

  // ---------------------------------------------------------------------
  // Sending messages / intake flow
  // ---------------------------------------------------------------------

  /// Called when the user taps a quick-reply chip.
  void quickReplyTap(String convoId, String label) {
    final c = getById(convoId);
    if (c.complete) {
      handleFollowup(convoId, label);
      return;
    }
    _pushMe(c, label);
    _advanceIntake(c);
  }

  /// Free-text message from the composer.
  void sendMsg(String convoId, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final c = getById(convoId);
    _pushMe(c, t);
    if (c.live && !c.complete) {
      _advanceIntake(c);
    } else if (!c.isAI) {
      Timer(AppConstants.aiReplyDelay, () {
        _aiSay(c, "Thanks, noted! I'll get back to you shortly. 🙂");
      });
    } else {
      Timer(AppConstants.aiReplyDelay, () {
        _aiSay(c, 'Got it — anything else I can help you find?');
      });
    }
  }

  /// Once pros are revealed, user taps a follow-up chip.
  void handleFollowup(String convoId, String label) {
    final c = getById(convoId);
    _pushMe(c, label);
    Timer(AppConstants.aiFollowupDelay, () {
      _aiSay(
        c,
        'Sure — tap either professional above to see details, compare or book. Want me to draft your requirement to send them?',
        onDone: () {
          c.chips = ['Yes, draft it', 'No thanks', 'New request'];
          notifyListeners();
        },
      );
    });
  }

  /// Used when the person taps 'Type my own' or 'New request', both of
  /// which are intercepted by the View before calling quickReplyTap().
  void hideChips(String convoId) {
    getById(convoId).chips = [];
    notifyListeners();
  }

  void _pushMe(Convo c, String text) {
    c.messages.add(ChatMessage.text(text: text, isMe: true, time: nowLabel));
    c.preview = text;
    c.lastFromMe = true;
    c.time = 'now';
    c.chips = [];
    notifyListeners();
  }

  void _advanceIntake(Convo c) {
    final s = scriptRepository.getScript(c.category);
    final step = (c.step >= 0 && c.step < s.steps.length) ? s.steps[c.step] : null;
    if (step != null && step.ask != null) {
      _aiSay(c, step.ask!, onDone: () {
        c.step++;
        if (c.step < s.steps.length) {
          c.chips = [...s.steps[c.step].chips, 'Type my own'];
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
    final s = scriptRepository.getScript(c.category);
    _aiSayProList(c, s.reveal, s.proIds, onDone: () {
      c.complete = true;
      c.live = false;
      c.preview = '${s.reveal.substring(0, s.reveal.length > 42 ? 42 : s.reveal.length)}…';
      c.lastFromMe = false;
      c.chips = [...s.after, 'New request'];
      notifyListeners();
    });
  }

  /// Simulates the AI "typing…" delay, then appends a plain text bubble.
  void _aiSay(Convo c, String text, {VoidCallback? onDone, String? time}) {
    c.isTyping = true;
    notifyListeners();
    Timer(AppConstants.aiTypingDelay, () {
      c.isTyping = false;
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
    c.isTyping = true;
    notifyListeners();
    Timer(AppConstants.aiTypingDelay, () {
      c.isTyping = false;
      c.messages.add(ChatMessage.proList(text: text, time: nowLabel, proIds: proIds));
      notifyListeners();
      onDone?.call();
    });
  }

  // ---------------------------------------------------------------------
  // Saved professionals / bookings
  // ---------------------------------------------------------------------
  void toggleSave(String proId) {
    if (savedProIds.contains(proId)) {
      savedProIds.remove(proId);
    } else {
      savedProIds.add(proId);
    }
    notifyListeners();
  }

  /// Returns true if the booking was recorded.
  bool confirmBooking(String proId, String? slot) {
    if (slot == null) return false;
    bookings.insert(0, Booking(proId: proId, slot: slot));
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------
  // Seed data — mirrors the initial CONVOS array + buildCompletedThread()
  // ---------------------------------------------------------------------
  List<Convo> _seedConvos() {
    final insurance = scriptRepository.getScript('insurance');
    final education = scriptRepository.getScript('education');
    final home = scriptRepository.getScript('home');

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
      ChatMessage.proList(text: 'I found a great match for you.', time: '10:02', proIds: const ['sri']),
      ChatMessage.text(text: 'Thanks!', isMe: true, time: '10:05'),
      ChatMessage.text(text: 'Glad I could help. Anything else?', isMe: false, time: '10:05'),
    ]);

    return [c1, c2, c3, a1, a2, a3];
  }
}
