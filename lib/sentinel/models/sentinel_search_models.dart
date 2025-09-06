/// 哨兵影像搜索相关的数据模型
import 'dart:convert';

/// 数据类型枚举
enum SatelliteDataType {
  sentinel2L2A('sentinel-2-l2a', '哨兵-2光学影像 (Sentinel-2 L2A)'),
  landsatC2L2('landsat-c2-l2', 'Landsat-7/8/9光学影像'),
  sentinel1GRD('sentinel-1-grd', '哨兵-1 SAR影像'),
  sentinel1RTC('sentinel-1-rtc', '哨兵-1辐射地形校正影像'),
  copDemGlo30('cop-dem-glo-30', '哥白尼30米数字高程模型');

  const SatelliteDataType(this.value, this.displayName);

  final String value;
  final String displayName;

  static SatelliteDataType fromString(String value) {
    return values.firstWhere(
          (type) => type.value == value,
      orElse: () => SatelliteDataType.sentinel2L2A,
    );
  }
}

/// 搜索结果数据模型
class SentinelSearchResult {

  factory SentinelSearchResult.fromJson(Map<String, dynamic> json, SatelliteDataType dataType) {
    return SentinelSearchResult(
      imageId: (json['image_id'] as String?) ?? '',
      captureDate: (json['capture_date'] as String?) ?? '',
      cloudCover: (json['cloud_cover'] as num?)?.toDouble(),
      constellation: (json['constellation'] as String?) ?? '未知',
      platform: (json['platform'] as String?) ?? '未知',
      dataType: dataType,
    );
  }

  SentinelSearchResult({
    required this.imageId,
    required this.captureDate,
    this.cloudCover,
    required this.constellation,
    required this.platform,
    required this.dataType,
  });
  final String imageId;
  final String captureDate;
  final double? cloudCover;
  final String constellation;
  final String platform;
  final SatelliteDataType dataType;

  /// 获取云量等级
  CloudCoverLevel get cloudCoverLevel {
    if (cloudCover == null) return CloudCoverLevel.unknown;
    if (cloudCover! > 70) return CloudCoverLevel.high;
    if (cloudCover! > 30) return CloudCoverLevel.medium;
    return CloudCoverLevel.low;
  }

  /// 获取卫星类型显示名称
  String get satelliteTypeName {
    switch (dataType) {
      case SatelliteDataType.sentinel2L2A:
        return '哨兵-2光学';
      case SatelliteDataType.sentinel1RTC:
        return '哨兵-1地形校正';
      case SatelliteDataType.sentinel1GRD:
        return '哨兵-1 SAR';
      case SatelliteDataType.landsatC2L2:
        return 'Landsat光学';
      case SatelliteDataType.copDemGlo30:
        return '数字高程模型';
    }
  }
}

/// 云量等级枚举
enum CloudCoverLevel {
  low,     // 低云量 (0-30%)
  medium,  // 中云量 (30-70%)
  high,    // 高云量 (70-100%)
  unknown, // 未知（如DEM数据）
}

/// 搜索参数模型
class SentinelSearchParams { // 支持多选

  SentinelSearchParams({
    required this.startDate,
    required this.endDate,
    required this.maxCloudCover,
    this.geoJson,
    required this.dataTypes,
  });
  final DateTime startDate;
  final DateTime endDate;
  final double maxCloudCover;
  final String? geoJson;
  final Set<SatelliteDataType> dataTypes;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> geoJsonData;

    if (geoJson != null && geoJson!.isNotEmpty) {
      try {
        final parsedJson = json.decode(geoJson!);

        // 确保转换为FeatureCollection格式
        if (parsedJson['type'] == 'FeatureCollection') {
          geoJsonData = parsedJson as Map<String, dynamic>;
        } else if (parsedJson['type'] == 'Feature') {
          geoJsonData = {
            "type": "FeatureCollection",
            "features": [parsedJson]
          };
        } else if (parsedJson['type'] != null && parsedJson['coordinates'] != null) {
          geoJsonData = {
            "type": "FeatureCollection",
            "features": [
              {
                "type": "Feature",
                "properties": {},
                "geometry": parsedJson
              }
            ]
          };
        } else {
          throw const FormatException('不支持的GeoJSON格式');
        }
      } catch (e) {
        // 如果解析失败，使用默认的全球范围
        geoJsonData = {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {},
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [
                    [-180, -85],
                    [180, -85],
                    [180, 85],
                    [-180, 85],
                    [-180, -85]
                  ]
                ]
              }
            }
          ]
        };
      }
    } else {
      // 默认全球范围
      geoJsonData = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {},
            "geometry": {
              "type": "Polygon",
              "coordinates": [
                [
                  [-180, -85],
                  [180, -85],
                  [180, 85],
                  [-180, 85],
                  [-180, -85]
                ]
              ]
            }
          }
        ]
      };
    }

    return {
      'geojson': geoJsonData,
      'start_date': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      'end_date': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'data_type': dataTypes.first.value, // 目前API只支持单个数据类型，取第一个
      'max_cloud_cover': maxCloudCover,
    };
  }
}

/// API响应模型
class SentinelApiResponse {

