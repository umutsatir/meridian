import Testing
import SwiftUI
@testable import MeridianUI

/// The tear runs the way the pointer is dragged, wherever the stub was grabbed.
@MainActor
@Suite struct TearDirectionTests {
    @Test func draggingLeftTearsFromTheRightEvenWhenGrabbedOnTheLeftHalf() {
        let t = TicketTearModel()
        t.begin(x: 100, y: 520)
        t.move(x: 60, y: 520)
        #expect(t.grab == .right)
        #expect(t.progress > 0)
    }

    @Test func draggingRightTearsFromTheLeftEvenWhenGrabbedOnTheRightHalf() {
        let t = TicketTearModel()
        t.begin(x: 250, y: 520)
        t.move(x: 300, y: 520)
        #expect(t.grab == .left)
        #expect(t.progress > 0)
    }

    @Test func smallJitterDoesNotPickADirection() {
        let t = TicketTearModel()
        t.begin(x: 180, y: 520)
        t.move(x: 182, y: 540)
        #expect(t.progress == 0)
        t.move(x: 170, y: 540)
        #expect(t.grab == .right && t.progress > 0)
    }

    @Test func aPartialTearKeepsItsSideWhenGrabbedAgain() {
        let t = TicketTearModel()
        t.begin(x: 300, y: 520)
        t.move(x: 240, y: 520)
        let p = t.progress
        t.end()
        #expect(t.grab == .right && p > 0)
        t.begin(x: 100, y: 520)
        t.move(x: 130, y: 520) // dragging right now closes the tear a little instead of switching sides
        #expect(t.grab == .right)
        #expect(t.progress < p)
    }

    @Test func pullingDownSwingsTheStubFurther() {
        let flat = TicketTearGeometry.piecePose(progress: 0.3, grab: .right, dy: 0, pull: 0)
        let down = TicketTearGeometry.piecePose(progress: 0.3, grab: .right, dy: 0, pull: 8)
        #expect(down.degrees > flat.degrees)
        let leftFlat = TicketTearGeometry.piecePose(progress: 0.3, grab: .left, dy: 0, pull: 0)
        let leftDown = TicketTearGeometry.piecePose(progress: 0.3, grab: .left, dy: 0, pull: 8)
        #expect(leftDown.degrees < leftFlat.degrees)
    }
}
