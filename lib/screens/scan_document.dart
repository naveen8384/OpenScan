import 'dart:io';
import 'dart:ui';
import 'dart:core';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:images_to_pdf/images_to_pdf.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:openscan/screens/home_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class ScanDocument extends StatefulWidget {
  static String route = "ScanDocument";

  @override
  _ScanDocumentState createState() => _ScanDocumentState();
}

class _ScanDocumentState extends State<ScanDocument> {
  File imageFile;
  List<Widget> imageFiles;
  File _pdfFile;
  String _status = "Not created";
  FileStat _pdfStat;
  bool _generating = false;
  String appName = 'OpenScan';
  String appPath;
  String docPath;

  @override
  void initState() {
    super.initState();
    imageFiles = <Widget>[
      Container(
        padding: EdgeInsets.only(top: 8.0),
        child: Text(
          "Scroll down to view other photos",
          textAlign: TextAlign.center,
        ),
      ),
    ];
    createDirectoryName();
  }

  Future _onWillPop() async{
    Navigator.popAndPushNamed(context,HomeScreen.route);
  }

  Future<String> getAppPath() async {
    final Directory _appDocDir = await getApplicationDocumentsDirectory();
    final Directory _appDocDirFolder =
        Directory('${_appDocDir.path}/$appName/');

    if (await _appDocDirFolder.exists()) {
      return _appDocDirFolder.path;
    } else {
      final Directory _appDocDirNewFolder =
          await _appDocDirFolder.create(recursive: true);
      return _appDocDirNewFolder.path;
    }
  }

  Future<void> displayDialog() async {
    String displayText;

    if (_status == "PDF Generated (${_pdfStat.size ~/ 1024}kb)")
      displayText = "Success. File stored in the Downloads folder.";
    else if (_status.startsWith("Failed to generate pdf"))
      displayText = "Failed to generate pdf. Try Again.";

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alert'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('$displayText'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPdf() async {
    try {
      this.setState(() => _generating = true);
      final output =
          File("/storage/emulated/0/Download/OpenScan ${DateTime.now()}.pdf");

      var images = [imageFile];
      var decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());

      this.setState(() => _status = 'Generating PDF');
      await ImagesToPdf.createPdf(
        pages: images
            .map(
              (file) => PdfPage(
                imageFile: file,
                size: Size(decodedImage.width.toDouble(),
                    decodedImage.height.toDouble()),
                compressionQuality: 0.5,
              ),
            )
            .toList(),
        output: output,
      );
      _pdfStat = await output.stat();
      this.setState(() {
        _pdfFile = output;
        _status = 'PDF Generated (${_pdfStat.size ~/ 1024}kb)';
      });
      print(output);
    } catch (e) {
      this.setState(() => _status = 'Failed to generate pdf: $e".');
    } finally {
      this.setState(() => _generating = false);
    }
  }

  Future _cropImage(imageFile) async {
    File croppedFile = await ImageCropper.cropImage(
        sourcePath: imageFile.path,
        aspectRatioPresets: Platform.isAndroid
            ? [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ]
            : [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio5x3,
                CropAspectRatioPreset.ratio5x4,
                CropAspectRatioPreset.ratio7x5,
                CropAspectRatioPreset.ratio16x9
              ],
        androidUiSettings: AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.black45,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        iosUiSettings: IOSUiSettings(
          title: 'Cropper',
        ));
    if (croppedFile != null) {
      setState(() {
        imageFile = croppedFile;
      });
      return imageFile;
    }
  }

  var image;
  Future _openCamera() async {
    final _picker = ImagePicker();
    var picture = await _picker.getImage(source: ImageSource.camera);
    setState(() {
      final requiredPicture = File(picture.path);
      print(picture.path);
      image = requiredPicture;
    });
  }

  Future<void> createDirectoryName() async {
    Directory appDir = await getExternalStorageDirectory();
    print(appDir);
    docPath = "${appDir.path}/OpenScan ${DateTime.now()}";
  }

  Future<void> _saveImage(File image) async {
    if (await Directory(docPath).exists() != true) {
      new Directory(docPath).create();
    }

    File tempPic = File("$docPath/${imageFiles.length - 1}.png");
    image.copy(tempPic.path);
  }

  Future<void> _deleteTemporaryFiles() async {
    // Delete the temporary files created by the image_picker package
    Directory appDocDir = await getExternalStorageDirectory();
    String appDocPath = "${appDocDir.path}/Pictures/";
    Directory del = Directory(appDocPath);
    if (await del.exists()) {
      del.deleteSync(recursive: true);
    }
    // print(" something ");
    // print(await del.exists());
    new Directory(appDocPath).create();
    // print(await del.exists());
  }

  @override
  void dispose() {
    super.dispose();
    imageFile = null;
    image = null;
    imageFiles = null;
    _pdfFile = null;
    _status = null;
    _pdfStat = null;
    _generating = null;
    appName = null;
    appPath = null;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            title: Text("Scan Document"),
          ),
          body: ListView.separated(
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            itemCount: imageFiles.length,
            itemBuilder: (context, index) {
              return imageFiles[index];
            },
            separatorBuilder: (BuildContext context, _) => Divider(),
          ),
          bottomNavigationBar: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                    onPressed: () {
//                    _cropImage();
                    },
                    child: Container(
                      height: 50,
                      child: Icon(Icons.crop),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: RaisedButton(
                    onPressed: () async {
//                    await _createPdf();
//                    await displayDialog();
                      await _deleteTemporaryFiles();
                      Navigator.popAndPushNamed(context,HomeScreen.route);
                    },
                    color: Colors.lightGreen,
                    child: Container(
                      alignment: Alignment.center,
                      height: 50,
                      child: Text("Done"),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              await _openCamera();
              if (image != null) {
                var imageFile = await _cropImage(image);
                imageFiles.add(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(
                      imageFile,
                      width: size.width * 0.4,
                    ),
                  ),
                );
                await _saveImage(image);
                setState(() {});
              }
            },
            child: Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

