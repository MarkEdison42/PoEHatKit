# PoEHatKit

Swift drivers for the [Waveshare PoE HAT (B)](https://www.waveshare.com/wiki/PoE_HAT_(B)) on a
Raspberry Pi: four lines of text on its 0.91" OLED, and its fan switched by CPU temperature. No
Python, no framework: plain `/dev/i2c-1` reads and writes. It works with Hummingbird, Vapor or a
bare executable.

| Part | Chip | I2C address |
| --- | --- | --- |
| OLED, 128x32 | SSD1306 | 0x3C |
| Fan | PCF8574 I/O expander, pin 0, active low | 0x20 |

## Use

```swift
.package(url: "https://github.com/MarkEdison42/PoEHatKit.git", from: "0.1.0"),
...
.product(name: "PoEHatKit", package: "PoEHatKit"),
```

```swift
import PoEHatKit

let hat = PoEHat(logger: logger) { status in
    [
        "my-app 1.2",
        "all good",
        "",
        "CPU \(status.cpuCelsius.map { String(format: "%.1f", $0) } ?? "--")C  Fan \(status.fanOn ? "ON" : "OFF")",
    ]
}
let task = Task { await hat.run() }
// ... at shutdown:
task.cancel()
```

`run()` keeps going until its task is cancelled. Every `refresh` (2 s by default) it:

- reads the CPU temperature;
- sets the fan: on at 45 C and above, off at 40 C and below, and unchanged in between. It also
  runs if the temperature can't be read;
- asks your closure for the lines and redraws the screen, but only if the picture changed.

When cancelled, it shows `stoppedLines` (default `["stopped"]`) and leaves the fan running,
because nothing controls it after that.

Each line holds `Framebuffer.columns` (21) characters of the 5x7 font; longer text is cut at the
right edge, and anything outside printable ASCII shows as `?`.

If the hat is missing, or I2C is not enabled, or the program is running on a Mac, `run()` logs
one warning per chip and tries again every `reopenDelay` (30 s). It never throws. The display
and the fan are opened separately, so one can work without the other.

Everything is set in `PoEHat.Configuration`: bus path, fan thresholds
(`FanHysteresis(onAt:offAt:)`, nil unless off is below on), refresh, reopen delay, thermal file,
and stopped lines.

### With swift-service-lifecycle

To stop on graceful shutdown rather than cancellation:

```swift
struct HatService: Service {
    let hat: PoEHat
    func run() async throws { await cancelWhenGracefulShutdown { await hat.run() } }
}
```

### Lower level

`SSD1306`, `PoEHatFan` and `I2CDevice` can be used directly, and `Framebuffer(lines:)` renders
text in the page layout the SSD1306 expects. The drivers talk to an `I2CBus` protocol, so tests
can record the bytes instead of touching hardware.

## Pi setup

1. Enable I2C: uncomment `dtparam=i2c_arm=on` in `/boot/firmware/config.txt`, add `i2c-dev`
   to `/etc/modules`, then reboot. `sudo apt install i2c-tools` and `sudo i2cdetect -y 1`
   should then show `20` and `3c`.
2. Give the program's user the `i2c` group. For a systemd unit, that's
   `SupplementaryGroups=i2c`.

## Build notes

- `/dev/i2c-*` exists only on Linux. On macOS everything compiles and the tests run, and
  `run()` just logs that the bus is missing.
- The `I2C_SLAVE` ioctl goes through a small C target (`CI2C`), because Swift can't call
  `ioctl` under the static musl SDK. The package builds with both the glibc toolchain on a Pi
  and `--swift-sdk` static Linux cross-compiles.
- On this Mac (swift.org 6.4.0 via swiftly), run the tests with `./scripts/test-mac.sh`, not
  `swift test`; the script explains why.

## Origins

- The SSD1306 start-up commands, the addresses and the fan pin come from Waveshare's demo code
  (`PoE_HAT_B_code.zip`, 2019).
- The font is the classic public-domain 5x7 LCD font.
- It has been tested against the hat on a Raspberry Pi.

## Licence

MIT; see [LICENSE](LICENSE).
