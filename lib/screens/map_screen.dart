import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

const mapboxAccessToken =
    'pk.eyJ1Ijoic2ltb2FpdGVsZ2F6emFyIiwiYSI6ImNtMzVzeXYyazA2bWkybHMzb2Fxb3p6aGIifQ.ORYyvkZ2Z1H8WmouDkXtvQ';

final myPosition = LatLng(40.416775, -3.703790);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _currentPosition;
  bool _tracking = false;
  List<LatLng> _route = []; 
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(myPosition, 15);
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_currentPosition!, 15);
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$mapboxAccessToken',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'].isNotEmpty) {
        final location = data['features'][0]['center'];
        final latitude = location[1];
        final longitude = location[0];

        // Recentrer la carte
        _mapController.move(LatLng(latitude, longitude), 15);

        setState(() {
          _tracking = true;
        });

        // Obtenez l'itinéraire entre la position actuelle et l'emplacement recherché
        _getRoute(LatLng(latitude, longitude));
      }
    }
  }

  // Fonction pour obtenir l'itinéraire entre la position actuelle et l'emplacement recherché
  Future<void> _getRoute(LatLng destination) async {
    if (_currentPosition == null) return;

    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/${_currentPosition!.longitude},${_currentPosition!.latitude};${destination.longitude},${destination.latitude}.json?access_token=$mapboxAccessToken&alternatives=false&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'].isNotEmpty) {
        final route = data['routes'][0]['geometry']['coordinates'];
        List<LatLng> routePoints = route
            .map<LatLng>((point) => LatLng(point[1], point[0]))
            .toList();

        setState(() {
          _route = routePoints;
        });

        // Calculer le centre de l'itinéraire
        double latSum = 0;
        double lonSum = 0;
        for (var point in routePoints) {
          latSum += point.latitude;
          lonSum += point.longitude;
        }

        // Calculer le centre moyen
        LatLng center = LatLng(latSum / routePoints.length, lonSum / routePoints.length);

        // Mettre à jour la carte pour centrer le trajet
        _mapController.move(center, 14); // Ajuster le niveau de zoom ici (14)
      }
    }
  }

  // Fonction pour gérer le clic sur la carte et créer l'itinéraire
  void _onMapTapped(LatLng latLng) {
    if (_currentPosition != null) {
      _getRoute(latLng); // Calculer l'itinéraire
      setState(() {
        _tracking = true; // Activer le suivi
      });
    }
  }

  // Fonction pour arrêter le suivi de localisation
  void _stopTracking() {
    setState(() {
      _tracking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('simooo'),
        backgroundColor: Colors.blueAccent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un lieu...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onSubmitted: (value) => _searchLocation(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _searchLocation,
                ),
                IconButton(
                  icon: Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                ),
                if (_tracking)
                  IconButton(
                    icon: Icon(Icons.stop),
                    onPressed: _stopTracking,
                  ),
              ],
            ),
          ),
        ),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          minZoom: 5,
          maxZoom: 25,
          onTap: (_, latLng) {
            _onMapTapped(latLng); // Clic sur la carte pour générer l'itinéraire
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
            additionalOptions: {
              'accessToken': mapboxAccessToken,
              'id': 'mapbox/streets-v11',
            },
          ),
          // Affichage du trajet sur la carte
          if (_route.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _route,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          if (_currentPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition!,
                  width: 30.0,
                  height: 30.0,
                  child: Icon(
                    Icons.location_on,
                    size: 30,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
