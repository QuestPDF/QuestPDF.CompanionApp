import 'package:questpdf_companion/communication_service.dart';

int? parseCommunicationPort(List<String> arguments) {
  if (arguments.length != 1) return null;

  final port = int.tryParse(arguments.single.trim());

  if (port == null) return null;

  return port.clamp(communicationServiceMinPort, communicationServiceMaxPort);
}
