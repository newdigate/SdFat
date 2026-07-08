#include "Arduino.h"
#include "HardwareSerial.h"
#include <SdFat.h>

// SdioCard is SdFat's raw SDIO backend (Phase A driver).
static SdioCard card;
static uint8_t pattern[512];
static uint8_t pio_buf[512];                 // any RAM is fine for the PIO/FIFO path
DMAMEM static uint8_t dma_buf[512] __attribute__((aligned(32)));  // OCRAM: DMA-reachable, 4-byte-aligned

// Write a known pattern to a sector, read it back, compare byte-exact.
static bool blockRoundTrip(uint8_t opt, uint8_t* buf) {
  if (!card.begin(SdioConfig(opt))) return false;
  if (card.sectorCount() == 0) return false;
  for (int i = 0; i < 512; i++) pattern[i] = (uint8_t)(i * 7 + (opt ? 0x5A : 0xA5));
  const uint32_t lba = 12345;
  memcpy(buf, pattern, 512);
  if (!card.writeSector(lba, buf)) return false;
  memset(buf, 0, 512);
  if (!card.readSector(lba, buf)) return false;
  return memcmp(buf, pattern, 512) == 0;
}

void setup() {
  Serial1.begin(115200);
  while (!Serial1) {}

  bool init_ok = card.begin(SdioConfig(FIFO_SDIO));
  Serial1.print("SD_INIT=");       Serial1.println(init_ok ? "PASS" : "FAIL");

  bool pio = blockRoundTrip(FIFO_SDIO, pio_buf);
  Serial1.print("SD_BLOCK_PIO=");  Serial1.println(pio ? "PASS" : "FAIL");

  bool dma = blockRoundTrip(DMA_SDIO, dma_buf);
  Serial1.print("SD_BLOCK_DMA=");  Serial1.println(dma ? "PASS" : "FAIL");
}
void loop() {}
