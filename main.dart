import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/game_state.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'pages/home_page.dart';
import 'pages/host_page.dart';
import 'pages/join_page.dart';
import 'pages/game_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Ensure anonymous auth
  await FirebaseAuth.instance.signInAnonymously();
  runApp(const ZeroApp());
}

class ZeroApp extends StatelessWidget {
  const ZeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
        Provider(create: (_) => ApiService()),
        ProxyProvider<ApiService, FirebaseService>(
          update: (_, api, __) => FirebaseService(api),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'Zero - Semantic Guess',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        routes: {
          '/': (_) => const HomePage(),
          '/host': (_) => const HostPage(),
          '/join': (_) => const JoinPage(),
          '/game': (_) => const GamePage(),
        },
        initialRoute: '/',
      ),
    );
  }
}
