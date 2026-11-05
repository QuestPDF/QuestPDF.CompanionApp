import 'package:json_annotation/json_annotation.dart';

part 'generic_exception_stack_frame.g.dart';

@JsonSerializable()
class GenericExceptionStackFrame {
  final String codeLocation;
  final String? fileName;
  final int? lineNumber;

  GenericExceptionStackFrame(this.codeLocation, this.fileName, this.lineNumber);

  bool get hasSourceCode => fileName != null && lineNumber != null;

  factory GenericExceptionStackFrame.fromJson(Map<String, dynamic> json) => _$GenericExceptionStackFrameFromJson(json);

  Map<String, dynamic> toJson() => _$GenericExceptionStackFrameToJson(this);
}
