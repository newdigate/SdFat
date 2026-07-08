#include "Arduino.h"
#include "HardwareSerial.h"
#include <SD.h>

static const char* kName = "rttest.txt";
static const char* kMsg  = "RT1176 SD FAT works 0123456789";

void setup() {
  Serial1.begin(115200);
  while (!Serial1) {}

  if (!SD.begin(BUILTIN_SDCARD)) {
    Serial1.println("SD_FS_WRITE=FAIL");
    Serial1.println("SD_FS_READ=FAIL");
    Serial1.println("SD_FS_DIR=FAIL");
    return;
  }

  // --- write ---
  SD.remove(kName);
  File f = SD.open(kName, FILE_WRITE);
  bool wrote = false;
  if (f) {
    size_t n = f.write((const uint8_t*)kMsg, strlen(kMsg));
    f.close();
    wrote = (n == strlen(kMsg));
  }
  Serial1.print("SD_FS_WRITE="); Serial1.println(wrote ? "PASS" : "FAIL");

  // --- reopen + read back byte-exact ---
  File g = SD.open(kName, FILE_READ);
  bool readback = false;
  if (g) {
    char buf[64] = {0};
    int n = g.read(buf, sizeof(buf) - 1);
    g.close();
    readback = (n == (int)strlen(kMsg)) && memcmp(buf, kMsg, strlen(kMsg)) == 0;
  }
  Serial1.print("SD_FS_READ="); Serial1.println(readback ? "PASS" : "FAIL");

  // --- list root directory (expect at least our file) ---
  int count = 0;
  File root = SD.open("/");
  if (root) {
    for (File e = root.openNextFile(); e; e = root.openNextFile()) {
      count++;
      e.close();
    }
    root.close();
  }
  Serial1.print("SD_FS_DIR="); Serial1.println(count > 0 ? "PASS" : "FAIL");
}
void loop() {}
