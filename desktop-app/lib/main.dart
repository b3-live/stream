import 'dart:async';
import 'dart:io';
import 'package:http_server/http_server.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:process_run/shell.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:downloadable/downloadable.dart';

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'b3.live',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'b3.live control center'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String? ip;
  int port = 8000;
  bool foundFile = false;
  Directory? directory;


  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
    getIp();
    _startWebServer();
  }

  Future<void> getIp() async {
      ip = await NetworkInfo().getWifiIP();
      port = int.fromEnvironment('PORT', defaultValue: 8000);
  }

  Future _startWebServer() async {
    runZoned(() {
      const LISTEN = String.fromEnvironment('LISTEN', defaultValue: '0.0.0.0');
      HttpServer.bind(LISTEN, port).then((server) {
        print('Server running at: ${server.address.address}');
        server.transform(HttpBodyHandler()).listen((HttpRequestBody body) async {
          print('Request URI path ${body.request.uri.path.toString()}');
          switch (body.request.uri.path.toString()) {
            case '/upload': {
              if (body.type != "form") {
                body.request.response.statusCode = 400;
                body.request.response.close();
                return;
              }
              for (var key in body.body.keys.toSet()) {
                if (key == "file") {
                  foundFile = true;
                }
              }
              if (!foundFile) {
                body.request.response.statusCode = 400;
                body.request.response.close();
                return;
              }
              HttpBodyFileUpload data = body.body['file'];
              // Save file
              directory = await getDownloadsDirectory();
              File fFile = File('${directory?.path}/file');
              fFile.writeAsBytesSync(data.content);
              body.request.response.statusCode = 201;
              body.request.response.close();
              break;
            }
            case '/download':
              {
                print('Download: ${body.request.uri.query.toString()}');
                String fileName = body.request.uri.query.toString().split('/').last;
		var tempFolder = 'videos';

		var downloadable = Downloadable(
		  downloadLink: '${body.request.uri.query.toString()}',
		  fileAddress: tempFolder + '/$fileName',
		);

		var downloaded = await downloadable.downloaded;

		if (!downloaded) {
		  var onDownloadComplete = () {
		    print('download complete!');
		  };

		  var progressStream = downloadable.download(onDownloadComplete);

		  progressStream.listen((p) {
		    print('${p * 100}%...');
		  });
		}
                body.request.response.statusCode = 200;
                body.request.response.headers.set("Content-Type", "text/html; charset=utf-8");
                body.request.response.write("Download");
                body.request.response.close();
                break;
              }
            default: {
              print('Request URI ${body.request.uri.toString().substring(1)}');
              var shell = Shell();

              await shell.run('''./hello.sh''');

              _launchUrl(Uri.parse(body.request.uri.toString().substring(1)));
              body.request.response.statusCode = 404;
              body.request.response.write('Not found');
              body.request.response.close();
            }
        }
        });
      });
    },
        onError: (e, stackTrace) => print('Oh noes! $e $stackTrace'));
  }

  Future<void> _launchUrl(Uri _url) async {
    if (!await launchUrl(_url)) {
      throw 'Could not launch $_url';
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: PrettyQr(
          //image: AssetImage('images/twitter.png'),
          size: 300,
          data: '${String.fromEnvironment('LISTEN', defaultValue: '0.0.0.0') == '0.0.0.0' ? 
            'b3live://local?http://$ip:$port' : 
	    'b3live://local?http://${String.fromEnvironment('LISTEN')}:$port'}',
          errorCorrectLevel: QrErrorCorrectLevel.M,
          typeNumber: null,
          roundEdges: true,
        ),
        //child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
         // mainAxisAlignment: MainAxisAlignment.center,
         // children: <Widget>[
         //   Text(
 	 //     'Serving on ${ip != null ? '$ip' : 'You have pushed the button this many times: '}'
         //   ),
         //   Text(
         //     '$_counter',
         //     style: Theme.of(context).textTheme.headline4,
         //   ),
         // ],
        //),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.not_started),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
