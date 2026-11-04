import 'package:json_annotation/json_annotation.dart';
import 'package:questpdf_companion/areas/document_preview/models/page_snapshot_rendered.dart';

part 'update_page_snapshots_command.g.dart';

@JsonSerializable()
class UpdatePageSnapshotsCommand {
  final List<PageSnapshotRendered> pages;

  UpdatePageSnapshotsCommand(this.pages);

  factory UpdatePageSnapshotsCommand.fromJson(Map<String, dynamic> json) => _$UpdatePageSnapshotsCommandFromJson(json);

  Map<String, dynamic> toJson() => _$UpdatePageSnapshotsCommandToJson(this);
}
