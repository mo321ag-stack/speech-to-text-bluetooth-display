/* twi_i2c.h - ATmega32A hardware TWI (I2C) master driver with timeouts. */
#ifndef TWI_I2C_H
#define TWI_I2C_H

#include <stdint.h>

typedef enum {
    TWI_OK = 0,
    TWI_ERR_TIMEOUT,     /* bus stuck (no TWINT): wiring, missing pull-ups */
    TWI_ERR_START,       /* START condition not accepted */
    TWI_ERR_ADDR_NACK,   /* no device answered at this address */
    TWI_ERR_DATA_NACK    /* device refused a data byte */
} twi_status_t;

void         twi_init(uint32_t scl_hz);
twi_status_t twi_start(uint8_t addr7);           /* START + SLA+W */
twi_status_t twi_write(uint8_t data);
void         twi_stop(void);
/* START + address + STOP; TWI_OK if a device ACKs. */
twi_status_t twi_probe(uint8_t addr7);
/* One complete transaction: START, address, n bytes, STOP. */
twi_status_t twi_write_bytes(uint8_t addr7, const uint8_t *data, uint8_t n);

#endif
