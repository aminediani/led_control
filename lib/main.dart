import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/io.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_statusbarcolor/flutter_statusbarcolor.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dotted_line/dotted_line.dart';
//import 'package:flutter_fluid_slider/flutter_fluid_slider.dart';
//import 'package:wave_progress_widget/wave_progress.dart';
//import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'mylib/wave_progress.dart';
import 'mylib/flutter_fluid_slider.dart';
import 'mylib/curved_navigation_bar.dart';
import 'mylib/animated_glow.dart';

//import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    FlutterStatusbarcolor.setStatusBarColor(Color(0x00FFFFFF));

    return MaterialApp(
      theme: ThemeData(fontFamily: 'EncodeSans', primarySwatch: Colors.blue),
      home: WebSocketLed(),
      debugShowCheckedModeBanner: false,
    );
  }
}

//apply this class on home: attribute at MaterialApp()
class WebSocketLed extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _WebSocketLed();
  }
}

class _WebSocketLed extends State<WebSocketLed> {
  List<Color> gradientColors = [
    const Color(0x7722D500),
    const Color(0x4402d39a),
  ];

  //pagecontrol
  int pageindex = 1;
  final PageController pagecontroller = PageController(initialPage: 1);
  bool navTaped = false;

  IOWebSocketChannel channel;
  bool connected = false; //boolean value to track if WebSocket is connected
  String textRec;
  bool firstconnection = false;

  double _slidervalue = 4.4;
  bool textHider = true;

  //Charger Param
  String voltagevalue = "--";
  String currentValue = "--";
  String hourscharge = "0";
  String minutescharge = "0";
  String secondescharge = "0";
  bool secondeschargelogic = false;
  int currentRefPWM = 0;
  bool chargeState = false;
  double initBatVoltage = 0.00;
  bool getResValue = false;
  int getResValueCounter = 0;

  //batt percentage
  double a = 1 / 1.4;
  double b = -3 / 1.4;
  double batRes = 1.04;
  double percentage = 0;

  //UI param
  double valueslideg = 0;
  double valueTextSize = 18;
  double titleTextSize = 10;
  Color valueTextColor = Colors.white;
  Color titleTextColor = Color(0x9EFFFFFF);
  List<double> dataListY = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  List<double> dataListYofVoltage = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  double dxloop = 0;
  String oldsecondescharge = "";

  String batteryState = "State";

  double chartWidth = 300;
  double chartWidthMin = 300;
  double prescale, scale;

  @override
  void initState() {
    connected = false;
    textRec = "";

    Future.delayed(Duration.zero, () async {
      channelconnect();
      //connect to WebSocket wth NodeMCU
    });

    Future.delayed(Duration(seconds: 3), () async {
      Timer.periodic(Duration(milliseconds: 300), (timer) {
        threadComm();
        //sleep(Duration(seconds: 1));
      });
    });
    super.initState();
  }

  getDataStream() {
    try {
      if (connected == true) {
        //print("Connected");
        if (firstconnection) {
          channel.sink.add("getpwmdata");
          firstconnection = false;
        } else {
          channel.sink.add("getalldata"); //sending Command to NodeMCU
        }
      } else {
        channelconnect();
        print("reconnecting...");
      }
    } catch (e) {
      print("error on **.");
    }
  }

