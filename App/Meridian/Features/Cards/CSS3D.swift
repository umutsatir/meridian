import SwiftUI

/// Column-vector 4x4 matrix with the CSS transform functions the canvas uses (`translateZ`, `rotateY`, `scale`,
/// `perspective`). `projection()` returns the planar homography of the z = 0 plane for `GeometryEffect`.
nonisolated struct CSSMat4 {
    var a: [Double]

    static let identity = CSSMat4(a: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])

    static func translate(_ x: Double, _ y: Double, _ z: Double = 0) -> CSSMat4 {
        var m = identity; m.a[3] = x; m.a[7] = y; m.a[11] = z; return m
    }
    static func scale(_ s: Double) -> CSSMat4 {
        var m = identity; m.a[0] = s; m.a[5] = s; m.a[10] = s; return m
    }
    static func rotateY(_ deg: Double) -> CSSMat4 {
        let r = deg * .pi / 180, c = cos(r), s = sin(r)
        var m = identity; m.a[0] = c; m.a[2] = s; m.a[8] = -s; m.a[10] = c; return m
    }
    static func rotateX(_ deg: Double) -> CSSMat4 {
        let r = deg * .pi / 180, c = cos(r), s = sin(r)
        var m = identity; m.a[5] = c; m.a[6] = -s; m.a[9] = s; m.a[10] = c; return m
    }
    static func perspective(_ d: Double) -> CSSMat4 {
        var m = identity; m.a[14] = -1 / d; return m
    }

    static func * (l: CSSMat4, r: CSSMat4) -> CSSMat4 {
        var o = [Double](repeating: 0, count: 16)
        for i in 0..<4 { for j in 0..<4 { var s = 0.0; for k in 0..<4 { s += l.a[i * 4 + k] * r.a[k * 4 + j] }; o[i * 4 + j] = s } }
        return CSSMat4(a: o)
    }

    /// Maps element-local points (x, y, 0) to container points with the CSS perspective of the container.
    static func compose(elementTopLeft: CGPoint, origin: CGPoint, transform: CSSMat4,
                        perspective d: Double, perspectiveOrigin po: CGPoint) -> CSSMat4 {
        translate(po.x, po.y) * perspective(d) * translate(-po.x, -po.y)
            * translate(elementTopLeft.x, elementTopLeft.y)
            * translate(origin.x, origin.y) * transform * translate(-origin.x, -origin.y)
    }

    func projection() -> ProjectionTransform {
        var p = ProjectionTransform()
        p.m11 = a[0]; p.m12 = a[4]; p.m13 = a[12]
        p.m21 = a[1]; p.m22 = a[5]; p.m23 = a[13]
        p.m31 = a[3]; p.m32 = a[7]; p.m33 = a[15]
        return p
    }
}

/// A rectangle with a Gaussian-free elliptical radial glow (`radial-gradient(rx ry at cx cy, color, transparent stop)`).
struct EllipticalGlow: View {
    let color: Color
    var rx: Double = 0.7, ry: Double = 0.6, cx: Double = 0.62, cy: Double = 0.3, stop: Double = 0.7
    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            c.translateBy(x: cx * size.width, y: cy * size.height)
            c.scaleBy(x: rx * size.width, y: ry * size.height)
            let g = Gradient(stops: [.init(color: color, location: 0), .init(color: color.opacity(0), location: stop)])
            c.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)), with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: 1))
        }
        .allowsHitTesting(false)
    }
}
