import 'package:latlong2/latlong.dart';

/// 地图配置文件，存储吉林一号影像套件的访问密钥
class MapConfig {
  /// 吉林一号影像套件的mk（地图标识）
  static const String mk = "3ddec00f5f435270285ffc7ad1a60ce5"; // 替换为你的mk

  /// 吉林一号影像套件的tk（访问令牌）
  static const String tk = "ad59d51f17ac9199ae9dbf4d60dfdd99"; // 替换为你的tk

  /// 吉林一号影像切片URL模板
  static String get tileUrlTemplate =>
      "https://api.jl1mall.com/getMap/{z}/{x}/{y}?mk=$mk&tk=$tk";

  /// 初始中心点坐标（长春市区示例）
  static const LatLng initialCenter = LatLng(43.97830219, 125.39490636);

  /// 初始缩放级别
  static const double initialZoom = 16.0;

  /// 最大缩放级别
  static const double maxZoom = 18.0;

  /// 最小缩放级别
  static const double minZoom = 1.0;
}
