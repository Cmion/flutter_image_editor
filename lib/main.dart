import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_editor/image_editor.dart';
import 'package:tuple/tuple.dart';

void main() {
  runApp(const MyApp());
}

double toRad(num degree) {
  return (degree * math.pi) / 180;
}

double toDeg(num rad) {
  return rad * (180 / math.pi);
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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipAnimationController;

  Uint8List? image;

  List<String> sampleImages = [
    'https://images.unsplash.com/photo-1675856531253-5940b77ea03e?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxlZGl0b3JpYWwtZmVlZHwxMzV8fHxlbnwwfHx8fA%3D%3D&auto=format&fit=crop&w=800&q=60',
    'https://images.unsplash.com/photo-1670272505391-8efda8e7a99c?ixlib=rb-4.0.3&ixid=MnwxMjA3fDF8MHxlZGl0b3JpYWwtZmVlZHwxMzd8fHxlbnwwfHx8fA%3D%3D&auto=format&fit=crop&w=800&q=60',
    'https://images.unsplash.com/photo-1675851816472-f95824b6f502?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxlZGl0b3JpYWwtZmVlZHwxNjV8fHxlbnwwfHx8fA%3D%3D&auto=format&fit=crop&w=800&q=60',
    'https://plus.unsplash.com/premium_photo-1675799745857-d94e32a43849?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxlZGl0b3JpYWwtZmVlZHwxM3x8fGVufDB8fHx8&auto=format&fit=crop&w=2000&q=60',
    'https://images.unsplash.com/photo-1675995832602-caf2726a07aa?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxlZGl0b3JpYWwtZmVlZHw1OHx8fGVufDB8fHx8&auto=format&fit=crop&w=2000&q=60',
    'https://plus.unsplash.com/premium_photo-1661695869290-d54909c179ec?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxlZGl0b3JpYWwtZmVlZHwxMTN8fHxlbnwwfHx8fA%3D%3D&auto=format&fit=crop&w=2000&q=60',
  ];
  late String imageURL;
  int imageIndex = 0;
  double angleIndex = 0;
  double rotation = 0;

  GlobalKey imageContainerKey = GlobalKey();
  Size? imageContainerKeySize = const Size(0, 0);
  Rect imageContainerRect = Rect.zero;

  Size? imageDefaultSize = const Size(0, 0);
  Rect imageRect = Rect.zero;
  GlobalKey imageKey = GlobalKey();

  bool hideCropper = true;
  bool isVertical = true;

  // Drag
  Offset topLeftDragOffset = Offset.zero;
  Offset topRightDragOffset = Offset.zero;
  Offset bottomLeftDragOffset = Offset.zero;
  Offset bottomRightDragOffset = Offset.zero;

  Offset topDragOffset = Offset.zero;
  Offset bottomDragOffset = Offset.zero;
  Offset leftDragOffset = Offset.zero;
  Offset rightDragOffset = Offset.zero;

  Offset dragSpaceOffset = const Offset(100, 100);

  double dragAngleRadius = 30;

  @override
  void initState() {
    _onSetImage();
    _flipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      lowerBound: -1,
      upperBound: 1,
    );

    super.initState();
  }

  @override
  void dispose() {
    _flipAnimationController.dispose();
    super.dispose();
  }

  Future<Tuple2<Uint8List?, ImageInfo>> _onLoadNetworkImage(String path) async {
    final completer = Completer<ImageInfo>();
    var img = CachedNetworkImageProvider(path);
    img.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) => completer.complete(info)));
    final imageInfo = await completer.future;
    imageContainerKeySize = Size(
        imageInfo.image.height.toDouble(), imageInfo.image.width.toDouble());
    final byteData =
        await imageInfo.image.toByteData(format: ui.ImageByteFormat.png);

    return Tuple2(byteData?.buffer.asUint8List(), imageInfo);
  }

  void _onSetImage() async {
    imageURL = sampleImages[imageIndex];
    Tuple2<Uint8List?, ImageInfo> tuple = (await _onLoadNetworkImage(imageURL));
    image = tuple.item1!;

    imageDefaultSize = Size(tuple.item2.image.width.toDouble(),
        (tuple.item2.image.height).toDouble());
    hideCropper = false;
    setState(() {});
  }

  Future<void> _onPerformImageEdit() async {
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

  void _onChangeImage() {
    _onResetCropper();
    imageIndex = imageIndex + 1;
    if (imageIndex == sampleImages.length) {
      imageIndex = 0;
    }
    _onSetImage();
    // setState(() {});
  }

  void _onResetCropper() {
    topRightDragOffset = Offset.zero;
    topLeftDragOffset = Offset.zero;
    bottomLeftDragOffset = Offset.zero;
    bottomRightDragOffset = Offset.zero;
    rightDragOffset = Offset.zero;
    topDragOffset = Offset.zero;
    bottomDragOffset = Offset.zero;
    leftDragOffset = Offset.zero;
    imageRect = Rect.zero;
    hideCropper = true;
    angleIndex = 0;
    _flipAnimationController.value = 1;
  }

  void _onFlipImage({bool horizontal = false, bool vertical = false}) async {
    // final editorOption = ImageEditorOption();
    // editorOption.addOption(const FlipOption());
    // editorOption.outputFormat = const OutputFormat.png(100);
    // Uint8List? data = await ImageEditor.editImage(
    //     image: image!, imageEditorOption: editorOption);
    // if (data != null) {
    //   setState(() {
    //     image = data;
    //   });
    // }

    if (_flipAnimationController.isCompleted &&
        _flipAnimationController.value == 1) {
      _flipAnimationController.animateTo(-1, curve: Curves.easeInOut);
    } else {
      _flipAnimationController.animateTo(1, curve: Curves.easeInOut);
    }
  }

  void _onImageRotation() async {
    _onResetCropper();
    angleIndex = (angleIndex - 0.25);

    if ((angleIndex % 0.5).abs() == 0) {
      isVertical = true;
      imageRect = _computeBoxFitScaleDown(true);
    } else {
      isVertical = false;
      imageRect = _computeBoxFitScaleDown(false);
    }

    setState(() {});
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
      case 'top':
        topDragOffset = details.globalPosition;
        break;
      case 'bottom':
        bottomDragOffset = details.globalPosition;
        break;
      case 'left':
        leftDragOffset = details.globalPosition;
        break;
      case 'right':
        rightDragOffset = details.globalPosition;
        break;
      default:
        break;
    }
  }

  void _onPanUpdate(DragUpdateDetails details, String position) {
    switch (position) {
      case 'top':
        Offset containerBalancingOffset = Offset(0, imageContainerRect.top);
        Offset imageBalancingOffset = Offset(0, imageRect.top);

        topDragOffset = (Offset(0, details.globalPosition.dy) -
                containerBalancingOffset -
                imageBalancingOffset)
            .clampDY(
                0,
                (imageRect.height - dragAngleRadius) +
                    bottomLeftDragOffset.dy -
                    dragSpaceOffset.dy);

        topLeftDragOffset = Offset(topLeftDragOffset.dx, topDragOffset.dy);
        topRightDragOffset = Offset(topRightDragOffset.dx, topDragOffset.dy);

        break;

      case 'bottom':
        Offset containerBalancingOffset = Offset(0, imageContainerRect.top);
        Offset imageBalancingOffset = Offset(0, imageRect.bottom);

        bottomDragOffset = (Offset(0, details.globalPosition.dy) -
                containerBalancingOffset -
                imageBalancingOffset)
            // .clamp(clampOffset1, clampOffset2)
            .clampDY(
                topLeftDragOffset.dy -
                    imageRect.height +
                    dragAngleRadius +
                    dragSpaceOffset.dy,
                0);

        bottomLeftDragOffset =
            Offset(bottomLeftDragOffset.dx, bottomDragOffset.dy);
        bottomRightDragOffset =
            Offset(bottomRightDragOffset.dx, bottomDragOffset.dy);
        break;

      case 'left':
        Offset containerBalancingOffset = Offset(imageContainerRect.left, 0);
        Offset imageBalancingOffset = Offset(imageRect.left, 0);

        leftDragOffset = (Offset(details.globalPosition.dx, 0) -
                containerBalancingOffset -
                imageBalancingOffset)
            .clampDX(
                0,
                imageRect.width -
                    dragAngleRadius +
                    topRightDragOffset.dx -
                    dragSpaceOffset.dx);

        topLeftDragOffset = Offset(leftDragOffset.dx, topLeftDragOffset.dy);

        bottomLeftDragOffset =
            Offset(leftDragOffset.dx, bottomLeftDragOffset.dy);
        break;

      case 'right':
        Offset containerBalancingOffset = Offset(imageContainerRect.left, 0);
        Offset imageBalancingOffset = Offset(imageRect.right, 0);

        rightDragOffset = ((Offset(details.globalPosition.dx, 0) -
                imageBalancingOffset -
                containerBalancingOffset))
            .clampDX(
                -(imageRect.right - dragAngleRadius - imageRect.left) +
                    topLeftDragOffset.dx +
                    dragSpaceOffset.dx,
                0);

        topRightDragOffset = Offset(rightDragOffset.dx, topRightDragOffset.dy);

        bottomRightDragOffset =
            Offset(rightDragOffset.dx, bottomRightDragOffset.dy);
        break;

      case 'topLeft':
        // Offset clampOffset1 = Offset.zero;
        // Offset clampOffset2 = Offset(imageRect.width - dragAngleRadius,
        //     imageRect.bottom - imageRect.top - dragAngleRadius);
        Offset containerBalancingOffset =
            Offset(imageContainerRect.left, imageContainerRect.top);
        Offset imageBalancingOffset = Offset(imageRect.left, imageRect.top);

        topLeftDragOffset = (details.globalPosition -
                containerBalancingOffset -
                imageBalancingOffset)
            // .clamp(clampOffset1, clampOffset2)
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

        topDragOffset = Offset(topDragOffset.dx, topLeftDragOffset.dy);
        leftDragOffset = Offset(topLeftDragOffset.dx, leftDragOffset.dy);

        break;

      case 'topRight':
        // Offset clampOffset1 =
        //     Offset(-(imageRect.right - dragAngleRadius - imageRect.left), 0);
        // Offset clampOffset2 =
        //     Offset(0, imageRect.bottom - imageRect.top - dragAngleRadius);

        Offset containerBalancingOffset =
            Offset(imageContainerRect.left, imageContainerRect.top);
        Offset imageBalancingOffset = Offset(imageRect.right, imageRect.top);

        topRightDragOffset = ((details.globalPosition -
                imageBalancingOffset -
                containerBalancingOffset))
            // // .clamp(clampOffset1, clampOffset2)
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

        topDragOffset = Offset(topDragOffset.dx, topRightDragOffset.dy);
        rightDragOffset = Offset(topRightDragOffset.dx, rightDragOffset.dy);

        break;

      case 'bottomLeft':
        // Offset clampOffset1 =
        //     Offset(0, -(imageRect.bottom - dragAngleRadius - imageRect.top));
        // Offset clampOffset2 = Offset(imageRect.width - dragAngleRadius, 0);
        Offset containerBalancingOffset =
            Offset(imageContainerRect.left, imageContainerRect.top);
        Offset imageBalancingOffset = Offset(imageRect.left, imageRect.bottom);

        bottomLeftDragOffset = (details.globalPosition -
                containerBalancingOffset -
                imageBalancingOffset)
            // .clamp(clampOffset1, clampOffset2)
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

        leftDragOffset = Offset(bottomLeftDragOffset.dx, leftDragOffset.dy);
        bottomDragOffset = Offset(bottomDragOffset.dx, bottomLeftDragOffset.dy);

        break;

      case 'bottomRight':
        // Offset clampOffset1 = Offset(
        //     -(imageRect.right - dragAngleRadius - imageRect.left),
        //     -(imageRect.bottom - dragAngleRadius - imageRect.top));
        // Offset clampOffset2 = const Offset(0, 0);
        Offset containerBalancingOffset =
            Offset(imageContainerRect.left, imageContainerRect.top);
        Offset imageBalancingOffset = Offset(imageRect.right, imageRect.bottom);

        bottomRightDragOffset = (details.globalPosition -
                containerBalancingOffset -
                imageBalancingOffset)
            // .clamp(clampOffset1, clampOffset2)
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

        bottomDragOffset =
            Offset(bottomDragOffset.dx, bottomRightDragOffset.dy);
        rightDragOffset = Offset(bottomRightDragOffset.dx, rightDragOffset.dy);

        break;
      default:
        break;
    }

    setState(() {});
  }

  Future<void> _onCreateNewImage() async {
    final editorOption = ImageEditorOption();
    if (_flipAnimationController.value < 1) {
      editorOption.addOption(const FlipOption());
    }

    if (angleIndex != 0) {
      double angle = math.pi * 2.0 * angleIndex;
      editorOption.addOption(RotateOption(toDeg(angle).toInt()));
    }

    if (topDragOffset != Offset.zero ||
        rightDragOffset != Offset.zero ||
        leftDragOffset != Offset.zero ||
        bottomDragOffset != Offset.zero) {
      Rect rect = Rect.fromLTRB(
              topLeftDragOffset.dx,
              topLeftDragOffset.dy,
              imageRect.width + topRightDragOffset.dx,
              imageRect.height + bottomRightDragOffset.dy)
          ;

      print(rect);

      editorOption.addOption(ClipOption(
          x: rect.left,
          y: rect.top,
          width: rect.size.width,
          height: rect.size.height));
    }

    editorOption.outputFormat = const OutputFormat.png(100);

    Uint8List? data = await ImageEditor.editImage(
        image: image!, imageEditorOption: editorOption);

    // if (data != null) {
    //   setState(() {
    //     image = data;
    //   });
    // }
  }

  void _onPanEnd(DragEndDetails details) {
    print(details);
    _onCreateNewImage();
  }

  Future<void> _executeAfterLayoutBuild(
      BuildContext context, BoxConstraints constraints) async {
    // this code will get executed after the build method
    // because of the way async functions are scheduled
    if (mounted) {
      imageContainerKeySize = Size(constraints.maxWidth, constraints.maxHeight);

      if (imageContainerKey.currentContext != null) {
        RenderBox box =
            imageContainerKey.currentContext!.findRenderObject() as RenderBox;
        Offset offset = box.localToGlobal(Offset.zero);

        imageContainerRect = Rect.fromLTRB(
            offset.dx,
            offset.dy,
            offset.dx + constraints.maxWidth,
            offset.dy + constraints.maxHeight);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (imageKey.currentContext != null &&
            imageDefaultSize != null &&
            imageDefaultSize?.width != 0 &&
            imageDefaultSize?.height != 0 &&
            mounted &&
            imageRect.height <= 0) {
          imageRect = _computeBoxFitScaleDown(isVertical);

          setState(() {});
        }
      });
    }
  }

  ///  This code uses an if-else statement to check if the aspect ratio of the Image widget is greater than the aspect ratio of the Container widget.
  /// If the aspect ratio of the Image widget is greater, then the Image widget is scaled based on its width, and the top offset of the Image widget is calculated.
  ///  If the aspect ratio of the Container widget is greater, then the Image widget is scaled based on its height, and the left offset of the Image widget is calculated.
  /// This code should work for both vertical and horizontal images, and it should give you the correct Rect of the Image widget based on the BoxFit.scaleDown logic.
  Rect _computeBoxFitScaleDown([bool isNormalAlignment = true]) {
    final Size imageSize = imageDefaultSize!;
    double imageWidth = imageSize.width;
    double imageHeight = imageSize.height;
    final RenderBox containerRenderBox =
        imageKey.currentContext!.findRenderObject() as RenderBox;
    final Size containerSize = containerRenderBox.size;
    double containerWidth = containerSize.width;
    double containerHeight = containerSize.height;

    Rect imageRect = Rect.zero;

    if ((imageWidth / containerWidth > imageHeight / containerHeight)) {
      double scale = containerWidth / imageWidth;
      double scaledHeight = imageHeight * scale;
      double top = (containerHeight - scaledHeight) / 2;
      imageRect = Rect.fromLTWH(0, top, containerWidth, scaledHeight);
    } else {
      double scale = containerHeight / imageHeight;
      double scaledWidth = imageWidth * scale;
      double left = (containerWidth - scaledWidth) / 2;
      imageRect = Rect.fromLTWH(left, 0, scaledWidth, containerHeight);
    }

    if (!isNormalAlignment) {
      double scale = 1;
      double scaledWidth = 1;
      // If is the width is greater than the height
      if (imageDefaultSize!.width > imageDefaultSize!.height) {
        scale = containerHeight / imageWidth;
        scaledWidth = imageHeight * scale;
        double left = (containerWidth - scaledWidth) / 2;
        imageRect = Rect.fromLTWH(left, 0, scaledWidth, containerHeight);
      } else {
        scale = containerWidth / imageHeight;
        double scaledHeight = imageWidth * scale;

        double top = (containerHeight - scaledHeight) / 2;
        imageRect = Rect.fromLTWH(0, top, containerWidth, scaledHeight);
      }
    }

    return imageRect;
  }

  double _computeRotationScale() {
    double scale = 1;

    if (imageContainerKeySize?.width != null &&
        imageContainerKeySize?.height != null &&
        !isVertical) {
      if (imageDefaultSize!.width > imageDefaultSize!.height) {
        scale =
            (imageContainerKeySize!.height / imageContainerKeySize!.width) * 1;
      } else {
        scale =
            (imageContainerKeySize!.width / imageContainerKeySize!.height) * 1;
      }
    }

    return scale;
  }

  @override
  Widget build(BuildContext context) {
    Image? memImage;

    if (image != null) {
      memImage = Image.memory(image!);
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
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MyHomePage.screenHeight(context, ratio: 0.6),
                minHeight: MyHomePage.screenHeight(context, ratio: 0.6),
                maxWidth: MyHomePage.screenWidth(context),
                minWidth: MyHomePage.screenWidth(context),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _flipAnimationController,
                        key: imageContainerKey,
                        builder: (context, child) {
                          return Transform.scale(
                            scaleX: _flipAnimationController.value,
                            child: child,
                          );
                        },
                        child: AnimatedRotation(
                          curve: Curves.decelerate,
                          duration: const Duration(milliseconds: 350),
                          turns: angleIndex,
                          child: AnimatedScale(
                            scale: _computeRotationScale(),
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.decelerate,
                            child: Container(
                              color: Colors.transparent,
                              key: imageKey,
                              child: Image.memory(
                                image!,
                                fit: BoxFit.scaleDown,
                              ),
                            ),
                          ),
                          onEnd: () {
                            if (mounted) {
                              setState(() {
                                hideCropper = false;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    if (!hideCropper)
                      Positioned.fill(
                        child: LayoutBuilder(builder: (context, constraints) {
                          _executeAfterLayoutBuild(context, constraints);

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
                              imageOffset: topLeftDragOffset +
                                  Offset(imageRect.left, imageRect.top),
                            ),
                          );
                        }),
                      ),
                    if (!hideCropper)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: LayoutBuilder(builder: (context, constraints) {
                          _executeAfterLayoutBuild(context, constraints);

                          return CustomPaint(
                            willChange: true,
                            size: imageRect.size,
                            painter: OverlayFade(offsets: [
                              Offset(topLeftDragOffset.dx + imageRect.left,
                                  topLeftDragOffset.dy + imageRect.top),
                              Offset(topRightDragOffset.dx + imageRect.right,
                                  topRightDragOffset.dy + imageRect.top),
                              Offset(bottomLeftDragOffset.dx + imageRect.left,
                                  bottomLeftDragOffset.dy + imageRect.height),
                              Offset(bottomRightDragOffset.dx + imageRect.right,
                                  bottomRightDragOffset.dy + imageRect.height),
                            ], fadeRect: imageRect),
                          );
                        }),
                      ),
                    if (!hideCropper)
                      Positioned(
                        left: imageRect.left,
                        top: imageRect.top,
                        child: Transform.translate(
                          offset: topLeftDragOffset,
                          child: GestureDetector(
                            // behavior: HitTestBehavior.translucent,
                            onPanStart: (details) =>
                                _onPanStart(details, 'topLeft'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'topLeft'),

                            child:
                                LayoutBuilder(builder: (context, constraints) {
                              return CustomPaint(
                                willChange: true,
                                size: Size(dragAngleRadius, dragAngleRadius),
                                painter:
                                    TopLeftHandlePainter(offset: Offset.zero),
                              );
                            }),
                          ),
                        ),
                      ),
                    if (!hideCropper)
                      Positioned(
                        top: imageRect.top,
                        right: imageRect.left,
                        child: Transform.translate(
                          offset: topRightDragOffset,
                          child: GestureDetector(
                            onPanStart: (details) =>
                                _onPanStart(details, 'topRight'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'topRight'),
                            child:
                                LayoutBuilder(builder: (context, constraints) {
                              return CustomPaint(
                                willChange: true,
                                size: Size(dragAngleRadius, dragAngleRadius),
                                painter: TopRightHandlePainter(
                                  offset: Offset.zero,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    if (!hideCropper)
                      Positioned(
                        left: imageRect.left,
                        bottom: imageRect.top,
                        child: Transform.translate(
                          offset: bottomLeftDragOffset,
                          child: GestureDetector(
                            onPanStart: (details) =>
                                _onPanStart(details, 'bottomLeft'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'bottomLeft'),
                            child: CustomPaint(
                              willChange: true,
                              size: Size(dragAngleRadius, dragAngleRadius),
                              painter: BottomLeftHandlePainter(
                                offset: Offset.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!hideCropper)
                      Positioned(
                        right: imageRect.left,
                        bottom: imageRect.top,
                        child: Transform.translate(
                          offset: bottomRightDragOffset,
                          child: GestureDetector(
                            onPanStart: (details) =>
                                _onPanStart(details, 'bottomRight'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'bottomRight'),
                            child: CustomPaint(
                              willChange: true,
                              size: Size(dragAngleRadius, dragAngleRadius),
                              painter: BottomRightHandlePainter(
                                offset: Offset.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!hideCropper)
                      Positioned(
                        left: (topLeftDragOffset.dx + imageRect.left) + 30,
                        top: imageRect.top,
                        child: Transform.translate(
                          offset: topDragOffset,
                          child: GestureDetector(
                            // onTap: () => print('tap on'),
                            onPanStart: (details) =>
                                _onPanStart(details, 'top'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'top'),
                            child:
                                LayoutBuilder(builder: (context, constraint) {
                              Size size = Size(
                                  (imageRect.width - (dragAngleRadius * 2)),
                                  dragAngleRadius);

                              size = Rect.fromLTRB(
                                      topLeftDragOffset.dx,
                                      topLeftDragOffset.dy,
                                      imageRect.width + topRightDragOffset.dx,
                                      imageRect.height +
                                          bottomRightDragOffset.dy)
                                  .size;
                              size = Size(size.width - (dragAngleRadius * 2),
                                  dragAngleRadius);
                              return CustomPaint(
                                willChange: true,
                                size: size,
                                painter: VerticalHandlePainter(
                                  offset: Offset.zero,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    if (!hideCropper)
                      Positioned(
                        left: (topLeftDragOffset.dx + imageRect.left) + 30,
                        bottom: 0,
                        child: Transform.translate(
                          offset: bottomDragOffset,
                          child: GestureDetector(
                            // onTap: () => print('tap on'),
                            onPanStart: (details) =>
                                _onPanStart(details, 'bottom'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'bottom'),
                            child:
                                LayoutBuilder(builder: (context, constraint) {
                              Size size = Size(
                                  (imageRect.width - (dragAngleRadius * 2)),
                                  dragAngleRadius);

                              size = Rect.fromLTRB(
                                      topLeftDragOffset.dx,
                                      topLeftDragOffset.dy,
                                      imageRect.width + topRightDragOffset.dx,
                                      imageRect.height +
                                          bottomRightDragOffset.dy)
                                  .size;
                              size = Size(size.width - (dragAngleRadius * 2),
                                  dragAngleRadius);
                              return CustomPaint(
                                willChange: true,
                                size: size,
                                painter: VerticalHandlePainter(
                                  offset: Offset(0, dragAngleRadius),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    if (!hideCropper)
                      Positioned(
                        left: imageRect.left,
                        top: topLeftDragOffset.dy + imageRect.top + 30,
                        child: Transform.translate(
                          offset: leftDragOffset,
                          child: GestureDetector(
                            // onTap: () => print('tap on'),
                            onPanStart: (details) =>
                                _onPanStart(details, 'left'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'left'),
                            child:
                                LayoutBuilder(builder: (context, constraint) {
                              Size size = Size(dragAngleRadius,
                                  (imageRect.height - (dragAngleRadius * 2)));

                              size = Rect.fromLTRB(
                                      topLeftDragOffset.dx,
                                      topLeftDragOffset.dy,
                                      imageRect.width + topRightDragOffset.dx,
                                      imageRect.height +
                                          bottomRightDragOffset.dy)
                                  .size;
                              size = Size(dragAngleRadius,
                                  size.height - (dragAngleRadius * 2));
                              return CustomPaint(
                                willChange: true,
                                size: size,
                                painter: HorizontalHandlePainter(
                                  offset: Offset.zero,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    if (!hideCropper)
                      Positioned(
                        right: imageRect.left,
                        top: topLeftDragOffset.dy + imageRect.top + 30,
                        child: Transform.translate(
                          offset: rightDragOffset,
                          child: GestureDetector(
                            // onTap: () => print('tap on'),
                            onPanStart: (details) =>
                                _onPanStart(details, 'right'),
                            onPanEnd: _onPanEnd,
                            onPanUpdate: (details) =>
                                _onPanUpdate(details, 'right'),
                            child:
                                LayoutBuilder(builder: (context, constraint) {
                              Size size = Size(dragAngleRadius,
                                  (imageRect.height - (dragAngleRadius * 2)));

                              size = Rect.fromLTRB(
                                      topLeftDragOffset.dx,
                                      topLeftDragOffset.dy,
                                      imageRect.width + topRightDragOffset.dx,
                                      imageRect.height +
                                          bottomRightDragOffset.dy)
                                  .size;
                              size = Size(dragAngleRadius,
                                  size.height - (dragAngleRadius * 2));
                              return CustomPaint(
                                willChange: true,
                                size: size,
                                painter: HorizontalHandlePainter(
                                  offset: Offset(dragAngleRadius, 0),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: _onImageRotation,
                child: const Icon(Icons.rotate_90_degrees_ccw_outlined),
              ),
              OutlinedButton(
                onPressed: () {
                  _onFlipImage(horizontal: true);
                },
                child: const Icon(Icons.flip_outlined),
              ),
              OutlinedButton(
                onPressed: _onChangeImage,
                child: const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [OverlayFade] Handles the fading of un-cropped part of the image
class OverlayFade extends CustomPainter {
  OverlayFade({required this.offsets, required this.fadeRect});
  List<Offset> offsets;
  Rect fadeRect;
  @override
  void paint(Canvas canvas, Size size) {
    // Paint paint = Paint()
    //   ..color = Colors.redAccent
    //   ..style = PaintingStyle.fill;
    //
    // Paint fadePaint = Paint()
    //   ..color = Colors.greenAccent
    //   ..style = PaintingStyle.fill;

    Path cropPath = Path();

    cropPath.moveTo(offsets[0].dx, offsets[0].dy);
    cropPath.lineTo(offsets[1].dx, offsets[1].dy);
    cropPath.lineTo(offsets[3].dx, offsets[3].dy);
    cropPath.lineTo(offsets[2].dx, offsets[2].dy);

    Path fadePath = Path();

    fadePath.moveTo(fadeRect.left, fadeRect.top);
    fadePath.lineTo(fadeRect.right, fadeRect.top);
    fadePath.lineTo(fadeRect.right, fadeRect.bottom);
    fadePath.lineTo(fadeRect.left, fadeRect.bottom);

    final Path mainPath = Path();
    mainPath.fillType = PathFillType.evenOdd;
    mainPath.addPath(fadePath, Offset.zero);
    mainPath.addPath(cropPath, Offset.zero);

    canvas.drawPath(mainPath, Paint()..color = Colors.black.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
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
      ..strokeWidth = 0.5;

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
      ..strokeWidth = 0.5
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

class VerticalHandlePainter extends CustomPainter {
  VerticalHandlePainter({this.handleSize = 15, required this.offset});
  final double handleSize;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size paintSize) {
    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    Offset p1 = Offset(paintSize.width / 2 - (handleSize), offset.dy);
    Offset p2 = Offset(paintSize.width / 2 + (handleSize), offset.dy);

    canvas.drawLine(p1, p2, paint);
    paint.color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTRB(0, 0, paintSize.width, handleSize * 2), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class HorizontalHandlePainter extends CustomPainter {
  HorizontalHandlePainter({this.handleSize = 15, required this.offset});
  final double handleSize;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size paintSize) {
    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    Offset p1 = Offset(offset.dx, paintSize.height / 2 - (handleSize));
    Offset p2 = Offset(offset.dx, paintSize.height / 2 + (handleSize));

    canvas.drawLine(p1, p2, paint);
    paint.color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTRB(0, 0, paintSize.width, paintSize.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class TopLeftHandlePainter extends CustomPainter {
  TopLeftHandlePainter({this.handleSize = 15, required this.offset});
  final double handleSize;
  final Offset offset;

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
      ..strokeWidth = 2.5
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
  TopRightHandlePainter({this.handleSize = 15, required this.offset});

  final double handleSize;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    ui.PointMode pointMode = ui.PointMode.polygon;

    List<Offset> angle3 = [
      Offset(offset.dx + size.width - handleSize, offset.dy),
      Offset(offset.dx + size.width, offset.dy),
      Offset(offset.dx + size.width, offset.dy),
      Offset(offset.dx + size.width, handleSize + offset.dy),
    ];

    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
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
  BottomLeftHandlePainter({this.handleSize = 15, required this.offset});
  final double handleSize;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    ui.PointMode pointMode = ui.PointMode.polygon;

    List<Offset> angle2 = [
      Offset(offset.dx, size.height - handleSize - offset.dy),
      Offset(offset.dx, size.height - offset.dy),
      Offset(offset.dx, size.height - offset.dy),
      Offset(handleSize, size.height - offset.dy),
    ];

    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    canvas.drawPoints(pointMode, angle2, paint);

    paint.color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTRB(offset.dx, size.height - offset.dy - handleSize * 2,
            handleSize * 2, size.height - offset.dy),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BottomRightHandlePainter extends CustomPainter {
  BottomRightHandlePainter({this.handleSize = 15, required this.offset});

  final double handleSize;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    ui.PointMode pointMode = ui.PointMode.polygon;

    List<Offset> angle4 = [
      Offset(size.width - offset.dx, size.height - handleSize - offset.dy),
      Offset(size.width - offset.dx, size.height - offset.dy),
      Offset(size.width - offset.dx, size.height - offset.dy),
      Offset(size.width - handleSize - offset.dx, size.height - offset.dy),
    ];

    Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    canvas.drawPoints(pointMode, angle4, paint);

    paint.color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTRB(offset.dx, size.height - offset.dy - handleSize * 2,
            handleSize * 2, size.height - offset.dy),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

extension OffsetExtension on Offset {
  Offset get flipped => Offset(dy, dx);
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
