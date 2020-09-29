
// PH meter @komkrit 9/2020
// qr code  => {"ID":"pH-20420","apikey":"dZs11hNvVA41o3RDzjA4yQ","A":"-0.0226","B":"7.0752"}

#include <EEPROM.h>
#include "EEPROMAnything.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Time.h>
#include <TimeLib.h>
#include <BlynkSimpleEsp32.h>
#include <Adafruit_ADS1015.h>
#include <ArduinoJson.h>

#include <TFT_eSPI.h>
#include <SPI.h>
#include "WiFi.h"
#include <Wire.h>
#include "Button2.h"
#include "esp_adc_cal.h"

#define ADC_EN 14 //ADC_EN is the ADC detection enable port
#define ADC_PIN 34
#define BUTTON_1 35
#define BUTTON_2 0

Adafruit_ADS1115 ads;

TFT_eSPI tft = TFT_eSPI(135, 240); // Invoke custom library
Button2 btn1(BUTTON_1);
Button2 btn2(BUTTON_2);

char buff[512];
int vref = 1100;
int btnCick = false;

String voltage;
float battery_voltage;
String PH;
float pHdata;
String BLEStatus;
String ADCvalue;
String JsonBLEData;
float A, B;

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

BlynkTimer timer;

#define SERVICE_UUID "0000fff0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000fff1-0000-1000-8000-00805f9b34fb"

class MyServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    deviceConnected = true;
    BLEDevice::startAdvertising();
  };

  void onDisconnect(BLEServer *pServer)
  {
    deviceConnected = false;
  }
};

class MyCallbacks : public BLECharacteristicCallbacks
{
  void onWrite(BLECharacteristic *pCharacteristic)
  {
    std::string value = pCharacteristic->getValue();

    if (value.length() > 0)
    {
      if (value.find("{") != -1)
      {
        Serial.print("cmd-> ");
        Serial.println(value.c_str());

        // {"A":-0.0226,"B":7.0752}

        StaticJsonDocument<64> doc;
        deserializeJson(doc, value);
        A = doc["A"];
        B = doc["B"];
        Serial.println(A, 4);
        Serial.println(B, 4);
        EEPROM_writeAnything(10, A);
        EEPROM_writeAnything(20, B);
      }
      else
      {
        Serial.println("unknow command...");
      }
    }
  }

  //    void writeString(int add, String data) {
  //      int _size = data.length();
  //      for (int i = 0; i < _size; i++) {
  //        EEPROM.write(add + i, data[i]);
  //      }
  //      EEPROM.write(add + _size, '\0');
  //      EEPROM.commit();
  //    }
};

void espDelay(int ms)
{
  esp_sleep_enable_timer_wakeup(ms * 1000);
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH, ESP_PD_OPTION_ON);
  esp_light_sleep_start();
}

void updatePH()
{
  float multiplier = 0.0625F;
  //int16_t results = phReading.reading(ads.readADC_Differential_0_1());

  int16_t results = ads.readADC_Differential_0_1();
  Serial.print("Differential: ");
  Serial.print(results);
  Serial.print("(");
  Serial.print(results * multiplier);
  Serial.println("mV)");

  ADCvalue = String((results * multiplier), 3); //mV
  //pHdata = -0.0226 * ADCvalue.toFloat() + 7.0752;
  pHdata = A * ADCvalue.toFloat() + B;

  Serial.println(String(pHdata));

  JsonBLEData = "";
  DynamicJsonDocument doc(64);
  //  doc["Batt"] = String(battery_voltage, 2);
  //  doc["ADC"]  = ADCvalue;
  //  doc["pH"]   = String(pHdata, 2);

  //doc["B"] = String(battery_voltage, 2);
  doc["pH"] = String(pHdata, 2);
  serializeJson(doc, JsonBLEData);
  Serial.println(JsonBLEData);
}

void updateDisplay()
{
  uint16_t v = analogRead(ADC_PIN);
  battery_voltage = ((float)v / 4095.0) * 2.0 * 3.3 * (vref / 1000.0);

  voltage = "B:" + String(battery_voltage) + "V";
  PH = String(pHdata);
  //BLEStatus = "App Contected";

  //Serial.println(voltage);
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_GREEN);
  tft.setTextSize(5);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(PH, tft.width() / 2, tft.height() / 2);

  tft.setTextColor(TFT_WHITE);
  tft.setTextSize(2);
  tft.setTextDatum(TL_DATUM);
  tft.drawString(voltage, 150, 120);
  tft.setTextDatum(TR_DATUM);
  tft.drawString("ADC:" + ADCvalue, 1, 120);
  tft.setTextSize(1);
  tft.setTextDatum(TR_DATUM);
  tft.drawString(BLEStatus, 233, 10);
}

