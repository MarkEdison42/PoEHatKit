import Testing
@testable import PoEHatKit

/// Stands in for the I2C bus, the hardware boundary: records what is written and answers reads
/// with a fixed byte.
final class RecordingBus: I2CBus {
    var writes: [[UInt8]] = []
    var readValue: UInt8
    init(readValue: UInt8 = 0xFF) { self.readValue = readValue }
    func write(_ bytes: [UInt8]) throws { writes.append(bytes) }
    func readByte() throws -> UInt8 { readValue }
}

@Suite struct SSD1306Tests {
    // Hypothesis: start sends Waveshare's commands as one command stream (control byte 0x00),
    // ending with display on (0xAF) and including the 32-row multiplex (0xA8 0x1F).
    @Test func startIsOneCommandStream() throws {
        let bus = RecordingBus()
        try SSD1306(bus: bus).start()
        #expect(bus.writes.count == 1)
        #expect(bus.writes[0].first == 0x00)
        #expect(bus.writes[0].last == 0xAF)
        #expect(bus.writes[0].count == 1 + 23)
        #expect(bus.writes[0].firstRange(of: [0xA8, 0x1F]) != nil)
    }

    // Hypothesis: each of the four pages is addressed (0xB0 + page, column 0 as 0x00 0x10) and
    // then given its 128 bytes after the data control byte 0x40, in page order.
    @Test func showWritesEachPage() throws {
        let bus = RecordingBus()
        var lines = ["", "", "", ""]
        lines[2] = "  |"    // lights byte 2 * 128 + 14
        try SSD1306(bus: bus).show(Framebuffer(lines: lines))
        #expect(bus.writes.count == 8)
        for p in 0..<4 {
            #expect(bus.writes[p * 2] == [0x00, 0xB0 + UInt8(p), 0x00, 0x10])
            #expect(bus.writes[p * 2 + 1].count == 129)
            #expect(bus.writes[p * 2 + 1].first == 0x40)
        }
        #expect(bus.writes[5][1 + 14] == 0x7F)
        #expect(bus.writes[5].dropFirst().filter { $0 != 0 }.count == 1)
        #expect(bus.writes[3].dropFirst().allSatisfy { $0 == 0 })
    }
}

@Suite struct PoEHatFanTests {
    // Hypothesis: the fan pin is bit 0, active low; the other seven pins are written back as read.
    @Test(arguments: [
        (read: UInt8(0xFF), on: true, written: UInt8(0xFE)),
        (read: UInt8(0xFE), on: false, written: UInt8(0xFF)),
        (read: UInt8(0x5A), on: true, written: UInt8(0x5A)),
        (read: UInt8(0x5A), on: false, written: UInt8(0x5B)),
    ])
    func fanBit(read: UInt8, on: Bool, written: UInt8) throws {
        let bus = RecordingBus(readValue: read)
        try PoEHatFan(bus: bus).set(on: on)
        #expect(bus.writes == [[written]])
    }
}
