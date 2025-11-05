# Interactive Bézier Curve with Physics & Sensor Control

This submission includes a **Web** implementation (HTML Canvas + JavaScript) and an **iOS** implementation (Swift + CoreMotion + CADisplayLink). Both render a **cubic Bézier curve** that behaves like a springy rope and visualize **tangent vectors** along the curve. All math (curve and derivative), sampling, and physics are implemented manually.

---

## Files

- `index.html` — Web version (open directly in a browser).
- `BezierRope.swift` — iOS view controller + view. Drop into an Xcode iOS app target and set `BezierRopeViewController` as the root VC.
- `README.md` — this file.

---

## Math

Cubic Bézier with control points P0..P3:
\[
B(t) = (1-t)^3 P_0 + 3(1-t)^2 t\, P_1 + 3(1-t) t^2\, P_2 + t^3 P_3, \quad t \in [0,1]
\]

Derivative (tangent direction):
\[
B'(t) = 3(1-t)^2(P_1-P_0) + 6(1-t)t(P_2-P_1) + 3t^2(P_3-P_2)
\]

For rendering, the curve is **sampled** at uniform `t` steps (e.g., 100 segments). Tangents are drawn at `t = 0, 0.1, ..., 1` after normalizing `B'(t)` to a fixed short length.

---

## Physics (Spring + Damping)

Dynamic control points `P1` and `P2` chase **targets** (mouse on Web, mapped pitch/roll on iOS) using a second‑order spring‑damper:
\[
\mathbf{a} = -k(\mathbf{x}-\mathbf{x}_\mathrm{target}) - c\,\mathbf{v}
\]
Integrated per frame with semi‑implicit Euler:
\[
\mathbf{v} \pluseq \mathbf{a}\,\Delta t,\quad \mathbf{x} \pluseq \mathbf{v}\,\Delta t
\]

- **Stiffness `k`** controls how strongly the point is pulled back.
- **Damping `c`** removes oscillations (critical damping is around \(c \approx 2\sqrt{k}\) per axis in normalized units; here it’s tuned heuristically).

Time step is clamped for stability.

---

## Interaction

### Web (mouse/drag)
- Move the mouse or drag: `P1` and `P2` target positions are set to small offsets to the left/right of the pointer, so the rope bows naturally.
- HUD shows stiffness, damping, and FPS. Adjust with:
  - `↑/↓` stiffness, `←/→` damping, `R` reset.

### iOS (CoreMotion)
- Uses `CMMotionManager.deviceMotion` with an `xArbitraryZVertical` reference frame.
- `pitch` (x tilt) and `roll` (y tilt) map to vertical and horizontal offsets around screen center to define targets for `P1`/`P2`.
- `CADisplayLink` drives the update at ~60 FPS.

---

## Rendering

- Curve: polyline through sampled `B(t)` points.
- Tangents: short line segments centered at `B(t)` along the normalized `B'(t)` direction.
- Control polygon and control points are shown for clarity.

---

## Performance

- Both versions aim for **60 FPS**.
- JS version avoids allocations in the hot path and clamps Δt.
- iOS version uses Core Graphics with lightweight drawing.

---

## How to Run

### Web
1. Open `index.html` in a modern browser (Chrome, Safari, Firefox).
2. Move the mouse / drag to interact.

### iOS
1. Create a new iOS App project in Xcode (Storyboard or SwiftUI lifecycle).
2. Add `BezierRope.swift` to the target.
3. Make `BezierRopeViewController` your root view controller, e.g. in `SceneDelegate`:
   ```swift
   window = UIWindow(windowScene: windowScene)
   window?.rootViewController = BezierRopeViewController()
   window?.makeKeyAndVisible()
   ```
4. Run on a device (motion data is best on real hardware).

---

## Notes & Design Choices

- **No prebuilt Bézier/animation APIs** are used. All math is explicit.
- **Sampling density** (100 segments) balances quality and speed; increase if desired.
- **Tangent length** scales with the viewport for consistent visuals.
- **Stability**: Δt is clamped; parameters are tuned for a lively but stable response.

---

## Recording (30s max)

- **Web**: Use any screen recorder (e.g., built‑in macOS screenshot toolbar: `Shift+Cmd+5`) and capture the browser window while interacting.
- **iOS**: Use iOS built‑in screen recording from Control Center while moving the device.

