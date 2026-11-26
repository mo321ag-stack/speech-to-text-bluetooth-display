/* twi_i2c.c - ATmega32A TWI master. SDA = PC1 (pin 23), SCL = PC0 (pin 22). */
#include "config.h"
#include "twi_i2c.h"
#include <avr/io.h>

/* TWI status codes (datasheet, master transmitter) */
#define TW_START        0x08
#define TW_REP_START    0x10
#define TW_MT_SLA_ACK   0x18
#define TW_MT_DATA_ACK  0x28
#define TW_STATUS       (TWSR & 0xF8)

/* ~ several ms at 8 MHz: long enough for any byte at 100 kHz, short enough not to hang. */
#define TWI_WAIT_LOOPS  20000U

static uint32_t s_scl = TWI_SCL_HZ;

void twi_init(uint32_t scl_hz)
{
    s_scl = scl_hz;
    TWSR = 0;                                         /* prescaler 1 */
    TWBR = (uint8_t)(((F_CPU / scl_hz) - 16UL) / 2UL);/* 8 MHz, 100 kHz -> 32 */
    TWCR = (1 << TWEN);
    /* The LCD backpack has its own pull-ups; also enable the weak internal ones. */
    PORTC |= (1 << PC0) | (1 << PC1);
}

static twi_status_t wait_twint(void)
{
    uint16_t n = TWI_WAIT_LOOPS;
    while (!(TWCR & (1 << TWINT))) {
        if (--n == 0) {
            /* Bus is stuck: reset the TWI unit so the next transfer can try again. */
            TWCR = 0;
            twi_init(s_scl);
            return TWI_ERR_TIMEOUT;
        }
    }
    return TWI_OK;
}

twi_status_t twi_start(uint8_t addr7)
{
    TWCR = (1 << TWINT) | (1 << TWSTA) | (1 << TWEN);
    if (wait_twint() != TWI_OK) return TWI_ERR_TIMEOUT;
    if (TW_STATUS != TW_START && TW_STATUS != TW_REP_START) return TWI_ERR_START;

    TWDR = (uint8_t)(addr7 << 1);                     /* write direction */
    TWCR = (1 << TWINT) | (1 << TWEN);
    if (wait_twint() != TWI_OK) return TWI_ERR_TIMEOUT;
    if (TW_STATUS != TW_MT_SLA_ACK) return TWI_ERR_ADDR_NACK;
    return TWI_OK;
}

twi_status_t twi_write(uint8_t data)
{
    TWDR = data;
    TWCR = (1 << TWINT) | (1 << TWEN);
    if (wait_twint() != TWI_OK) return TWI_ERR_TIMEOUT;
    if (TW_STATUS != TW_MT_DATA_ACK) return TWI_ERR_DATA_NACK;
    return TWI_OK;
}

void twi_stop(void)
{
    uint16_t n = TWI_WAIT_LOOPS;
    TWCR = (1 << TWINT) | (1 << TWSTO) | (1 << TWEN);
    while ((TWCR & (1 << TWSTO)) && --n) { }
}

twi_status_t twi_probe(uint8_t addr7)
{
    twi_status_t s = twi_start(addr7);
    twi_stop();
    return s;
}

twi_status_t twi_write_bytes(uint8_t addr7, const uint8_t *data, uint8_t n)
{
    twi_status_t s = twi_start(addr7);
    for (uint8_t i = 0; s == TWI_OK && i < n; i++) s = twi_write(data[i]);
    twi_stop();
    return s;
}
