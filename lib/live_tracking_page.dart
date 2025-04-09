import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:live_tracking/components/rider_info.dart';
import 'package:live_tracking/constants.dart';
import 'package:location/location.dart';

class LiveTrackingPage extends StatefulWidget {
  const LiveTrackingPage({super.key});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  final Completer<GoogleMapController> _googleMapController = Completer();

  LatLng sourceLocation = LatLng(37.33500926, -122.03272188);
  LatLng destinationLocation = LatLng(37.33429383, -122.06600055);

  BitmapDescriptor sourceIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor currentLocationIcon = BitmapDescriptor.defaultMarker;

  Future<void> setCustomIcon() async {
    try {
      final iconResult = await Future.wait([
        BitmapDescriptor.asset(
          ImageConfiguration(size: Size(15, 28)),
          "assets/Pin_source.png",
        ),
        BitmapDescriptor.asset(
          ImageConfiguration(size: Size(24, 28)),
          "assets/Pin_destination.png",
        ),
        BitmapDescriptor.asset(
          ImageConfiguration(size: Size(38, 44)),
          "assets/Pin_current_location.png",
        ),
      ]);

      setState(() {
        sourceIcon = iconResult[0];
        destinationIcon = iconResult[1];
        currentLocationIcon = iconResult[2];
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();

  void getPolyPoints() async {
    try {
      PolylineResult polylineResult = await polylinePoints
          .getRouteBetweenCoordinates(
            googleApiKey: google_api_key,
            request: PolylineRequest(
              origin: PointLatLng(
                sourceLocation.latitude,
                sourceLocation.longitude,
              ),
              destination: PointLatLng(
                destinationLocation.latitude,
                destinationLocation.longitude,
              ),
              mode: TravelMode.driving,
              optimizeWaypoints: true,
            ),
          );

      if (polylineResult.points.isNotEmpty) {
        for (var point in polylineResult.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        setState(() {});
      } else {
        debugPrint("No route found.");
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  void initState() {
    // getCurrentLocation();
    setCustomIcon();
    getPolyPoints();
    super.initState();
  }

  // User's current location
  final Location _location = Location();
  LocationData? locationData;

  void getCurrentLocation() async {
    try {
      LocationData currentLoc = await _location.getLocation();
      setState(() {
        locationData = currentLoc;
      });

      //  we need to move the map on user current location
      final GoogleMapController controller = await _googleMapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(locationData!.latitude!, locationData!.longitude!),
            zoom: 14.5,
            tilt: 59,
            bearing: -70,
          ),
        ),
      );

      // if the user is moving we also want to update the location on map
      _location.onLocationChanged.listen((LocationData newLocation) async {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(newLocation.latitude!, newLocation.longitude!),
              zoom: 14.5,
              tilt: 59,
              bearing: -70,
            ),
          ),
        );

        setState(() {
          locationData = newLocation;
        });
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Track Order",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: sourceLocation,
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _googleMapController.complete(controller);
              },
              polylines: {
                Polyline(
                  polylineId: PolylineId("route"),
                  points: polylineCoordinates,
                  color: primaryColor,
                  width: 6,
                ),
              },
              markers: {
                Marker(
                  markerId: MarkerId("source"),
                  position: sourceLocation,
                  icon: sourceIcon,
                ),
                Marker(
                  markerId: MarkerId("destination"),
                  position: destinationLocation,
                  icon: destinationIcon,
                ),
                if (locationData != null)
                  Marker(
                    markerId: MarkerId("currentLocation"),
                    position: LatLng(
                      locationData!.latitude!,
                      locationData!.longitude!,
                    ),
                    icon: currentLocationIcon,
                  ),
              },
            ),
          ),

          RiderInfo(),
        ],
      ),
    );
  }
}
