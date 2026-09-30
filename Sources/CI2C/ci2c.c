#include "ci2c.h"
#include <sys/ioctl.h>

/// I2C_SLAVE from linux/i2c-dev.h, spelled out so this also compiles on macOS.
#define CI2C_SLAVE 0x0703

int ci2c_select(int fd, int address) {
    return ioctl(fd, CI2C_SLAVE, address);
}
