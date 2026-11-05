import 'package:dartx/dartx.dart';

final _camelCaseBoundary = RegExp(r'([a-z])([A-Z])');

// "TextBlock" → "Text Block"
String prettifyName(String text) {
  return text.replaceAllMapped(_camelCaseBoundary, (match) => '${match[1]} ${match[2]}').capitalize();
}
