import SwiftUI
import MeridianCore

struct ContentView: View {
    private let airportCount = (try? AirportIndex.bundled().airports.count) ?? 0

    var body: some View {
        Text("Meridian · \(airportCount) airports")
            .frame(minWidth: 960, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
