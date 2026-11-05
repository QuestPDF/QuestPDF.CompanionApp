import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../generic_exception_view_state_provider.dart';
import '../models/generic_exception_details.dart';
import 'generic_exception_view_item.dart';

class GenericExceptionViewLayout extends ConsumerWidget {
  const GenericExceptionViewLayout({super.key});

  static List<GenericExceptionDetails> flatten(GenericExceptionDetails? exception) {
    return [for (var current = exception; current != null; current = current.innerException) current];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exception = ref.watch(genericExceptionViewStateProvider).state;

    final exceptionWidgets = flatten(exception)
        .map((x) => GenericExceptionViewItem(type: x.type, message: x.message, stackTrace: x.stackTrace))
        .toList();

    return ColoredBox(
      color: context.appColors.chrome,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(48),
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: exceptionWidgets),
            ),
          ),
        ),
      ),
    );
  }
}
