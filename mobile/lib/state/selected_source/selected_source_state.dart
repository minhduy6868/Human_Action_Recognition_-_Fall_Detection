import '../../models/source.dart';

class SelectedSourceState {
  const SelectedSourceState({
    this.sources = const [],
    this.selectedSourceId,
    this.loading = false,
  });

  final List<Source> sources;
  final String? selectedSourceId;
  final bool loading;

  Source? get selectedSource {
    if (selectedSourceId == null) return null;
    for (final source in sources) {
      if (source.id == selectedSourceId) return source;
    }
    return null;
  }

  SelectedSourceState copyWith({
    List<Source>? sources,
    String? selectedSourceId,
    bool? loading,
  }) {
    return SelectedSourceState(
      sources: sources ?? this.sources,
      selectedSourceId: selectedSourceId ?? this.selectedSourceId,
      loading: loading ?? this.loading,
    );
  }
}
