#ifndef CI2C_H
#define CI2C_H

/// Selects the device address that later reads and writes on an i2c-dev descriptor talk to.
/// Swift cannot call ioctl() directly under musl, where it is only declared variadic.
int ci2c_select(int fd, int address);

#endif
