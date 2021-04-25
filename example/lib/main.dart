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
  RichTextEditingController _controller;

  var _controller1 = TextEditingController();

  var _focusNode = FocusNode();

  var _tt = "工";

  @override
  void initState() {
    super.initState();
    _controller = RichTextEditingController(textToRichSpan: _textToRichSpan,text: "afasdfasdfsd");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: RichTextField(
                controller: _controller,
                maxLines: 2,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: TextField(
                controller: _controller1,
                maxLines: 2,
              ),
            ),
          ),
          RaisedButton(
            onPressed: () {
              _controller.addSpan('\uE001');
              // setState(() {
              //   _tt += "人";
              // });
            },
            child: Text("Add Emoji"),
          )
        ],
      ),
    );
  }

  Widget _textToRichSpan(String text) {
    switch (text) {
      case '\uE001':
        return Image.asset(
          'assets/emojis/emoji_002.png',
          width: 24,
          height: 24,
        );
    }
  }
}
