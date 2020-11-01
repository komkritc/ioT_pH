import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';

class About extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: CustomAppBar(),
        body: Container(
          margin: EdgeInsets.all(5.0),
          child: Column(
            children: <Widget>[
              //Text('This project was funded by Nakhon Phanom University'),
              Text(''),
              Container(margin: EdgeInsets.all(1)),
              Image.asset(
                'assets/images/logo.png',
                height: 220,
                width: 220,
              ),

              Container(margin: EdgeInsets.all(1)),
              // Text(
              //   'Developers',
              //   style: TextStyle(fontWeight: FontWeight.bold),
              // ),
              Container(margin: EdgeInsets.all(5)),
              footnote(),
              Container(margin: EdgeInsets.all(25)),
              wissava(),
              Container(margin: EdgeInsets.all(5)),
              komkrit(),
            ],
          ),
        ));
  }
}

Widget komkrit() {
  return Row(
    children: <Widget>[
      // Expanded(
      //   child: FittedBox(
      //     fit: BoxFit.contain, // otherwise the logo will be tiny
      //     child: Image.asset('assets/images/komkrit.gif'),
      //   ),
      // ),
      Expanded(
        child: Text('ผศ.ดร.คมกฤษณ์ ชูเรือง', textAlign: TextAlign.left),
      ),
      Expanded(
        child: Text('Mobile APP & Electronics', textAlign: TextAlign.right),
      ),
    ],
  );
}

Widget wissava() {
  return Row(
    children: <Widget>[
      // Expanded(
      //   child: FittedBox(
      //     fit: BoxFit.contain, // otherwise the logo will be tiny
      //     child: Image.asset('assets/images/komkrit.gif'),
      //   ),
      // ),
      Expanded(
        child: Text('นายวิศวะ กุลนะ', textAlign: TextAlign.left),
      ),
      Expanded(
        child: Text('Ideas & Experiments', textAlign: TextAlign.right),
      ),
    ],
  );
}

Widget footnote() {
  return Row(
    children: <Widget>[
      // Expanded(
      //   child: FittedBox(
      //     fit: BoxFit.contain, // otherwise the logo will be tiny
      //     child: Image.asset('assets/images/komkrit.gif'),
      //   ),
      // ),
      Expanded(
        child: Text('IoT pH Meter พัฒนาโดยความร่วมมือระหว่าง \n\nศูนย์วิจัยข้าวสกลนคร \nและ \nคณะวิศวกรรมศาสตร์ มหาวิทยาลัยนครพนม',
            textAlign: TextAlign.center),
      ),
    ],
  );
}