void button_init()
{
  btn1.setLongClickHandler([](Button2 &b) {
    btnCick = false;
    int r = digitalRead(TFT_BL);
    tft.setTextSize(2);
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_GREEN, TFT_BLACK);
    tft.setTextDatum(MC_DATUM);
    tft.drawString("Going to SLEEP Mode", tft.width() / 2, tft.height() / 2);
    //tft.drawString("Press again to wake up",  tft.width() / 2, tft.height() / 2 );
    espDelay(6000);
    digitalWrite(TFT_BL, !r);

    tft.writecommand(TFT_DISPOFF);
    tft.writecommand(TFT_SLPIN);
    //After using light sleep, you need to disable timer wake, because here use external IO port to wake up
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_TIMER);
    // esp_sleep_enable_ext1_wakeup(GPIO_SEL_35, ESP_EXT1_WAKEUP_ALL_LOW);
    esp_sleep_enable_ext0_wakeup(GPIO_NUM_35, 0);
    delay(200);
    esp_deep_sleep_start();
  });
  btn1.setPressedHandler([](Button2 &b) {
    Serial.println("Detect Voltage..");
    btnCick = true;
  });

  btn2.setPressedHandler([](Button2 &b) {
    btnCick = false;
    Serial.println("btn press wifi scan");
    //wifi_scan();
  });
}

void button_loop()
{
  btn1.loop();
  btn2.loop();
}

void M3Senddata()
{
  if (deviceConnected)
  {

    //    char M3value[]  = {0xFE, 0xFD, 0x1A, 0x01, 0x01, 0x6A, 0x0D, 0x0A};
    //    M3value[5] = random(70, 130);
    //    pCharacteristic->setValue((uint8_t*)&M3value, 8);

    pCharacteristic->setValue((char *)JsonBLEData.c_str());
    pCharacteristic->notify();
    delay(10);
  }
}

void setup()
{
  Serial.begin(115200);
  tft.init();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);
  espDelay(1000);

  uint64_t macAddress = ESP.getEfuseMac();
  uint64_t macAddressTrunc = macAddress << 40;
  uint16_t chipID = macAddressTrunc >> 40;
  String deviceName = "pH-" + String(chipID);
  Serial.println(deviceName);
  tft.setTextSize(2);
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("IoT pH Meter", tft.width() / 2, 35);
  tft.drawString(deviceName, tft.width() / 2, tft.height() / 2);

  espDelay(5000);

  EEPROM.begin(64);
  EEPROM_readAnything(10, A);
  EEPROM_readAnything(20, B);

  Serial.println("ioT-PH-Meter by Dr.Komkrit Chooruang");
  Serial.println(A, 4);
  Serial.println(B, 4);
  pinMode(ADC_EN, OUTPUT);
  digitalWrite(ADC_EN, HIGH);

  ads.setGain(GAIN_TWO); // 2x gain   +/- 2.048V  1 bit = 0.0625mV
  // ads.setGain(GAIN_FOUR);       // 4x gain   +/- 1.024V  1 bit = 0.03125mV
  // ads.setGain(GAIN_EIGHT);      // 8x gain   +/- 0.512V  1 bit = 0.015625mV
  // ads.setGain(GAIN_SIXTEEN);    // 16x gain  +/- 0.256V  1 bit = 0.0078125mV
  ads.begin();

  button_init();
  esp_adc_cal_characteristics_t adc_chars;
  esp_adc_cal_value_t val_type = esp_adc_cal_characterize((adc_unit_t)ADC_UNIT_1, (adc_atten_t)ADC1_CHANNEL_6, (adc_bits_width_t)ADC_WIDTH_BIT_12, 1100, &adc_chars);
  //Check type of calibration value used to characterize ADC
  if (val_type == ESP_ADC_CAL_VAL_EFUSE_VREF)
  {
    Serial.printf("eFuse Vref:%u mV", adc_chars.vref);
    Serial.println("");
    vref = adc_chars.vref;
  }
  else if (val_type == ESP_ADC_CAL_VAL_EFUSE_TP)
  {
    Serial.printf("Two Point --> coeff_a:%umV coeff_b:%umV\n", adc_chars.coeff_a, adc_chars.coeff_b);
  }
  else
  {
    Serial.println("Default Vref: 1100mV");
  }

  // Create the BLE Device
  BLEDevice::init(deviceName.c_str());

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_WRITE |
          BLECharacteristic::PROPERTY_NOTIFY |
          BLECharacteristic::PROPERTY_INDICATE);

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("Waiting a client connection to notify...");
  timer.setInterval(5000L, M3Senddata);
  timer.setInterval(3000L, updatePH);
  timer.setInterval(1000L, updateDisplay);
}

void loop()
{
  timer.run();
  button_loop();
  vTaskDelay(1); //15ms*1

  if (!deviceConnected && oldDeviceConnected)
  {
    delay(500);                  // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // restart advertising
    Serial.println("start advertising");
    oldDeviceConnected = deviceConnected;
    BLEStatus = "";
  }
  // connecting
  if (deviceConnected && !oldDeviceConnected)
  {
    // do stuff here on connecting
    oldDeviceConnected = deviceConnected;
    BLEStatus = "Connected";
  }
}