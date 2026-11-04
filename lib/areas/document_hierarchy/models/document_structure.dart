import 'package:json_annotation/json_annotation.dart';

import 'document_hierarchy_element.dart';
import 'document_structure_page_size.dart';

part 'document_structure.g.dart';

@JsonSerializable()
class DocumentStructure {
  final bool isDocumentHotReloaded;
  final List<DocumentStructurePageSize> pages;
  final DocumentHierarchyElement hierarchy;

  DocumentStructure(this.isDocumentHotReloaded, this.pages, this.hierarchy);

  factory DocumentStructure.fromJson(Map<String, dynamic> json) => _$DocumentStructureFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentStructureToJson(this);
}
