import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_covid_dashboard_ui/config/palette.dart';
import 'package:flutter_covid_dashboard_ui/config/styles.dart';
import 'package:flutter_covid_dashboard_ui/widgets/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import 'package:wakelock/wakelock.dart';
import 'dart:convert';
//import 'package:http/http.dart' show http;
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_scan/barcode_scan.dart' as qrScanner;
import 'package:flutter/services.dart';
import '../src/CovidServer.dart';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:background_location/background_location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maps_launcher/maps_launcher.dart';

class UserMain extends StatefulWidget {
  @override
  _UserMainState createState() => _UserMainState();
}

class _UserMainState extends State<UserMain>
    with AutomaticKeepAliveClientMixin, CovidServer {
  //Completer<GoogleMapController> _controller = Completer();

  qrScanner.ScanResult scanResult;
  String qrCodeData;

  String latitude = '';
  String longitude = '';
  String apikey;

  String _bleRxData = '';
  String _pHValue = '0.00';
  String _battery = '3.80';
  String _batteryStatus = '';
  String _id;
  String _a;
  String _b;

  Timer timer;

  //List<String> _events = [];

  //String TARGET_DEVICE_NAME; //E66+ 3A47
  String ble_TARGET_DEVICE_NAME;
  final String ble_SERVICE_UUID = "0000fff0-0000-1000-8000-00805f9b34fb";
  final String ble_CHARACTERISTIC_UUID = "0000fff1-0000-1000-8000-00805f9b34fb";

  bool scanFlag = false;
  String connectionText = "";

  FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult> scanSubScription;
  BluetoothDevice targetDevice;
  BluetoothCharacteristic tempCharacteristic;
  BluetoothCharacteristic stepsCharacteristic;
  String finalDateTime = '';

  loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _id = prefs.getString('ID') ?? 'pH-28452';
    _a = prefs.getString('A') ?? '-0.0226';
    _b = prefs.getString('B') ?? '7.0752';
    apikey = prefs.getString('apikey');
    print(_id);
    print(apikey);
    print(_a);
    print(_b);
  }

  startScan() {
    ble_TARGET_DEVICE_NAME = _id;
    //TARGET_DEVICE_NAME = "pH-001";

    //disconnectFromDevice();
    print("start looking for...$ble_TARGET_DEVICE_NAME");
    if (!scanFlag) {
      scanFlag = true;

      scanSubScription =
          flutterBlue.scan(timeout: Duration(seconds: 10)).listen((scanResult) {
        print("scanning");
        print(scanResult.device);
        connectionText = "scanning";
        if (scanResult.device.name.contains(ble_TARGET_DEVICE_NAME)) {
          print('DEVICE found');
          targetDevice = scanResult.device;
          connectToDevice();
          scanSubScription.cancel(); // ?
          stopScan();

          flutterBlue.stopScan(); //komkritc

          connectionText = "connecting";
        }
      }, onDone: () {
        connectionText = "none found";
        print("stopping scan");
        stopScan();
        //scanFlag = false;
      });
    }
  }

  stopScan() {
    scanSubScription?.cancel();
    scanSubScription = null;
  }

  connectToDevice() async {
    if (targetDevice == null) return;

    connectionText = "connecting";
    await targetDevice.connect();
    print('DEVICE CONNECTED');
    connectionText = "connected";
    discoverServices();
  }

  disconnectFromDevice() {
    if (targetDevice == null) return;

    targetDevice.disconnect();
    connectionText = "Device Disconnected";
    scanFlag = false;
    print(connectionText);
  }

  discoverServices() async {
    if (targetDevice == null) return;

    List<BluetoothService> services = await targetDevice.discoverServices();
    services.forEach((service) {
      // do something with service

      if (service.uuid.toString() == ble_SERVICE_UUID) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == ble_CHARACTERISTIC_UUID) {
            tempCharacteristic = characteristic;

            pHReading();
          }
        });
      }
    });
  }

  pHReading() async {
    if (tempCharacteristic == null) return;
    print('read the pH value ...');
    print(tempCharacteristic.uuid.toString());

    await tempCharacteristic.setNotifyValue(true);
    //await tempCharacteristic.read();
    tempCharacteristic.value.listen((value) {
      // do something with new value
      //print(value.toString());

      print(value);

      _bleRxData = utf8.decode(value);
      print(_bleRxData);

      if (_bleRxData.contains('{')) {
        var result = json.decode(_bleRxData);
        if (result['pH'] != null) {
          _pHValue = result['pH'];
        }
        if (result['Batt'] != null) {
          _battery = result['Batt'];
        }
        // _pHValue = result['pH'];
        // _battery = result['Batt'];
        print(_pHValue);
        print(_battery);

        if (double.parse(_battery) > 4.25) {
          _batteryStatus = 'Charged';
        }
        if (double.parse(_battery) >= 3.7 && double.parse(_battery) <= 4.25) {
          _batteryStatus = 'Good';
        }
        if (double.parse(_battery) <3.7) {
          _batteryStatus = 'Low -> Please charge battery!!!';
        }
      }

      // _bleRxData = utf8.decode(value);
      // print(_bleRxData);
      // var result = json.decode(_bleRxData);
      // _pHValue = result['pH'];
      // print(_pHValue);

      setState(() {});
    });
    // await tempCharacteristic.write([0x03, 0x18, 0x07, 0x00, 0x02, 0x68, 0xC4]);
    // await tempCharacteristic.write([0x02, 0x0E, 0x06, 0x00, 0x0F, 0xD8]);
    setState(() {});
  }

  cal_ESP32() async {
    if (tempCharacteristic == null) return;
    print('save config to ESP32 ...'); //{"A":-0.0226,"B":7.0752}
    String esp32Cal = "{\"A\":" + _a + "," + "\"B\":" + _b + "}";
    print(esp32Cal);
    var esp32 = utf8.encode(esp32Cal);
    await tempCharacteristic.write(esp32);
  }

  @override
  void initState() {
    super.initState();
    loadConfig();
    Wakelock.enable();

    _fastupdateLocation();

    Timer(Duration(seconds: 2), () {
      startScan();
    });

    Timer.periodic(Duration(seconds: 15), (timer) {
      refreshData();
    });
  }

  @override
  void dispose() {
    BackgroundLocation.stopLocationService();
    Wakelock.disable();
    super.dispose();
  }

  void uploaddata() {
    //apikey = 'dZs11hNvVA41o3RDzjA4yQ';
    // {"ID":"MC01","Date":"0/0/2000","Time":"0:0:0","Lat":"0.000000","Lon":"0.000000","pH":"6.00"}
    _updateLocation();
    pHReading();
    setState(() {});
  }

  void refreshData() {
    print('refresh data...');
    startScan();
    pHReading();
    _updateLocation();
    setState(() {});
  }

  Future qrScan() async {
    try {
      var options = qrScanner.ScanOptions(
        useCamera: -1,
        autoEnableFlash: false,
        android: qrScanner.AndroidOptions(
          aspectTolerance: 0.00,
          useAutoFocus: true,
        ),
      );

      var result = await qrScanner.BarcodeScanner.scan(options: options);

      setState(() => scanResult = result);
      qrCodeData = scanResult.rawContent;
      print(qrCodeData);

      if (qrCodeData.contains('{')) {
        var jsonresult = json.decode(qrCodeData);
        _id = jsonresult['ID'];
        apikey = jsonresult['apikey'];
        _a = jsonresult['A'];
        _b = jsonresult['B'];

        print('qr data:--->');
        print(_id);
        print(apikey);
        print(_a);
        print(_b);

        //{"A":-0.0226,"B":7.0752}

        final prefs = await SharedPreferences.getInstance();
        prefs.setString('ID', _id);
        prefs.setString('apikey', apikey);
        prefs.setString('A', _a);
        prefs.setString('B', _b);

        cal_ESP32();
      }
      // final prefs = await SharedPreferences.getInstance();
      // _id = prefs.getString('ID') ?? 'pH-001';
      // _a = prefs.getString('A') ?? '-0.0226';
      // _b = prefs.getString('B') ?? '7.0752';

      // obtain shared preferences
      // if (qrCodeData.length == 36) {
      //   apikey = qrCodeData;
      //   final prefs = await SharedPreferences.getInstance();
      //   prefs.setString('apikey', qrCodeData);
      //   disconnectFromDevice();
      //   //_getuserinfo();
      //   refreshData();
      // }

    } on PlatformException catch (e) {
      var result = qrScanner.ScanResult(
        type: qrScanner.ResultType.Error,
        format: qrScanner.BarcodeFormat.unknown,
      );

      if (e.code == qrScanner.BarcodeScanner.cameraAccessDenied) {
        setState(() {
          result.rawContent = 'The user did not grant the camera permission!';
        });
      } else {
        result.rawContent = 'Unknown error: $e';
      }
      setState(() {
        scanResult = result;
      });
    }
  }

  Future<void> _fastupdateLocation() async {
    Position position = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      //_currentPosition = position;
      //print(_currentPosition);
      latitude = position.latitude.toStringAsFixed(6);
      longitude = position.longitude.toStringAsFixed(6);
      print(latitude);
      print(longitude);
    });
  }

  Future<void> _updateLocation() async {
    // Position position = await Geolocator()
    //     .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    BackgroundLocation.startLocationService();
    await BackgroundLocation().getCurrentLocation().then((location) {
      //print("This is current Location" + location.longitude.toString());
      latitude = location.latitude.toStringAsFixed(6);
      longitude = location.longitude.toStringAsFixed(6);
      print(latitude);
      print(longitude);
      BackgroundLocation.stopLocationService();
    });
  }

  _makePostRequest() async {
    String url = 'https://maker.ifttt.com/trigger/ph_meter/with/key/' + apikey;
    print(url);
    Map<String, String> headers = {"Content-type": "application/json"};

    String json =
        '{\"ID\":\"$_id\",\"DateTime\":\"$finalDateTime\",\"Lat\":\"$latitude\",\"Lon\":\"$longitude\",\"pH\":\"$_pHValue\"}';
    String json2 = '{"value1":$json}';
    print(json);

    Response response = await post(url, headers: headers, body: json2);
    int statusCode = response.statusCode;
    print('http status code> $statusCode');
    if (statusCode == 200) {
      Fluttertoast.showToast(
          msg: "Data Successfully Saved",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.black,
          fontSize: 16.0);
    } else {
      Fluttertoast.showToast(
          msg: "Failed to Save Data !!!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.black,
          fontSize: 16.0);
    }
  }

  SliverToBoxAdapter _buildHeader(double screenHeight) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Palette.primaryColor,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40.0),
            bottomRight: Radius.circular(40.0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'IoT pH Meter',
              textAlign: TextAlign.center,
              style: const TextStyle(
                //fontFamily: 'Montserrat',
                color: Colors.white54,
                fontSize: 25.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '$_id',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FlatButton.icon(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5.0,
                    horizontal: 10.0,
                  ),
                  onPressed: qrScan, //uploaddata, //qrScan, //_updateLocation,
                  color: Colors.purple[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  icon: const Icon(
                    Icons.camera,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Scan QR',
                    style: Styles.buttonTextStyle,
                  ),
                  textColor: Colors.white,
                ),
              ],
            ),
            Text(
              ' Battery: $_batteryStatus',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.normal,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Text(
                //   'Last Update : $_last_update',
                //   style: const TextStyle(
                //     color: Colors.white,
                //     fontSize: 14.0,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
                // Text(
                //   'Last Temperature : $_last_temp °C',
                //   style: const TextStyle(
                //     color: Colors.white,
                //     fontSize: 14.0,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
                SizedBox(height: screenHeight * 0.01),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildUserStat(double screenHeight) {
    return SliverToBoxAdapter(
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20.0),
            child: Text(''),
          ),
          // Text('Lontitude'),
          //StatsGrid(),
          userStat(),
          const SizedBox(height: 20.0),
          Text('pH',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 31.0, fontWeight: FontWeight.w600)),
          const SizedBox(height: 15.0),
          Text('$_pHValue',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 80.0, fontWeight: FontWeight.w600)),

          const SizedBox(height: 30.0),
          FloatingActionButton.extended(
            onPressed: () {
              // Fluttertoast.showToast(
              //     msg: "Save data to Google Sheet.",
              //     toastLength: Toast.LENGTH_SHORT,
              //     gravity: ToastGravity.CENTER,
              //     timeInSecForIosWeb: 1,
              //     backgroundColor: Colors.white54,
              //     textColor: Colors.black,
              //     fontSize: 16.0);

              DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
              finalDateTime = dateFormat.format(DateTime.now());
              print(finalDateTime);
              _makePostRequest();
            },
            icon: Icon(Icons.cloud_upload),
            label: Text("Save"),
            backgroundColor: Colors.blue,
            splashColor: Colors.yellowAccent,
          ),
        ],
      ),
    );
  }

  Widget userStat() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.12,
      child: Column(
        children: <Widget>[
          Flexible(
            child: Row(
              children: <Widget>[
                _buildStatCard('Latitude', '$latitude', Colors.teal),
                _buildStatCard('Longitude ', '$longitude', Colors.teal),
              ],
            ),
          ),
          // Flexible(
          //   child: Row(
          //     children: <Widget>[
          //       _buildStatCard('ADC Value', '$_pHValue', Colors.teal),
          //       _buildStatCard('Battery', '$_pHValue ', Colors.teal),
          //       //_buildStatCard('Critical', 'N/A', Colors.purple),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Expanded _buildStatCard(String title, String count, MaterialColor color) {
    return Expanded(
      child: InkWell(
        onDoubleTap: () {
          MapsLauncher.launchCoordinates(
              double.parse(latitude), double.parse(longitude));
        },
        child: Container(
          width: 50.0,
          height: 70.0,
          margin: const EdgeInsets.all(5.0),
          padding: const EdgeInsets.all(5.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Column(
            //mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: CustomAppBar(),
      body: CustomScrollView(
        physics: ClampingScrollPhysics(),
        slivers: <Widget>[
          _buildHeader(screenHeight * 0.15),
          _buildUserStat(screenHeight * 0.7),
          //_buildYourOwnTest(screenHeight),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
