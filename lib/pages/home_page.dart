import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/glass_button.dart';
import '../widgets/fade_slide.dart';
import '../models/game_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2193F3), Color(0xFF24D2CF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 140, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const FadeSlide(
                  child: Text(
                    "ZeroSense",
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 12)],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const FadeSlide(
                  offsetY: 30,
                  child: Text(
                    "Semantic Word Guess",
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 80),

                FadeSlide(
                  offsetY: 40,
                  child: GlassButton(
                    text: "Host Online Game",
                    icon: Icons.videogame_asset_rounded,
                    onTap: () {
                      Provider.of<GameState>(context, listen: false).reset();
                      Navigator.pushNamed(context, '/host');
                    },
                  ),
                ),

                const SizedBox(height: 20),

                FadeSlide(
                  offsetY: 50,
                  child: GlassButton(
                    text: "Join Online Game",
                    icon: Icons.group_add_rounded,
                    onTap: () {
                      Provider.of<GameState>(context, listen: false).reset();
                      Navigator.pushNamed(context, '/join');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
