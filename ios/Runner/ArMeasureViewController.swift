import ARKit
import SceneKit
import UIKit

/// Measures how wide a target is on the wall: aim at its left edge, then at its
/// right edge. The iPhone twin of Android's `ArMeasureActivity`, and the two must
/// measure the same thing; Thoth Guide AI gives this width to its image tracker.
///
/// The width is the **horizontal** distance between the two points. ARKit's world
/// Y axis follows gravity (`.gravity` is the default world alignment), so leaving
/// Y out means two points at slightly different heights can't inflate it.
///
/// It is read from anchors, not from where the points were first placed: ARKit
/// goes on correcting an anchor as it learns the room, and that correction is what
/// makes a span too long to fit in one view trustworthy.
final class ArMeasureViewController: UIViewController, ARSessionDelegate {
  enum Outcome {
    case measured(Double)
    case cancelled
    case unavailable(String)
  }

  /// Thoth drops a narrower target, so it isn't offered as a result.
  private static let minimumMeters = 0.01
  /// Below this ARKit's ambient estimate means the stone can't be seen well.
  private static let dimAmbientIntensity: CGFloat = 100

  private let onFinish: (Outcome) -> Void
  private var finished = false

  private let sceneView = ARSCNView()
  private let overlay = ArMeasureOverlayView()
  private let hintLabel = UILabel()
  private let distanceLabel = UILabel()
  private let primaryButton = UIButton(type: .system)
  private let undoButton = UIButton(type: .system)
  private let cancelButton = UIButton(type: .system)

  private var leftAnchor: ARAnchor?
  private var rightAnchor: ARAnchor?
  private var seenAnchors = Set<UUID>()
  private var lostTrackOfPoints = false
  private var displayLink: CADisplayLink?

  /// What the reticle is on right now, refreshed every frame.
  private var surface: simd_float4x4?

  init(onFinish: @escaping (Outcome) -> Void) {
    self.onFinish = onFinish
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("Created in code only")
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    buildViews()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    UIApplication.shared.isIdleTimerDisabled = true

    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal, .vertical]
    configuration.isAutoFocusEnabled = true
    configuration.isLightEstimationEnabled = true
    sceneView.session.delegate = self
    sceneView.session.run(configuration)

    let link = CADisplayLink(target: self, selector: #selector(refresh))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    UIApplication.shared.isIdleTimerDisabled = false
    displayLink?.invalidate()
    displayLink = nil
    sceneView.session.pause()
  }

  private func buildViews() {
    sceneView.translatesAutoresizingMaskIntoConstraints = false
    sceneView.automaticallyUpdatesLighting = false
    view.addSubview(sceneView)

    overlay.translatesAutoresizingMaskIntoConstraints = false
    overlay.isUserInteractionEnabled = false
    overlay.backgroundColor = .clear
    view.addSubview(overlay)

    distanceLabel.textColor = .white
    distanceLabel.font = .systemFont(ofSize: 40, weight: .medium)
    distanceLabel.textAlignment = .center
    distanceLabel.isHidden = true

    hintLabel.textColor = .white
    hintLabel.font = .systemFont(ofSize: 16)
    hintLabel.textAlignment = .center
    hintLabel.numberOfLines = 0
    hintLabel.text = "Starting the camera…"

    cancelButton.setTitle("Cancel", for: .normal)
    cancelButton.tintColor = .white
    cancelButton.contentHorizontalAlignment = .leading
    cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

    let top = UIStackView(arrangedSubviews: [cancelButton, distanceLabel, hintLabel])
    top.axis = .vertical
    top.spacing = 8
    top.translatesAutoresizingMaskIntoConstraints = false

    let topScrim = scrim()
    topScrim.addSubview(top)
    view.addSubview(topScrim)

    style(undoButton, title: "Undo", filled: false)
    undoButton.isHidden = true
    undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)

    style(primaryButton, title: "Set left edge", filled: true)
    primaryButton.isEnabled = false
    primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

    let bottom = UIStackView(arrangedSubviews: [undoButton, primaryButton])
    bottom.axis = .horizontal
    bottom.spacing = 12
    bottom.translatesAutoresizingMaskIntoConstraints = false

    let bottomScrim = scrim()
    bottomScrim.addSubview(bottom)
    view.addSubview(bottomScrim)

