import 'package:ditck/features/home/views/meeting_view_page.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset('assets/logos/logo.png', height: 32),
            const SizedBox(width: 8),
            const Text(
              'Dashboard',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Ongoing Meeting'),
            const SizedBox(height: 8),
            _meetingCard(
              context,
              title: 'Project Sync',
              time: '10:00 AM - 11:00 AM',
              participants: ['avatar1.jpg', 'avatar2.jpg', 'avatar3.jpg'],
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 16),

            _sectionTitle('Upcoming Meeting'),
            const SizedBox(height: 8),
            _meetingCard(
              context,
              title: 'Design Review',
              time: '2:00 PM - 3:00 PM',
              participants: ['avatar2.jpg', 'avatar3.jpg'],
              color: const Color(0xFF9333EA),
            ),
            const SizedBox(height: 16),

            _sectionTitle('Team Members'),
            const SizedBox(height: 8),
            Column(
              children: [
                _teamMember('avatar1.jpg', 'Alice Johnson', 'UI/UX Designer'),
                _teamMember('avatar2.jpg', 'Mark Lee', 'Project Manager'),
                _teamMember('avatar3.jpg', 'Sophia Brown', 'Backend Engineer'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _meetingCard(
    BuildContext context, {
    required String title,
    required String time,
    required List<String> participants,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Color side bar
          Container(
            width: 6,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),

          // Meeting details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 8),

                // Participant avatars
                Row(
                  children: participants
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundImage: AssetImage('assets/avatar/$p'),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          // Join button
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MeetingViewPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text(
              'Join',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamMember(String avatar, String name, String role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage('assets/avatar/$avatar'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
