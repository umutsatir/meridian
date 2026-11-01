import SwiftUI

/// The `.paper::before` grain (240 pt tile, 55 % opacity, multiply) for app screens that draw their own paper
/// (the passport pages). Clip it to the page shape.
public struct MRPaperGrain: View {
    public init() {}
    public var body: some View { PaperGrain() }
}
