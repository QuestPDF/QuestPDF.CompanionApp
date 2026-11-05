import 'package:json_annotation/json_annotation.dart';

part 'page_snapshot_index.g.dart';

@JsonSerializable()
class PageSnapshotIndex {
  final int pageIndex;
  final int zoomLevel;

  PageSnapshotIndex(this.pageIndex, this.zoomLevel);

  factory PageSnapshotIndex.fromJson(Map<String, dynamic> json) => _$PageSnapshotIndexFromJson(json);

  Map<String, dynamic> toJson() => _$PageSnapshotIndexToJson(this);
}
