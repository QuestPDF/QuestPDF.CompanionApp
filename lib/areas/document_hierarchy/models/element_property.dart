import 'package:json_annotation/json_annotation.dart';

part 'element_property.g.dart';

@JsonSerializable()
class ElementProperty {
  final String label;
  final String value;

  ElementProperty(this.label, this.value);

  factory ElementProperty.fromJson(Map<String, dynamic> json) => _$ElementPropertyFromJson(json);

  Map<String, dynamic> toJson() => _$ElementPropertyToJson(this);
}
