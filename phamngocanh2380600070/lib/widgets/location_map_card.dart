import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationMapCard extends StatefulWidget {
  const LocationMapCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
  final double latitude;
  final double longitude;
  final double? accuracy;
  @override
  State<LocationMapCard> createState() => _LocationMapCardState();
}

class _LocationMapCardState extends State<LocationMapCard> {
  final _controller = MapController();
  bool _ready = false;
  bool _tileError = false;
  @override
  void didUpdateWidget(covariant LocationMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      _controller.move(LatLng(widget.latitude, widget.longitude), 16);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                maxZoom: 19,
                onMapReady: () => _ready = true,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  fallbackUrl: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
                  maxNativeZoom: 17,
                  userAgentPackageName: 'com.example.kidguard',
                  tileProvider: NetworkTileProvider(
                    cachingProvider:
                        BuiltInMapCachingProvider.getOrCreateInstance(
                          maxCacheSize: 100 * 1024 * 1024,
                        ),
                  ),
                  errorTileCallback: (_, _, _) {
                    if (!_tileError && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _tileError = true);
                      });
                    }
                  },
                ),
                if (widget.accuracy != null && widget.accuracy! > 0)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: point,
                        radius: widget.accuracy!,
                        useRadiusInMeter: true,
                        color: Colors.indigo.withValues(alpha: 0.12),
                        borderColor: Colors.indigo,
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ColoredBox(
                    color: Colors.white,
                    child: TextButton(
                      onPressed: () async {
                        try {
                          await const MethodChannel('kidguard/guard')
                              .invokeMethod('mapAttribution');
                        } catch (_) {}
                      },
                      child: const Text(
                        '© OpenStreetMap contributors, SRTM\n© OpenTopoMap (CC-BY-SA)',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_tileError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Không tải được bản đồ. Kiểm tra kết nối Internet.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
      ],
    );
  }
}
