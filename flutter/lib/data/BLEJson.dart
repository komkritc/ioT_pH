class BLEJsonData {
  String adc;

  BLEJsonData(this.adc);

  BLEJsonData.fromJson(Map<String, dynamic> parsedJson) {
    adc = parsedJson['A'];
  }
}
