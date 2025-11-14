import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Zero', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 8),
              const Text('Semantic Word Guess', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  Provider.of<GameState>(context, listen: false).reset();
                  Navigator.pushNamed(context, '/host');
                },
                child: const Text('Host Online Game'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Provider.of<GameState>(context, listen: false).reset();
                  Navigator.pushNamed(context, '/join');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blueAccent, side: const BorderSide(color: Colors.blueAccent)),
                child: const Text('Join Online Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
