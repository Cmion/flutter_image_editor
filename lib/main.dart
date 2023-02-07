import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_editor/image_editor.dart';

void main() {
  runApp(const MyApp());
}

double toRad(num degree) {
  return (degree * math.pi) / 180;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  static Size size(BuildContext context) {
    return MediaQuery.of(context).size;
  }

  static double screenHeight(BuildContext context, {ratio = 1, sub = 0}) {
    return size(context).height * ratio - sub;
  }

  static double screenWidth(BuildContext context,
      {ratio = 1, sub = 0, horizontalSub = 0}) {
    return (size(context).width * ratio - sub) - (horizontalSub * 2);
  }
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
  Uint8List? image;
  String imageURL =
      ("https://images.unsplash.com/photo-1675469674388-602b33b9f68e?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxlZGl0b3JpYWwtZmVlZHw0fHx8ZW58MHx8fHw%3D&auto=format&fit=crop&w=800&q=60");
  double angleIndex = 0;
  double rotation = 0;
  GlobalKey imageKey = GlobalKey();
  Size? imageKeySize = const Size(0, 0);
  Rect imageRect = Rect.zero;

  bool hideCropper = false;
  bool isVertical = true;

  // Grid
  double gridHeight = 0;
  double gridWidth = 0;
  double originalGridHeight = 0;
  double originalGridWidth = 0;

  Offset topLeftDragOffset = Offset.zero;
  Offset topRightDragOffset = Offset.zero;
  Offset bottomLeftDragOffset = Offset.zero;
  Offset bottomRightDragOffset = Offset.zero;

  Offset dragSpaceOffset = const Offset(100, 100);

  double dragAngleRadius = 30;

  @override
  void initState() {
    _setImage();
    // _editImage();
    super.initState();
  }

  Future<Uint8List?> _loadNetworkImage(String path) async {
    final completer = Completer<ImageInfo>();
    var img = NetworkImage(path);
    img.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) => completer.complete(info)));
    final imageInfo = await completer.future;
    imageKeySize = Size(
        imageInfo.image.height.toDouble(), imageInfo.image.width.toDouble());
    final byteData =
        await imageInfo.image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  void _setImage() async {
    image = (await _loadNetworkImage(imageURL))!;
    // print('IMaged image:: $image');
    setState(() {
      imageKeySize = imageKey.currentContext?.size;
      gridHeight = imageKeySize?.height ?? 0;
      gridWidth = imageKeySize?.width ?? 0;
    });
  }

  Future<void> _editImage() async {
    final editorOption = ImageEditorOption();
    editorOption.addOption(const FlipOption());
    editorOption
        .addOption(const ClipOption(x: 0, y: 0, width: 1920, height: 1920));
    editorOption.addOption(const RotateOption(360));

    editorOption.outputFormat = const OutputFormat.png(88);

    Uint8List? data = await ImageEditor.editImage(
        image: image!, imageEditorOption: editorOption);
    if (data != null) {
      setState(() {
        image = data;
      });
    }
  }

  void _flipImage({bool horizontal = false, bool vertical = false}) async {
    final editorOption = ImageEditorOption();
    editorOption.addOption(const FlipOption());
    editorOption.outputFormat = const OutputFormat.png(100);
    Uint8List? data = await ImageEditor.editImage(
        image: image!, imageEditorOption: editorOption);
    if (data != null) {
      setState(() {
        image = data;
      });
    }
  }

  void _rotateImage() async {
    setState(() {
      angleIndex = (angleIndex - 0.25);
      hideCropper = true;

      // print(angleIndex);
      if ((angleIndex % 0.5).abs() == 0) {
        isVertical = true;

        // print(isVertical);
      } else {
        isVertical = false;
      }
    });
  }

  void _onPanStart(DragStartDetails details, String position) {
    switch (position) {
      case 'topLeft':
        topLeftDragOffset = details.localPosition;
        break;
      case 'topRight':
        topRightDragOffset = details.localPosition;
        break;
      case 'bottomLeft':
        bottomLeftDragOffset = details.globalPosition;
        break;
      case 'bottomRight':
        bottomRightDragOffset = details.globalPosition;
        break;
      default:
        break;
    }
  }

  void _onPanUpdate(DragUpdateDetails details, String position) {
    switch (position) {
      case 'topLeft':
        Offset clampOffset1 = Offset.zero;
        Offset clampOffset2 = Offset(imageRect.width - dragAngleRadius,
            imageRect.bottom - imageRect.top - dragAngleRadius);
        Offset balancingOffset = Offset(imageRect.left, imageRect.top);

        topLeftDragOffset = (details.globalPosition - balancingOffset)
            .clamp(clampOffset1, clampOffset2)
            .clampDY(
                0,
                (imageRect.height - dragAngleRadius) +
                    bottomLeftDragOffset.dy -
                    dragSpaceOffset.dy)
            .clampDX(
                0,
                imageRect.width -
                    dragAngleRadius +
                    topRightDragOffset.dx -
                    dragSpaceOffset.dx);

        topRightDragOffset =
            Offset(topRightDragOffset.dx, topLeftDragOffset.dy);

        bottomLeftDragOffset =
            Offset(topLeftDragOffset.dx, bottomLeftDragOffset.dy);

        break;

      case 'topRight':
        Offset clampOffset1 =
            Offset(-(imageRect.right - dragAngleRadius - imageRect.left), 0);
        Offset clampOffset2 =
            Offset(0, imageRect.bottom - imageRect.top - dragAngleRadius);
        Offset balancingOffset = Offset(imageRect.right, imageRect.top);

        topRightDragOffset = ((details.globalPosition - balancingOffset))
            .clamp(clampOffset1, clampOffset2)
            .clampDY(
                0,
                (imageRect.height - dragAngleRadius) +
                    bottomLeftDragOffset.dy -
                    dragSpaceOffset.dy)
            .clampDX(
                -(imageRect.right - dragAngleRadius - imageRect.left) +
                    topLeftDragOffset.dx +
                    dragSpaceOffset.dx,
                0);

        topLeftDragOffset = Offset(topLeftDragOffset.dx, topRightDragOffset.dy);

        bottomRightDragOffset =
            Offset(topRightDragOffset.dx, bottomRightDragOffset.dy);

        break;

      case 'bottomLeft':
        Offset clampOffset1 =
            Offset(0, -(imageRect.bottom - dragAngleRadius - imageRect.top));
        Offset clampOffset2 = Offset(imageRect.width - dragAngleRadius, 0);
        Offset balancingOffset = Offset(imageRect.left, imageRect.bottom);

        bottomLeftDragOffset = (details.globalPosition - balancingOffset)
            .clamp(clampOffset1, clampOffset2)
            .clampDY(
                topLeftDragOffset.dy -
                    imageRect.height +
                    dragAngleRadius +
                    dragSpaceOffset.dy,
                0)
            .clampDX(
                0,
                imageRect.width -
                    dragAngleRadius +
                    bottomRightDragOffset.dx -
                    dragSpaceOffset.dx);

        bottomRightDragOffset =
            Offset(bottomRightDragOffset.dx, bottomLeftDragOffset.dy);

        topLeftDragOffset =
            Offset(bottomLeftDragOffset.dx, topLeftDragOffset.dy);

        break;

      case 'bottomRight':
        Offset clampOffset1 = Offset(
            -(imageRect.right - dragAngleRadius - imageRect.left),
            -(imageRect.bottom - dragAngleRadius - imageRect.top));
        Offset clampOffset2 = const Offset(0, 0);
        Offset balancingOffset = Offset(imageRect.right, imageRect.bottom);

        bottomRightDragOffset = (details.globalPosition - balancingOffset)
            .clamp(clampOffset1, clampOffset2)
            .clampDY(
                topRightDragOffset.dy -
                    imageRect.height +
                    dragAngleRadius +
                    dragSpaceOffset.dy,
                0)
            .clampDX(
                -(imageRect.right - dragAngleRadius - imageRect.left) +
                    bottomLeftDragOffset.dx +
                    dragSpaceOffset.dx,
                0);

        bottomLeftDragOffset =
            Offset(bottomLeftDragOffset.dx, bottomRightDragOffset.dy);

        topRightDragOffset =
            Offset(bottomRightDragOffset.dx, topRightDragOffset.dy);

        break;
      default:
        break;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Image? memImage;
    double scale = 1;

    if (image != null) {
      memImage = Image.memory(image!);
    }
    if (imageKeySize?.width != null &&
        imageKeySize?.height != null &&
        !isVertical) {
      scale =
          (MyHomePage.screenWidth(context, ratio: 0.6) / imageKeySize!.height) *
              1.5;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 40, width: 0),
          if (memImage != null)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Stack(
                children: [
                  AnimatedRotation(
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 250),
                    turns: angleIndex,
                    key: imageKey,
                    child: AnimatedScale(
                      scale: scale,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Image.memory(image!),
                    ),
                    onEnd: () {
                      setState(() {
                        hideCropper = false;
                      });
                    },
                  ),
                  if (!hideCropper)
                    Positioned.fill(
                      child: LayoutBuilder(builder: (context, constraints) {
                        executeAfterBuild(context, constraints);

                        Size size = Size(
                            constraints.maxWidth - topLeftDragOffset.dx,
                            constraints.maxHeight - topLeftDragOffset.dy);

                        size = Rect.fromLTRB(
                                topLeftDragOffset.dx,
                                topLeftDragOffset.dy,
                                imageRect.width + topRightDragOffset.dx,
                                imageRect.height + bottomRightDragOffset.dy)
                            .size;

                        return CustomPaint(
                          willChange: true,
                          painter: OverlayGrid(
                            size: size,
                            imageOffset: topLeftDragOffset,
                          ),
                        );
                      }),
                    ),
                  if (!hideCropper)
                    Transform.translate(
                      offset: topLeftDragOffset,
                      child: GestureDetector(
                        // behavior: HitTestBehavior.translucent,
                        onPanStart: (details) =>
                            _onPanStart(details, 'topLeft'),
                        onPanUpdate: (details) =>
                            _onPanUpdate(details, 'topLeft'),

                        child: LayoutBuilder(builder: (context, constraints) {
                          Size size = Size(gridWidth, gridHeight);
                          // print(size);
                          return CustomPaint(
                            willChange: true,
                            size: Size(dragAngleRadius, dragAngleRadius),
                            painter: TopLeftHandlePainter(
                                size: size,
                                offset: Offset.zero,
                                imageRect: imageRect),
                          );
                        }),
                      ),
                    ),
                  if (!hideCropper)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: topRightDragOffset,
                        child: GestureDetector(
                          // behavior: HitTestBehavior.translucent,
                          onPanStart: (details) =>
                              _onPanStart(details, 'topRight'),
                          onPanUpdate: (details) =>
                              _onPanUpdate(details, 'topRight'),

                          child: LayoutBuilder(builder: (context, constraints) {
                            Size size = Size(gridWidth, gridHeight);
                            // print(size);
                            return CustomPaint(
                              willChange: true,
                              size: Size(dragAngleRadius, dragAngleRadius),
                              painter: TopRightHandlePainter(
                                  size: size,
                                  offset: Offset.zero,
                                  imageRect: imageRect),
                            );
                          }),
                        ),
                      ),
                    ),
                  if (!hideCropper)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Transform.translate(
                        offset: bottomLeftDragOffset,
                        child: GestureDetector(
                          onPanStart: (details) =>
                              _onPanStart(details, 'bottomLeft'),
                          onPanUpdate: (details) =>
                              _onPanUpdate(details, 'bottomLeft'),
                          child: CustomPaint(
                            willChange: true,
                            size: Size(dragAngleRadius, dragAngleRadius),
                            painter: BottomLeftHandlePainter(),
                          ),
                        ),
                      ),
                    ),
                  if (!hideCropper)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Transform.translate(
                        offset: bottomRightDragOffset,
                        child: GestureDetector(
                          onPanStart: (details) =>
                              _onPanStart(details, 'bottomRight'),
                          onPanUpdate: (details) =>
                              _onPanUpdate(details, 'bottomRight'),
                          child: CustomPaint(
                            willChange: true,
                            size: Size(dragAngleRadius, dragAngleRadius),
                            painter: BottomRightHandlePainter(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: () {
                  _rotateImage();
                },
                child: const Icon(Icons.rotate_90_degrees_ccw_outlined),
              ),
              OutlinedButton(
                onPressed: () {
                  _flipImage(horizontal: true);
                },
                child: const Icon(Icons.flip_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> executeAfterBuild(
      BuildContext context, BoxConstraints constraints) async {
    // this code will get executed after the build method
    // because of the way async functions are scheduled
    if (mounted) {
      // setState(() {
      imageKeySize = Size(constraints.maxWidth, constraints.maxHeight);

      if (gridHeight == 0 && gridWidth == 0) {
        gridHeight = constraints.maxHeight;
        gridWidth = constraints.maxWidth;
      }

      if (originalGridHeight == 0 && originalGridWidth == 0) {
        originalGridHeight = constraints.maxHeight;
        originalGridWidth = constraints.maxWidth;
      }

      if (imageKey.currentContext != null) {
        RenderBox box =
            imageKey.currentContext!.findRenderObject() as RenderBox;
        Offset offset = box.localToGlobal(Offset.zero);

        imageRect = Rect.fromLTRB(
            offset.dx,
            offset.dy,
            offset.dx + constraints.maxWidth,
            offset.dy + constraints.maxHeight);

        // print(imageRect);
      }
    }
  }
}

class OverlayGrid extends CustomPainter {
  OverlayGrid({required this.size, required this.imageOffset});
  final Size size;
  final Offset imageOffset;

  double cornerSize = 15;
  @override
  void paint(Canvas canvas, Size _) {
    // print(size);
    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    _drawVertical(paint, canvas, size);
    _drawHorizontal(paint, canvas, size);
    _drawAngles(canvas, size);
  }

  void _drawVertical(Paint paint, Canvas canvas, Size size) {
    double gutterSize = size.width / 3;
    Offset v1 = Offset(imageOffset.dx + gutterSize, imageOffset.dy);
    Offset v2 =
        Offset(imageOffset.dx + gutterSize, imageOffset.dy + size.height);

    Offset v3 = Offset(imageOffset.dx + gutterSize * 2, imageOffset.dy);
    Offset v4 =
        Offset(imageOffset.dx + gutterSize * 2, imageOffset.dy + size.height);

    // Vertical 1
    canvas.drawLine(v1, v2, paint);
    // Vertical 2
    canvas.drawLine(v3, v4, paint);
  }

  void _drawHorizontal(Paint paint, Canvas canvas, Size size) {
    double gutterSize = size.height / 3;
    Offset v1 = Offset(imageOffset.dx, imageOffset.dy + gutterSize);
    Offset v2 =
        Offset(imageOffset.dx + size.width, imageOffset.dy + gutterSize);

    Offset v3 = Offset(imageOffset.dx, imageOffset.dy + gutterSize * 2);
    Offset v4 =
        Offset(imageOffset.dx + size.width, imageOffset.dy + gutterSize * 2);

    // Vertical 1
    canvas.drawLine(v1, v2, paint);
    // Vertical 2
    canvas.drawLine(v3, v4, paint);
  }

  void _drawAngles(Canvas canvas, Size paintSize) {
    final Paint gridPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double x = (paintSize.width - size.width) / 2;
    final double y = (paintSize.height - size.height) / 2;

    canvas.drawRect(
        Rect.fromLTRB(imageOffset.dx + x, imageOffset.dy + y,
            imageOffset.dx + x + size.width, imageOffset.dy + y + size.height),
        gridPaint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}

class TopLeftHandlePainter extends CustomPainter {
  TopLeftHandlePainter(
      {this.handleSize = 15,
      required this.size,
      required this.offset,
      required this.imageRect});
  final double handleSize;
  final Size size;
  final Offset offset;
  final Rect imageRect;

  @override
  void paint(Canvas canvas, Size paintSize) {
    ui.PointMode pointMode = ui.PointMode.polygon;
    List<Offset> angle1 = [
      offset,
      Offset(offset.dx, offset.dy + handleSize),
      offset,
      Offset(offset.dx + handleSize, offset.dy)
    ];

    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.square;

    canvas.drawPoints(pointMode, angle1, paint);

    paint.color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTRB(offset.dx, offset.dy, offset.dx + handleSize * 2,
            offset.dy + handleSize * 2),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class TopRightHandlePainter extends CustomPainter {
  TopRightHandlePainter(
      {this.handleSize = 15,
      required this.size,
      required this.offset,
      required this.imageRect});

  final double handleSize;
  final Size size;
  final Offset offset;
  final Rect imageRect;

  @override
  void paint(Canvas canvas, Size size) {
    ui.PointMode pointMode = ui.PointMode.polygon;

    List<Offset> angle3 = [
      Offset(size.width - handleSize, 0),
      Offset(size.width, 0),
      Offset(size.width, 0),
      Offset(size.width, handleSize),
    ];

    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.square;

    canvas.drawPoints(pointMode, angle3, paint);

    paint.color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTRB(offset.dx, offset.dy, offset.dx + handleSize * 2,
            offset.dy + handleSize * 2),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BottomLeftHandlePainter extends CustomPainter {
  BottomLeftHandlePainter({this.handleSize = 15});
  final double handleSize;
  @override
  void paint(Canvas canvas, Size size) {
    ui.PointMode pointMode = ui.PointMode.polygon;

    List<Offset> angle2 = [
      Offset(0, size.height - handleSize),
      Offset(0, size.height),
      Offset(0, size.height),
      Offset(handleSize, size.height),
    ];

    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.square;

    canvas.drawPoints(pointMode, angle2, paint);

    paint.color = Colors.transparent;
    canvas.drawRect(Rect.fromLTRB(0, 0, handleSize * 2, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BottomRightHandlePainter extends CustomPainter {
  BottomRightHandlePainter({this.handleSize = 15});
  final double handleSize;
  @override
  void paint(Canvas canvas, Size size) {
    ui.PointMode pointMode = ui.PointMode.polygon;

    List<Offset> angle4 = [
      Offset(size.width, size.height - handleSize),
      Offset(size.width, size.height),
      Offset(size.width, size.height),
      Offset(size.width - handleSize, size.height),
    ];

    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.square;

    canvas.drawPoints(pointMode, angle4, paint);

    paint.color = Colors.transparent;
    canvas.drawRect(Rect.fromLTRB(0, 0, handleSize * 2, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

extension OffsetExtension on Offset {
  Offset clampToRect(Rect rect) {
    return Offset(
      dx.clamp(rect.left, rect.right),
      dy.clamp(rect.top, rect.bottom),
    );
  }

  Offset clamp(Offset offset1, Offset offset2) {
    return Offset(
      dx.clamp(offset1.dx, offset2.dx),
      dy.clamp(offset1.dy, offset2.dy),
    );
  }

  Offset clampDX(double lowerLimit, double upperLimit) {
    return Offset(
      dx.clamp(lowerLimit, upperLimit),
      dy,
    );
  }

  Offset clampDY(double lowerLimit, double upperLimit) {
    return Offset(
      dx,
      dy.clamp(lowerLimit, upperLimit),
    );
  }

  Offset negate() {
    return Offset(
      dx * -1,
      dy * -1,
    );
  }

  Offset negateX() {
    return Offset(
      dx * -1,
      dy,
    );
  }

  Offset negateY() {
    return Offset(
      dx,
      dy * -1,
    );
  }
}
