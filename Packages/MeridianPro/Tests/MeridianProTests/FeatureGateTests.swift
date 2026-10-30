import Testing
@testable import MeridianPro

@Suite struct FeatureGateTests {
    static let allEntitlements: [Entitlement] = [.free, .pro(.lifetime), .pro(.annual), .pro(.monthly), .pro(.family)]

    @Test func proFeaturesNeedPro() {
        for feature in FeatureGate.proFeatures {
            #expect(!FeatureGate.isAvailable(feature, for: .free), "\(feature)")
            for e in Self.allEntitlements where e.isPro {
                #expect(FeatureGate.isAvailable(feature, for: e), "\(feature) \(e)")
            }
        }
    }

    @Test func everyoneGetsFreeFeatures() {
        for feature in FeatureGate.freeFeatures {
            for e in Self.allEntitlements { #expect(FeatureGate.isAvailable(feature, for: e), "\(feature) \(e)") }
        }
    }

    @Test func friendLimitsAreFourAndTwelve() {
        #expect(FeatureGate.friendLimit(for: .free) == 4)
        for e in Self.allEntitlements where e.isPro { #expect(FeatureGate.friendLimit(for: e) == 12) }
    }

    /// PRD §13: a feature that was free is never moved behind Pro. If this
    /// test fails, the change breaks the promise; do not edit the snapshot.
    @Test func freeFeaturesNeverShrink() {
        let promisedFree: Set<Feature> = [
            .unlimitedFlights, .mapTerra, .mapMonochrome, .mapStandard, .windowView,
            .coreSoundscapes, .announcements, .tickets, .wallet, .passport, .stats,
            .menuBar, .miniMap, .widgets, .friendFlightsSmall,
        ]
        #expect(promisedFree.isSubset(of: FeatureGate.freeFeatures))
        #expect(FeatureGate.proFeatures == [.mapSatellite, .flyoverViews, .extraSoundscapes, .friendFlightsLarge])
    }

    @Test func freeAndProPartitionAllFeatures() {
        #expect(FeatureGate.freeFeatures.isDisjoint(with: FeatureGate.proFeatures))
        #expect(FeatureGate.freeFeatures.union(FeatureGate.proFeatures) == Set(Feature.allCases))
    }
}
