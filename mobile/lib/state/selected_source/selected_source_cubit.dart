import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/storage/app_storage.dart';
import '../../models/source.dart';
import '../../services/sources_api.dart';
import 'selected_source_state.dart';

class SelectedSourceCubit extends Cubit<SelectedSourceState> {
  SelectedSourceCubit(this._sourcesApi, this._storage)
      : super(const SelectedSourceState());

  final SourcesApi _sourcesApi;
  final CustomSharedPreferences _storage;

  static const _prefsKey = 'selected_source_id';

  Future<void> initialize() async {
    await refreshSources();
  }

  Future<void> refreshSources() async {
    emit(state.copyWith(loading: true));
    try {
      final sources = await _sourcesApi.listSources();
      final saved = _storage.prefs.getString(_prefsKey);
      String? selected = saved;
      if (selected == null || !sources.any((s) => s.id == selected)) {
        final active = sources.where((s) => s.isActive).toList();
        selected = active.isNotEmpty ? active.first.id : (sources.isNotEmpty ? sources.first.id : null);
      }
      if (selected != null) {
        await _storage.prefs.setString(_prefsKey, selected);
      }
      emit(
        SelectedSourceState(
          sources: sources,
          selectedSourceId: selected,
          loading: false,
        ),
      );
    } catch (_) {
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> selectSource(String sourceId) async {
    if (!state.sources.any((s) => s.id == sourceId)) return;
    await _storage.prefs.setString(_prefsKey, sourceId);
    emit(state.copyWith(selectedSourceId: sourceId));
  }
}
