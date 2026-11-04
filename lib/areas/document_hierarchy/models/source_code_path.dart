import 'package:json_annotation/json_annotation.dart';

part 'source_code_path.g.dart';

@JsonSerializable()
class SourceCodePath {
  final String filePath;
  final int lineNumber;

  SourceCodePath(this.filePath, this.lineNumber);

  factory SourceCodePath.fromJson(Map<String, dynamic> json) => _$SourceCodePathFromJson(json);

  Map<String, dynamic> toJson() => _$SourceCodePathToJson(this);
}
