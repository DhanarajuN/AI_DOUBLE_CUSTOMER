import 'package:flutter/foundation.dart';
import '../models/convo.dart';
import '../models/pro.dart';
import '../repositories/convo_repository.dart';
import '../repositories/pro_repository.dart';

/// Backs [ChatListView]. Exposes only what that screen needs and forwards
/// commands to the shared [ConvoRepository].
class ChatListViewModel extends ChangeNotifier {
  final ConvoRepository _convoRepository;
  final ProRepository _proRepository;

  ChatListViewModel(this._convoRepository, this._proRepository) {
    _convoRepository.addListener(notifyListeners);
  }

  String _query = '';
  String get query => _query;

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Chats matching [query] by title or last-message preview
  /// (case-insensitive); all chats when the query is empty.
  List<Convo> get visibleConvos {
    final all = _convoRepository.visibleConvos;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) => c.title.toLowerCase().contains(q) || c.preview.toLowerCase().contains(q))
        .toList();
  }

  int get archivedCount => _convoRepository.archivedCount;

  Pro? proFor(Convo c) => c.proId != null ? _proRepository.getById(c.proId!) : null;

  void openConvo(String id) => _convoRepository.markRead(id);

  /// Moves a conversation out of the main chat list and into Archived.
  void archive(String id) => _convoRepository.setArchived(id, true);

  /// Starts a fresh AI-guided intake conversation, returning its id so the
  /// View can navigate to the thread.
  String startIntake(String category) => _convoRepository.startIntake(category);

  @override
  void dispose() {
    _convoRepository.removeListener(notifyListeners);
    super.dispose();
  }
}
