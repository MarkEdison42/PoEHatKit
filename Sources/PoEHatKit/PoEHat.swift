import Foundation
import Logging

/// Drives a Waveshare PoE HAT (B): four lines of your text on its OLED, and its fan by CPU
/// temperature. The display and the fan are separate chips and are opened, and given up on,
/// separately; a missing hat (or a Mac) costs one log line and a retry every `reopenDelay`, never
/// the program.
///
///     let hat = PoEHat(logger: logger) { status in
///         ["my-app", "all good", "", "CPU \(status.cpuCelsius ?? 0)C"]
///     }
///     let task = Task { await hat.run() }
///     ...
///     task.cancel()    // shows `stoppedLines` and leaves the fan running
public struct PoEHat: Sendable {
    public struct Configuration: Sendable {
        /// The i2c-dev bus the hat is on; `/dev/i2c-1` on a Pi once `dtparam=i2c_arm=on`.
        public var busPath: String
        public var fan: FanHysteresis
        /// How often the temperature is read, the fan set and the screen redrawn (only when the
        /// picture has changed).
        public var refresh: Duration
        /// How long to wait before trying again to open a chip that did not answer.
        public var reopenDelay: TimeInterval
        /// Millidegrees Celsius, as the Linux kernel reports the SoC temperature.
        public var thermalPath: String
        /// Shown when `run()` ends, since nothing will update the screen after that.
        public var stoppedLines: [String]

        public init(busPath: String = "/dev/i2c-1",
                    fan: FanHysteresis = FanHysteresis(onAt: 45, offAt: 40)!,
                    refresh: Duration = .seconds(2),
                    reopenDelay: TimeInterval = 30,
                    thermalPath: String = "/sys/class/thermal/thermal_zone0/temp",
                    stoppedLines: [String] = ["stopped"]) {
            self.busPath = busPath
            self.fan = fan
            self.refresh = refresh
            self.reopenDelay = reopenDelay
            self.thermalPath = thermalPath
            self.stoppedLines = stoppedLines
        }
    }

    /// What the hat knows, handed to the lines closure on every refresh.
    public struct Status: Sendable {
        /// nil when the temperature cannot be read.
        public var cpuCelsius: Double?
        public var fanOn: Bool
    }

    public let configuration: Configuration
    private let logger: Logger
    private let lines: @Sendable (Status) async -> [String]

    /// - Parameter lines: the text for the screen, up to four lines of `Framebuffer.columns`
    ///   characters; longer lines are cut at the right edge.
    public init(configuration: Configuration = Configuration(), logger: Logger,
                lines: @escaping @Sendable (Status) async -> [String]) {
        self.configuration = configuration
        self.logger = logger
        self.lines = lines
    }

    /// Runs until the calling task is cancelled.
    public func run() async {
        let busPath = configuration.busPath
        let reopenDelay = configuration.reopenDelay
        var fan = configuration.fan
        var display: SSD1306?
        var fanChip: PoEHatFan?
        var fanAnswered = false
        var shown: Framebuffer?
        var nextOpen = Date.distantPast
        var lastFailure: [String: String] = [:]

        // The same failure repeating (no hat, I2C not enabled) is said once at warning level and
        // then at debug.
        func failed(_ part: String, _ error: any Error) {
            let message = "\(error)"
            if lastFailure[part] == message {
                logger.debug("hat \(part): \(message)")
            } else {
                logger.warning("hat \(part): \(message); retrying every \(Int(reopenDelay)) s")
                lastFailure[part] = message
            }
        }

        logger.info("PoE HAT: \(busPath), fan on at \(fan.onAt) C, off at \(fan.offAt) C")
        while !Task.isCancelled {
            let now = Date()
            if (display == nil || fanChip == nil) && now >= nextOpen {
                nextOpen = now.addingTimeInterval(reopenDelay)
                if display == nil {
                    do {
                        let d = SSD1306(bus: try I2CDevice(path: busPath, address: SSD1306.address))
                        try d.start()
                        display = d
                        shown = nil
                        lastFailure["display"] = nil
                        logger.info("hat display: SSD1306 at 0x3c on \(busPath)")
                    } catch { failed("display", error) }
                }
                if fanChip == nil {
                    do {
                        fanChip = PoEHatFan(bus: try I2CDevice(path: busPath, address: PoEHatFan.address))
                        fanAnswered = false
                    } catch { failed("fan", error) }
                }
            }

            let celsius = readCelsius()
            let wasOn = fan.isOn
            let on = fan.update(celsius: celsius)
            if let chip = fanChip {
                // Written every pass, not only on change, so the fan is right again straight after
                // the expander loses power or the hat is reseated.
                do {
                    try chip.set(on: on)
                    if !fanAnswered { logger.info("hat fan: PCF8574 at 0x20 on \(busPath)"); fanAnswered = true }
                    lastFailure["fan"] = nil
                    if on != wasOn { logger.info("hat fan \(on ? "on" : "off") at \(celsius.map { String(format: "%.1f", $0) } ?? "unknown") C") }
                } catch { fanChip = nil; failed("fan", error) }
            }

            if let d = display {
                let frame = Framebuffer(lines: await lines(Status(cpuCelsius: celsius, fanOn: on)))
                if frame != shown {
                    do { try d.show(frame); shown = frame } catch { display = nil; failed("display", error) }
                }
            }

            // Returns early when the task is cancelled, so shutdown is never held up by the wait.
            try? await Task.sleep(for: configuration.refresh)
        }

        // Nothing will update the screen or the fan after this: say so, and leave the fan running.
        try? display?.show(Framebuffer(lines: configuration.stoppedLines))
        try? fanChip?.set(on: true)
    }

    private func readCelsius() -> Double? {
        guard let text = try? String(contentsOfFile: configuration.thermalPath, encoding: .utf8),
              let milli = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return milli / 1000
    }
}
