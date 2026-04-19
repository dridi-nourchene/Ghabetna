// features/forest/models/forest_model.dart

class GeoJSONPolygon {
  final String type;
  final List<List<List<double>>> coordinates;

  const GeoJSONPolygon({
    this.type = 'Polygon',
    required this.coordinates,
  });

  factory GeoJSONPolygon.fromJson(Map<String, dynamic> json) => GeoJSONPolygon(
        type: json['type'] ?? 'Polygon',
        coordinates: (json['coordinates'] as List)
            .map((ring) => (ring as List)
                .map((point) => (point as List)
                    .map((v) => (v as num).toDouble())
                    .toList())
                .toList())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'coordinates': coordinates,
      };

  /// Returns the outer ring as [lat, lng] pairs (for flutter_map)
  List<List<double>> get latLngList =>
      coordinates.isNotEmpty
          ? coordinates[0].map((p) => [p[1], p[0]]).toList()
          : [];
}

class Forest {
  final String  id;
  final String  name;
  final GeoJSONPolygon geojson;
  final double? areaHectares;
  final double? centroidLat;
  final double? centroidLng;
  final String  createdBy;
  final String  createdAt;
  final String? updatedAt;

  const Forest({
    required this.id,
    required this.name,
    required this.geojson,
    this.areaHectares,
    this.centroidLat,
    this.centroidLng,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Forest.fromJson(Map<String, dynamic> json) => Forest(
        id:            json['id'],
        name:          json['name'],
        geojson:       GeoJSONPolygon.fromJson(json['geojson']),
        areaHectares:  (json['area_hectares'] as num?)?.toDouble(),
        centroidLat:   (json['centroid_lat']  as num?)?.toDouble(),
        centroidLng:   (json['centroid_lng']  as num?)?.toDouble(),
        createdBy:     json['created_by'],
        createdAt:     json['created_at'],
        updatedAt:     json['updated_at'],
      );

  Map<String, dynamic> toJson() => {
        'id':             id,
        'name':           name,
        'geojson':        geojson.toJson(),
        'area_hectares':  areaHectares,
        'centroid_lat':   centroidLat,
        'centroid_lng':   centroidLng,
        'created_by':     createdBy,
        'created_at':     createdAt,
        'updated_at':     updatedAt,
      };

  String get areaLabel {
    if (areaHectares == null) return 'N/A';
    if (areaHectares! >= 1000) {
      return '${(areaHectares! / 1000).toStringAsFixed(1)} kha';
    }
    return '${areaHectares!.toStringAsFixed(1)} ha';
  }
}

// ── Parcelle ──────────────────────────────────────────────

class Parcelle {
  final String  id;
  final String  name;
  final String  forestId;
  final GeoJSONPolygon geojson;
  final double? areaHectares;
  final double? centroidLat;
  final double? centroidLng;
  final String  createdBy;
  final String  createdAt;
  final String? updatedAt;

  const Parcelle({
    required this.id,
    required this.name,
    required this.forestId,
    required this.geojson,
    this.areaHectares,
    this.centroidLat,
    this.centroidLng,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Parcelle.fromJson(Map<String, dynamic> json) => Parcelle(
        id:           json['id'],
        name:         json['name'],
        forestId:     json['forest_id'],
        geojson:      GeoJSONPolygon.fromJson(json['geojson']),
        areaHectares: (json['area_hectares'] as num?)?.toDouble(),
        centroidLat:  (json['centroid_lat']  as num?)?.toDouble(),
        centroidLng:  (json['centroid_lng']  as num?)?.toDouble(),
        createdBy:    json['created_by'],
        createdAt:    json['created_at'],
        updatedAt:    json['updated_at'],
      );

  String get areaLabel {
    if (areaHectares == null) return 'N/A';
    return '${areaHectares!.toStringAsFixed(1)} ha';
  }
}

// ── Paginated response ────────────────────────────────────

class PaginatedForests {
  final int          total;
  final int          page;
  final int          pageSize;
  final List<Forest> items;

  const PaginatedForests({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });

  factory PaginatedForests.fromJson(Map<String, dynamic> json) =>
      PaginatedForests(
        total:    json['total'],
        page:     json['page'],
        pageSize: json['page_size'],
        items:    (json['items'] as List)
            .map((f) => Forest.fromJson(f))
            .toList(),
      );
}

class PaginatedParcelles {
  final int             total;
  final int             page;
  final int             pageSize;
  final List<Parcelle>  items;

  const PaginatedParcelles({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });

  factory PaginatedParcelles.fromJson(Map<String, dynamic> json) =>
      PaginatedParcelles(
        total:    json['total'],
        page:     json['page'],
        pageSize: json['page_size'],
        items:    (json['items'] as List)
            .map((p) => Parcelle.fromJson(p))
            .toList(),
      );
}