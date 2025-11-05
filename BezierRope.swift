import UIKit
import CoreMotion

/// Interactive cubic Bézier "rope" driven by device motion (pitch/roll) and spring-damper physics.
/// Requirements satisfied:
/// - Manual cubic Bézier sampling and derivative for tangents
/// - No UIBezierPath used for the curve; rendered from sampled segments
/// - CoreMotion + CADisplayLink @ 60 FPS target
final class BezierRopeViewController: UIViewController {
    private let motion = CMMotionManager()
    private var displayLink: CADisplayLink?
    private var ropeView = BezierRopeView()

    // Physics parameters
    private var k: CGFloat = 18.0      // stiffness
    private var d: CGFloat = 7.0       // damping

    // Targets (based on pitch/roll)
    private var t1 = CGPoint.zero
    private var t2 = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.043, green: 0.059, blue: 0.078, alpha: 1.0)
        ropeView.backgroundColor = .clear
        ropeView.isOpaque = false
        view.addSubview(ropeView)
        ropeView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ropeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ropeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ropeView.topAnchor.constraint(equalTo: view.topAnchor),
            ropeView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Initial layout and targets
        ropeView.resetLayout()
        t1 = ropeView.p1
        t2 = ropeView.p2

        // Motion updates
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 60.0
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        }

        // Main loop
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
        motion.stopDeviceMotionUpdates()
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt = CGFloat(min(1.0/30.0, max(1.0/120.0, link.targetTimestamp - link.timestamp)))

        // Read motion (pitch ~ x tilt, roll ~ y tilt). Clamp for stability.
        if let dm = motion.deviceMotion {
            let pitch = CGFloat(dm.attitude.pitch)   // radians
            let roll  = CGFloat(dm.attitude.roll)    // radians

            // Map pitch/roll to target offsets around screen center
            let bounds = view.bounds
            let center = CGPoint(x: bounds.midX, y: bounds.midY)

            let scale: CGFloat = min(bounds.width, bounds.height) * 0.25
            let offX = max(-1, min(1, roll)) * scale
            let offY = max(-1, min(1, pitch)) * scale

            // P1 is left of center, P2 is right of center
            t1 = CGPoint(x: center.x - scale * 0.6 + offX * 0.6, y: center.y + offY)
            t2 = CGPoint(x: center.x + scale * 0.6 + offX * 0.6, y: center.y + offY)
        }

        // Integrate physics for p1/p2
        func integrate(p: inout CGPoint, v: inout CGPoint, target: CGPoint) {
            let disp = CGPoint(x: p.x - target.x, y: p.y - target.y)
            let ax = -k * disp.x - d * v.x
            let ay = -k * disp.y - d * v.y
            v.x += ax * dt
            v.y += ay * dt
            p.x += v.x * dt
            p.y += v.y * dt
        }

        integrate(p: &ropeView.p1, v: &ropeView.v1, target: t1)
        integrate(p: &ropeView.p2, v: &ropeView.v2, target: t2)

        ropeView.setNeedsDisplay()
    }
}

final class BezierRopeView: UIView {
    // Endpoints fixed; control points dynamic with velocities
    var p0 = CGPoint.zero
    var p3 = CGPoint.zero
    var p1 = CGPoint.zero
    var p2 = CGPoint.zero
    var v1 = CGPoint.zero
    var v2 = CGPoint.zero

    func resetLayout() {
        let w = bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width
        let h = bounds.height > 1 ? bounds.height : UIScreen.main.bounds.height
        p0 = CGPoint(x: 0.1*w, y: 0.5*h)
        p3 = CGPoint(x: 0.9*w, y: 0.5*h)
        p1 = CGPoint(x: 0.3*w, y: 0.4*h)
        p2 = CGPoint(x: 0.7*w, y: 0.6*h)
        v1 = .zero
        v2 = .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // keep endpoints anchored to edges on rotation/resize
        let w = bounds.width
        let h = bounds.height
        p0 = CGPoint(x: 0.1*w, y: 0.5*h)
        p3 = CGPoint(x: 0.9*w, y: 0.5*h)
    }

