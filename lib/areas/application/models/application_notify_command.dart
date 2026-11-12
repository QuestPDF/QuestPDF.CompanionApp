import 'package:json_annotation/json_annotation.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';

part 'application_notify_command.g.dart';

@JsonSerializable()
class ApplicationNotifyCommand {
  final LicenseType license;

  ApplicationNotifyCommand(this.license);

  factory ApplicationNotifyCommand.fromJson(Map<String, dynamic> json) => _$ApplicationNotifyCommandFromJson(json);

  Map<String, dynamic> toJson() => _$ApplicationNotifyCommandToJson(this);
}