    let safe = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      sceneView.topAnchor.constraint(equalTo: view.topAnchor),
      sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      overlay.topAnchor.constraint(equalTo: view.topAnchor),
      overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      topScrim.topAnchor.constraint(equalTo: view.topAnchor),
      topScrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      topScrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      top.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
      top.bottomAnchor.constraint(equalTo: topScrim.bottomAnchor, constant: -12),
      top.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
      top.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),

      bottomScrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      bottomScrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bottomScrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottom.topAnchor.constraint(equalTo: bottomScrim.topAnchor, constant: 12),
      bottom.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
      bottom.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
      bottom.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
      bottom.heightAnchor.constraint(equalToConstant: 52),
      undoButton.widthAnchor.constraint(equalTo: primaryButton.widthAnchor, multiplier: 0.5),
    ])
  }

  private func scrim() -> UIView {
    let scrim = UIView()
    scrim.backgroundColor = UIColor(white: 0, alpha: 0.6)
    scrim.translatesAutoresizingMaskIntoConstraints = false
    return scrim
  }

  private func style(_ button: UIButton, title: String, filled: Bool) {
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    button.layer.cornerRadius = 12
    if filled {
      button.backgroundColor = .white
      button.setTitleColor(.black, for: .normal)
    } else {
      button.layer.borderWidth = 1
      button.layer.borderColor = UIColor.white.cgColor
      button.setTitleColor(.white, for: .normal)
    }
  }

  // MARK: - Each frame

  @objc private func refresh() {
    guard let frame = sceneView.session.currentFrame else { return }

    dropAnchorsIfLost(frame)

    var tracking = false
    if case .normal = frame.camera.trackingState { tracking = true }

    surface = tracking ? surfaceAtCentre() : nil

    let left = leftAnchor.flatMap { currentPosition(of: $0, in: frame) }
    let right = rightAnchor.flatMap { currentPosition(of: $0, in: frame) }
    let measuredTo = right ?? (left != nil ? surface.map(position(of:)) : nil)

    var distance: Double?
    if let left = left, let measuredTo = measuredTo {
      distance = horizontalDistance(left, measuredTo)
    }

    overlay.update(
      surfaceFound: surface != nil,
      left: tracking ? left.flatMap { screenPoint($0, in: frame) } : nil,
      right: tracking ? measuredTo.flatMap { screenPoint($0, in: frame) } : nil
    )

    showControls(frame: frame, tracking: tracking, leftSet: left != nil, rightSet: right != nil, distance: distance)
  }

  /// The nearest real surface under the reticle: a detected plane if there is one
  /// there, otherwise ARKit's estimate. Null when it can't see one.
  private func surfaceAtCentre() -> simd_float4x4? {
    let centre = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
    for target in [ARRaycastQuery.Target.existingPlaneGeometry, .estimatedPlane] {
      guard let query = sceneView.raycastQuery(from: centre, allowing: target, alignment: .any) else {
        continue
      }
      if let hit = sceneView.session.raycast(query).first {
        return hit.worldTransform
      }
    }
    return nil
  }

  /// An anchor ARKit has dropped after losing the room means nothing now. A new one
  /// only appears in the next frame, so missing counts once it has been seen.
  private func dropAnchorsIfLost(_ frame: ARFrame) {
    let present = Set(frame.anchors.map { $0.identifier })
    let placed = [leftAnchor, rightAnchor].compactMap { $0 }
    seenAnchors.formUnion(placed.map { $0.identifier }.filter { present.contains($0) })

    let lost = placed.contains { seenAnchors.contains($0.identifier) && !present.contains($0.identifier) }
    guard lost else { return }

    placed.forEach { sceneView.session.remove(anchor: $0) }
    leftAnchor = nil
    rightAnchor = nil
    seenAnchors.removeAll()
    lostTrackOfPoints = true
  }

  private func currentPosition(of anchor: ARAnchor, in frame: ARFrame) -> simd_float3? {
    let current = frame.anchors.first { $0.identifier == anchor.identifier } ?? anchor
    return position(of: current.transform)
  }

  private func position(of transform: simd_float4x4) -> simd_float3 {
    simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
  }

  private func horizontalDistance(_ a: simd_float3, _ b: simd_float3) -> Double {
    hypot(Double(a.x - b.x), Double(a.z - b.z))
  }

  /// Null when the point is behind the camera, where a projection is meaningless.
  private func screenPoint(_ point: simd_float3, in frame: ARFrame) -> CGPoint? {
    let inCamera = simd_mul(simd_inverse(frame.camera.transform), simd_float4(point, 1))
    guard inCamera.z < 0 else { return nil }
    let projected = sceneView.projectPoint(SCNVector3(point.x, point.y, point.z))
    return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
  }

  private func showControls(frame: ARFrame, tracking: Bool, leftSet: Bool, rightSet: Bool, distance: Double?) {
    let distanceText = distance.map { String(format: "%.2f m", locale: Locale(identifier: "en_US"), $0) }
    let measurable = (distance ?? 0) >= Self.minimumMeters

    let hint: String
    if !tracking {
      hint = trackingHint(frame)
    } else if lostTrackOfPoints {
      hint = "Tracking was lost. Set the edges again."
    } else if rightSet {
      hint = "Check the line runs along the edges, then use this width."
    } else if surface == nil {
      hint = "Move slowly and keep the wall in view until the ring turns green."
    } else if leftSet {
      hint = "Walk along the wall if you need to. Aim the ring at the right edge."
    } else {
      hint = "Aim the ring at the left edge of what the target shows."
    }

    if hintLabel.text != hint { hintLabel.text = hint }
    distanceLabel.text = distanceText
    distanceLabel.isHidden = distanceText == nil

    let title = rightSet ? "Use \(distanceText ?? "this width")" : (leftSet ? "Set right edge" : "Set left edge")
    if primaryButton.title(for: .normal) != title {
      UIView.performWithoutAnimation {
        primaryButton.setTitle(title, for: .normal)
        primaryButton.layoutIfNeeded()
      }
    }
    let enabled = rightSet ? (tracking && measurable) : (tracking && surface != nil)
    primaryButton.isEnabled = enabled
    primaryButton.alpha = enabled ? 1 : 0.4
    undoButton.isHidden = !leftSet
  }

  private func trackingHint(_ frame: ARFrame) -> String {
    if let light = frame.lightEstimate, light.ambientIntensity < Self.dimAmbientIntensity {
      return "Too dark. Add some light if you can."
    }
    switch frame.camera.trackingState {
    case .limited(.excessiveMotion):
      return "Moving too fast. Move the phone slowly."
    case .limited(.insufficientFeatures):
      return "Point at carved or patterned stone, not a plain area."
    default:
      return "Move the phone slowly from side to side."
    }
  }

  // MARK: - Actions

  @objc private func primaryTapped() {
    if let left = leftAnchor, let right = rightAnchor {
      guard let frame = sceneView.session.currentFrame,
        let from = currentPosition(of: left, in: frame),
        let to = currentPosition(of: right, in: frame)
      else { return }
      finish(.measured(horizontalDistance(from, to)))
      return
    }

    guard let surface = surface else { return }
    let anchor = ARAnchor(transform: surface)
    sceneView.session.add(anchor: anchor)
    if leftAnchor == nil {
      leftAnchor = anchor
    } else {
      rightAnchor = anchor
    }
    lostTrackOfPoints = false
  }

  @objc private func undoTapped() {
    if let right = rightAnchor {
      sceneView.session.remove(anchor: right)
      rightAnchor = nil
    } else if let left = leftAnchor {
      sceneView.session.remove(anchor: left)
      leftAnchor = nil
    }
  }

  @objc private func cancelTapped() {
    finish(.cancelled)
  }

  private func finish(_ outcome: Outcome) {
    guard !finished else { return }
    finished = true
    dismiss(animated: true) { [onFinish] in onFinish(outcome) }
  }

  // MARK: - ARSessionDelegate

  func session(_ session: ARSession, didFailWithError error: Error) {
    let reason: String
    switch (error as? ARError)?.code {
    case .cameraUnauthorized:
      reason = "AR needs permission to use the camera."
    case .unsupportedConfiguration:
      reason = "This phone doesn't support AR."
    default:
      reason = "AR isn't available on this phone right now."
    }
    DispatchQueue.main.async { [weak self] in self?.finish(.unavailable(reason)) }
  }
}