  SentinelApiResponse({
    required this.success,
    required this.totalCount,
    required this.searchParams,
    required this.dataInformation,
  });

  factory SentinelApiResponse.fromJson(Map<String, dynamic> json) {
    final success = (json['success'] as bool?) ?? false;
    final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final totalCount = (data['total_count'] as int?) ?? 0;
    final searchParams = (data['search_params'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final items = (data['items'] as List<dynamic>?) ?? <dynamic>[];

    // 从搜索参数中推断数据类型
    final dataTypeStr = (searchParams['data_type'] as String?) ?? 'sentinel-2-l2a';
    final dataType = SatelliteDataType.fromString(dataTypeStr);

    final results = items
        .map((item) => SentinelSearchResult.fromJson(item as Map<String, dynamic>, dataType))
        .toList();

    return SentinelApiResponse(
      success: success,
      totalCount: totalCount,
      searchParams: searchParams,
      dataInformation: results,
    );
  }
  final bool success;
  final int totalCount;
  final Map<String, dynamic> searchParams;
  final List<SentinelSearchResult> dataInformation;

  bool get isSuccessful => success;
}

/// 卫星图层配置类
class SatelliteLayerConfig {

  SatelliteLayerConfig({
    this.tileJsonUrl,
    required this.itemUrl,
    required this.satelliteType,
    this.directTileUrl,
  });
  final String? tileJsonUrl;
  final String itemUrl;
  final String satelliteType;
  final String? directTileUrl;

  static SatelliteLayerConfig fromDataType(SatelliteDataType dataType, String imageId) {
    switch (dataType) {
      case SatelliteDataType.sentinel2L2A:
        return SatelliteLayerConfig(
          tileJsonUrl: 'https://planetarycomputer.microsoft.com/api/data/v1/item/tilejson.json?collection=sentinel-2-l2a&item=$imageId&assets=visual&asset_bidx=visual%7C1%2C2%2C3&nodata=0&format=png',
          itemUrl: 'https://planetarycomputer.microsoft.com/api/stac/v1/collections/sentinel-2-l2a/items/$imageId',
          satelliteType: '哨兵-2光学',
        );

      case SatelliteDataType.sentinel1RTC:
        return SatelliteLayerConfig(
          tileJsonUrl: 'https://planetarycomputer.microsoft.com/api/data/v1/item/tilejson.json?collection=sentinel-1-rtc&item=$imageId&assets=vv&assets=vh&tile_format=png&expression=0.03+%2B+log+%2810e-4+-+log+%280.05+%2F+%280.02+%2B+2+%2A+vv%29%29%29%3B0.05+%2B+exp+%280.25+%2A+%28log+%280.01+%2B+2+%2A+vv%29+%2B+log+%280.02+%2B+5+%2A+vh%29%29%29%3B1+-+log+%280.05+%2F+%280.045+-+0.9+%2A+vv%29%29&asset_as_band=True&rescale=0%2C.8000&rescale=0%2C1.000&rescale=0%2C1.000&format=png',
          itemUrl: 'https://planetarycomputer.microsoft.com/api/stac/v1/collections/sentinel-1-rtc/items/$imageId',
          satelliteType: '哨兵-1地形校正',
        );

      case SatelliteDataType.sentinel1GRD:
        return SatelliteLayerConfig(
          tileJsonUrl: 'https://planetarycomputer.microsoft.com/api/data/v1/item/tilejson.json?collection=sentinel-1-grd&item=$imageId&assets=vv&assets=vh&expression=vv%3Bvh%3Bvv%2Fvh&rescale=0%2C600&rescale=0%2C270&rescale=0%2C9&asset_as_band=True&tile_format=png&format=png',
          itemUrl: 'https://planetarycomputer.microsoft.com/api/stac/v1/collections/sentinel-1-grd/items/$imageId',
          satelliteType: '哨兵-1 SAR',
        );

      case SatelliteDataType.landsatC2L2:
        return SatelliteLayerConfig(
          tileJsonUrl: 'https://planetarycomputer.microsoft.com/api/data/v1/item/tilejson.json?collection=landsat-c2-l2&item=$imageId&assets=red&assets=green&assets=blue&color_formula=gamma+RGB+2.7%2C+saturation+1.5%2C+sigmoidal+RGB+15+0.55&format=png',
          itemUrl: 'https://planetarycomputer.microsoft.com/api/stac/v1/collections/landsat-c2-l2/items/$imageId',
          satelliteType: 'Landsat光学',
        );

      case SatelliteDataType.copDemGlo30:
        return SatelliteLayerConfig(
          tileJsonUrl: null,
          itemUrl: 'https://planetarycomputer.microsoft.com/api/stac/v1/collections/cop-dem-glo-30/items/$imageId',
          satelliteType: '数字高程模型',
          directTileUrl: 'https://planetarycomputer.microsoft.com/api/data/v1/item/tiles/WebMercatorQuad/{z}/{x}/{y}@2x?collection=cop-dem-glo-30&item=$imageId&algorithm=hillshade&algorithm_params={"azimuth": 315, "angle_altitude": 45}&assets=data&buffer=3&colormap_name=gray&format=png',
        );
    }
  }
}