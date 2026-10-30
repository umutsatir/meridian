import SwiftUI
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Helpers for rendering views to PNG inside `swift test` (no app, no window).
enum RenderSupport {
    /// Registers every `.ttf`/`.otf` in `MERIDIAN_FONTS_DIR` (Inter, Barlow Condensed ...), once. Returns the number of files.
    @discardableResult
    static func registerFonts() -> Int {
        guard let dir = ProcessInfo.processInfo.environment["MERIDIAN_FONTS_DIR"],
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return 0 }
        var n = 0
        for f in files where f.hasSuffix(".ttf") || f.hasSuffix(".otf") {
            if CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: dir + "/" + f) as CFURL, .process, nil) { n += 1 }
        }
        return n
    }

    /// Output directory for rendered PNGs: `MAPS_OUT` or a temp dir.
    static var outDir: URL {
        let path = ProcessInfo.processInfo.environment["MAPS_OUT"] ?? NSTemporaryDirectory() + "meridian-maps-out"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return URL(fileURLWithPath: path)
    }

    @MainActor
    static func render<V: View>(_ view: V, size: CGSize, scale: CGFloat = 1) -> CGImage? {
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height, alignment: .topLeading).clipped())
        r.scale = scale
        r.proposedSize = ProposedViewSize(size)
        return r.cgImage
    }

    /// Draws the image into a bitmap, which forces a lazily evaluated `CGImage` (ImageRenderer output) to be rasterized.
    static func rasterize(_ image: CGImage) {
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        _ = ctx.data
    }

    @discardableResult
    static func writePNG(_ image: CGImage, name: String) -> URL {
        let url = outDir.appendingPathComponent(name + ".png")
        if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }
        return url
    }
}
