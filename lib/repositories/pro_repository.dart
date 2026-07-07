import '../data/pros_data.dart';
import '../models/pro.dart';

/// Read access to professional profiles. Swap [StaticProRepository] for an
/// API-backed implementation later without touching any ViewModel or View.
abstract class ProRepository {
  Map<String, Pro> getAll();
  Pro? getById(String id);
}

class StaticProRepository implements ProRepository {
  @override
  Map<String, Pro> getAll() => kPros;

  @override
  Pro? getById(String id) => kPros[id];
}