    // Cubic Bézier point
    private func B(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let tt = t*t, uu = u*u
        let uuu = uu*u, ttt = tt*t
        let x = uuu*p0.x + 3*uu*t*p1.x + 3*u*tt*p2.x + ttt*p3.x
        let y = uuu*p0.y + 3*uu*t*p1.y + 3*u*tt*p2.y + ttt*p3.y
        return CGPoint(x: x, y: y)
    }

    // Cubic Bézier derivative
    private func dB(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = 3*u*u*(p1.x-p0.x) + 6*u*t*(p2.x-p1.x) + 3*t*t*(p3.x-p2.x)
        let y = 3*u*u*(p1.y-p0.y) + 6*u*t*(p2.y-p1.y) + 3*t*t*(p3.y-p2.y)
        return CGPoint(x: x, y: y)
    }

    override func draw(_ rect: CGRect) {
        guard let g = UIGraphicsGetCurrentContext() else { return }
        let w = rect.width, h = rect.height

        // Background
        g.setFillColor(UIColor(red: 0.043, green: 0.059, blue: 0.078, alpha: 1.0).cgColor)
        g.fill(rect)

        // Subtle grid
        g.saveGState()
        g.setStrokeColor(UIColor(red: 0.063, green: 0.094, blue: 0.129, alpha: 1.0).cgColor)
        g.setLineWidth(1)
        g.setAlpha(0.25)
        let grid: CGFloat = 32
        var x: CGFloat = 0
        while x <= w {
            g.move(to: CGPoint(x: x, y: 0)); g.addLine(to: CGPoint(x: x, y: h)); g.strokePath()
            x += grid
        }
        var y: CGFloat = 0
        while y <= h {
            g.move(to: CGPoint(x: 0, y: y)); g.addLine(to: CGPoint(x: w, y: y)); g.strokePath()
            y += grid
        }
        g.restoreGState()

        // Curve polyline
        g.setStrokeColor(UIColor(red: 0.486, green: 0.780, blue: 1.0, alpha: 1.0).cgColor)
        g.setLineWidth(3)
        let samples = 100
        var t: CGFloat = 0
        let dt: CGFloat = 1.0 / CGFloat(samples)
        var first = true
        for _ in 0...samples {
            let pt = B(t)
            if first {
                g.move(to: pt)
                first = false
            } else {
                g.addLine(to: pt)
            }
            t += dt
        }
        g.strokePath()

        // Tangents
        g.setStrokeColor(UIColor(red: 0.62, green: 0.94, blue: 0.66, alpha: 1.0).cgColor)
        g.setLineWidth(1.5)
        let tangentLen = min(w, h) * 0.04
        for i in 0...10 {
            let tt = CGFloat(i) / 10.0
            let p = B(tt)
            var d = dB(tt)
            let L = max(1e-6, hypot(d.x, d.y))
            d.x /= L; d.y /= L
            let a = CGPoint(x: p.x - d.x * tangentLen * 0.5, y: p.y - d.y * tangentLen * 0.5)
            let b = CGPoint(x: p.x + d.x * tangentLen * 0.5, y: p.y + d.y * tangentLen * 0.5)
            g.move(to: a); g.addLine(to: b); g.strokePath()
        }

        // Control polygon
        g.setStrokeColor(UIColor(red: 0.941, green: 0.706, blue: 0.435, alpha: 1.0).cgColor)
        g.setLineWidth(1.5)
        g.move(to: p0); g.addLine(to: p1); g.addLine(to: p2); g.addLine(to: p3); g.strokePath()

        // Control points
        func dot(_ p: CGPoint, r: CGFloat, color: UIColor) {
            g.setFillColor(color.cgColor)
            g.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2*r, height: 2*r))
            g.fillPath()
        }
        dot(p0, 5, .systemRed)
        dot(p3, 5, .systemRed)
        dot(p1, 5, .systemYellow)
        dot(p2, 5, .systemYellow)
    }
}
