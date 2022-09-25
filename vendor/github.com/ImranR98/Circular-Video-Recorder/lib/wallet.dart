import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';
import 'test_connector.dart';
import 'package:floating/floating.dart';
import 'package:shared_preferences/shared_preferences.dart';


enum TransactionState {
  idle,
  sending,
  successful,
  failed,
}

class WalletPage extends StatefulWidget {
  const WalletPage({
    required this.connector,
    Key? key,
  }) : super(key: key);

  final TestConnector connector;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final floating = Floating();
  bool termsOfService = false;
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

  late Future<double> balanceFuture = widget.connector.getBalance();
  final addressController = TextEditingController();
  final amountController = TextEditingController();
  bool validateAddress = true;
  bool validateAmount = true;
  TransactionState state = TransactionState.idle;

  @override
  void dispose() {
    addressController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    Future.delayed(const Duration(seconds: 1), () => copyAddressToClipboard());
    super.initState();
  }

  Future<void> enablePip() async {
    final status = await floating.enable(Rational.landscape());
    debugPrint('PiP enabled? $status');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      appBar: AppBar(title: Text("b3.live")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Visibility(
                  visible: !termsOfService,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Create a b3.live account',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                  ),
                ),
                Visibility(
                  visible: !termsOfService,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Address',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                  ),
                ),
                Visibility(
                  visible: !termsOfService,
                  child: Text(widget.connector.address),
                ),
                 /*
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Balance',
                    style: Theme.of(context).textTheme.headline5,
                  ),
                ),
                FutureBuilder<double>(
                  future: balanceFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final balance = snapshot.data;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${balance!.toStringAsFixed(5)} ${widget.connector.coinName}'),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => setState(() {
                                  balanceFuture = widget.connector.getBalance();
                                }),
                                child: const Text('Refresh'),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: ElevatedButton(
                                  onPressed: () {
                                    copyAddressToClipboard();
                                    Future.delayed(
                                      const Duration(seconds: 1),
                                      () => launchUrl(
                                        Uri.parse(
                                          widget.connector.faucetUrl,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Faucet'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else {
                      return const CircularProgressIndicator();
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: addressController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: true,
                    decoration: InputDecoration(
                      labelText: 'Recipient address',
                      errorText: validateAddress ? null : 'Invalid address',
                    ),
                  ),
                ), */
                Visibility(
                  visible: !termsOfService,
                  child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: addressController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: true,
                    decoration: InputDecoration(
                      labelText: 'User name',
                      /* errorText: validateAddress ? null : 'Invalid username', */
                    ),
                  ),
                ),
                ),
                Visibility(
                  visible: !termsOfService,
                  child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Pin Number',
                      errorText: validateAmount
                          ? null
                          : 'Please enter a four digit pin number',
                    ),
                  ),
                ),
                ),
                Visibility(
                  visible: !termsOfService,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: RichText(
                      text: const TextSpan(
                        text: "To upload video, in addition to a b3.live acccount you will also need a ",
                        style: TextStyle(color: Colors.redAccent),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Lens',
                            style: TextStyle(
                              color: Colors.black,
                              backgroundColor:  Colors.green,
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0x9EFF22),
                              decorationStyle: TextDecorationStyle.wavy,
                            ),
                          ),
                          TextSpan(
                            text: ' profile',
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),/*
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      errorText: validateAmount
                          ? null
                          : 'Please enter amount in ${widget.connector.coinName}',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: ElevatedButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      if (amountController.text.isNotEmpty) {
                        setState(() => validateAmount = true);
                        if (widget.connector
                            .validateAddress(address: addressController.text)) {
                          setState(() => validateAddress = true);

                          // action
                          await transactionAction();
                        } else {
                          setState(() => validateAddress = false);
                        }
                      } else {
                        setState(() => validateAmount = false);
                      }
                    },
                    child: Text(transactionString()),
                  ),
                ), */
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (termsOfService) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('username', addressController.text);
                        await prefs.setString('pin', amountController.text);
                        await prefs.setString('address', widget.connector.address);
                      }

                      if (termsOfService && Platform.isAndroid)
                        Navigator.of(context).pop();
                      FocusScope.of(context).unfocus();
                      if (amountController.text.isNotEmpty) {
                        debugPrint("amountController: ${widget.connector.address}");
                        debugPrint("amountController: ${amountController.text}");
                        debugPrint("addressController: ${addressController.text}");
                        const String msg = "I-have-a-Lens-profile";
                        if (Platform.isAndroid && !termsOfService) {
                          await enablePip();
                          //await systemBrowser("https://googlechrome.github.io/samples/picture-in-picture/");
                          //await systemBrowser("https://your.cmptr.cloud:2017/chrome.html");

                          _launchURL("https://metamask.app.link/dapp/www.430.studio?contract=${widget.connector.address}&network=${addressController.text}&standard=erc721&message=${amountController.text}");
                        }
                        else if (!termsOfService || !Platform.isAndroid) {
                        webViewController?.loadUrl(
                          urlRequest: URLRequest(url: Uri.parse(
                          "https://www.430.studio/?mode=verify&contract=${widget.connector.address}&network=${addressController.text}&standard=erc721&message=${amountController.text}")
                          ));
                        webViewController?.loadUrl(
                          urlRequest: URLRequest(url: await webViewController?.getUrl()));
                        };
                        setState(() { termsOfService = true; });
                      };
                    },
                    child: Text(termsOfService ? "Accept" : "Create Account"),
                  ),
                ),
                Visibility(
                  visible: termsOfService,
                  child: SizedBox (
                      width: 640.0,
                      height: 300.0,
                      child: InAppWebView(
                        //initialUrlRequest: URLRequest(url: Uri.parse("https://metamask.app.link/dapp/www.430.studio/")),
                        initialUrlRequest: URLRequest(url: Uri.parse("https://your.cmptr.cloud:2017/terms.html")),
                        initialOptions: InAppWebViewGroupOptions(
                          crossPlatform: InAppWebViewOptions(
                            mediaPlaybackRequiresUserGesture: false,
                            //debuggingEnabled: true,
                          ),
                        ),
                        onLoadHttpError: (controller, url, code, message) {
                          debugPrint("Cant access site");
                          setState( () { termsOfService = true; });
                          webViewController?.loadFile(assetFilePath: "assets/error.html");
                        },
                        onWebViewCreated: (InAppWebViewController controller) {
                         webViewController = controller;
                        },
                        androidOnPermissionRequest: (InAppWebViewController controller, String origin, List<String> resources) async {
                          return PermissionRequestResponse(resources: resources, action: PermissionRequestResponseAction.GRANT);
                        }
                      ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Visibility(
        visible: false /*termsOfService && Platform.isAndroidi*/,
        child: Align(
          child: FloatingActionButton(
            child: Icon(
              Icons.refresh,
              ),
            onPressed: () async {
              const msg = "I-have-a-Lens-profile";
              _launchURL("https://metamask.app.link/dapp/www.430.studio?contract=${widget.connector.address}&network=${addressController.text}&standard=erc721&message=${msg}");
              setState(() {
              });
            },
          ),
          alignment: Alignment(1, 0.7),
        ),
      ),
    );
  }

  String transactionString() {
    switch (state) {
      case TransactionState.idle:
        return 'Send transaction';
      case TransactionState.sending:
        return 'Sending transaction. Please go back to the Wallet to confirm.';
      case TransactionState.successful:
        return 'Transaction successful';
      case TransactionState.failed:
        return 'Transaction failed';
    }
  }

  void _launchURL(String url) async {
    await canLaunch(url) ? await launch(url) : throw 'Cannot Launch!';
  }

  Future<void> systemBrowser(String url) async {
    if (await canLaunchUrl(Uri.parse(url)))
      await launchUrl(Uri.parse(url)); 
  }

  Future<void> transactionAction() async {
    switch (state) {
      case TransactionState.idle:
        // Send transaction
        setState(() => state = TransactionState.sending);

        Future.delayed(Duration.zero, () => widget.connector.openWalletApp());

        final hash = await widget.connector.sendTestingAmount(
            recipientAddress: addressController.text,
            amount: double.parse(amountController.text));

        if (hash != null) {
          setState(() => state = TransactionState.successful);
        } else {
          setState(() => state = TransactionState.failed);
        }
        break;
      case TransactionState.sending:
      case TransactionState.successful:
      case TransactionState.failed:
        // Do nothing
        break;
    }
  }

  Future<void> accountCreation() async {

    debugPrint("open: https://www.430.studio/?contract=${widget.connector.address}&network=${addressController.text}&standard=erc721&message=${amountController.text}");

    webViewController?.loadUrl(
      urlRequest: URLRequest(url: Uri.parse(
        "https://www.430.studio/?contract=${widget.connector.address}&network=${addressController.text}&standard=erc721&message=${amountController.text}"))
    );
    setState( () { termsOfService = true; });  
                    
  }

  void copyAddressToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.connector.address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 500),
        content: Text('Address copied!'),
      ),
    );
  }
}
