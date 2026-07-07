import 'package:flutter/foundation.dart';
import '../models/convo.dart';
import '../models/pro.dart';
import '../repositories/convo_repository.dart';
import '../repositories/pro_repository.dart';

/// Backs [ChatThreadView]. Bound to a single conversation id, which can be
/// swapped in place via [startNewRequest] — mirrors tapping 'New request'
/// inside an already-open thread, which replaces the thread's contents
/// without pushing a new route.
class ChatThreadViewModel extends ChangeNotifier {
  final ConvoRepository _convoRepository;
  final ProRepository _proRepository;
  String _convoId;

  ChatThreadViewModel(
    this._convoRepository,
    this._proRepository, {
    required String convoId,
  }) : _convoId = convoId {
    _convoRepository.markRead(_convoId);
    _convoRepository.addListener(notifyListeners);
  }

  Convo get convo => _convoRepository.getById(_convoId);
  Pro? get pro => convo.proId != null ? _proRepository.getById(convo.proId!) : null;
  List<String> get chips => convo.chips;
  bool get showChips => convo.showChips;
  bool get isTyping => convo.isTyping;

  void sendMsg(String text) => _convoRepository.sendMsg(_convoId, text);

  void quickReplyTap(String label) => _convoRepository.quickReplyTap(_convoId, label);

  void hideChips() => _convoRepository.hideChips(_convoId);

  void startNewRequest(String category) {
    _convoId = _convoRepository.startIntake(category);
    notifyListeners();
  }

  @override
  void dispose() {
    _convoRepository.removeListener(notifyListeners);
    super.dispose();
  }
}
