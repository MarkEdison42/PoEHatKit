import Foundation
import Logging
import Testing
@testable import PoEHatKit

@Suite struct PoEHatLoopTests {
    // Hypothesis: cancelling the task ends run() at once, not after the refresh wait. With a
    // 60-second refresh, a loop whose sleep ignored cancellation would take a minute here. No hat is
    // present (the bus path does not exist), so this also shows a missing hat does not throw.
    @Test func cancellationEndsRunWithoutWaitingForRefresh() async throws {
        let config = PoEHat.Configuration(busPath: "/nonexistent/i2c-test", refresh: .seconds(60),
                                          thermalPath: "/nonexistent/temp")
        let hat = PoEHat(configuration: config, logger: Logger(label: "test")) { _ in [] }
        let clock = ContinuousClock()
        let started = clock.now
        let task = Task { await hat.run() }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        await task.value
        #expect(clock.now - started < .seconds(5))
    }
}
