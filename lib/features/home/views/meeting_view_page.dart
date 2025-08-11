import 'package:flutter/material.dart';

class MeetingViewPage extends StatelessWidget {
  const MeetingViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon:
                        const Icon(Icons.more_vert, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Main video area
            Expanded(
              child: Center(
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logos/logo.png',
                        height: 60,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'John Doe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Reactions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _reactionButton('👍'),
                _reactionButton('❤️'),
                _reactionButton('😂'),
                _reactionButton('👏'),
              ],
            ),

            const SizedBox(height: 24),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(
                      icon: Icons.mic_off,
                      color: Colors.white,
                      background: Colors.redAccent),
                  const SizedBox(width: 16),
                  _controlButton(
                      icon: Icons.videocam,
                      color: Colors.white,
                      background: Colors.blueAccent),
                  const SizedBox(width: 16),
                  _controlButton(
                      icon: Icons.screen_share,
                      color: Colors.white,
                      background: Colors.green),
                  const SizedBox(width: 16),
                  _controlButton(
                      icon: Icons.call_end,
                      color: Colors.white,
                      background: Colors.red,
                      isLeave: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reactionButton(String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          // handle reaction tap
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  Widget _controlButton(
      {required IconData icon,
      required Color color,
      required Color background,
      bool isLeave = false}) {
    return GestureDetector(
      onTap: () {
        // handle control action
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
