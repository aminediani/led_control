import 'package:flutter/material.dart';

class AnimeGlow extends StatefulWidget {
  // final double value;
  // final double min;
  // final double max;
  final Color colorglow;

  const AnimeGlow({
    Key key,
    // @required this.value,
    this.colorglow = Colors.black,
    // this.max = 1.0,
  }) :
        // assert(value != null),
        //       assert(min != null),
        //       assert(max != null),
        //       assert(min <= max),
        //       assert(value >= min && value <= max),
        super(key: key);
  @override
  _MyAnime createState() => _MyAnime();
}

class _MyAnime extends State<AnimeGlow> with SingleTickerProviderStateMixin {
  AnimationController _animationController;
  Animation _animationGlow;
  CurvedAnimation _animation;

  @override
  initState() {
    super.initState();
    _animationController = AnimationController(
      animationBehavior: AnimationBehavior.preserve,
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _animationController.repeat(reverse: true);
    _animation = CurvedAnimation(
      curve: Curves.easeInOut,
      parent: _animationController,
    );

    _animationGlow = Tween(begin: 2, end: 15).animate(_animationController)
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.colorglow,
              blurRadius: 5 + (_animation.value).toDouble() * 20,
              spreadRadius: 5 + (_animation.value).toDouble() * 15,
            )
            // blurRadius: (_animationGlow).value.toDouble()*1.0,
            // spreadRadius: (_animationGlow.value).toDouble()*1.0)
          ]),
    );
  }
}

// Color get _sliderColor {
//   return Colors.grey;
// }

// @override
// Widget build(BuildContext context) {
//   return LayoutBuilder(
//     builder: (BuildContext context, BoxConstraints constraints) {},
//   );
// }