  channelconnect() {
    try {
      channel =
          IOWebSocketChannel.connect("ws://192.168.0.1:81"); //channel IP : Port
      channel.stream.listen(
        (message) {
          setState(() {
            if (message == "connected") {
              connected = true; //message is "connected" from NodeMCU
              firstconnection = true;
            } else if (message.toString().startsWith('dt')) {
              voltagevalue = ""; //rest
              currentValue = "";
              hourscharge = "";
              minutescharge = "";
              secondescharge = ""; //rest
              textRec = message.toString();
              // print("TXTR" + textRec); //code TXTR
              int j = 0;
              if (textRec.substring(0, 2) == "dt") j = 2;
              if (textRec.substring(j, j + 1) == "i") j++;
              while (
                  j < textRec.length && !(textRec.substring(j, j + 1) == "v")) {
                currentValue += textRec.substring(j, j + 1);
                j++;
              }
              j++;
              while (
                  j < textRec.length && !(textRec.substring(j, j + 1) == "h")) {
                voltagevalue += textRec.substring(j, j + 1);
                j++;
              }
              j++;
              while (
                  j < textRec.length && !(textRec.substring(j, j + 1) == "m")) {
                hourscharge += textRec.substring(j, j + 1);
                j++;
              }
              j++;
              while (
                  j < textRec.length && !(textRec.substring(j, j + 1) == "s")) {
                minutescharge += textRec.substring(j, j + 1);
                j++;
              }
              j++;
              while (j <= textRec.length &&
                  !(textRec.substring(j, j + 1) == "e")) {
                secondescharge += textRec.substring(j, j + 1);
                j++;
              }
            } else if (message.toString().startsWith('sendpwm')) {
              String tmp0 = message.toString();
              tmp0 = tmp0.substring(7, tmp0.length);
              currentRefPWM = int.parse(tmp0);
            } else if (message.toString() == "poweron") {
              chargeState = true;
            } else if (message.toString() == "poweroff") {
              chargeState = false;
            }

            //battery_percentage_calculation base on the Resistance_value
            bool viHaveTrueValue =
                (voltagevalue != "--" && currentValue != "--");
            double tVoltage;
            double tCurrent;
            if (viHaveTrueValue) {
              tVoltage = double.parse(voltagevalue);
              tCurrent = double.parse(currentValue);
            }

            //--percentage setup
            if (voltagevalue == "--" ||
                currentValue == "--" ||
                tVoltage < 3.0) {
              percentage = 0;
            } else {
              double batVoltage = tVoltage - batRes * tCurrent * 0.001;
              // a and b for 3.0 to 4.4 -> 0% to 100%
              if (!getResValue) percentage = (a * batVoltage + b);
              if (percentage >= 1.0) percentage = 1.0;
            }

            //--get the intial BAT volatge
            if (connected && viHaveTrueValue && currentValue == "0") {
              //if (!getResValue)
              if (!chargeState) initBatVoltage = tVoltage;
              if (chargeState)
                getResValue = true;
              else
                getResValue = false;
              print("get intial Volatge" + initBatVoltage.toString());
            }

            //--Serie Resistance calculation after current rise up
            if (connected && viHaveTrueValue && tCurrent >= 50 && getResValue) {
              batRes = (double.parse(voltagevalue) - initBatVoltage) /
                  (tCurrent * 0.001);
              print(' get new resistance value: ' + batRes.toString());

              if (getResValueCounter <= 30) {
                getResValueCounter++; //recalcul res value
              } else {
                getResValue = false; //stop getting res value
                getResValueCounter = 0;
              }
            }

            //chart data insert
            if (connected && currentValue != "--" && voltagevalue != "--") {
              if (oldsecondescharge != secondescharge) {
                oldsecondescharge = secondescharge;

                //"0.01" due 10 factor of the Y axis max, see maxY in fl_chart
                double tmpchartdy;
                double tmpchartdyVolt;
                if (viHaveTrueValue) {
                  tmpchartdy = double.parse(currentValue) * 0.01;
                  tmpchartdyVolt = double.parse(voltagevalue);
                }
                if (dxloop <= 50) {
                  dataListY.add(tmpchartdy);
                  dataListYofVoltage.add(tmpchartdyVolt);
                  dxloop++; //max10
                } else {
                  dataListY.removeAt(0);
                  dataListY.add(tmpchartdy);

                  dataListYofVoltage.removeAt(0);
                  dataListYofVoltage.add(tmpchartdyVolt);

                  // print("VL: " +
                  //     dataListYofVoltage.length.toString() +
                  //     "IL: " +
                  //     dataListY.length.toString());
                }
              }
            }

            //battery state
            if (connected) {
              double tmpvolt;
              double tmpcurrent;
              if (viHaveTrueValue) {
                tmpvolt = double.parse(voltagevalue);
                tmpcurrent = double.parse(currentValue);
              }

              if (voltagevalue == "--")
                batteryState = "--";
              else if (getResValue) {
                batteryState = "Progess...";
              } else if (tmpvolt >= 2.5 && tmpcurrent >= 50) {
                batteryState = "Charging";
              } else if (tmpvolt >= 2.5 && tmpcurrent == 0) {
                batteryState = "Idle";
              } else if (tmpvolt == 0 && tmpcurrent == 0) {
                batteryState = "Unplugged";
              }
            }
          });
        },
        onDone: () {
          //if WebSocket is disconnected
          //print("Web socket is closed");
          setState(() {
            connected = false;
            voltagevalue = "--";
            currentValue = "--";
            batteryState = "--";
          });
        },
        onError: (error) {
          //print(error.toString());
        },
      );
    } catch (_) {
      //print("error on connecting to websocket.");
    }
  }

  Future<void> sendcmd(String cmd) async {
    if (connected == true) {
      if (cmd != "poweron" && cmd != "poweroff") {
        print("Send the valid command");
      } else {
        channel.sink.add(cmd); //sending Command to NodeMCU
      }
    } else {
      channelconnect(); //todo refrech
      print("Websocket is not connected.");
    }
  }

  Future<void> threadComm() async {
    //while (true) {
    getDataStream();
    //sleep(Duration(seconds: 1));
    //}
  }

