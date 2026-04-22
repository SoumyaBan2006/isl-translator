import 'package:cloud_firestore/cloud_firestore.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveSession({
    required List<String> signs,
    required String sentence,
    required String translatedSentence,
    required String language,
  }) async {
    try {
      await _db.collection('sessions').add({
        'timestamp': FieldValue.serverTimestamp(),
        'signs': signs,
        'sentence': sentence,
        'translatedSentence': translatedSentence,
        'language': language,
      });
    } catch (e) {
      // Save failed silently
    }
  }

  Stream<QuerySnapshot> getSessions() {
    return _db
        .collection('sessions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
}