/*
 * ============================================================
 * SmartAttend — ESP32 BLE Beacon Firmware
 * Continuously broadcasts classroom identity for Flutter to detect
 * ============================================================
 *
 * Hardware: ESP32 (any variant)
 * Library:  ESP32 BLE Arduino (built-in with esp32 board package)
 *
 * HOW IT WORKS:
 *   - ESP32 broadcasts a BLE advertisement packet every 100ms
 *   - Advertisement contains:
 *     - Device Name: "CLASSROOM_A101" (configurable below)
 *     - Service UUID: unique per classroom
 *   - Flutter app scans for devices starting with "CLASSROOM_" or "LAB_"
 *   - RSSI is measured by the phone to determine proximity
 *
 * CONFIGURATION:
 *   - Change CLASSROOM_NAME and CLASSROOM_UUID below
 *   - Flash to ESP32, no other setup needed
 *
 * ============================================================
 */

#include <BLEDevice.h>
#include <BLEAdvertising.h>
#include <BLEUtils.h>

// ─── CONFIGURATION ───────────────────────────────────────────
// Change these for each classroom ESP32

// Classroom identifier — must match your database 'room_name'
#define CLASSROOM_NAME "CLASSROOM_A101"

// Unique UUID for this classroom (generate one at https://www.uuidgenerator.net/)
// Must match your database 'ble_uuid' column
#define CLASSROOM_UUID "12345678-1234-1234-1234-1234567890AB"

// TX Power (advertised, not actual transmit power)
// Adjust for range calibration. Range: -100 to 20 dBm
#define TX_POWER_DBM -7

// Advertisement interval in ms (lower = more frequent = more battery)
#define ADV_INTERVAL_MIN 0x0040  // 40ms
#define ADV_INTERVAL_MAX 0x0060  // 60ms

// LED feedback (optional)
#define LED_PIN 2  // Built-in LED on most ESP32 boards
// ─────────────────────────────────────────────────────────────

BLEAdvertising* pAdvertising = nullptr;
bool ledState = false;

void setup() {
  Serial.begin(115200);
  delay(100);

  Serial.println();
  Serial.println("====================================");
  Serial.println("  SmartAttend ESP32 BLE Beacon");
  Serial.println("====================================");
  Serial.print("Classroom: ");
  Serial.println(CLASSROOM_NAME);
  Serial.print("UUID:      ");
  Serial.println(CLASSROOM_UUID);

  // ─── LED setup ─────────────────────────────────────────
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  // ─── BLE Initialization ────────────────────────────────
  BLEDevice::init(CLASSROOM_NAME);
  BLEDevice::setPower(ESP_PWR_LVL_P9);  // Max power for range

  // ─── Advertising Setup ─────────────────────────────────
  pAdvertising = BLEDevice::getAdvertising();

  // Build advertisement data
  BLEAdvertisementData advData;
  advData.setFlags(0x06);  // BR/EDR Not Supported | LE General Discoverable
  advData.setCompleteServices(BLEUUID(CLASSROOM_UUID));
  advData.setName(CLASSROOM_NAME);

  // Build scan response (extended name, TX power)
  BLEAdvertisementData scanRespData;
  scanRespData.setName(CLASSROOM_NAME);
  scanRespData.setTXPower(TX_POWER_DBM);

  pAdvertising->setAdvertisementData(advData);
  pAdvertising->setScanResponseData(scanRespData);

  // Set advertising interval
  pAdvertising->setMinInterval(ADV_INTERVAL_MIN);
  pAdvertising->setMaxInterval(ADV_INTERVAL_MAX);

  // ─── Start Advertising ─────────────────────────────────
  pAdvertising->start();

  Serial.println("✅ BLE Beacon broadcasting!");
  Serial.println("Waiting for SmartAttend app to scan...");
}

void loop() {
  // ─── Blink LED every 2s to indicate beacon is alive ────
  static unsigned long lastBlink = 0;
  if (millis() - lastBlink > 2000) {
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState ? HIGH : LOW);
    lastBlink = millis();

    // Print status to serial
    Serial.print("📡 Broadcasting: ");
    Serial.print(CLASSROOM_NAME);
    Serial.print(" | Uptime: ");
    Serial.print(millis() / 1000);
    Serial.println("s");
  }

  // ─── Keep advertising running ───────────────────────────
  // The BLE library handles advertising in the background.
  // No restart needed unless explicitly stopped.
  
  delay(100);
}

/*
 * ============================================================
 * MULTI-CLASSROOM DEPLOYMENT GUIDE
 * ============================================================
 *
 * For each classroom, flash a separate ESP32 with:
 *
 * CLASSROOM A101:
 *   CLASSROOM_NAME = "CLASSROOM_A101"
 *   CLASSROOM_UUID = "12345678-1234-1234-1234-1234567890AB"
 *
 * CLASSROOM A102:
 *   CLASSROOM_NAME = "CLASSROOM_A102"
 *   CLASSROOM_UUID = "12345678-1234-1234-1234-1234567890CD"
 *
 * CLASSROOM B201:
 *   CLASSROOM_NAME = "CLASSROOM_B201"
 *   CLASSROOM_UUID = "12345678-1234-1234-1234-1234567890EF"
 *
 * LAB CS01:
 *   CLASSROOM_NAME = "LAB_CS01"
 *   CLASSROOM_UUID = "12345678-1234-1234-1234-1234567890FF"
 *
 * These MUST match your database classrooms table exactly!
 *
 * ============================================================
 * SERIAL CONFIGURATION (Optional)
 * ============================================================
 *
 * You can configure the ESP32 via Serial commands:
 *   Send: "NAME=CLASSROOM_B101" to change room name
 *   Send: "STATUS" to print current config
 *
 * ============================================================
 * POWER TIPS
 * ============================================================
 *
 * - Power via USB from classroom plug
 * - OR use 18650 LiPo battery (runs ~72 hours at 40ms interval)
 * - Deep sleep between ads is NOT used here to keep BLE stable
 * - If battery life is critical, increase ADV_INTERVAL to 500ms
 *
 * ============================================================
 * RSSI CALIBRATION
 * ============================================================
 *
 * The SmartAttend Flutter app uses RSSI > -70 dBm to verify
 * classroom presence. Typical values:
 *
 * Distance  | RSSI
 * ----------+---------
 * 1m        | -40 to -55
 * 5m        | -55 to -65
 * 10m       | -65 to -75
 * Outside   | < -75
 *
 * Place ESP32 centrally in the classroom for best results.
 * ============================================================
 */