  Future<void> sendCmdCustom(String cmd) async {
    if (connected == true) {
      channel.sink.add(cmd); //sending Command to NodeMCU
    } else {
      channelconnect(); //refrech
      print("Websocket is not connected.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F0F0),
      body: Container(
          // decoration: BoxDecoration(
          //   gradient: LinearGradient(
          //       colors: [Color(0xFF4081F8), Color(0xFF4098F8)],
          //       transform: GradientRotation(200.0)),
          // ),
          //alignment: Alignment.topLeft, //inner widget alignment to center
          padding: EdgeInsets.all(0),
          child: Stack(
            children: [
              Container(
                child: AnimatedCrossFade(
                  sizeCurve: Curves.bounceIn,
                  firstCurve: Curves.bounceIn,
                  //secondCurve: Curves.easeInOutQuart,
                  duration: const Duration(milliseconds: 2000),
                  firstChild: Container(
                    height: 100,
                    color: Color(0xFF22D400),
                  ),
                  secondChild: Container(
                    height: 100,
                    color: Colors.red,
                  ),
                  crossFadeState: connected
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                ),
                //color: connected ? Color(0xFF22D400) : Colors.red,
                height: 100.0,
                color: Colors.green,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    //color: Colors.black,
                    height: 33.0, //status bar height
                  ),
                  Container(
                      //id rectangle
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0xFF3777F5), Color(0xFF559DF9)],
                              transform: GradientRotation(0.0)),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Color(0xB94F92E7),
                                spreadRadius: 0,
                                blurRadius: 15,
                                offset: Offset(0, 5)),
                          ],
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(35),
                              bottomRight: Radius.circular(35),
                              topLeft: Radius.circular(35),
                              topRight: Radius.circular(35))),
                      width: double.infinity,
                      padding: EdgeInsets.only(
                          left: 10, top: 20, bottom: 15, right: 10),
                      child: Column(
                          //id 1er rectangle column
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              //crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              //title + network row
                              children: [
                                Text(
                                  " Charger Monitor",
                                  style: TextStyle(
                                    fontSize: 19.0,
                                    color: Color(0xFFFFFFFF),
                                    fontFamily: 'CenturyGothicB',
                                  ),
                                ),
                                Row(
                                  //network + icon
                                  children: [
                                    IconButton(
                                      iconSize: 22,
                                      icon: Icon(connected
                                          ? Icons.signal_wifi_4_bar
                                          : Icons.signal_wifi_off),
                                      color: connected
                                          ? Color(0xFF12D41A)
                                          : Colors.red,
                                      onPressed: () {},
                                    ),
                                    Container(
                                        alignment: Alignment.topLeft,
                                        child: connected
                                            ? Text(
                                                "Connected ",
                                                style: TextStyle(
                                                    fontSize: 13.0,
                                                    color: Colors
                                                        .white, //Color(0xFF12D41A), //green
                                                    fontFamily: 'EncodeSansB'),
                                              )
                                            : Text(
                                                "Disconnected",
                                                style: TextStyle(
                                                    fontSize: 13.0,
                                                    color: Colors.white,
                                                    fontFamily: 'EncodeSansB'),
                                              )),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 7,
                            ), //btw title & data grid
                            Padding(
                              padding: const EdgeInsets.all(
                                  15.0), //data grid padding
                              child: Row(
                                //data grid 1er row
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        voltagevalue + "V",
                                        style: TextStyle(
                                            color: valueTextColor,
                                            fontSize: valueTextSize,
                                            fontFamily: 'EncodeSansB'),
                                      ),
                                      Text(
                                        "Battery Volatge",
                                        style: TextStyle(
                                            height: 1.5,
                                            fontSize: titleTextSize,
                                            color: titleTextColor,
                                            fontFamily: 'EncodeSansB'),
                                      )
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentValue + "mA",
                                        style: TextStyle(
                                            color: valueTextColor,
                                            fontSize: valueTextSize,
                                            fontFamily: 'EncodeSansB'),
                                      ),
                                      Text(
                                        "Charging Current",
                                        style: TextStyle(
                                            height: 1.5,
                                            fontSize: titleTextSize,
                                            color: titleTextColor,
                                            fontFamily: 'EncodeSansB'),
                                      )
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (percentage * 100).toInt().toString() +
                                            "%",
                                        style: TextStyle(
                                            color: valueTextColor,
                                            fontSize: valueTextSize,
                                            fontFamily: 'EncodeSansB'),
                                      ),
                                      Text(
                                        "Level of Charge",
                                        style: TextStyle(
                                            height: 1.5,
                                            fontSize: titleTextSize,
                                            color: titleTextColor,
                                            fontFamily: 'EncodeSansB'),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              //crossAxisAlignment: CrossAxisAlignment.center,
                              //mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 15.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "--°C",
                                        style: TextStyle(
                                            color: valueTextColor,
                                            fontSize: valueTextSize,
                                            fontFamily: 'EncodeSansB'),
                                      ),
                                      Text(
                                        "Battery temp.",
                                        style: TextStyle(
                                            height: 1.5,
                                            fontSize: titleTextSize,
                                            color: titleTextColor,
                                            fontFamily: 'EncodeSansB'),
                                      )
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 30.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (int.parse(hourscharge) < 10
                                                ? "0"
                                                : "") +
                                            hourscharge +
                                            ":" +
                                            (int.parse(minutescharge) < 10
                                                ? "0"
                                                : "") +
                                            minutescharge +
                                            ":" +
                                            (int.parse(secondescharge) < 10
                                                ? "0"
                                                : "") +
                                            secondescharge,
                                        style: TextStyle(
                                            color: valueTextColor,
                                            fontSize: valueTextSize,
                                            fontFamily: 'EncodeSansB'),
                                      ),
                                      Text(
                                        "Charge Duration  ",
                                        style: TextStyle(
                                            height: 1.5,
                                            fontSize: titleTextSize,
                                            color: titleTextColor,
                                            fontFamily: 'EncodeSansB'),
                                      )
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 19),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        batteryState,
                                        style: TextStyle(
                                            color: valueTextColor,
                                            fontSize: 16,
                                            fontFamily: 'EncodeSansB'),
                                      ),
                                      Text(
                                        "Battery State",
                                        style: TextStyle(
                                            height: 1.5,
                                            fontSize: titleTextSize,
                                            color: titleTextColor,
                                            fontFamily: 'EncodeSansB'),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(
                              height: 12,
                            ),
                          ])),
                  Stack(children: [
                    Container(
                      height: 730.0 - 138.0,
                      child: PageView(
                        allowImplicitScrolling: true,
                        physics: BouncingScrollPhysics(),
                        onPageChanged: (indexp) {
                          if (navTaped) {
                            navTaped = false;
                          } else {
                            if (pageindex != indexp) {
                              setState(() {
                                pageindex = indexp;
                              });
                            }
                          }
                        },
                        scrollDirection: Axis.horizontal,
                        controller: pagecontroller,
                        children: <Widget>[
                          Container(
                            //1er Page
                            padding: EdgeInsets.only(
                                top: 0, left: 10, right: 10, bottom: 0),
                            child: ListView(
                              physics: BouncingScrollPhysics(),
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          color: Color(0xA94F92E7),
                                          spreadRadius: 0,
                                          blurRadius: 15,
                                          offset: Offset(0, 7)),
                                    ],
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(30)),
                                    gradient: LinearGradient(colors: [
                                      Color(0xFF4081F8),
                                      Color(0xC04098F8)
                                    ], transform: GradientRotation(200.0)),
                                  ),
                                  padding: EdgeInsets.all(10),
                                  margin: EdgeInsets.only(
                                      left: 10, right: 10, bottom: 15),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Current & Voltage Graphs",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontFamily: 'CenturyGothicB'),
                                  ),
                                ),
                                GestureDetector(
                                  //chart 1
                                  onDoubleTap: () {
                                    chartWidth = chartWidthMin;
                                  },
                                  onScaleStart: (ScaleStartDetails details) {
                                    prescale = chartWidth;
                                    print(prescale);
                                  },
                                  onScaleUpdate: (ScaleUpdateDetails datails) {
                                    setState(() {
                                      if (chartWidth >= chartWidthMin)
                                        chartWidth = prescale * datails.scale;
                                      else if (datails.scale >= 1)
                                        chartWidth = prescale * datails.scale;
                                    });
                                    print(chartWidth);
                                  },
                                  onScaleEnd: (ScaleEndDetails dd) {},
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 400, //with of blue container
                                        height: 350, //adjust the HEIGHT
                                        //chart1
                                        margin: EdgeInsets.all(20),

                                        decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black54,
                                                  spreadRadius: 0,
                                                  blurRadius: 15,
                                                  offset: Offset(0, 0)),
                                            ],
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(15)),
                                            gradient: LinearGradient(
                                                colors: [
                                                  Color(0xFF232d37),
                                                  Color(0xFF232d37)
                                                ],
                                                transform:
                                                    GradientRotation(200.0))
                                            //blue background
                                            // gradient: LinearGradient(
                                            //     colors: [
                                            //       Colors.blueAccent,
                                            //       Colors.blue
                                            //     ],
                                            //     transform:
                                            //         GradientRotation(200.0)),
                                            ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: 0,
                                              left: 0,
                                              top: 24,
                                              bottom: 60),
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            physics: BouncingScrollPhysics(),
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(
                                                    5), //hiding text in chart
                                                width: chartWidth, //chart width
                                                child: LineChart(
                                                  mainData(
                                                      flSpotData(dataListY)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        margin:
                                            EdgeInsets.only(top: 320, left: 60),
                                        child: Text(
                                          "Current of Charge VS Time(s)",
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  //chart2
                                  margin: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          color: Color(0xA9232d37),
                                          spreadRadius: 0,
                                          blurRadius: 15,
                                          offset: Offset(0, 7)),
                                    ],
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15)),
                                    gradient: LinearGradient(colors: [
                                      Color(0xFF232d37),
                                      Color(0xFF232d37)
                                    ], transform: GradientRotation(200.0)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        right: 0.0,
                                        left: 20.0,
                                        top: 24,
                                        bottom: 30),
                                    child: Stack(
                                      children: [
                                        Container(
                                          child: LineChart(
                                            mainData2(
                                                flSpotData(dataListYofVoltage)),
                                          ),
                                        ),
                                        Container(
                                          margin: EdgeInsets.only(
                                              top: 290, left: 40),
                                          child: Text(
                                            "Voltage of Charge VS Time(s)",
                                            style: TextStyle(
                                                color: Colors.white70),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 50,
                                )
                              ],
                            ),
                          ),
                          Container(
                            child: Column(
                              children: [
                                Container(
                                  //Circular Slider
                                  padding: const EdgeInsets.only(
                                      top: 25.0, bottom: 30),
                                  alignment: Alignment.center,
                                  child: Stack(
                                    alignment: AlignmentDirectional.center,
                                    children: [
                                      Container(
                                        width: 250,
                                        height: 250,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                              colors: [
                                                Color(0x0099FFD8),
                                                Color(0x00AFFAB4)
                                              ],
                                              transform:
                                                  GradientRotation(100.0)),
                                        ),
                                      ),
                                      Container(
                                        margin: EdgeInsets.all(10),
                                        width: 230,
                                        height: 230,
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                                color: Color(
                                                    0x003EFFB5), //replaced by Glow
                                                spreadRadius: 10,
                                                blurRadius: 20,
                                                offset: Offset(0, 0)),
                                            BoxShadow(
                                                color: Color(0x00FFE900),
                                                spreadRadius: 0,
                                                blurRadius: 5,
                                                offset: Offset(-5, -5))
                                          ],
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                              colors: [
                                                Color(0xFFF0F0F0),
                                                Color(0xFFFDEBE1)
                                              ],
                                              transform:
                                                  GradientRotation(100.0)),
                                        ),
                                      ),
                                      //Glow
                                      AnimeGlow(
                                          colorglow: Color(0xff3EFF55)
                                              .withOpacity(0.79)),
                                      //Wave
                                      Container(
                                        child: WaveProgress(
                                            230.0,
                                            Color(0x00FFFFFF), //wite
                                            //Color(0xff3EFF55),green
                                            Color(0xCF1F7CF6), //blue
                                            connected ? percentage * 100 : 50),
                                      ),
                                      //bubble Image:
                                      Opacity(
                                        opacity: 0.8,
                                        child: Container(
                                          width: 230,
                                          height: 230,
                                          child: Image.asset(
                                            "assets/bubble6.png",
                                            //color: Colors.blue.withOpacity(1),
                                            //colorBlendMode: BlendMode.screen,
                                            //filterQuality: FilterQuality.high,
                                          ),
                                        ),
                                      ),
                                      //slider sleek
                                      Container(
                                        padding: EdgeInsets.only(top: 0.0),
                                        child: SleekCircularSlider(
                                          appearance: CircularSliderAppearance(
                                            animDurationMultiplier: 1.5,
                                            counterClockwise: false,
                                            size: 250, //250
                                            startAngle: 180,
                                            angleRange: 300,
                                            customColors: CustomSliderColors(
                                                dotColor: Color(0xFF00FFF5),
                                                shadowColor: Color.fromRGBO(
                                                    50, 250, 251, 1.0),
                                                shadowMaxOpacity: 0.07,
                                                trackColor: Color.fromRGBO(
                                                    255, 255, 255, 0.0),
                                                progressBarColors: [
                                                  Color(0xFF11FFFF),
                                                  Color.fromRGBO(
                                                      0, 250, 250, 1.0),
                                                  Color.fromRGBO(
                                                      0, 250, 250, 0.0),
                                                ]),
                                            customWidths: CustomSliderWidths(
                                                handlerSize: 10, //7
                                                progressBarWidth: 10.0,
                                                //handlerSize: 10.0,
                                                shadowWidth: 30.0,
                                                trackWidth: 3.0),
                                          ),
                                          min: 50,
                                          max: 1000,
                                          initialValue: 800,
                                          onChange: (double valueslide) {
                                            //print(valueslide);
                                            setState(() {
                                              currentRefPWM =
                                                  valueslide.toInt();
                                            });
                                            sendCmdCustom("pwm" +
                                                currentRefPWM.toString());
                                          },
                                          onChangeEnd: (val) {
                                            setState(() {});
                                          },
                                          innerWidget: (double value) {
                                            //int val = value.toInt();
                                            return Container(
                                                alignment: Alignment.center,
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text('$currentRefPWM',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .black87,
                                                                fontFamily:
                                                                    'EncodeSansB',
                                                                fontSize: 35)),
                                                        Text(' mA',
                                                            style: TextStyle(
                                                                height: 2.1,
                                                                color: Colors
                                                                    .black87,
                                                                fontFamily:
                                                                    'EncodeSansB',
                                                                fontSize: 20)),
                                                      ],
                                                    ),
                                                    Text('  Current Limit',
                                                        style: TextStyle(
                                                            height: 1,
                                                            color: Colors.black,
                                                            fontFamily:
                                                                'EncodeSansB',
                                                            fontSize: 12)),
                                                  ],
                                                ));
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Stack(
                                  children: [
                                    Container(
                                      padding:
                                          EdgeInsets.only(top: 10, left: 7),
                                      height: 50,
                                      width: 200,
                                      child: Text("  Charge Volt.",
                                          style: TextStyle(
                                            fontSize: 18.0,
                                            color: Color(0xFFFFFFFF),
                                            fontFamily: 'EncodeSans',
                                          )),
                                      //titre bar
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                              color: Color(0xA94F92E7),
                                              spreadRadius: 0,
                                              blurRadius: 15,
                                              offset: Offset(0, 7)),
                                        ],
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(30)),
                                        gradient: LinearGradient(colors: [
                                          Color(0xFF4081F8),
                                          Color(0xC04098F8)
                                        ], transform: GradientRotation(200.0)),
                                      ),
                                      margin:
                                          EdgeInsets.only(left: 20, right: 20),
                                    ),
                                    Container(
                                      //bar
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                              color: Color(0xAF51D500),
                                              spreadRadius: -5,
                                              blurRadius: 15,
                                              offset: Offset(7, 10)),
                                        ],
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(30)),
                                        gradient: LinearGradient(colors: [
                                          Color(0xFF51D500),
                                          Color(0xFF51D500)
                                        ], transform: GradientRotation(0.0)),
                                      ),
                                      margin:
                                          EdgeInsets.only(left: 170, right: 20),
                                      padding:
                                          EdgeInsets.only(left: 0, right: 0),
                                      child: Stack(
                                        children: [
                                          Container(
                                            height: 50,
                                            padding: EdgeInsets.only(
                                              left: 20,
                                              right: 20,
                                            ),
                                            child: Center(
                                              child: DottedLine(
                                                dashColor: Colors.yellow
                                                    .withOpacity(0.9),
                                                lineLength: 300,
                                                dashGapLength: 6,
                                                lineThickness: 6,
                                                dashLength: 6,
                                                dashRadius: 20,
                                                //dashGapRadius: 20,
                                              ),
                                            ),
                                          ),
                                          FluidSlider(
                                            thumbDiameter: 50,
                                            thumbColor: Colors.white,
                                            valueTextStyle: TextStyle(
                                                fontSize: 17.0,
                                                fontFamily: 'EncodeSansM',
                                                color: Color(0xFF22D400)),
                                            sliderColor: Color(0xFF51D500),
                                            showDecimalValue: true,
                                            value: _slidervalue,
                                            onChangeEnd: (double valueVolt) {
                                              int tmpint;
                                              if (valueVolt >= 4.35) {
                                                //4.4
                                                tmpint = 255;
                                              } else if (valueVolt >= 4.25) {
                                                tmpint = 196;
                                              } else if (valueVolt >= 4.15) {
                                                tmpint = 187;
                                              } else if (valueVolt >= 4.05) {
                                                tmpint = 178;
                                              } else if (valueVolt >= 4.00) {
                                                tmpint = 168;
                                              }
                                              sendCmdCustom(
                                                  "dac" + tmpint.toString());
                                              setState(() {
                                                textHider = true;
                                              });
                                            },
                                            onChanged: (double newValue) {
                                              //print(newValue);

                                              setState(() {
                                                _slidervalue = newValue;
                                              });
                                            },
                                            onChangeStart: (valuenoUsed) {
                                              setState(() {
                                                textHider = false;
                                              });
                                            },
                                            min: 4.00,
                                            max: 4.40,
                                            start:
                                                Text(textHider ? "" : "4.0V ",
                                                    style: TextStyle(
                                                      backgroundColor:
                                                          Color(0xFF51D500),
                                                      fontSize: 17.0,
                                                      color: Color(0xFFFFFFFF),
                                                      fontFamily: 'EncodeSans',
                                                    )),
                                            end: Text(textHider ? "" : "4.4V ",
                                                style: TextStyle(
                                                  fontSize: 17.0,
                                                  backgroundColor:
                                                      Color(0xFF51D500),
                                                  color: Color(0xFFFFFFFF),
                                                  fontFamily: 'EncodeSansM',
                                                )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 15,
                                ),
                                Container(
                                  //Charging Power switch box
                                  margin: EdgeInsets.all(20),
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          color: Color(0xA94F92E7),
                                          spreadRadius: 0,
                                          blurRadius: 15,
                                          offset: Offset(0, 7)),
                                    ],
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15)),
                                    gradient: LinearGradient(colors: [
                                      Color(0xFF4081F8),
                                      Color(0xC04098F8)
                                    ], transform: GradientRotation(200.0)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Power Switch",
                                            style: TextStyle(
                                              fontSize: 20.0,
                                              color: Color(0xFFFFFFFF),
                                              fontFamily: 'EncodeSansL',
                                            ),
                                          ),
                                          CupertinoSwitch(
                                            activeColor: Color(0xFF51D500),
                                            value: chargeState,
                                            onChanged: (value) {
                                              chargeState = !value;
                                              if (chargeState) {
                                                sendcmd("poweroff");
                                                chargeState = false;
                                              } else {
                                                sendcmd("poweron");
                                                chargeState = true;
                                              }

                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Battery State :",
                                            style: TextStyle(
                                              fontSize: 20.0,
                                              height: 1.5,
                                              color: Color(0xFFFFFFFF),
                                              fontFamily: 'EncodeSansL',
                                            ),
                                          ),
                                          Text(
                                            batteryState,
                                            style: TextStyle(
                                              fontSize: 20.0,
                                              color: Color(0xFFFFFFFF),
                                              fontFamily: 'EncodeSansM',
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            //third page
                            child: Container(
                              margin: EdgeInsets.only(top: 30),
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Battery Information",
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontFamily: 'CenturyGothicB'),
                                      ),
                                      Row(
                                        children: [
                                          // Icon(
                                          //   Icons.edit,
                                          //   color: Color(0xFF4793F5),
                                          // ),
                                          Text(
                                            " Edit",
                                            style: TextStyle(
                                                color: Color(0xFF4793F5),
                                                fontSize: 16,
                                                fontFamily: 'CenturyGothicB'),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Profile Name :",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontFamily: 'EncodeSansM')),
                                      Text("BAT-A0",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontFamily: 'EncodeSansM'))
                                    ],
                                  ),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [textDetail(), textDetailBAT01()],
                                  ),
                                  addNewBatteryButton()
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 600.0 - 65.0),
                      //top: 0.1,
                      child: CurvedNavigationBar(
                        height: 50,
                        color: Color(0xF11F7CF6),
                        buttonBackgroundColor: Color(0xFF22D400),
                        animationCurve: Curves.easeInOutExpo,
                        animationDuration: Duration(milliseconds: 600),
                        index: pageindex,
                        backgroundColor: Color(0x0000000),
                        items: <Widget>[
                          Icon(
                            Icons.insert_chart, //multiline_chart
                            size: 30,
                            color: Colors.white,
                          ),
                          Icon(
                            Icons.home, //adj
                            size: 30,
                            color: Colors.white,
                          ),
                          Icon(
                            Icons.info,
                            size: 30,
                            color: Colors.white,
                          ),
                        ],
                        onTap: (index) async {
                          navTaped = true;
                          await pagecontroller.animateToPage(index,
                              duration: Duration(milliseconds: 400),
                              curve: Curves.easeInOutExpo);
                        },
                      ),
                    ),
                  ])
                ],
              ),
            ],
          )),
    );
  }

  LineChartData mainData(List<FlSpot> flspotList) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalGrid: true,
        getDrawingHorizontalGridLine: (value) {
          return const FlLine(
            color: Color(0x55ffffff),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalGridLine: (value) {
          return const FlLine(
            color: Color(0x11ffffff),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          textStyle: TextStyle(
              color: const Color(0xaaffffff),
              fontWeight: FontWeight.bold,
              fontSize: 16),
          getTitles: (value) {
            switch (value.toInt()) {
              case 0:
                return '';
              case 10:
                return '20sec';
              case 90:
                return '   Time (s)';
            }
            return '';
          },
          margin: 8,
        ),
        leftTitles: SideTitles(
          showTitles: true,
          textStyle: TextStyle(
            color: const Color(0xaaffffff),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          getTitles: (value) {
            switch (value.toInt()) {
              case 0:
                return '0.0A';
              case 5:
                return '0.5A';
              case 10:
                return '1A';
            }
            return '';
          },
          reservedSize: 35,
          margin: 5,
        ),
      ),
      borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0x44ffffff), width: 1)),
      lineTouchData: LineTouchData(
        // touchCallback: ( ) {
        //   return  Container(child: Text("dd"),);
        // },
        // getTouchedSpotIndicator: (LineChartBarData ff, List<int> jj) {
        //   return List<TouchedSpotIndicatorData>();
        // },
        enabled: true,

        touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.black.withOpacity(0.5),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final flSpot = barSpot;
                // if (flSpot.x == 0 || flSpot.x == 6) {
                //   return null;
                // }

                return LineTooltipItem(
                  '${(flSpot.y.toDouble() * 100).toInt()} mA',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            }),
      ),
      // extraLinesData: ExtraLinesData(
      //     showHorizontalLines: true,
      //     horizontalLines: [HorizontalLine(x: 1), HorizontalLine(x: 5)]),
      minX: 0,
      maxX: flspotList.length * 1.0 - 1,
      minY: 0,
      maxY: 10,
      lineBarsData: [
        LineChartBarData(
          gradientFrom: Offset(0, 0),
          gradientTo: Offset(0, 1),
          spots:
              flspotList.length > 2 ? flspotList : [FlSpot(0, 0), FlSpot(0, 0)],
          isCurved: true,
          curveSmoothness: 0.15,
          //preventCurveOverShooting: true,
          colors: gradientColors.map((color) => color.withOpacity(1)).toList(),
          barWidth: 2.5,
          isStrokeCapRound: true, //le bout de stocke
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            gradientFrom: Offset(0, 0),
            gradientTo: Offset(0, 1),
            show: true,
            colors: gradientColors,
          ),
        ),
      ],
    );
  }

  LineChartData mainData2(List<FlSpot> flspotList) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalGrid: true,
        getDrawingHorizontalGridLine: (value) {
          return const FlLine(
            color: Color(0xaa37434d),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalGridLine: (value) {
          return const FlLine(
            color: Color(0x5537434d),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          textStyle: TextStyle(
              color: const Color(0xff68737d),
              fontWeight: FontWeight.bold,
              fontSize: 16),
          getTitles: (value) {
            switch (value.toInt()) {
              case 5:
                return 'Sec/Dec';

              case 90:
                return 'Time(s)';
            }
            return '';
          },
          margin: 8,
        ),
        leftTitles: SideTitles(
          showTitles: true,
          textStyle: TextStyle(
            color: const Color(0xff67727d),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          getTitles: (value) {
            switch (value.toInt()) {
              case 0:
                return '0V';
              case 2:
                return '2.0V';
              case 3:
                return '3.0V';
              case 4:
                return '4.0V';
              case 5:
                return '5.0V';
            }
            return '';
          },
          reservedSize: 28,
          margin: 12,
        ),
      ),
      borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xaa37434d), width: 2)),
      lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.white,
              tooltipRoundedRadius: 15,
              maxContentWidth: 300)),
      // extraLinesData: ExtraLinesData(
      //     showHorizontalLines: true,
      //     horizontalLines: [HorizontalLine(x: 1), HorizontalLine(x: 5)]),
      minX: 0,
      maxX: flspotList.length * 1.0 - 1,
      minY: 0,
      maxY: 5,
      lineBarsData: [
        LineChartBarData(
          gradientFrom: Offset(0, 0),
          gradientTo: Offset(0, 1),
          spots: //flspotList,
              flspotList.length > 2 ? flspotList : [FlSpot(0, 0), FlSpot(0, 0)],

          isCurved: true,
          curveSmoothness: 0.15,
          colors: gradientColors.map((color) => color.withOpacity(1)).toList(),
          barWidth: 2.5,
          isStrokeCapRound: true, //le bout de stocke
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            gradientFrom: Offset(0, 0),
            gradientTo: Offset(0, 1),
            show: true,
            colors: gradientColors,
          ),
        ),
      ],
    );
  }

  Widget textDetail() {
    return Text(
      "- Model\n- Manufacter\n- Current of Charge\n- Maximum Voltage\n- Minimal Voltage\n- Capacity\n- Maximun Temperature\n- Fast charge support\n- Fast charge current",
      style: TextStyle(height: 1.5, fontSize: 15, fontFamily: 'EncodeSansM'),
    );
  }

  Widget textDetailBAT01() {
    return Text(
        "AA-5501\nSAMSUNG\n500mA\n4.4V\n3.0V\n3000mAh\n80°C\nsupported\n1500mA",
        textAlign: TextAlign.right,
        style: TextStyle(height: 1.5, fontSize: 15, fontFamily: 'EncodeSans'));
  }

  Widget addNewBatteryButton() {
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: 40),
        padding: EdgeInsets.all(5),
        width: 230,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Color(0xA94F92E7),
                spreadRadius: 0,
                blurRadius: 15,
                offset: Offset(0, 7)),
          ],
          borderRadius: BorderRadius.all(Radius.circular(30)),
          gradient: LinearGradient(
              colors: [Color(0xFF4081F8), Color(0xC04098F8)],
              transform: GradientRotation(200.0)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 30,
            ),
            Text("   Add New Battery",
                style: TextStyle(
                    fontFamily: 'CenturyGothicB', color: Colors.white))
          ],
        ),
      ),
    );
  }

  List<FlSpot> flSpotData(List<double> listdt) {
    List<FlSpot> returndata = [FlSpot(0, listdt[0]), FlSpot(1, listdt[1])];
    double pd = 2;
    for (int p = 2; p <= listdt.length - 1; p++) {
      returndata.add(FlSpot(pd, listdt[p]));
      pd++;
    }
    return returndata;
  }
}
