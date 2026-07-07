import '../data/scripts_data.dart';
import '../models/convo.dart';

/// Read access to category intake scripts, category metadata and booking
/// slots. Swap [StaticScriptRepository] for an API-backed implementation
/// later without touching any ViewModel or View.
abstract class ScriptRepository {
  CategoryScript getScript(String category);
  Map<String, CategoryMeta> getCategoryMeta();
  List<String> getSlots();
}

class StaticScriptRepository implements ScriptRepository {
  @override
  CategoryScript getScript(String category) => kScripts[category]!;

  @override
  Map<String, CategoryMeta> getCategoryMeta() => kCategoryMeta;

  @override
  List<String> getSlots() => kSlots;
}
