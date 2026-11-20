#ifndef INJECTION_H
#define INJECTION_H

// adjust this address, if necessary
#define RESILIATOR_GPIO_ADDR 0xff000000

#define resiliator_gpio (*(volatile unsigned int *)RESILIATOR_GPIO_ADDR)

#define start_injecting() (resiliator_gpio = 1)
#define end_injecting() (resiliator_gpio = 2)
#define success() (resiliator_gpio = 0xbf4a79cc)
#define failure() (resiliator_gpio = 0x40b58633)

#define success_if(cond) {               \
    /* arm success */                    \
    resiliator_gpio = 0xd739e749;        \
    if (cond) {                          \
        /* trigger success */            \
        resiliator_gpio = 0x28c618b6;    \
    } else {                             \
        failure();                       \
    }                                    \
}

#endif
