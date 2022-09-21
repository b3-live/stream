import 'types/channel.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import 'types/params.dart';
import 'types/resolution.dart';
import 'types/sample_rate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key, required this.params}) : super(key: key);
  final Params params;

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int resultAlert = -1;

  @override
  void initState() {
    super.initState();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(
                context,
              );
            }),
      ),
      body: Container(
          width: MediaQuery.of(context).size.width,
          child: SettingsList(
            sections: [
              SettingsSection(
                title: Text('Video'),
                tiles: [
                SettingsTile(
                      title: Text('Livepeer API token'),
                      value: Text("******"), // widget.params.rtmpUrl),
                      onPressed: (BuildContext context) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return EditTextScreen(
                                  title: "Enter your livepeer LP_API_TOKEN",
                                  initialValue: "******", //widget.params.rtmpUrl,
                                  onChanged: (value) {
                                    setState(() {
                                      //widget.params.rtmpUrl = value;
                                    });
                                  });
                            });
                      }),
                  SettingsTile(
                    title: Text('Resolution'),
                    value: Text(widget.params.getResolutionToString()),
                    onPressed: (BuildContext context) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return PickerScreen(
                                title: "Pick a resolution",
                                initialValue: "default resolution", //widget.params.video.resolution,
                                values: {'name': 'John Doe', 'occupation': 'gardener'} );// getResolutionsMap());
                          }).then((value) {
                        if (value != null) {
                          setState(() {
                            //widget.params.video.resolution = value;
                          });
                        }
                      });
                    },
                  ),
                  SettingsTile(
                    title: Text('Framerate'),
                    value: Text("default" /*widget.params.video.fps.toString()*/),
                    onPressed: (BuildContext context) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return PickerScreen(
                                title: "Pick a frame rate",
                                initialValue:
                                    "default frame rate", //widget.params.video.fps.toString(),
                                values: fpsList.toMap());
                          }).then((value) {
                        if (value != null) {
                          setState(() {
                            // widget.params.video.fps = value;
                          });
                        }
                      });
                    },
                  ),
                  CustomSettingsTile(
                    child: Container(
                      child: Column(
                        children: [
                          SettingsTile(
                            title: Text('Bitrate'),
                          ),
                          Row(
                            children: [
                              Slider(
                                value: (/*widget.params.video.bitrate*/ 1 *  1024)
                                    .toDouble(),
                                onChanged: (newValue) {
                                  setState(() {
                                    //widget.params.video.bitrate =
                                    //    (newValue.roundToDouble() * 1024)
                                    //        .toInt();
                                  });
                                },
                                min: 500,
                                max: 10000,
                              ),
                              Text('default' /*${widget.params.video.bitrate}'*/)
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SettingsSection(
                title: Text('Audio'),
                tiles: [
                  SettingsTile(
                    title: Text("Number of channels"),
                    value: Text("2 chan", ), //widget.params.getChannelToString()),
                    onPressed: (BuildContext context) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return PickerScreen(
                                title: "Pick the number of channels",
                                initialValue:
                                    "2 chan", //widget.params.getChannelToString(),
                                values: {'name': 'John Doe', 'occupation': 'gardener'} ); //getChannelsMap());
                          }).then((value) {
                        if (value != null) {
                          setState(() {
                            //widget.params.audio.channel = value;
                          });
                        }
                      });
                    },
                  ),
                  SettingsTile(
                    title: Text('Bitrate'),
                    value: Text("default rate", ), // widget.params.getBitrateToString()),
                    onPressed: (BuildContext context) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return PickerScreen(
                                title: "Pick a bitrate",
                                initialValue:
                                    "defaut ", //widget.params.getChannelToString(),
                                values: {'name': 'John Doe', 'occupation': 'gardener'}, //audioBitrateList.toMap(
                                    //valueTransformation: (int e) =>
                                    //    bitrateToPrettyString(e))
			    );
                          }).then((value) {
                        if (value != null) {
                          setState(() {
                            //widget.params.audio.bitrate = value;
                          });
                        }
                      });
                    },
                  ),
                  SettingsTile(
                    title: Text('Sample rate'),
                    value: Text("default ",), //widget.params.getSampleRateToString()),
                    onPressed: (BuildContext context) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return PickerScreen(
                                title: "Pick a sample rate",
                                initialValue:
                                    "default ", // widget.params.getSampleRateToString(),
                                values: {'name': 'John Doe', 'occupation': 'gardener'}, ); //getSampleRatesMap());
                          }).then((value) {
                        if (value != null) {
                          setState(() {
                            //widget.params.audio.sampleRate = value;
                          });
                        }
                      });
                    },
                  ),
                  SettingsTile.switchTile(
                    title: Text('Enable echo canceler'),
                    initialValue: true, //widget.params.audio.enableEchoCanceler,
                    onToggle: (bool value) {
                      setState(() {
                        //widget.params.audio.enableEchoCanceler = value;
                      });
                    },
                  ),
                  SettingsTile.switchTile(
                    title: Text('Enable noise suppressor'),
                    initialValue: true, //widget.params.audio.enableNoiseSuppressor,
                    onToggle: (bool value) {
                      setState(() {
                        //widget.params.audio.enableNoiseSuppressor = value;
                      });
                    },
                  ),
                ],
              ),
              SettingsSection(
                title: Text('Blockchain'),
                tiles: [
                  SettingsTile(
                      title: Text('NFT Storage API Key'),
                      value: Text("******"), // widget.params.rtmpUrl),
                      onPressed: (BuildContext context) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return EditTextScreen(
                                  title: "Enter NFT_STORAGE_API_KEY",
                                  initialValue: "******", //widget.params.rtmpUrl,
                                  onChanged: (value) {
                                    setState(() {
                                      //widget.params.rtmpUrl = value;
                                    });
                                  });
                            });
                      }),
                  SettingsTile(
                      title: Text('Gateway to the Polygon testnet'),
                      value: Text("******" /*widget.params.streamKey*/),
                      onPressed: (BuildContext context) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return EditTextScreen(
                                  title: "Enter your ALCHEMY_POLYGON_MUMBAI_API_KEY",
                                  initialValue: "key", //widget.params.streamKey,
                                  onChanged: (value) {
                                    setState(() {
                                      //widget.params.streamKey = value;
                                    });
                                  });
                            });
                      }),
                      SettingsTile(
                      title: Text('Wallet/account private key'),
                      value: Text("******" /*widget.params.streamKey*/),
                      onPressed: (BuildContext context) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return EditTextScreen(
                                  title: "Enter your PRIVATE_KEY",
                                  initialValue: "******", //widget.params.streamKey,
                                  onChanged: (value) {
                                    setState(() {
                                      //widget.params.streamKey = value;
                                    });
                                  });
                            });
                      }),
                ],
              )
            ],
          )),
    );
  }
}

class PickerScreen extends StatelessWidget {
  const PickerScreen({
    Key? key,
    required this.title,
    required this.initialValue,
    required this.values,
  }) : super(key: key);

  final String title;
  final dynamic initialValue;
  final Map<dynamic, String> values;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(title),
            tiles: values.keys.map((e) {
              final value = values[e];

              return SettingsTile(
                title: Text(value!),
                onPressed: (_) {
                  Navigator.of(context).pop(e);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class EditTextScreen extends StatelessWidget {
  const EditTextScreen(
      {Key? key,
      required this.title,
      required this.initialValue,
      required this.onChanged})
      : super(key: key);

  final String title;
  final String initialValue;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: SettingsList(
        sections: [
          SettingsSection(title: Text(title), tiles: [
            CustomSettingsTile(
              child: TextField(
                  controller: TextEditingController(text: initialValue),
                  onChanged: onChanged),
            ),
          ]),
        ],
      ),
    );
  }
}
