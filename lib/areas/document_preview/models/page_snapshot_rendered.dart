import 'dart:convert';
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

part 'page_snapshot_rendered.g.dart';

@JsonSerializable()
class PageSnapshotRendered {
  final int pageIndex;
  final int zoomLevel;

  @JsonKey(fromJson: _fromBase64, toJson: _toBase64)
  final Uint8List imageData;

  PageSnapshotRendered(this.pageIndex, this.zoomLevel, this.imageData);

  factory PageSnapshotRendered.fromJson(Map<String, dynamic> json) => _$PageSnapshotRenderedFromJson(json);

  Map<String, dynamic> toJson() => _$PageSnapshotRenderedToJson(this);

  static Uint8List _fromBase64(String base64String) => base64Decode(base64String);

  static String _toBase64(Uint8List bytes) => base64Encode(bytes);
}
