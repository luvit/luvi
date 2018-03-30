#include <stdint.h>

uint64_t lbit_rshift(uint64_t x, uint8_t n) {
  return x >> n;
}
uint64_t lbit_lshift(uint64_t x, uint8_t n) {
  return x << n;
}
uint64_t lbit_rol(uint64_t x, uint8_t n) {
  return (x << n) | (x >> (64 - n));
}
uint64_t lbit_ror(uint64_t x, uint8_t n) {
  return (x >> n) | (x << (64 - n));
}
uint64_t lbit_or(uint64_t x, uint64_t y) {
  return x | y;
}
uint64_t lbit_and(uint64_t x, uint64_t y) {
  return x & y;
}
uint64_t lbit_xor(uint64_t x, uint64_t y) {
  return x ^ y;
}
uint64_t lbit_not(uint64_t x) {
  return ~x;
}
