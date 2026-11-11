import '../../../theme/app_colors.dart';
import '../state/application_state_provider.dart';

class LicenseDetails {
  final String title;
  final String description;
  final StatusTone tone;

  const LicenseDetails({required this.title, required this.description, required this.tone});

  static LicenseDetails of(LicenseType license) {
    return switch (license) {
      LicenseType.evaluation => const LicenseDetails(
        title: "Evaluation",
        description: "For internal testing, technical review and proof-of-concept work only, not for production. Organizations that do not qualify for the Community license can evaluate QuestPDF for up to 60 days before choosing a paid license.",
        tone: StatusTone.error,
      ),
      LicenseType.community => const LicenseDetails(
        title: "Community",
        description: "Free for commercial use by individuals and organizations under USD 1M in annual gross revenue, and for charities, non-profit academic institutions and open-source projects. Includes every feature, for unlimited developers, projects and deployments.",
        tone: StatusTone.warning,
      ),
      LicenseType.professional => const LicenseDetails(
        title: "Professional",
        description: "A perpetual license for one legal entity, covering unlimited developers, projects, servers and deployments. Includes a year of updates and direct email support; versions released in that time remain yours even without renewal.",
        tone: StatusTone.success,
      ),
      LicenseType.enterprise => const LicenseDetails(
        title: "Enterprise",
        description: "Everything in Professional, extended to all affiliated companies under common ownership. Adds priority next-business-day support and procurement options such as order forms, invoicing and multi-year terms.",
        tone: StatusTone.success,
      ),
    };
  }
}
