import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_service.dart';

class HistoryScreen extends StatelessWidget {
  final VoidCallback? onGoToTranslate;
  const HistoryScreen({super.key, this.onGoToTranslate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0a0a),
        title: const Text('History',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white54, size: 18),
          onPressed: () => onGoToTranslate?.call(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFF1a1a1a)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: SessionService().getSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1D9E75), strokeWidth: 2),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F6E56).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(Icons.history_rounded,
                        color: Color(0xFF1D9E75), size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text('No translations yet',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  const Text('Start signing to see history here',
                      style: TextStyle(
                          color: Color(0xFF4a4a4a), fontSize: 13)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final data =
                  docs[i].data() as Map<String, dynamic>;
              final signs =
                  (data['signs'] as List?)?.join(' → ') ?? '';
              final sentence = data['translatedSentence'] ??
                  data['sentence'] ??
                  '';
              final language =
                  (data['language'] ?? 'en').toString().toUpperCase();
              final timestamp = data['timestamp'] as Timestamp?;
              final timeStr = timestamp != null
                  ? _formatTime(timestamp.toDate())
                  : '';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d0d0d),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF1a1a1a)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF085041),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(language,
                              style: const TextStyle(
                                  color: Color(0xFF4ade80),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const Spacer(),
                        Text(timeStr,
                            style: const TextStyle(
                                color: Color(0xFF3a3a3a),
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(sentence,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4)),
                    const SizedBox(height: 4),
                    Text(signs,
                        style: const TextStyle(
                            color: Color(0xFF3a3a3a),
                            fontSize: 11)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}