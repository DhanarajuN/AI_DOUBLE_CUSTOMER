import 'package:flutter/foundation.dart';
import '../models/pro.dart';
import '../repositories/convo_repository.dart';
import '../repositories/pro_repository.dart';

/// Backs [ProfileView]. Bound to a single professional id.
class ProfileViewModel extends ChangeNotifier {
  final ConvoRepository _convoRepository;
  final ProRepository _proRepository;
  final String proId;

  String? selectedSlot;

  ProfileViewModel(
    this._convoRepository,
    this._proRepository, {
    required this.proId,
  }) {
    _convoRepository.addListener(notifyListeners);
  }

  Pro? get pro => _proRepository.getById(proId);
  bool get isSaved => _convoRepository.isSaved(proId);
  List<Booking> get bookings => _convoRepository.bookings;

  void toggleSave() => _convoRepository.toggleSave(proId);

  void pickSlot(String slot) {
    selectedSlot = slot;
    notifyListeners();
  }

  bool confirmBooking() => _convoRepository.confirmBooking(proId, selectedSlot);

  /// Opens (or creates) a 1:1 chat with this professional, returning the
  /// conversation id so the caller can navigate to its thread.
  String chatWithPro() => _convoRepository.chatWithPro(pro!);

  @override
  void dispose() {
    _convoRepository.removeListener(notifyListeners);
    super.dispose();
  }
}
