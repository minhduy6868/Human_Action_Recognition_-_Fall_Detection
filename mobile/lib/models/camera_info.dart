class CameraInfo {
  const CameraInfo({
    required this.index,
  });

  final int index;

  factory CameraInfo.fromMap(Map<String, dynamic> map) {
    return CameraInfo(
      index: (map['index'] as num?)?.toInt() ?? 0,
    );
  }
}

class CameraList {
  const CameraList({
    required this.activeIndex,
    required this.items,
  });

  final int activeIndex;
  final List<CameraInfo> items;

  factory CameraList.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? <dynamic>[];
    return CameraList(
      activeIndex: (map['active_index'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((item) => CameraInfo.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
