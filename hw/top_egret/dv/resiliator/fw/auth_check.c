// Unhardened byte-array authentication check for testing core fault detection.
// Handling the authentication result in assembly avoids compiler-dependent lowering:
//   Branchless: gpio = (compare - 1) XOR SUCCESS_WORD
//   Branching:  gpio = compare ? SUCCESS_WORD : FAILURE_WORD

#include <stdint.h>

#include "hw/vendor/kjnsen_resiliator/firmware/injection.h"

#define SECRET_LEN 4
#define GPIO_ADDR    0xff000000
#define SUCCESS_WORD 0xbf4a79cc
#define FAILURE_WORD 0x40b58633

// Differ in the final byte. Volatile prevents constant folding.
static volatile uint8_t kSecret[SECRET_LEN]  = {0x6c, 0x9a, 0x2f, 0x31};
static volatile uint8_t kAttempt[SECRET_LEN] = {0x6c, 0x9a, 0x2f, 0xce};

// Return 1 for a match. A volatile index preserves stack loads before branches.
__attribute__((noinline)) static int byte_array_compare(volatile uint8_t *a,
                                                        volatile uint8_t *b,
                                                        int len) {
  for (volatile int i = 0; i < len; i++) {
    if (a[i] != b[i]) {
      return 0;
    }
  }
  return 1;
}

int main(void) {
  // Start the injection window after setup.
  start_injecting();

  int r = byte_array_compare(kSecret, kAttempt, SECRET_LEN);

#if defined(VERDICT_BRANCHLESS)
  __asm__ volatile(
      "addi %0, %0, -1\n\t"   // r = r - 1
      "li   t0, %1\n\t"       // t0 = SUCCESS_WORD
      "xor  %0, %0, t0\n\t"   // r = (r - 1) XOR SUCCESS_WORD
      "li   t1, %2\n\t"       // t1 = GPIO_ADDR
      "sw   %0, 0(t1)\n\t"    // gpio = r
      : "+r"(r)
      : "i"(SUCCESS_WORD), "i"(GPIO_ADDR)
      : "t0", "t1", "memory");
#elif defined(VERDICT_BRANCH)
  __asm__ volatile(
      "li   t1, %2\n\t"       // t1 = GPIO_ADDR
      "beqz %0, 1f\n\t"       // if r == 0 (mismatch), report failure
      "li   t0, %1\n\t"       // t0 = SUCCESS_WORD
      "sw   t0, 0(t1)\n\t"
      "j    2f\n"
      "1:\n\t"
      "li   t0, %3\n\t"       // t0 = FAILURE_WORD
      "sw   t0, 0(t1)\n"
      "2:\n\t"
      : "+r"(r)
      : "i"(SUCCESS_WORD), "i"(GPIO_ADDR), "i"(FAILURE_WORD)
      : "t0", "t1", "memory");
#else
#error "define VERDICT_BRANCHLESS or VERDICT_BRANCH"
#endif

  // start.S reports failure if execution continues past the verdict.
  return 0;
}
