import SwiftUI
import Testing
@testable import MeridianUI
#if canImport(AppKit)
import AppKit

/// Opt-in: `MR_GALLERY_OUT=/dir swift test --filter GalleryRender` writes gallery-dark.png / gallery-light.png.
@Suite @MainActor struct GalleryRenderTests {
    @Test func rendersGallery() throws {
        guard let dir = ProcessInfo.processInfo.environment["MR_GALLERY_OUT"] else { return }
        MRFonts.register()
        for dark in [true, false] {
            let r = ImageRenderer(content: MRGallery(dark: dark, scrolls: false).frame(width: 1100, height: 1500))
            r.scale = 2
            let image = try #require(r.nsImage)
            let tiff = try #require(image.tiffRepresentation)
            let rep = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(rep.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("gallery-\(dark ? "dark" : "light").png"))
        }
    }
}
#endif
