import SwiftUI

@main
struct EncoXControlApp: App {
    @StateObject private var ble = BLEController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
        }
    }
}
