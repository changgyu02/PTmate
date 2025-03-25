import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<StatefulWidget> createState() => QRScannerState();
}

class QRScannerState extends State<QRScannerPage> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // 디바이스의 크기에 따라 scanArea를 지정 반응형(?)과 비슷한 개념
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
        MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,  // QRView가 생성되면 _onQRViewCreated를 실행
      overlay: QrScannerOverlayShape(
          borderColor: Colors.blueAccent, // 모서리 테두리 색
          borderRadius: 10, // 둥글게 둥글게
          borderLength: 30, // 테두리 길이 길면 길수록 네모에 가까워진다.
          borderWidth: 10, // 테두리 너비
          cutOutSize: scanArea),
      // 카메라 사용 권한을 체크한다.
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller; // 컨트롤러를 통해 스캐너를 제어
    });

    int counter = 0;
    controller.scannedDataStream.listen((scanData) async{
      counter++; // QR코드가 인식되면 counter를 1 올려준다.
      await controller.pauseCamera(); // 인식되었으니 카메라를 멈춘다.

      setState(() {
        result = scanData; // 스캔된 데이터를 담는다.
        debugPrint('barcode_result----------------');
        debugPrint(result!.code);

        String url = result!.code.toString();

        if(counter == 1){
          Navigator.pop(context, url);
        }
      });
    });
  }

  // 권한 체크를 위한 함수
  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    //log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) { // 카메라 사용 권한이 없을 경우
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}