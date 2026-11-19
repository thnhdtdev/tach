import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../services/photo/photo_loader.dart';

class ExpensePhoto extends StatelessWidget {
  const ExpensePhoto({super.key, required this.photoUrl, this.photoBytes});

  final String? photoUrl;
  final Uint8List? photoBytes;

  static const _samples = {
    'sample:eggs': _Sample(
      Color(0xFFE9B872),
      Color(0xFF8A5A2B),
      Icons.egg_outlined,
    ),
    'sample:meter': _Sample(
      Color(0xFF8E9AA6),
      Color(0xFF2F3A45),
      Icons.electric_meter_outlined,
    ),
    'sample:rice': _Sample(
      Color(0xFFE6D3B1),
      Color(0xFF9A7B4F),
      Icons.rice_bowl_outlined,
    ),
    'sample:cleaning': _Sample(
      Color(0xFF9CC9E0),
      Color(0xFF35607A),
      Icons.cleaning_services_outlined,
    ),
    'sample:hotpot': _Sample(
      Color(0xFFE08A6A),
      Color(0xFF6E2A1E),
      Icons.ramen_dining_outlined,
    ),
    'sample:water': _Sample(
      Color(0xFFA9C7F2),
      Color(0xFF2E4F86),
      Icons.water_drop_outlined,
    ),
    'sample:gas': _Sample(
      Color(0xFFC2B6A6),
      Color(0xFF4A423A),
      Icons.local_fire_department_outlined,
    ),
    'sample:viewfinder': _Sample(Color(0xFF6F7F7A), Color(0xFF1E2A27), null),
  };

  static Color sampleColor(String photoUrl) {
    final sample = _samples[photoUrl] ?? _samples['sample:viewfinder']!;
    return Color.lerp(sample.light, sample.dark, 0.5)!;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytes;
    if (bytes != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Giải mã ảnh ở cỡ gần với cỡ hiển thị để ô nhỏ không ngốn bộ nhớ.
          final side = constraints.biggest.longestSide;
          final pixels = side.isFinite
              ? (side * MediaQuery.devicePixelRatioOf(context)).round()
              : null;
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: pixels,
            errorBuilder: (_, _, _) => const _NoPhoto(),
          );
        },
      );
    }

    final url = photoUrl;
    if (url == null) return const _NoPhoto();
    if (url.startsWith(remotePhotoPrefix)) {
      return _RemotePhoto(path: url.substring(remotePhotoPrefix.length));
    }

    final sample = _samples[url] ?? _samples['sample:viewfinder']!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _SamplePainter(sample)),
            if (sample.icon != null)
              Center(
                child: Icon(
                  sample.icon,
                  size: side * 0.42,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RemotePhoto extends StatefulWidget {
  const _RemotePhoto({required this.path});

  final String path;

  @override
  State<_RemotePhoto> createState() => _RemotePhotoState();
}

class _RemotePhotoState extends State<_RemotePhoto> {
  late Future<Uint8List?> _bytes = getIt<PhotoLoader>().load(widget.path);

  @override
  void didUpdateWidget(_RemotePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytes = getIt<PhotoLoader>().load(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(color: TachColors.nightRaised);
        }
        final bytes = snapshot.data;
        if (bytes == null) return const _NoPhoto();
        return ExpensePhoto(photoUrl: null, photoBytes: bytes);
      },
    );
  }
}

class _Sample {
  const _Sample(this.light, this.dark, this.icon);

  final Color light;
  final Color dark;
  final IconData? icon;
}

class _SamplePainter extends CustomPainter {
  const _SamplePainter(this.sample);

  final _Sample sample;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sample.light, sample.dark],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.2),
      size.shortestSide * 0.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          size.shortestSide * 0.2,
        ),
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.9),
      size.shortestSide * 0.55,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          size.shortestSide * 0.22,
        ),
    );
  }

  @override
  bool shouldRepaint(_SamplePainter oldDelegate) =>
      oldDelegate.sample != sample;
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TachColors.mintDeep,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Icon(
              Icons.receipt_long_outlined,
              size: constraints.biggest.shortestSide * 0.36,
              color: TachColors.mintLight,
            ),
          );
        },
      ),
    );
  }
}
