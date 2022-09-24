import 'dart:async';
import 'dart:io';
import 'package:qr_mobile_vision/qr_camera.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:dhttpd/dhttpd.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:uni_links/uni_links.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'barecode_scanner_controller.dart';
import 'package:walletconnect_qrcode_modal_dart/walletconnect_qrcode_modal_dart.dart';

import 'test_connector.dart';
import 'wallet.dart';
import 'algorand_test_connector.dart';
import 'ethereum_test_connector.dart';

import 'package:ssh2/ssh2.dart';

import 'package:floating/floating.dart';


late List<CameraDescription> _cameras;
late Directory saveDir;
bool _initialURILinkHandled = false;
SSHClient? client;

String? baseUri;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  await Permission.microphone.request();
  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  _cameras = await availableCameras();
  saveDir = await getRecordingDir();
  runApp(const MyApp());
  SystemChrome.setEnabledSystemUIOverlays([]);
}

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  connectionFailed,
  connectionCancelled,
}

Future<Directory> getRecordingDir() async {
  Directory? saveDir;
  while (saveDir == null) {
    if (Platform.isAndroid) {
      saveDir = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      saveDir = await getApplicationDocumentsDirectory();
    } else {
      saveDir = await getDownloadsDirectory();
    }
  }
  return saveDir;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'b3.live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: const ColorScheme.light(
              //primary: Colors.black, secondary: Colors.amber)),
              primary: Colors.redAccent, secondary: Colors.amberAccent)),
      darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent, secondary: Colors.amberAccent)),
      home: const MyHomePage(title: 'b3.live'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final floating = Floating();

  TestConnector connector = EthereumTestConnector();

  static const _networks = ['Ethereum (Ropsten)', 'Algorand (Testnet)'];

  ConnectionState _state = ConnectionState.disconnected;
  String? _networkName = _networks.first;
// InAppWeb
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

// InAppWeb
  late CameraController cameraController;
  //int recordMins = 0;
  //int recordCount = -1;
  Uri? _initialURI;
  Uri? _currentURI;
  Object? _err;

  StreamSubscription? _streamSubscription;

  String? qr;
  bool camState = false;
  bool dirState = false;
  int recordMins = 1;
  int recordCount = 30;
  ResolutionPreset resolutionPreset = ResolutionPreset.medium;
  DateTime currentClipStart = DateTime.now();
  String? ip;
  Dhttpd? server;
  String? createNFT;
  bool saving = false;
  bool moving = false;
  bool browser = true;
  bool metamaskInstalled = false;

  @override
  void initState() {
    connector.registerListeners(
      // connected
      (session) => print('Connected: $session'),
      // session updated
      (response) => print('Session updated: $response'),
      // disconnected
      () {
          setState(() => _state = ConnectionState.disconnected);
          print('Disconnected');
        });
    super.initState();
    KeepScreenOn.turnOn();
    _initURIHandler();
    _incomingLinkHandler();
    initCam();
    if (Platform.isAndroid)
      killCam();

    generateHTMLList();
    _checkForMetaMask();

// InApp
    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
// InApp

  }

  Future<void> _checkForMetaMask() async {
    metamaskInstalled = await canLaunch("https://metamask.app.link");
  }
  
  Future<void> enablePip() async {
    final status = await floating.enable(Rational.landscape());
    debugPrint('PiP enabled? $status');
  }

  Future<void> _initURIHandler() async {
    if (!_initialURILinkHandled) {
      _initialURILinkHandled = true;
      Fluttertoast.showToast(
          msg: "Starting camera, one moment",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white
      );
      try {
        final initialURI = await getInitialUri();
        // Use the initialURI and warn the user if it is not correct,
        // but keep in mind it could be `null`.
        if (initialURI != null) {
          baseUri = "${initialURI?.query.toString()}";
          debugPrint("initialURI: base URI received $baseUri");
          debugPrint("Initial URI received $initialURI");
          if (!mounted) {
            return;
          }
          setState(() {
            _currentURI = initialURI;
            _initialURI = initialURI;
          });
        } else {
          debugPrint("Null Initial URI received");
        }
      } on PlatformException {
        // Platform messages may fail, so we use a try/catch PlatformException.
        // Handle exception by warning the user their action did not succeed
        debugPrint("Failed to receive initial uri");
      } on FormatException catch (err) {
        if (!mounted) {
          return;
        }
        debugPrint('Malformed Initial URI received');
        setState(() => _err = err);
      }
    }
  }

  /// Handle incoming links - the ones that the app will receive from the OS
  /// while already started.
  void _incomingLinkHandler() {
    // It will handle app links while the app is already started - be it in
    // the foreground or in the background.
    _streamSubscription = uriLinkStream.listen((Uri? uri) {
       if (!mounted) {
         return;
       }
       debugPrint('Received URI: $uri');
       baseUri = "${uri?.query.toString()}";
       debugPrint("_incomingLinkHandler: base URI received $uri");
       setState(() {
         _currentURI = uri;
         _err = null;
       });
     }, onError: (Object err) {
       if (!mounted) {
         return;
       }
       debugPrint('Error occurred: $err');
       setState(() {
         _currentURI = null;
         if (err is FormatException) {
           _err = err;
         } else {
           _err = null;
         }
       });
     });
  }


  Future<void> initCam() async {
    cameraController = CameraController(_cameras[0], resolutionPreset);
    try {
      await cameraController.initialize();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            showInSnackBar('User denied camera access');
            break;
          default:
            showInSnackBar('Unknown error');
            break;
        }
      }
    }
  }

  Future<void> killCam() async {
    cameraController = CameraController(_cameras[0], resolutionPreset);
    try {
      await cameraController.dispose();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            showInSnackBar('User denied camera access');
            break;
          default:
            showInSnackBar('Unknown error');
            break;
        }
      }
    }
  }

  Future<List<FileSystemEntity>> getExistingClips() async {
    List<FileSystemEntity> existingFiles = await saveDir.list().toList();
    existingFiles.removeWhere(
        (element) => element.uri.pathSegments.last == 'index.html');
    return existingFiles;
  }

  Future<void> generateHTMLList() async {
    List<FileSystemEntity> existingClips = await getExistingClips();
    String html =
        '''<!DOCTYPE html>
		<html lang="en">
		<head>
			<meta http-equiv="content-type" content="text/html; charset=utf-8">
			<meta name="viewport" content="width=device-width, initial-scale=1.0">
			<title>b3.live - Clips</title>
			<style>
				@media (prefers-color-scheme: dark) {html {background-color: #222222; color: white;}} 
				body {font-family: Arial, Helvetica, sans-serif;} 
				a {color: inherit;}</style>
			<script>
				async function upload() {
          var a = document.getElementsByTagName('a');

          for (var idx= 0; idx < a.length; ++idx){
            console.log(a[idx].href);
            const res = await fetch(a[idx].href)
  				  const blob = await res.blob()

            const d = new Date();
            let time = d.getTime();

            var data = new FormData()
      			data.append('file', blob , time+'.mp4')

				    fetch("https://playagame.today/upload", {
				      method: "POST",
				      body: data
				      })
          }
				}
				setTimeout(upload, 180);
			</script>
		</head>
		<body><h1>b3.live - Clips:</h1>''';

    if (existingClips.isNotEmpty) {
      html += '<ul>';
      for (var element in existingClips) {
        html +=
            '<li><a href="./${element.uri.pathSegments.last}">${element.uri.pathSegments.last}</a></li>';
      }
      html += '</ul>';
    } else {
      html += '<p>No Clips Found!</p>';
    }
    html += '</body></html>';
    File('${saveDir.path}/index.html').writeAsString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: AppBar(
       title: Text(widget.title),
      ),*/
      body: Column(children: [
       /* PiPSwitcher(
              childWhenDisabled: const Text('disabled'),
              childWhenEnabled: const Text('enabled'),
            ), */
        Visibility(
          visible: !browser,
	  child:
		Expanded(
		  child: Container(
		    decoration: BoxDecoration(
		      color: Colors.black,
		      border: Border(
			  left: BorderSide(
			      color: cameraController.value.isRecordingVideo
				  ? Theme.of(context).colorScheme.primary
				  : Colors.black,
			      width: 5),
			  right: BorderSide(
			      color: cameraController.value.isRecordingVideo
				  ? Theme.of(context).colorScheme.primary
				  : Colors.black,
			      width: 5),
			  top: BorderSide(
			      color: cameraController.value.isRecordingVideo
				  ? Theme.of(context).colorScheme.primary
				  : Colors.black,
			      width: 5)),
		    ),
		    child: Padding(
		      padding: const EdgeInsets.all(1.0),
		      child: Center(
			child: !browser && cameraController.value.isInitialized
			    ? CameraPreview(cameraController)
			    : const Text('Could not Access Camera'),
		      ),
		    ),
		  ),
		),
	),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            decoration: BoxDecoration(
              color: cameraController.value.isRecordingVideo
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black,
              border: Border.all(
                color: cameraController.value.isRecordingVideo
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black,
                width: cameraController.value.isRecordingVideo ? 5 : 2.5,
              ),
            ),

//            child: cameraController.value.isRecordingVideo && false
 //               ? Text(
//                    'Current clip started at ${currentClipStart.hour <= 9 ? '0${currentClipStart.hour}' : currentClipStart.hour}:${currentClipStart.minute <= 9 ? '0${currentClipStart.minute}' : currentClipStart.minute}',
//                    textAlign: TextAlign.center,
//                    style: const TextStyle(
//                        fontWeight: FontWeight.bold, color: Colors.white))
//                : null,
          ),
        ]),
        if (cameraController.value.isRecordingVideo && false)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text('${saveDir.path}/${latestFileName()}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(letterSpacing: 1, color: Colors.white)),
            ),
          ]),
        Visibility(
          visible: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Expanded(
                  child: TextField(
                onChanged: (value) {
                  setState(() {
                    //recordMins = value.trim() == '' ? 0 : int.parse(value);
                    recordMins = value.trim() == '' ? 1 : int.parse(value);
                  });
                },
                enabled: !cameraController.value.isRecordingVideo,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Clip Length (Min)',
                ),
              )),
              const SizedBox(width: 15),
              Expanded(
                  child: TextField(
                      onChanged: (value) {
                        setState(() {
                          recordCount =
                              //value.trim() == '' ? -1 : int.parse(value);
                              value.trim() == '' ? 30 : int.parse(value);
                        });
                      },
                      enabled: !cameraController.value.isRecordingVideo,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Clip Count Limit',
                      ))),
              const SizedBox(width: 15),
              Expanded(
                  child: DropdownButtonFormField(
                      value: resolutionPreset,
                      items: ResolutionPreset.values
                          .map((e) => DropdownMenuItem<ResolutionPreset>(
                              value: e, child: Text(e.name)))
                          .toList(),
                      onChanged: cameraController.value.isRecordingVideo
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  resolutionPreset = value as ResolutionPreset;
                                });
                                //initCam();
                              }
                            },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Video Quality',
                      ))),
            ],
          ),
        ),
        Visibility(
          visible: false,
          child: Text(getStatusText(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Visibility(
          visible: browser,
          child: Expanded /*SizedBox*/(
              //width: 640.0,
              //height: 1080 /* 280.0 */,
              child: InAppWebView(
                        key: webViewKey,
                        //initialFile: "assets/start.html",
                        initialUrlRequest:
                        //URLRequest(url: Uri.parse("https://audiomotion.me")),
                        //URLRequest(url: Uri.parse("http://$ip:8080")),
                        //URLRequest(url: Uri.parse("https://googlechrome.github.io/samples/picture-in-picture/")),
                        URLRequest(url: Uri.parse("https://your.cmptr.cloud:2017/stream/b3.live-site/")),
                        //URLRequest(url: Uri.parse("https://blog.minhazav.dev/research/html5-qrcode")),
                        initialOptions: options,
                        pullToRefreshController: pullToRefreshController,
                        onWebViewCreated: (controller) {
                          webViewController = controller;
                        },
                        onLoadStart: (controller, url) {
                          setState(() {
                            this.url = url.toString();
                            urlController.text = this.url;
                          });
                        },
                        androidOnPermissionRequest: (controller, origin, resources) async {
                          return PermissionRequestResponse(
                              resources: resources,
                              action: PermissionRequestResponseAction.GRANT);
                        },
                        shouldOverrideUrlLoading: (controller, navigationAction) async {
                          var uri = navigationAction.request.url!;

                          if (![ "http", "https", "file", "chrome",
                            "data", "javascript", "about"].contains(uri.scheme)) {
                            if (await canLaunch(url)) {
                              // Launch the App
                              await launch(
                                url,
                              );
                              // and cancel the request
                              return NavigationActionPolicy.CANCEL;
                            }
                          }

                          return NavigationActionPolicy.ALLOW;
                        },
                        onLoadStop: (controller, url) async {
                          pullToRefreshController.endRefreshing();
                          setState(() {
                            this.url = url.toString();
                            urlController.text = this.url;
                          });
                        },
                        onLoadError: (controller, url, code, message) {
                          debugPrint("Cant access site");
                          pullToRefreshController.endRefreshing();
                        },
                        onLoadHttpError: (controller, url, code, message) {
                          debugPrint("Cant access site");
                          webViewController?.loadFile(assetFilePath: "assets/error.html");
                          pullToRefreshController.endRefreshing();
                        },
                        onProgressChanged: (controller, progress) {
                          if (progress == 100) {
                            pullToRefreshController.endRefreshing();
                          }
                          setState(() {
                            this.progress = progress / 100;
                            urlController.text = this.url;
                          });
                        },
                        onUpdateVisitedHistory: (controller, url, androidIsReload) {
                          setState(() {
                            this.url = url.toString();
                            urlController.text = this.url;
                          });
                        },
                        onConsoleMessage: (controller, consoleMessage) {
                          print(consoleMessage);
                        },
                      ),
/*              child: InAppWebView(
                      initialUrl: "https://audiomotion.me",
                      initialOptions: InAppWebViewGroupOptions(
                        crossPlatform: InAppWebViewOptions(
                          mediaPlaybackRequiresUserGesture: false,
                          //debuggingEnabled: true,
                        ),
                      ),
                      onWebViewCreated: (InAppWebViewController controller) {
                        _webViewController = controller;
                      },
                      androidOnPermissionRequest: (InAppWebViewController controller, String origin, List<String> resources) async {
                        return PermissionRequestResponse(resources: resources, action: PermissionRequestResponseAction.GRANT);
                      }
                  ),
*/
              //child: const WebView(
              //        initialUrl: 'https://audiomotion.me',
               //       javascriptMode: JavascriptMode.unrestricted,
	        //  ),
          ), 
        ),
        Visibility(
          visible: !browser,
          child:
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Expanded(
              child: ElevatedButton(
                  onPressed: cameraController.value.isRecordingVideo
                ? () => stopRecording(false)
                : recordMins > 0 && recordCount >= 0
                    ? recordRecursively
                    : null,
                  child: Text(cameraController.value.isRecordingVideo
                ? 'Stop Recording'
                : 'Start Recording')),
                  ),
                  const SizedBox(width: 5),
                  OutlinedButton(
              onPressed: moveToGallery,
              style: Theme.of(context).brightness == Brightness.light
                  ? ButtonStyle(
                foregroundColor:
                    MaterialStateProperty.all(Colors.black),
                overlayColor: MaterialStateProperty.all(
                    const Color.fromARGB(20, 0, 0, 0)))
                  : ButtonStyle(
                foregroundColor:
                    MaterialStateProperty.all(Colors.white),
                overlayColor: MaterialStateProperty.all(
                    const Color.fromARGB(20, 255, 255, 255))),
              child: const Text('Backup to Gallery'),
                  ),
                ],
              ),
            ), 
	      ),
        Visibility(
          visible: browser &&
             _transactionStateToString(state: _state) != "Wallet connected",
          child:
          ElevatedButton(
            onPressed: _transactionStateToAction(context, state: _state),
              child: Text(
                _transactionStateToString(state: _state),
              ),
          ),),
        Visibility(
          visible: !browser,
          child:
            SwitchListTile(
              onChanged: (_) {
                toggleNFT();
              },
              controlAffinity: ListTileControlAffinity.leading,
              visualDensity: VisualDensity.compact,
              value: createNFT != null,
              activeColor: Theme.of(context).colorScheme.secondary,
              title: const Text('Mint NFT via'),
              subtitle: !metamaskInstalled 
                  ? Text(
                      'Metamask may not be installed')
                  : null,
            ), 
        ),
        Visibility(
          visible: !browser,
          child:
            SwitchListTile(
              onChanged: (_) {
                toggleLocal();
              },
              controlAffinity: ListTileControlAffinity.leading,
              visualDensity: VisualDensity.compact,
              value: server != null,
              activeColor: Theme.of(context).colorScheme.secondary,
              title: const Text('Use Control Center'),
              subtitle: _currentURI == null
                  ? Text(
                    'Not connected',
                    style: const TextStyle(color: Colors.red)) : null, 
            ),
        ),
        if (saving || moving)
          Container(
              decoration:
                  BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                child: Row(children: [
                  Text(
                      '${saving && moving ? 'Saving & moving clips' : saving ? 'Saving last clip' : 'Moving clips'} - do not exit...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white))
                ]),
              )),
        if (saving || moving) const LinearProgressIndicator(),
      ]),
          
      floatingActionButton: Padding(
        padding: EdgeInsets.only(left:30),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
            child: Icon(
              Icons.video_file,),
            /*child: Text(
              browser ? "bcast" : "<< back",
              textAlign: TextAlign.center,
            ), */
            onPressed: () {
              setState(() {
              });
            }),
            Expanded(child: Container()),
            FloatingActionButton(
            child: Icon(
              browser ? Icons.add_circle : Icons.arrow_circle_left,
              ),
            onPressed: () {
              setState(() {
                //if (metamaskInstalled)
               //  launch("https://metamask.app.link/dapp/b3.live/",forceWebView: true); 
               browser = !browser;
               //if (_currentURI == null && browser == false)
                // _barCodeScanner(context);
               /*if (!camState)
               killCam();
               camState = !camState;
               if (!camState)
               initCam(); */
              });
            }),
          ]
        ),
    ) 
    );
  }

 String _transactionStateToString({required ConnectionState state}) {
    switch (state) {
      case ConnectionState.disconnected:
        return 'Connect your Wallet';
      case ConnectionState.connecting:
        return 'Connecting';
      case ConnectionState.connected:
        return 'Wallet connected';
      case ConnectionState.connectionFailed:
        return 'Wallet connection failed';
      case ConnectionState.connectionCancelled:
        return 'Wallet connection cancelled';
    }
  }

  void _openWalletPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
      builder: (context) => WalletPage(connector: connector),
    ));
  }

  VoidCallback? _transactionStateToAction(BuildContext context,
      {required ConnectionState state}) {
        
    print('WalletPage State: ${_transactionStateToString(state: state)}');
    switch (state) {
      // Progress, action disabled
      case ConnectionState.connecting:
        return null;
      case ConnectionState.connected:
        // Open new page
        return () => _openWalletPage();

      // Initiate the connection
      case ConnectionState.disconnected:
      case ConnectionState.connectionCancelled:
      case ConnectionState.connectionFailed:
        return () async {
          setState(() => _state = ConnectionState.connecting);
          try {
            final session = await connector.connect(context);
            if (session != null) {
              setState(() => _state = ConnectionState.connected);
              Future.delayed(Duration.zero, () => _openWalletPage());
            } else {
              setState(() => _state = ConnectionState.connectionCancelled);
              if (Platform.isAndroid)
                showAlert();
            }
          } catch (e) {
            print('WC exception occured: $e');
            setState(() => _state = ConnectionState.connectionFailed);
          }
        };
    }
  }

  Future<void> _barCodeScanner(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerWithController(),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      initCam();
      setState(() {
        _currentURI = Uri.parse(result);
        baseUri = "${_currentURI?.query.toString()}";
      });
    }

    // After the Selection Screen returns a result, hide any previous snackbars
    // and show the new result.
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$result')));
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> toggleLocal() async {
    if (_currentURI == null)
      _barCodeScanner(context);

    if (server == null) {
      try {
        ip = await NetworkInfo().getWifiIP();
        server = await Dhttpd.start(
            path: saveDir.path, address: InternetAddress.anyIPv4);
        setState(() {});
      } catch (e) {
        showInSnackBar('Error - try restarting the app');
        await disableWeb();
      }
    } else {
      await disableWeb();
    }
  }


  Future<void> toggleNFT() async {
    ClipboardData? data = await Clipboard.getData("text/plain");
    debugPrint("Clipboard is ${data?.text}");
    if (createNFT == null) {
      try {
      //  ip = await NetworkInfo().getWifiIP();
      //  createNFT = await Dhttpd.start(
      //      path: saveDir.path, address: InternetAddress.anyIPv4);
	      createNFT = "yes";
        metamaskInstalled = await canLaunch("https://metamask.app.link");
        setState(() {});
      } catch (e) {
        showInSnackBar('Error - Can not determine if Metamask is installed');
        await disableNFT();
      }
    } else {
      await disableNFT();
    }
  }

  Future<void> disableWeb() async {
    await server?.destroy();
    setState(() {
      server = null;
      ip = null;
    });
  }

  Future<void> disableNFT() async {
    //await createNFT?.destroy();
    setState(() {
      createNFT = null;
      metamaskInstalled = false;
    });
  }

  String getStatusText() {
    if (recordMins <= 0 || recordCount < 0) {
      String res = '';
      if (recordMins <= 0) res += 'Length must be above 0.';
      if (recordCount < 0) {
        if (res.isNotEmpty) {
          res += ' ';
        }
        res += 'Count must be 0 (infinite) or more.';
      }
      return res;
    }
    String status1 = cameraController.value.isRecordingVideo
        ? 'Now recording'
        : 'Set to record';
    int totalMins = recordMins * recordCount;
    String status2 =
        '$recordMins min clips ${recordCount == 0 ? '(until space runs out)' : '(keeping the latest ${totalMins < 60 ? '$totalMins minutes' : '${totalMins / 60} hours'})'}.';
    if (!cameraController.value.isRecordingVideo && recordMins > 15) {
      status1 = 'Warning: Long clip lengths (above 15) may cause crashes.\n\n'
          '$status1';
    }
    return '$status1 $status2';
  }

  void recordRecursively() async {
    if (!cameraController.value.isInitialized)
      initCam();
    if (recordMins > 0 && recordCount >= 0) {
      await cameraController.startVideoRecording();
      setState(() {
        currentClipStart = DateTime.now();
      });
      await Future.delayed(
          Duration(milliseconds: (recordMins * 60 * 1000).toInt()));
      if (cameraController.value.isRecordingVideo) {
        await stopRecording(true);
        recordRecursively();
      }
    }
  }

  String latestFileName() {
    return 'GRIME-${currentClipStart.millisecondsSinceEpoch.toString()}.mp4';
  }

  Future<void> stopRecording(bool cleanup) async {
    if (cameraController.value.isRecordingVideo) {
      XFile tempFile = await cameraController.stopVideoRecording();
      setState(() {});
      String appDocPath = saveDir.path;
      String fileName = '${latestFileName()}';
      String filePath = '$appDocPath/${fileName}';
      ip = await NetworkInfo().getWifiIP();
      //await onClickSFTP(appDocPath,fileName);

      // Once clip is saved, deleting cached copy and cleaning up old clips can be done asynchronously
      setState(() {
        saving = true;
      });
      tempFile.saveTo(filePath).then((_) {
        if (baseUri != null)
          final response =  http
            .get(Uri.parse('$baseUri/download?http://$ip:8080/$fileName'));
	// b3live://local?http://192.168.1.87:8000/download/?http://192.168.1.180:8080/GRIME-1663127048613.mp4
        debugPrint('BaseURI = $baseUri/download/?http://$ip:8080/$fileName');
        onClickSFTP(appDocPath,fileName);

        File(tempFile.path).delete();
        generateHTMLList();
        setState(() {
          saving = false;
        });
        if (cleanup) {
          deleteOldRecordings();
        }
      });
    }
  }

  Future<bool> deleteOldRecordings() async {
    bool ret = false;
    if (recordCount > 0) {
      List<FileSystemEntity> existingClips = await getExistingClips();
      if (existingClips.length > recordCount) {
        ret = true;
        await Future.wait(existingClips.sublist(recordCount).map((eC) {
          showInSnackBar(
              'Clip limit reached. Deleting: ${eC.uri.pathSegments.last}');
          return eC.delete();
        }));
        generateHTMLList();
      }
    }
    return ret;
  }

  Future<void> onClickSFTP(String path, String fileName) async {
    String result = '';
    List array = [];

    //resetValues();

    var client = new SSHClient(
      host: "dev.meetbeek.com",
      port: 8022,
      username: 'foo',
      passwordOrKey: 'pass',
    );
    try {
      result = await client.connect() ?? 'Null result';
      if (result == "session_connected") {
        debugPrint("SFTP session_connected");
        result = await client.connectSFTP() ?? 'Null result';
        if (result == "sftp_connected") {
          debugPrint("SFTP sftp_connected");

          array = await client.sftpLs() ?? [];

          // Create a test directory
          //print(await client.sftpMkdir("./testftp/tests_movie"));

          // Rename the test directory
          //print(await client.sftpRename(
          //  oldPath: "testsftp",
          //  newPath: "testsftprename",
          //));

          // Remove the renamed test directory
          //print(await client.sftpRmdir("testsftprename"));

          // Get local device temp directory
          Directory tempDir = await getTemporaryDirectory();
          String tempPath = tempDir.path;

          // Create local test file
          //final String fileName = 'ssh2_test_upload.txt';
          final File file = File('$tempPath/$fileName');
          await file.writeAsString('Testing file upload');

          debugPrint('Local file path is ${file.path}');
          debugPrint('Video video path ${path}');
          debugPrint('Video clip filename is ${fileName}');

          // Upload test file
          debugPrint(await client.sftpUpload(
            path: "${path}/${fileName}" /*file.path*/,
            toPath: "./testftp/" /*"./testftp/"*/,
            callback: (progress) async {
              debugPrint("Progress ${progress}");
              // if (progress == 30) await client.sftpCancelUpload();
            },
          ) ?? 'Upload failed');

          // Download test file
          print(await client.sftpDownload(
            path: fileName,
            toPath: tempPath,
            callback: (progress) async {
              print(progress);
              // if (progress == 20) await client.sftpCancelDownload();
            },
          ) ?? 'Download failed');

          // Delete the remote test file
          print(await client.sftpRm(fileName));

          // Delete the local test file
          await file.delete();

          // Disconnect from SFTP client - don't use
          // There is a bug that prevents the ssh client connection from being
          // closed after calling disconnectSFTP()
          //print(await client.disconnectSFTP());

          // Disconnect from SSH client
          await client.disconnect();
        }
      }
    } on PlatformException catch (e) {
      String errorMessage = 'Error: ${e.code}\nError Message: ${e.message}';
      result += errorMessage;
      print(errorMessage);
    }
  }

  showAlert() async {
          debugPrint("Showing Alert on Android");
          showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Potential Issue'),
              content: const Text(
                  'We noticed your wallet connection was cancelled.  If you choose MetaMask, and it was in the background, it may not have alllowed you to connect.\n\nIf you ran into this issue, please close MetaMask and close/restart b3.live. \n\nFinally, attempt to "Connect your Wallet" again.\n\nContinue?'),
              actions: [
                TextButton(
                    onPressed: () async {
                      // Remove the box
                      setState(() {
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Yes')),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('No'))
              ],
            );
          });
  }

  moveToGallery() async {
    List<FileSystemEntity> existingClips = await getExistingClips();
    if (existingClips.isEmpty) {
      showInSnackBar('You have no recorded Clips!');
    } else if (saving) {
      showInSnackBar('A clip is still being saved - try again later');
    } else {
      //await onClickSFTP();
      showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Confirmation'),
              content: const Text(
                  'This action will move all Clips in this App\'s internal storage to an external location accessible via a Gallery app.\n\nThese clips will no longer be "owned" by the App, so they will not be accessible via the Web GUI nor affected by the Clip Count Limit.\n\nContinue?'),
              actions: [
                TextButton(
                    onPressed: () async {
                      // Remove the box
                      setState(() {
                        moving = true;
                      });
                      Navigator.of(context).pop();
                      for (var eC in existingClips) {
                        await GallerySaver.saveVideo(eC.path,
                            albumName: 'b3.live');
                      }
                      await Future.wait(existingClips.map((eC) => eC.delete()));
                      generateHTMLList();
                      showInSnackBar(
                          '${existingClips.length} Clips moved to Gallery');
                      setState(() {
                        moving = false;
                      });
                    },
                    child: const Text('Yes')),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('No'))
              ],
            );
          });
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    KeepScreenOn.turnOff();
    _streamSubscription?.cancel();
    floating.dispose();
    super.dispose();
  }
}
