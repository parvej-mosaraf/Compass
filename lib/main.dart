import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const CompassApp());
}

class CompassApp extends StatelessWidget {
  const CompassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Compass',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          primary: Colors.red,
        ),
      ),
      home: const CompassScreen(),
    );
  }
}

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  double _heading = 0;

  Position? _position;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;

  String? _locationError;

  @override
  void initState() {
    super.initState();

    _listenToCompass();
    _initializeLocation();
  }

  void _listenToCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      final double? direction = event.heading;

      if (direction != null && mounted) {
        setState(() {
          _heading = direction;
        });
      }
    });
  }

  Future<void> _initializeLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _locationError = 'Location permission denied';
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError = 'Location permission permanently denied';
      });
      return;
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          Position position,
        ) {
          if (mounted) {
            setState(() {
              _position = position;
              _locationError = null;
            });
          }
        });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  String _getDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading < 67.5) return 'NE';
    if (heading < 112.5) return 'E';
    if (heading < 157.5) return 'SE';
    if (heading < 202.5) return 'S';
    if (heading < 247.5) return 'SW';
    if (heading < 292.5) return 'W';
    return 'NW';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Heading
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    '${_heading.round()}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDirection(_heading),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),

            // Compass
            Center(child: CompassView(heading: _heading)),

            // GPS
            Positioned(
              left: 24,
              right: 24,
              bottom: 35,
              child: LocationView(position: _position, error: _locationError),
            ),
          ],
        ),
      ),
    );
  }
}

class CompassView extends StatelessWidget {
  final double heading;

  const CompassView({super.key, required this.heading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 330,
      child: CustomPaint(painter: CompassPainter(heading: heading)),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;

  CompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double radius = size.width / 2;

    // Outer compass ring
    final Paint ringPaint = Paint()
      ..color = const Color(0xFF303030)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 5, ringPaint);

    // Tick marks
    for (int degree = 0; degree < 360; degree += 5) {
      final bool major = degree % 30 == 0;

      final double tickLength = major ? 14 : 6;

      final double angle = (degree - 90) * math.pi / 180;

      final Offset start = Offset(
        center.dx + (radius - 20) * math.cos(angle),
        center.dy + (radius - 20) * math.sin(angle),
      );

      final Offset end = Offset(
        center.dx + (radius - 20 - tickLength) * math.cos(angle),
        center.dy + (radius - 20 - tickLength) * math.sin(angle),
      );

      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = major ? const Color(0xFFAAAAAA) : const Color(0xFF454545)
          ..strokeWidth = major ? 1.5 : 1,
      );
    }

    // Cardinal directions stay fixed on screen.
    _drawDirection(canvas, center, radius, 'N', 0, Colors.red);

    _drawDirection(canvas, center, radius, 'E', 90, Colors.white);

    _drawDirection(canvas, center, radius, 'S', 180, Colors.white);

    _drawDirection(canvas, center, radius, 'W', 270, Colors.white);

    // =========================================================
    // NORTH/SOUTH NEEDLE
    // =========================================================

    canvas.save();

    // IMPORTANT:
    // Sensor heading is clockwise from North.
    // Rotate the needle opposite the phone heading so the
    // red tip continues pointing toward magnetic North.
    canvas.translate(center.dx, center.dy);

    canvas.rotate(-heading * math.pi / 180);

    canvas.translate(-center.dx, -center.dy);

    _drawNeedle(canvas, center);

    canvas.restore();

    // Center hub
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawDirection(
    Canvas canvas,
    Offset center,
    double radius,
    String text,
    double degree,
    Color color,
  ) {
    final double angle = (degree - 90) * math.pi / 180;

    final Offset position = Offset(
      center.dx + (radius - 48) * math.cos(angle),
      center.dy + (radius - 48) * math.sin(angle),
    );

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    painter.paint(
      canvas,
      Offset(position.dx - painter.width / 2, position.dy - painter.height / 2),
    );
  }

  void _drawNeedle(Canvas canvas, Offset center) {
    const double needleLength = 112;
    const double needleWidth = 11;

    // North = upward
    final Offset northTip = Offset(center.dx, center.dy - needleLength);

    final Offset northLeft = Offset(center.dx - needleWidth, center.dy);

    final Offset northRight = Offset(center.dx + needleWidth, center.dy);

    final Path north = Path()
      ..moveTo(northTip.dx, northTip.dy)
      ..lineTo(northLeft.dx, northLeft.dy)
      ..lineTo(northRight.dx, northRight.dy)
      ..close();

    canvas.drawPath(
      north,
      Paint()
        ..color = const Color(0xFFFF2020)
        ..style = PaintingStyle.fill,
    );

    // South = downward
    final Offset southTip = Offset(center.dx, center.dy + needleLength);

    final Path south = Path()
      ..moveTo(southTip.dx, southTip.dy)
      ..lineTo(northLeft.dx, northLeft.dy)
      ..lineTo(northRight.dx, northRight.dy)
      ..close();

    canvas.drawPath(
      south,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.heading != heading;
  }
}

class LocationView extends StatelessWidget {
  final Position? position;
  final String? error;

  const LocationView({super.key, required this.position, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Text(
        error!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    if (position == null) {
      return const Column(
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Getting GPS location...',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: Colors.red, size: 21),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS LOCATION',
                  style: TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '${position!.latitude.toStringAsFixed(6)}, '
                  '${position!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '±${position!.accuracy.round()}m',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
