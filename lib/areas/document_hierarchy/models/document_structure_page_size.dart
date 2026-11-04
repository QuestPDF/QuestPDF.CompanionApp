import 'package:json_annotation/json_annotation.dart';

part 'document_structure_page_size.g.dart';

@JsonSerializable()
class DocumentStructurePageSize {
  final double width;
  final double height;

  DocumentStructurePageSize(this.width, this.height);

  factory DocumentStructurePageSize.fromJson(Map<String, dynamic> json) => _$DocumentStructurePageSizeFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentStructurePageSizeToJson(this);
}
