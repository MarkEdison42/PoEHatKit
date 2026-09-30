import Testing
@testable import PoEHatKit

@Suite struct FanHysteresisTests {
    // Hypothesis: on at 55 and above, off at 50 and below, and between the two the fan keeps its
    // state in both directions. A single-threshold implementation fails the 52-degree steps.
    @Test func holdsBetweenThresholds() throws {
        var fan = try #require(FanHysteresis(onAt: 55, offAt: 50))
        #expect(fan.update(celsius: 54.9) == false)
        #expect(fan.update(celsius: 55.0) == true)
        #expect(fan.update(celsius: 52.0) == true)
        #expect(fan.update(celsius: 50.1) == true)
        #expect(fan.update(celsius: 50.0) == false)
        #expect(fan.update(celsius: 52.0) == false)
    }

    // Hypothesis: an unreadable temperature runs the fan.
    @Test func unknownTemperatureRunsFan() throws {
        var fan = try #require(FanHysteresis(onAt: 55, offAt: 50))
        #expect(fan.update(celsius: nil) == true)
    }

    // Hypothesis: thresholds with off not below on are refused.
    @Test func refusesInvertedThresholds() {
        #expect(FanHysteresis(onAt: 50, offAt: 55) == nil)
        #expect(FanHysteresis(onAt: 50, offAt: 50) == nil)
    }
}

@Suite struct FramebufferTests {
    // Hypothesis: nothing to draw leaves every pixel dark.
    @Test func blank() {
        #expect(Framebuffer(lines: []).bytes == [UInt8](repeating: 0, count: 512))
        #expect(Framebuffer(lines: ["   "]).bytes == [UInt8](repeating: 0, count: 512))
    }

    // Hypothesis: character k of line n starts at x = 6k on page n. "|" in the 5x7 font is a single
    // full-height column in the middle of the cell (0x7F at column 2), so "  |" on line 1 lights
    // exactly byte 128 + 12 + 2 = 142.
    @Test func placesGlyphByLineAndColumn() {
        let fb = Framebuffer(lines: ["", "  |"])
        #expect(fb.bytes[142] == 0x7F)
        #expect(fb.bytes.enumerated().filter { $0.element != 0 }.map(\.offset) == [142])
    }

    // Hypothesis: the 22nd character is not drawn, so it cannot spill onto the next page. Its cell
    // would start at x = 126 and its middle column would be byte 128, the first of page 1.
    @Test func clipsAtTwentyOneColumns() {
        let fb = Framebuffer(lines: [String(repeating: "|", count: 22)])
        #expect(fb.page(0).filter { $0 == 0x7F }.count == 21)
        #expect(fb.page(1).allSatisfy { $0 == 0 })
    }

    // Hypothesis: a character outside printable ASCII draws as "?".
    @Test func unknownCharacterDrawsQuestionMark() {
        #expect(Framebuffer(lines: ["é"]) == Framebuffer(lines: ["?"]))
        #expect(Framebuffer(lines: ["?"]) != Framebuffer())
    }
}
