/// The Waveshare PoE HAT (B)'s 0.91" OLED: an SSD1306 at 0x3C wired for 128x32. The start-up
/// commands are Waveshare's own (PoE_HAT_B_code/python/lib/waveshare_POE_HAT_B/SSD1306.py),
/// sent as one command stream; they flip the image to suit how the hat sits on the Pi.
public struct SSD1306 {
    public static let address: UInt8 = 0x3C
    /// Control byte before a run of commands, and before a run of display RAM bytes.
    static let commands: UInt8 = 0x00
    static let data: UInt8 = 0x40
    static let startup: [UInt8] = [
        0xAE,             // display off
        0x40,             // start line 0
        0xB0,             // page 0
        0xC8,             // scan COM63..COM0 (vertical flip)
        0x81, 0xFF,       // contrast
        0xA1,             // segment remap (horizontal flip)
        0xA6,             // normal, not inverted
        0xA8, 0x1F,       // multiplex ratio: 32 rows
        0xD3, 0x00,       // no display offset
        0xD5, 0xF0,       // clock divide / oscillator
        0xD9, 0x22,       // pre-charge
        0xDA, 0x02,       // COM pins for 128x32
        0xDB, 0x49,       // VCOMH
        0x8D, 0x14,       // charge pump on
        0xAF,             // display on
    ]

    let bus: any I2CBus

    public init(bus: any I2CBus) { self.bus = bus }

    public func start() throws {
        try bus.write([Self.commands] + Self.startup)
    }

    /// Page addressing mode (the reset default): select each page and column 0, then its 128 bytes.
    public func show(_ frame: Framebuffer) throws {
        for p in 0..<Framebuffer.pages {
            try bus.write([Self.commands, 0xB0 | UInt8(p), 0x00, 0x10])
            try bus.write([Self.data] + frame.page(p))
        }
    }
}

/// The hat's fan, on bit 0 of a PCF8574 I/O expander at 0x20. The pin is active low: a clear bit
/// runs the fan (Waveshare's FAN_ON writes `read & 0xFE`). The other seven pins are read back and
/// written unchanged.
public struct PoEHatFan {
    public static let address: UInt8 = 0x20
    let bus: any I2CBus

    public init(bus: any I2CBus) { self.bus = bus }

    public func set(on: Bool) throws {
        let pins = try bus.readByte()
        try bus.write([on ? pins & 0xFE : pins | 0x01])
    }
}
