/// What the operator says about a target the site had no profile for: the code
/// it goes by in the studio, and what it shows. Both end up on the profile, so
/// the limits are the studio's own.
class NewTargetDetails {
  const NewTargetDetails({required this.code, required this.description});

  static const int maxCodeLength = 255;
  static const int maxDescriptionLength = 5000;

  final String code;
  final String description;

  String get trimmedCode => code.trim();
  String get trimmedDescription => description.trim();

  String? get codeError {
    if (trimmedCode.isEmpty) return 'Give the target a code, such as the one painted beside it.';
    if (trimmedCode.length > maxCodeLength) return 'Keep the code under $maxCodeLength characters.';
    return null;
  }

  String? get descriptionError {
    if (trimmedDescription.isEmpty) return 'Say what the target shows. The studio needs it for the profile.';
    if (trimmedDescription.length > maxDescriptionLength) {
      return 'Keep the description under $maxDescriptionLength characters.';
    }
    return null;
  }

  bool get isValid => codeError == null && descriptionError == null;

  /// Codes are told apart the way the dashboard and the studio tell them apart.
  static String normalized(String code) => code.trim().toLowerCase();
}
