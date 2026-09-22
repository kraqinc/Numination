import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'models.dart';


class AiModesController extends AsyncNotifier<List<AiModeConfig>> {
  @override
  Future<List<AiModeConfig>> build() => _fetch();

  Future<List<AiModeConfig>> _fetch() async {
    try {
      final response = await ApiClient.get('/modes');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final list = (data['modes'] as List? ?? [])
          .map((e) => AiModeConfig.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    } catch (e) {
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
  AiModeConfig? findById(String id) {
    for (final m in state.valueOrNull ?? const <AiModeConfig>[]) {
      if (m.id == id) return m;
    }
    return null;
  }
}

final aiModesControllerProvider =
    AsyncNotifierProvider<AiModesController, List<AiModeConfig>>(AiModesController.new);
