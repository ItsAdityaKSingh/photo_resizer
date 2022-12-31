//  ignore_for_file: avoid_print
import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:image/image.dart' as im;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  runApp(Phoenix(child: const MyApp()));

}

void requestPermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
  var status1 = await Permission.manageExternalStorage.status;
  if (!status1.isGranted) {
    await Permission.manageExternalStorage.request();
  }
}

Future<bool> initAsync() async {
  if (Platform.isAndroid) {
    PermissionStatus permissionStatus; // note do not use PermissionStatus? permissionStatus;

    while (true) {
      try {
        permissionStatus = await Permission.storage.request();
        break;
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500), () {});
      }
    }
    return true;
  }
  else {
    bool p1 = await Permission.storage.request().isGranted;
    if (p1) {
      return true;
    } else {
      return false;
    }
  }
}

Future<bool> _promptPermissionSetting() async {
  if (Platform.isIOS && await Permission.storage.request().isGranted &&
      await Permission.photos.request().isGranted ||
      Platform.isAndroid && await Permission.storage.request().isGranted && await Permission.notification.request().isGranted) {
    return true;
  }
  return false;
}


void onStart() async {

  int prevLen = 12893;

  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();

  Future<void> resizeImage(File image) async {
    print(image.path);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    print('done');
    print(prefs.getInt('bHeight'));
    int? bh = prefs.getInt('bHeight')!;
    im.Image? img = im.decodeJpg(File(image.path).readAsBytesSync());
    im.Image thumbnail = im.copyResize(img!, width: ((bh/100)*img.width).round(), height: ((bh/100)*img.height).round());
    final f = await File('/data/user/0/com.example.photo_resizer/cache/y${DateTime.now()}.jpg').writeAsBytes(im.encodeJpg(thumbnail));
    ImageGallerySaver.saveFile(f.path).then((value) => print('Saved ✅'));
    File(image.path).deleteSync();

  }

  Future<MediaPage> getImagesFromGallery() async {

    final List<Album> imageAlbums = await PhotoGallery.listAlbums(
      mediumType: MediumType.image,
    );
    final MediaPage imagePage = await (imageAlbums.where((element) => element.name == 'Camera')).toList()[0].listMedia();
    print((await imagePage.items.first.getFile()).path);
    print((await imagePage.items.last.getFile()).path);
    return imagePage;
  }

  service.onDataReceived.listen((event) async {
    print(event!);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (event.containsKey('action')) {
      while (true) {
        getImagesFromGallery().then((value) async {
          if (value.items.length > prevLen) {
            await resizeImage((await value.items.last.getFile()));
            service.setNotificationInfo(
              title: "Running",
              content: "Updated at ${DateTime.now()}",
            );
          }
          prevLen = value.items.length ;
        });
        await Future.delayed(const Duration(seconds: 10));
      }
    }
  });
}


class MyApp extends StatefulWidget {

  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

late Future<bool> opened;
class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    final prefs = SharedPreferences.getInstance();
    opened = prefs.then((SharedPreferences prefs) {
      return prefs.getBool('opened') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
      future: opened,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return const CircularProgressIndicator();
          default:
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              if (snapshot.data!) {
                return const MyHome();
              } else {
                return const Intro();
              }
            }
        }
      }
    ),
    );
  }
}

class Intro extends StatelessWidget {
  const Intro({Key? key}) : super(key: key);

  Future<void> setOpen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('opened', true);
  }

  @override
  Widget build(BuildContext context) {
    setOpen();
    FlutterBackgroundService.initialize(onStart);
    FlutterBackgroundService().sendData({
      'action': 'action'
    });
    return FutureBuilder(
      future: initAsync(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('An Error Occurred', style: TextStyle(
                  fontSize: 20
                ),),
              ),
            );
          } else if (snapshot.hasData) {
            return Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Image(
                    image: AssetImage('assets/splash.jpeg'),
                  ),
                  const SizedBox(height: 30,),
                  ElevatedButton(
                    onPressed: (){
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyHome()));
                    },
                    child: const Text('Next'),
                  )
                ],
              ),
            );
          }
        }
        return const Scaffold(
          backgroundColor: Colors.black,
        );
      }
    );
  }
}


