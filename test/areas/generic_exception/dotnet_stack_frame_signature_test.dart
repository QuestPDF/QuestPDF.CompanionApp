import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/generic_exception/models/dotnet_stack_frame_signature.dart';

void main() {
  test('ordinary method', () {
    final signature = DotnetStackFrameSignature.parse(
      'QuestPDF.Fluent.ElementExtensions.Element(IContainer parent, Action`1 handler, String handlerName, Int32 sourceLineNumber)',
    );

    expect(signature.namespace, 'QuestPDF.Fluent');
    expect(signature.typeName, 'ElementExtensions');
    expect(signature.methodName, 'Element');
    expect(signature.origin, isNull);
  });

  test('generic type', () {
    final signature = DotnetStackFrameSignature.parse('System.Collections.Generic.Dictionary`2.get_Item(TKey key)');

    expect(signature.namespace, 'System.Collections.Generic');
    expect(signature.typeName, 'Dictionary<T1, T2>');
    expect(signature.methodName, 'get_Item');
  });

  test('generic method', () {
    final signature = DotnetStackFrameSignature.parse('System.Linq.Enumerable.First[TSource](IEnumerable`1 source)');

    expect(signature.typeName, 'Enumerable');
    expect(signature.methodName, 'First<TSource>');
  });

  test('type in the global namespace', () {
    final signature = DotnetStackFrameSignature.parse('Program.Main(String[] args)');

    expect(signature.namespace, '');
    expect(signature.typeName, 'Program');
    expect(signature.methodName, 'Main');
  });

  test('local function inside top-level statements', () {
    final signature = DotnetStackFrameSignature.parse(
      r'Program.<<Main>$>g__ComposeBrokenSection|0_2(IContainer container)',
    );

    expect(signature.typeName, 'Program');
    expect(signature.methodName, 'ComposeBrokenSection');
    expect(signature.origin, 'local function in Main');
  });

  test('lambda inside top-level statements', () {
    final signature = DotnetStackFrameSignature.parse(
      r'Program.<>c__DisplayClass0_0.<<Main>$>b__6(ColumnDescriptor column)',
    );

    expect(signature.namespace, '');
    expect(signature.typeName, 'Program');
    expect(signature.methodName, 'Main');
    expect(signature.origin, isNull);
  });

  test('lambda cached in the static closure class', () {
    final signature = DotnetStackFrameSignature.parse(
      'QuestPDF.Companion.CompanionSession.<>c.<GenerateDocumentSnapshot>b__25_0()',
    );

    expect(signature.namespace, 'QuestPDF.Companion');
    expect(signature.typeName, 'CompanionSession');
    expect(signature.methodName, 'GenerateDocumentSnapshot');
    expect(signature.origin, isNull);
  });

  test('constructors keep their type and leading dot', () {
    final instance = DotnetStackFrameSignature.parse('MyApp.Reports.InvoiceDocument..ctor(InvoiceModel model)');

    expect(instance.namespace, 'MyApp.Reports');
    expect(instance.typeName, 'InvoiceDocument');
    expect(instance.methodName, '.ctor');
    expect(instance.origin, isNull);

    final static = DotnetStackFrameSignature.parse('Settings..cctor()');

    expect(static.namespace, '');
    expect(static.typeName, 'Settings');
    expect(static.methodName, '.cctor');
  });

  test('async method state machine', () {
    final signature = DotnetStackFrameSignature.parse(
      'QuestPDF.Companion.CompanionSession.<GenerateDocumentSnapshot>d__25.MoveNext()',
    );

    expect(signature.namespace, 'QuestPDF.Companion');
    expect(signature.typeName, 'CompanionSession');
    expect(signature.methodName, 'GenerateDocumentSnapshot');
    expect(signature.origin, 'async');
  });

  test('async local function state machine', () {
    final signature = DotnetStackFrameSignature.parse(r'Program.<<<Main>$>g__RunAsync|0_0>d__0.MoveNext()');

    expect(signature.typeName, 'Program');
    expect(signature.methodName, 'RunAsync');
    expect(signature.origin, 'async local function in Main');
  });

  test('location without a parameter list', () {
    final signature = DotnetStackFrameSignature.parse('System.Threading.Tasks.Task.Wait');

    expect(signature.namespace, 'System.Threading.Tasks');
    expect(signature.typeName, 'Task');
    expect(signature.methodName, 'Wait');
  });
}
