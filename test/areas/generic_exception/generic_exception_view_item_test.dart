import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/generic_exception/models/generic_exception_stack_frame.dart';
import 'package:questpdf_companion/areas/generic_exception/widgets/generic_exception_view_item.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

GenericExceptionStackFrame frame(String location, {String? file, int? line}) =>
    GenericExceptionStackFrame(location, file, line);

Widget host(List<GenericExceptionStackFrame> stackTrace) {
  return ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GenericExceptionViewItem(type: 'System.Exception', message: 'Boom', stackTrace: stackTrace),
        ),
      ),
    ),
  );
}

final dictionaryFrame = frame('System.Collections.Generic.Dictionary`2.get_Item(TKey key)');
final libraryFrame = frame(
  'QuestPDF.Fluent.TextExtensions.Text(IContainer element, String text)',
  file: '/lib/Text.cs',
  line: 10,
);
final invoiceFrame = frame(
  'MyApp.Reports.Invoice.Compose(IDocumentContainer container)',
  file: '/app/Invoice.cs',
  line: 42,
);
final mainFrame = frame('MyApp.Program.Main(String[] args)', file: '/app/Program.cs', line: 7);

// the application state provider wraps a process-wide singleton, so all phases share one ProviderScope
void main() {
  testWidgets('default expansion of stack frames', (tester) async {
    // the first frame in user code opens, even when a library frame before it carries source
    await tester.pumpWidget(host([dictionaryFrame, libraryFrame, invoiceFrame]));
    await tester.pump();

    expect(find.textContaining('Open in'), findsOneWidget);
    expect(find.textContaining('Invoice.cs:42'), findsOneWidget);
    expect(find.textContaining('Text.cs:10'), findsNothing);

    // without user code, the first frame with source opens
    await tester.pumpWidget(host([dictionaryFrame, libraryFrame]));
    await tester.pump();

    expect(find.textContaining('Text.cs:10'), findsOneWidget);

    // the user collapses the suggested frame and opens another one
    await tester.pumpWidget(host([dictionaryFrame, invoiceFrame, mainFrame]));
    await tester.pump();
    expect(find.textContaining('Invoice.cs:42'), findsOneWidget);

    await tester.tap(find.textContaining('Invoice.Compose'));
    // collapsing first brings the next row into the viewport
    await tester.pump();
    await tester.tap(find.textContaining('Program.Main'));
    await tester.pump();

    expect(find.textContaining('Invoice.cs:42'), findsNothing);
    expect(find.textContaining('Program.cs:7'), findsOneWidget);

    // a new exception with the same shape arrives: the first user frame opens, the old choice is forgotten
    final nextInvoiceFrame = frame(invoiceFrame.codeLocation, file: invoiceFrame.fileName, line: invoiceFrame.lineNumber);
    final nextMainFrame = frame(mainFrame.codeLocation, file: mainFrame.fileName, line: mainFrame.lineNumber);

    await tester.pumpWidget(host([dictionaryFrame, nextInvoiceFrame, nextMainFrame]));
    await tester.pump();

    expect(find.textContaining('Invoice.cs:42'), findsOneWidget);
    expect(find.textContaining('Program.cs:7'), findsNothing);

    // let the tooltip and hover timers of the unmounted tree run out
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