class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  bool _loading = false;
  List _albums = [];
  late Future<bool> isOn;

  @override
  void initState() {
    super.initState();
    _loading = true;
    isOn = _prefs.then((SharedPreferences prefs) {
      return prefs.getBool('isOn') ?? false;
    });
    requestPermission();
    FlutterBackgroundService.initialize(onStart);
    FlutterBackgroundService().sendData({
      'action': 'action'
    });
    // FlutterBackgroundService.initialize(onStart);
  }


  Future<void> swap(bool value) async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      isOn = prefs.setBool('isOn', value).then((val) async {
        if (value) {
          FlutterBackgroundService.initialize(onStart);
          FlutterBackgroundService().sendData({
            'action': 'action'
          });
        }
        return value;

      });
    });

  }

  SingleValueDropDownController bHeightController = SingleValueDropDownController();
  SingleValueDropDownController heightController = SingleValueDropDownController();

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          title: const Text('Image Resizer', style: TextStyle(color: Colors.white),),
          actions: const [
            // FutureBuilder(
            //   future: isOn,
            //   builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            //     switch (snapshot.connectionState) {
            //       case ConnectionState.waiting:
            //         return const CircularProgressIndicator();
            //       default:
            //         if (snapshot.hasError) {
            //           return Text('Error: ${snapshot.error}');
            //         } else {
            //           return Switch(
            //             value: snapshot.data!,
            //             onChanged: (value) async {
            //               print(value);
            //               await swap(value);
            //             },
            //           );
            //         }
            //     }
            //   }
            // ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14,),
              const Text('Set Resize Parameter', style: TextStyle(fontSize: 16)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: DropDownTextField(
                  controller: bHeightController,
                  searchDecoration: const InputDecoration(
                      hintText: 'Select Size'
                  ),
                  clearOption: true,
                  enableSearch: true,
                  dropDownItemCount: 100,
                  dropDownList: [
                    for (int i = 10; i <= 50; i+=10)
                      DropDownValueModel(name: '${2*i}%', value: i.toString())
                  ],
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    print(bHeightController.dropDownValue!.value);
                    await prefs.setInt('bHeight', int.parse(bHeightController.dropDownValue!.value));
                    SystemNavigator.pop();
                  },
                  child: const Text('Set'),
                ),
              ),
              const SizedBox(height: 40,),
              const Text('Crop an Image from Gallery', style: TextStyle(fontSize: 16),),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: DropDownTextField(
                  controller: heightController,
                  searchDecoration: const InputDecoration(
                      hintText: 'Select Size'
                  ),
                  clearOption: true,
                  enableSearch: true,
                  dropDownItemCount: 100,
                  dropDownList: [
                    for (int i = 10; i <= 100; i+=10)
                      DropDownValueModel(name: '$i%', value: i.toString())
                  ],
                ),
              ),
              Center(
                child: ElevatedButton(onPressed: () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('height', int.parse(heightController.dropDownValue!.value));
                  final pickedFile = await ImagePicker().pickImage(requestFullMetadata:true, source: ImageSource.gallery);
                  final List<Album> imageAlbums = await PhotoGallery.listAlbums(
                    mediumType: MediumType.image,
                  );
                  final MediaPage imagePage = await (imageAlbums.where((element) => element.name == 'Camera')).toList()[0].listMedia();
                  final data = await readExifFromBytes(File(pickedFile!.path).readAsBytesSync());
                  print(data['EXIF DateTimeOriginal']);
                  for (var image in imagePage.items.reversed.toList()) {
                    print(await image.getFile());
                    String s = data['EXIF DateTimeOriginal'].toString();
                    String news = '';
                    int i = 0;
                    for (var element in s.runes) {
                      var ch = String.fromCharCode(element);
                      if (ch == ':' && i < 2) {
                        news += '-';
                        i++;
                        continue;
                      }
                      else {
                        news += ch;
                      }
                    }
                    final d1 = DateTime.parse(news);
                    final d2 = DateTime.parse(image.creationDate.toString());
                    if (d1.difference(d2).inSeconds == 0) {
                      File((await image.getFile()).path).deleteSync();
                      break;
                    }
                  }
                  print(pickedFile.path);
                  im.Image? image = im.decodeJpg(File(pickedFile.path).readAsBytesSync());
                  int h = prefs.getInt('height')!;
                  im.Image thumbnail = im.copyResize(image!, width: ((h/100)*image.width).round(), height: ((h/100)*image.height).round());
                  final f = await File('/data/user/0/com.example.photo_resizer/cache/y${DateTime.now()}.png').writeAsBytes(im.encodePng(thumbnail));
                  ImageGallerySaver.saveFile(f.path);
                  // Directory appDocDir = Directory("storage/emulated/0");
                  // var result = await FilesystemPicker.open(fsType: FilesystemType.file ,allowedExtensions: [".png", ".jpg"],rootDirectory: appDocDir, context: context);
                  // if (result != null) {
                  //   File file = File(result);
                  //   print(file.parent.path); //// the path where the file is saved
                  //   print(file.absolute.path);
                  //
                  //   im.Image? image = im.decodeJpg(File(file.absolute.path).readAsBytesSync());
                  //   int h = prefs.getInt('height')!;
                  //   im.Image thumbnail = im.copyResize(image!, width: ((h/100)*image.width).round(), height: ((h/100)*image.height).round());
                  //   final f = await File('/data/user/0/com.example.photo_resizer/cache/y${DateTime.now()}.png').writeAsBytes(im.encodePng(thumbnail));
                  //   ImageGallerySaver.saveFile(f.path);
                  //   File(file.absolute.path).deleteSync();
                  // }
                }, child: const Text('Choose and Crop')),
              )
            ],
          ),
        )
    );
  }
}
