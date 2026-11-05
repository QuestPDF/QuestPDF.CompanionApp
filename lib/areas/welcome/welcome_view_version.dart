import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questpdf_companion/areas/application/state/application_version_state.dart';

import '../../theme/app_colors.dart';

class WelcomeViewVersion extends ConsumerWidget {
  const WelcomeViewVersion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationVersion = ref.watch(applicationVersionProvider.select((x) => x.currentApplicationVersion));

    return Text(
      "Version ${applicationVersion?.text ?? "-"}",
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary),
    );
  }
}
