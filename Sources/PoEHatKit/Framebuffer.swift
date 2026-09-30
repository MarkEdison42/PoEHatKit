/// A 128x32 one-bit image in SSD1306 page layout: four pages of 128 bytes, one byte per column of
/// eight pixels, least significant bit at the top. A set bit is a lit pixel.
public struct Framebuffer: Sendable, Equatable {
    public static let width = 128
    public static let pages = 4
    /// Characters per line of text: 6-pixel cells (5x7 glyph and a gap) across 128 pixels.
    public static let columns = 21
    public private(set) var bytes = [UInt8](repeating: 0, count: width * pages)

    public init() {}

    /// Up to four lines of text, one per page, in 6-pixel cells. Characters past the 21st and lines
    /// past the fourth are not drawn; anything outside printable ASCII draws as "?".
    public init(lines: [String]) {
        for (page, line) in lines.prefix(Self.pages).enumerated() {
            for (col, ch) in line.prefix(Self.columns).enumerated() {
                let x = page * Self.width + col * 6
                bytes.replaceSubrange(x..<x + 5, with: Font5x7.glyph(ch))
            }
        }
    }

    public func page(_ p: Int) -> ArraySlice<UInt8> {
        bytes[p * Self.width..<(p + 1) * Self.width]
    }
}

/// Fan on at `onAt` degrees and above, off at `offAt` and below, unchanged in between so it does not
/// cycle on and off around a single threshold. An unreadable temperature turns it on: running the
/// fan needlessly costs a little noise, not running it when needed costs the Pi.
public struct FanHysteresis: Sendable {
    public let onAt: Double
    public let offAt: Double
    public private(set) var isOn = false

    /// Nil unless `offAt` is below `onAt`.
    public init?(onAt: Double, offAt: Double) {
        guard offAt < onAt else { return nil }
        self.onAt = onAt
        self.offAt = offAt
    }

    @discardableResult
    public mutating func update(celsius: Double?) -> Bool {
        guard let t = celsius else { isOn = true; return isOn }
        if t >= onAt { isOn = true } else if t <= offAt { isOn = false }
        return isOn
    }
}
