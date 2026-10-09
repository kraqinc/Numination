import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoderPreviewState {
  final bool ready;
  final String? url;

  const CoderPreviewState({
    this.ready = false,
    this.url,
  });

  CoderPreviewState copyWith({
    bool? ready,
    String? url,
    bool clearUrl = false,
  }) {
    return CoderPreviewState(
      ready: ready ?? this.ready,
      url: clearUrl ? null : (url ?? this.url),
    );
  }
}

class CoderPreviewNotifier
    extends FamilyNotifier<CoderPreviewState, String> {
  @override
  CoderPreviewState build(String projectId) =>
      const CoderPreviewState();

  void setPreview({required bool ready, String? url}) {
    state = CoderPreviewState(ready: ready, url: url);
  }

  void clear() {
    state = const CoderPreviewState();
  }
}

final coderPreviewProvider = NotifierProvider.family<
    CoderPreviewNotifier, CoderPreviewState, String>(
  CoderPreviewNotifier.new,
);