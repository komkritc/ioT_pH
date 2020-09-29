import 'package:http/http.dart' show get;
import 'dart:async';

class CovidServer {

  Future<void> uploadData(
      String lat, String lon, String temperature, String apikey) async {
    print('uploading data to server...');

    String  data = 'http://www.ie-advisor.net/covid19tracking/Api/updateData?temp=$temperature&&location_lat=$lat&&location_long=$lon&&apikey=$apikey';
    print(data);
    var response = await get(data);
    //var jsoncoviddata = json.decode(response.body);
    print(response.body);
    return response.body;
    //setState(() {});
  }
  
}
