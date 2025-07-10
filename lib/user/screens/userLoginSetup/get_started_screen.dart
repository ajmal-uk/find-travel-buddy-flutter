import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../user_screen.dart';

void main() {
  runApp(const MaterialApp(
    home: GetStartedPage(),
    debugShowCheckedModeBanner: false,
  ));
}

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final PageController _pageController = PageController();
  final List<Map<String, String>> setupFrames = [
    {
      "animation": "assets/system/animation/greet/welcome.json",
      "heading": "Welcome!",
      "description": "Get ready for an amazing journey with us."
    },
    {
      "animation": "assets/system/animation/greet/posttrip.json",
      "heading": "Share Your Trip",
      "description": "Let others know about your travel experiences."
    },
    {
      "animation": "assets/system/animation/greet/find.json",
      "heading": "Find a Buddy",
      "description": "Connect with others and explore together."
    },
    {
      "animation": "assets/system/animation/greet/plan.json",
      "heading": "Plan Your Trip",
      "description": "Organize your journey with ease and confidence."
    },
    {
      "animation": "assets/system/animation/greet/enjoy.json",
      "heading": "Enjoy the Adventure",
      "description": "Make the most of your trip and create lasting memories."
    },
    {
      "animation": "assets/system/animation/greet/postmemory.json",
      "heading": "Share Memories",
      "description": "Capture and share the highlights of your journey."
    }
  ];

  int _currentIndex = 0;

  void _nextPage() {
    if (_currentIndex < setupFrames.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 33, 150, 243),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: setupFrames.length,
              itemBuilder: (context, index) {
                final frame = setupFrames[index];
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 50,
                      ),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 400,
                            height: 400,
                            child: Lottie.asset(
                              frame['animation']!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        frame['heading']!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        frame['description']!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              setupFrames.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 52.0),
            child: Row(
              mainAxisAlignment: _currentIndex == 0
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromARGB(255, 33, 150, 243),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _previousPage,
                    child: const Text("Back"),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color.fromARGB(255, 33, 150, 243),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _currentIndex == setupFrames.length - 1
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const UserScreen()),
                          );
                        }
                      : _nextPage,
                  child: Text(_currentIndex == setupFrames.length - 1
                      ? "Get Started"
                      : "Next"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
