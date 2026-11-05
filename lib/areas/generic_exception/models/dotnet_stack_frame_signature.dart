/// The parts of a .NET stack frame location such as
/// ``QuestPDF.Fluent.ElementExtensions.Element(IContainer parent, Action`1 handler)``,
/// with compiler-generated names translated back to what the developer wrote.
class DotnetStackFrameSignature {
  /// `QuestPDF.Fluent`; empty for types in the global namespace
  final String namespace;

  /// `ElementExtensions`, `Dictionary<T1, T2>`; empty when the location is a bare method name
  final String typeName;

  /// `Element`; for a lambda or an async method, the method the developer declared
  final String methodName;

  /// how a compiler-generated method relates to the source code: `local function in Main`, `async`;
  /// null for ordinary methods and for lambdas, which are listed under the method that declares them
  final String? origin;

  const DotnetStackFrameSignature({
    required this.namespace,
    required this.typeName,
    required this.methodName,
    required this.origin,
  });

  static final _stateMachineTypePattern = RegExp(r'^<(.+)>d__\d+$');
  static final _localFunctionPattern = RegExp(r'^g__(\w+)\|');
  static final _genericArityPattern = RegExp(r'`(\d+)');
  static final _genericMethodPattern = RegExp(r'^(\w+)\[(.+)\]$');

  static DotnetStackFrameSignature parse(String location) {
    final parenthesisIndex = location.indexOf('(');
    final qualifiedName = parenthesisIndex < 0 ? location : location.substring(0, parenthesisIndex);

    final segments = _splitOutsideBrackets(qualifiedName.trim(), '.');
    var method = segments.removeLast();
    String? origin;

    // async methods and iterators run inside a generated state machine type: `<Method>d__12.MoveNext()`
    final stateMachine = segments.isEmpty ? null : _stateMachineTypePattern.firstMatch(segments.last);

    if (stateMachine != null && method == 'MoveNext') {
      segments.removeLast();
      final declared = _demangleMethod(stateMachine.group(1)!);
      method = declared.name;
      origin = declared.origin == null ? 'async' : 'async ${declared.origin}';
    } else {
      final declared = _demangleMethod(method);
      method = declared.name;
      origin = declared.origin;
    }

    // lambdas are hosted by closure classes (`<>c__DisplayClass0_0`) or the static lambda cache (`<>c`);
    // the type the developer wrote comes right before them
    segments.removeWhere((segment) => segment.startsWith('<>'));

    return DotnetStackFrameSignature(
      namespace: segments.length > 1 ? segments.take(segments.length - 1).join('.') : '',
      typeName: segments.isEmpty ? '' : _prettifyGenericType(segments.last),
      methodName: _prettifyGenericMethod(method),
      origin: origin,
    );
  }

  /// Unwraps `<Outer>b__0_1` (lambda), `<Outer>g__Name|0_1` (local function) and `<Main>$` (top-level statements).
  static ({String name, String? origin}) _demangleMethod(String name) {
    if (!name.startsWith('<')) return (name: name, origin: null);

    final closingIndex = _findClosingBracket(name, 0);
    if (closingIndex < 0) return (name: name, origin: null);

    final outer = _demangleMethod(name.substring(1, closingIndex));
    final suffix = name.substring(closingIndex + 1);

    if (suffix == r'$') return outer;

    // a lambda shows as the method that declares it
    if (suffix.startsWith('b__')) return outer;

    final localFunction = _localFunctionPattern.firstMatch(suffix);
    if (localFunction != null) return (name: localFunction.group(1)!, origin: 'local function in ${outer.name}');

    return (name: name, origin: null);
  }

  /// Replaces the backtick arity of a generic type with placeholder type arguments:
  /// ``Dictionary`2`` → `Dictionary<T1, T2>`.
  static String _prettifyGenericType(String text) {
    return text.replaceAllMapped(_genericArityPattern, (match) {
      final arity = int.parse(match.group(1)!);
      if (arity == 1) return '<T>';
      return '<${List.generate(arity, (index) => 'T${index + 1}').join(', ')}>';
    });
  }

  /// `Create[T]` → `Create<T>`
  static String _prettifyGenericMethod(String name) {
    final match = _genericMethodPattern.firstMatch(name);
    if (match == null) return name;
    return '${match.group(1)}<${match.group(2)}>';
  }

  /// Splits on [separator] while ignoring separators nested in angle or square brackets, which generated names contain.
  static List<String> _splitOutsideBrackets(String text, String separator) {
    final result = <String>[];
    var depth = 0;
    var start = 0;

    for (var index = 0; index < text.length; index++) {
      final character = text[index];

      if (character == '<' || character == '[') depth++;
      if (character == '>' || character == ']') depth--;

      if (character == separator && depth == 0) {
        result.add(text.substring(start, index));
        start = index + 1;
      }
    }

    result.add(text.substring(start));
    return result;
  }

  static int _findClosingBracket(String text, int openingIndex) {
    var depth = 0;

    for (var index = openingIndex; index < text.length; index++) {
      if (text[index] == '<') depth++;
      if (text[index] == '>') depth--;
      if (depth == 0) return index;
    }

    return -1;
  }
}
