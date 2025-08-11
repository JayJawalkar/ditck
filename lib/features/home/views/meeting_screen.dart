import 'package:ditck/features/home/views/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class MeetingRoomPage extends StatelessWidget {
  const MeetingRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0E1C36),
      body: Column(
        children: [
          // Custom App Bar
          Container(
            padding: const EdgeInsets.only(top: 56, bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A2E51),
                  const Color(0xFF0E1C36).withOpacity(0.01),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Team Standup Meeting',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Meeting info
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  'Starts in 5 minutes',
                  style: TextStyle(color: Colors.blue[200], fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  '10:00 AM - 10:30 AM',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background pattern
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.05,
                    child: CustomPaint(painter: _CirclePatternPainter()),
                  ),
                ),

                // Participants layout
                SizedBox(
                  width: size.width * 0.85,
                  height: size.width * 0.85,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Central speaker with glow effect
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: size.width * 0.15,
                          backgroundColor: Colors.blueGrey[900],
                          child: const CircleAvatar(
                            radius: 56,
                            backgroundImage: AssetImage(
                              'assets/avatar/avatar1.jpg',
                            ),
                          ),
                        ),
                      ),

                      // Surrounding participants
                      ...List.generate(6, (index) {
                        final double angle = (index / 6) * 2 * math.pi;
                        final double radius = size.width * 0.32;
                        final double offset = size.width * 0.425;
                        return Positioned(
                          left: offset + radius * math.cos(angle) - 30,
                          top: offset + radius * math.sin(angle) - 30,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _getBorderColor(index),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.blueGrey[800],
                              child: CircleAvatar(
                                radius: 26,
                                backgroundImage: AssetImage(
                                  'assets/avatar/avatar${(index % 3) + 2}.jpg',
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Column(
                children: [
                  // Join button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.video_call, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Join Meeting',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(int index) {
    final colors = [
      const Color(0xFF00C853), // Green
      const Color(0xFF2962FF), // Blue
      const Color(0xFFFFD600), // Yellow
      const Color(0xFF00B8D4), // Teal
      const Color(0xFFAA00FF), // Purple
      const Color(0xFFFF6D00), // Orange
    ];
    return colors[index % colors.length];
  }

  Widget _buildControlButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.blueGrey[900]!.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    for (double radius = 20; radius < maxRadius; radius += 25) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