/// The reticle, the two points and the line between them, as seen from the phone right now.
private final class ArMeasureOverlayView: UIView {
  private var surfaceFound = false
  private var left: CGPoint?
  private var right: CGPoint?

  func update(surfaceFound: Bool, left: CGPoint?, right: CGPoint?) {
    self.surfaceFound = surfaceFound
    self.left = left
    self.right = right
    setNeedsDisplay()
  }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }

    context.setLineWidth(3)
    context.setStrokeColor(UIColor.white.cgColor)
    context.setFillColor(UIColor.white.cgColor)

    if let left = left, let right = right {
      context.move(to: left)
      context.addLine(to: right)
      context.strokePath()
    }
    for point in [left, right].compactMap({ $0 }) {
      context.fillEllipse(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
    }

    let found = UIColor(red: 76 / 255, green: 217 / 255, blue: 100 / 255, alpha: 1)
    context.setStrokeColor((surfaceFound ? found : UIColor.white).cgColor)
    let centre = CGPoint(x: bounds.midX, y: bounds.midY)
    context.strokeEllipse(in: CGRect(x: centre.x - 18, y: centre.y - 18, width: 36, height: 36))
    context.strokeEllipse(in: CGRect(x: centre.x - 2, y: centre.y - 2, width: 4, height: 4))
  }
}
