// ── Modèle GeoJSON Polygon ────────────────────────────────
// Représente le polygone de la forêt
// Format reçu depuis FastAPI :
// {
//   "type": "Polygon",
//   "coordinates": [[[9.12, 36.45], [9.18, 36.45], ...]]
// }
class GeoJSONPolygon {
  final String type;
  final List<List<List<double>>> coordinates;

  GeoJSONPolygon({
    required this.type,
    required this.coordinates,
  });

  factory GeoJSONPolygon.fromJson(Map<String, dynamic> json) {
    return GeoJSONPolygon(
      type: json['type'],
      // coordinates est une liste de rings
      // chaque ring est une liste de points [lng, lat]
      coordinates: (json['coordinates'] as List)
          .map((ring) => (ring as List)
              .map((point) => (point as List)
                  .map((coord) => (coord as num).toDouble())
                  .toList())
              .toList())
          .toList(),
    );
  }
}


// ── Modèle Forest ─────────────────────────────────────────
// Représente une forêt reçue depuis FastAPI
class ForestModel {
  final String id;
  final String name;
  final GeoJSONPolygon geojson;
  final double? areaHectares;
  final double? centroidLat;
  final double? centroidLng;
  final String? supervisorName;
  final String status;
  final DateTime createdAt;

  ForestModel({
    required this.id,
    required this.name,
    required this.geojson,
    this.areaHectares,
    this.centroidLat,
    this.centroidLng,
    this.supervisorName,
    required this.status,
    required this.createdAt,
  });

  factory ForestModel.fromJson(Map<String, dynamic> json) {
    return ForestModel(
      id:             json['id'],
      name:           json['name'],
      geojson:        GeoJSONPolygon.fromJson(json['geojson']),
      areaHectares:   (json['area_hectares'] as num?)?.toDouble(),
      centroidLat:    (json['centroid_lat'] as num?)?.toDouble(),
      centroidLng:    (json['centroid_lng'] as num?)?.toDouble(),
      supervisorName: json['supervisor_name'],
      status:         json['status'],
      createdAt:      DateTime.parse(json['created_at']),
    );
  }
}


// ── Modèle GeoJSON Feature ────────────────────────────────
// Un élément dans la FeatureCollection
// Reçu depuis GET /api/v1/forests/geojson
class ForestFeature {
  final String type;
  final GeoJSONPolygon geometry;
  final ForestProperties properties;

  ForestFeature({
    required this.type,
    required this.geometry,
    required this.properties,
  });

  factory ForestFeature.fromJson(Map<String, dynamic> json) {
    return ForestFeature(
      type:       json['type'],
      geometry:   GeoJSONPolygon.fromJson(json['geometry']),
      properties: ForestProperties.fromJson(json['properties']),
    );
  }
}


// ── Propriétés d'une Feature ──────────────────────────────
class ForestProperties {
  final String id;
  final String name;
  final double? areaHectares;
  final String? supervisorName;
  final String status;
  final double? centroidLat;
  final double? centroidLng;

  ForestProperties({
    required this.id,
    required this.name,
    this.areaHectares,
    this.supervisorName,
    required this.status,
    this.centroidLat,
    this.centroidLng,
  });

  factory ForestProperties.fromJson(Map<String, dynamic> json) {
    return ForestProperties(
      id:             json['id'],
      name:           json['name'],
      areaHectares:   (json['area_hectares'] as num?)?.toDouble(),
      supervisorName: json['supervisor_name'],
      status:         json['status'],
      centroidLat:    (json['centroid_lat'] as num?)?.toDouble(),
      centroidLng:    (json['centroid_lng'] as num?)?.toDouble(),
    );
  }
}


// ── Modèle FeatureCollection ──────────────────────────────
// Ce que retourne GET /api/v1/forests/geojson
// Consommé directement par flutter_map
class ForestsGeoJSONCollection {
  final String type;
  final List<ForestFeature> features;

  ForestsGeoJSONCollection({
    required this.type,
    required this.features,
  });

  factory ForestsGeoJSONCollection.fromJson(Map<String, dynamic> json) {
    return ForestsGeoJSONCollection(
      type:     json['type'],
      features: (json['features'] as List)
          .map((f) => ForestFeature.fromJson(f))
          .toList(),
    );
  }
}