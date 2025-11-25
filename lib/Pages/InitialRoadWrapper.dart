// initial_route_wrapper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';

class InitialRouteWrapper extends StatefulWidget {
  const InitialRouteWrapper({super.key});

  @override
  State<InitialRouteWrapper> createState() => _InitialRouteWrapperState();
}

class _InitialRouteWrapperState extends State<InitialRouteWrapper> {
  bool _isLoading = true;
  String _initialRoute = '/login'; // Default fallback

  // Key for SharedPreferences
  static const String _introSeenKey = 'hasSeenIntro';

  @override
  void initState() {
    super.initState();
    _determineRoute();
  }

  /// This function now handles all logic in the correct order.
  void _determineRoute() async {
    // 1. Check SharedPreferences for intro screen
    final prefs = await SharedPreferences.getInstance();
    final hasSeenIntro = prefs.getBool(_introSeenKey) ?? false;

    // 2. Wait for Firebase Auth to initialize and tell us who is logged in
    // This is the most reliable way to check for a logged-in user.
    User? user = await FirebaseAuth.instance.authStateChanges().first;

    String targetRoute;

    if (user == null) {
      // --- User is NOT logged in ---
      // 3A. If not logged in, check if they've seen the intro
      targetRoute = hasSeenIntro ? '/login' : '/introduction';
    } else {
      // --- User IS logged in ---
      // 3B. Now that we know who the user is, check their role from Firestore.
      // We will check by UID, which is much faster and more reliable than email.
      try {
        final overseerDoc = await FirebaseFirestore.instance
            .collection('overseers')
            .where('uid', isEqualTo: user.uid)
            .get();

        final admin = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: "Admin")
            .get();
        final tactsoBranches = await FirebaseFirestore.instance
            .collection('tactso_branches')
            .where('uid',isEqualTo:  user.uid)
            .get();

        print("This is the ${overseerDoc}");  
        
        if(tactsoBranches.docs.isNotEmpty){ 
 
          targetRoute = '/tactso-branches';
        } else if (overseerDoc.docs.isNotEmpty) {
          // ⭐️ SUCCESS: User is an overseer
          targetRoute = '/overseer';
        } else if (admin.docs.isNotEmpty) {
          // ⭐️ SUCCESS: User is an admin
          targetRoute = '/admin';
        } else{
          targetRoute = '/main-menu';
        }
      } catch (e) {
        // Handle potential Firestore errors (like permission denied)
        print("Error checking user role: $e");
        // Log them out and send to login screen
        await FirebaseAuth.instance.signOut();
        targetRoute = '/login';
      }
    }

    // 4. We have our final route. Update the state to stop loading.
    if (mounted) {
      setState(() {
        _initialRoute = targetRoute;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show a loading spinner while we check everything
      return  Scaffold(body:isIOSPlatform?Center(child:CupertinoActivityIndicator() ,): Center(child: CircularProgressIndicator()));
    }
    

    // We have a confirmed route. Navigate to it immediately after this
    // build is complete. This is the correct way to navigate on init.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(_initialRoute);
      }
    });

    // Return an empty container while the navigation happens
    return const SizedBox.shrink();
  }
}
