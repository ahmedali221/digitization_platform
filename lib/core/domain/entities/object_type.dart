/// What a record on a floor is a record of. The list is fixed here and
/// mirrored by the dashboard's `App\Enums\ObjectType` — a case added to one
/// must be added to the other. Each name is also the value sent over the API.
enum ObjectType {
  wall,
  painting,
  statue,
  stela,
  sarcophagus,
  other;

  /// A flat surface is shot as a grid and stitched; anything with sides is
  /// photographed as a set of images.
  bool get isFlat => this == wall || this == painting;

  CaptureMode get captureMode => isFlat ? CaptureMode.grid : CaptureMode.loose;

  static ObjectType fromWire(String? raw) => values.asNameMap()[raw] ?? wall;
}

/// How a record is photographed. A wall can be either; every other
/// [ObjectType] has exactly one (see [ObjectType.captureMode]).
enum CaptureMode {
  grid,
  loose;

  static CaptureMode fromWire(String? raw) => values.asNameMap()[raw] ?? grid;
}

/// The six sides an object is photographed from in organised capture, in the
/// order they are offered.
enum ObjectSide {
  front,
  back,
  left,
  right,
  top,
  bottom;

  static ObjectSide? fromWire(String? raw) => values.asNameMap()[raw];
}

/// Where an item created on a phone stands on a site that reviews such
/// items. Everything else is [accepted].
enum IntakeStatus {
  accepted,
  pending,
  rejected;

  static IntakeStatus fromWire(String? raw) =>
      values.asNameMap()[raw] ?? accepted;
}

/// What a site is. The hierarchy is identical; a museum only changes the
/// wording (halls and objects) and the type an add form starts on.
enum SiteKind {
  site,
  museum;

  static SiteKind fromWire(String? raw) => values.asNameMap()[raw] ?? site;
}
