import CI2C
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#else
import Darwin
#endif

/// Plain byte reads and writes to one I2C address. The drivers take this rather than
/// `I2CDevice` so their byte sequences can be checked without a bus.
public protocol I2CBus {
    func write(_ bytes: [UInt8]) throws
    func readByte() throws -> UInt8
}

public enum I2CError: Error, CustomStringConvertible {
    case open(String, errno: Int32)
    case address(String, UInt8, errno: Int32)
    case io(String, UInt8, errno: Int32)
    case short(String, UInt8)

    public var description: String {
        switch self {
        case .open(let p, let e): "cannot open \(p): \(String(cString: strerror(e)))"
        case .address(let p, let a, let e): "cannot select address 0x\(String(a, radix: 16)) on \(p): \(String(cString: strerror(e)))"
        case .io(let p, let a, let e): "no answer from 0x\(String(a, radix: 16)) on \(p): \(String(cString: strerror(e)))"
        case .short(let p, let a): "short transfer with 0x\(String(a, radix: 16)) on \(p)"
        }
    }
}

/// One device on a Linux i2c-dev bus (`/dev/i2c-1` on a Pi once `dtparam=i2c_arm=on`). Opening
/// succeeds whether or not anything answers at the address; the first transfer is what fails.
public final class I2CDevice: I2CBus {
    private let fd: Int32
    private let path: String
    private let address: UInt8

    public init(path: String, address: UInt8) throws {
        let fd = open(path, O_RDWR)
        guard fd >= 0 else { throw I2CError.open(path, errno: errno) }
        guard ci2c_select(fd, CInt(address)) >= 0 else {
            let e = errno; close(fd); throw I2CError.address(path, address, errno: e)
        }
        self.fd = fd
        self.path = path
        self.address = address
    }

    deinit { close(fd) }

    public func write(_ bytes: [UInt8]) throws {
        let n = bytes.withUnsafeBytes { Glue.write(fd, $0.baseAddress, $0.count) }
        guard n >= 0 else { throw I2CError.io(path, address, errno: errno) }
        guard n == bytes.count else { throw I2CError.short(path, address) }
    }

    public func readByte() throws -> UInt8 {
        var b: UInt8 = 0
        let n = Glue.read(fd, &b, 1)
        guard n >= 0 else { throw I2CError.io(path, address, errno: errno) }
        guard n == 1 else { throw I2CError.short(path, address) }
        return b
    }
}

/// The C library's read and write, which `I2CBus`'s own `write` shadows inside the class.
private enum Glue {
    static func write(_ fd: Int32, _ buf: UnsafeRawPointer?, _ n: Int) -> Int {
        #if canImport(Glibc)
        Glibc.write(fd, buf, n)
        #elseif canImport(Musl)
        Musl.write(fd, buf, n)
        #else
        Darwin.write(fd, buf, n)
        #endif
    }

    static func read(_ fd: Int32, _ buf: UnsafeMutableRawPointer?, _ n: Int) -> Int {
        #if canImport(Glibc)
        Glibc.read(fd, buf, n)
        #elseif canImport(Musl)
        Musl.read(fd, buf, n)
        #else
        Darwin.read(fd, buf, n)
        #endif
    }
}
