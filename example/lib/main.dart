import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rich_text_edit/rich_text_edit.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _controller = RichTextEditingController();

  var _focusNode = FocusNode();

  var _controller1 = TextEditingController();
  var _focusNode1 = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: RepaintBoundary(
                child: RichEditableText(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(color: Colors.red),
                  cursorColor: Colors.white,
                  backgroundCursorColor: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: RepaintBoundary(
                child: EditableText(
                  controller: _controller1,
                  focusNode: _focusNode1,
                  style: TextStyle(color: Colors.red),
                  cursorColor: Colors.white,
                  backgroundCursorColor: Colors.white,
                ),
              ),
            ),
          ),
          RaisedButton(
            onPressed: () {
              _controller.addSpan(WidgetSpan(
                  child: Image.asset(
                    "assets/emojis/emoji_00${1 + Random().nextInt(3)}.png",
                    width: 32,
                    height: 32,
                  )));

              _controller1.value = _controller1.value.copyWith(
                  text: _controller1.value.text + '\u0001'
              );
            },
            child: Text("Add Emoji"),
          )
        ],
      ),
    );
  }
}
