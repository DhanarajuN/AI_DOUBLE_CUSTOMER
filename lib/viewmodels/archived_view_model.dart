import 'package:flutter/foundation.dart';
import '../models/convo.dart';
import '../models/pro.dart';
import '../repositories/convo_repository.dart';
import '../repositories/pro_repository.dart';

/// Backs [ArchivedView].
class ArchivedViewModel extends ChangeNotifier {
  final ConvoRepository _convoRepository;
  final ProRepository _proRepository;

  ArchivedViewModel(this._convoRepository, this._proRepository) {
    _convoRepository.addListener(notifyListeners);
  }

  List<Convo> get archivedConvos => _convoRepository.archivedConvos;

  Pro? proFor(Convo c) => c.proId != null ? _proRepository.getById(c.proId!) : null;

  void openConvo(String id) => _convoRepository.markRead(id);

  /// Moves a conversation out of Archived and back into the main chat list.
  void unarchive(String id) => _convoRepository.setArchived(id, false);

  @override
  void dispose() {
    _convoRepository.removeListener(notifyListeners);
    super.dispose();
  }
}
