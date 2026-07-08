#include "Arduino.h"
#include "HardwareSerial.h"
#include <SD.h>

// Read-only persistence check (Phase-B, Task 7): reads the file a prior
// sd_fs_test run wrote, WITHOUT creating or removing it.  A PASS after a full
// re-flash + fresh SD.begin() (card re-init + FAT re-mount) — or after a real
// power cycle — proves the file is genuinely persisted on the card, not held in
// any MCU RAM.  Expects sd_fs_test to have run first (it writes rttest.txt).
static const char* kName = "rttest.txt";
static const char* kMsg  = "RT1176 SD FAT works 0123456789";

void setup() {
  Serial1.begin(115200);
  while (!Serial1) {}

  if (!SD.begin(BUILTIN_SDCARD)) {
    Serial1.println("SD_PERSIST_MOUNT=FAIL");
    Serial1.println("SD_PERSIST_READ=FAIL");
    return;
  }
  Serial1.println("SD_PERSIST_MOUNT=PASS");

  File g = SD.open(kName, FILE_READ);
  bool ok = false;
  if (g) {
    char buf[64] = {0};
    int n = g.read(buf, sizeof(buf) - 1);
    g.close();
    ok = (n == (int)strlen(kMsg)) && memcmp(buf, kMsg, strlen(kMsg)) == 0;
  }
  Serial1.print("SD_PERSIST_READ="); Serial1.println(ok ? "PASS" : "FAIL");
}
void loop() {}
