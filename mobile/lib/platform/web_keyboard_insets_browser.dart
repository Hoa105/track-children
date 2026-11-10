import 'dart:js_interop';

import 'package:flutter/widgets.dart';

import 'keyboard_inset_layout.dart';

@JS('trackChildrenViewport.visibleHeight')
external double get _visibleHeight;
@JS('trackChildrenViewport.subscribe')
external JSFunction _subscribe(JSFunction listener);

class WebKeyboardInsets extends StatefulWidget {
  const WebKeyboardInsets({super.key, required this.child});
  final Widget child;
  @override
  State<WebKeyboardInsets> createState() => _WebKeyboardInsetsState();
}

class _WebKeyboardInsetsState extends State<WebKeyboardInsets> {
  JSFunction? unsubscribe;
  @override
  void initState() {
    super.initState();
    unsubscribe = _subscribe(
      (() {
        if (mounted) setState(() {});
      }).toJS,
    );
  }

  @override
  void dispose() {
    unsubscribe?.callAsFunction();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyboardInsetLayout(visibleHeight: _visibleHeight, child: widget.child);
}
