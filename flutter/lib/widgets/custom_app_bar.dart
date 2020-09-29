import 'package:flutter/material.dart';
import 'package:flutter_covid_dashboard_ui/config/palette.dart';
import 'package:flutter_covid_dashboard_ui/screens/screens.dart';
import 'package:android_intent/android_intent.dart';
//import '../screens/user_main.dart';

class CustomAppBar extends StatelessWidget with PreferredSizeWidget {
  _opensetting()  {
    final AndroidIntent intent = const AndroidIntent(
      action: 'action_application_details_settings',
      data: 'package:com.example.covid19tracker',
    );
    intent.launch();
  }

  Future<String> _asyncInputDialog(BuildContext context) async {
    String teamName = '';
    return showDialog<String>(
      context: context,
      barrierDismissible:
          false, // dialog is dismissible with a tap on the barrier
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter the password'),
          content: new Row(
            children: <Widget>[
              new Expanded(
                  child: new TextField(
                autofocus: true,
                // decoration: new InputDecoration(
                //     labelText: 'Team Name', hintText: 'eg. Juventus F.C.'),
                onChanged: (value) {
                  teamName = value;
                },
              ))
            ],
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Submit'),
              onPressed: () {
                if (teamName == '1234') {
                  _opensetting();
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Palette.primaryColor,
      elevation: 0.0,
      // leading: IconButton(
      //   icon: const Icon(Icons.sync),
      //   iconSize: 28.0,
      //   onPressed: () {},
      // ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.settings),
          iconSize: 28.0,
          onPressed: () {_asyncInputDialog(context);},
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
