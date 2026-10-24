// The hero's save in the cloud, so the same account plays the same hero on every device (the
// phone at lunch, the laptop in the evening). One Firestore document per account:
//   ck_saves/{uid}      { at: <ms since epoch>, save: "<GameState JSON>" }
//   ck_foodbook/{uid}   the same shape, holding recent foods and recipes
// The device copy is still written first and is what the game runs on; the cloud copy follows a
// moment later. On load the newer of the two wins. Needs the rules in firestore.rules.calorieknight.

import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved game and when it was saved.
typedef StampedSave = ({int at, String json});

/// What a cloud read found: [ok] false when the cloud couldn't be reached (offline, rules), which
/// is not the same as "nothing saved there yet" ([ok] true, [save] null).
typedef CloudFetch = ({bool ok, StampedSave? save});

abstract class CloudSave {
  Future<CloudFetch> fetch();
  Future<bool> put(StampedSave save);
}

class FirestoreCloudSave implements CloudSave {
  FirestoreCloudSave(this.uid, {this.collection = 'ck_saves'});
  final String uid, collection;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance.collection(collection).doc(uid);

  @override
  Future<CloudFetch> fetch() async {
    try {
      final snap = await _doc.get();
      final d = snap.data();
      if (!snap.exists || d == null) return (ok: true, save: null);
      final at = d['at'], json = d['save'];
      if (at is! num || json is! String || json.isEmpty) return (ok: true, save: null);
      return (ok: true, save: (at: at.toInt(), json: json));
    } catch (_) {
      return (ok: false, save: null); // offline, or the rules aren't in: play on the device copy
    }
  }

  @override
  Future<bool> put(StampedSave save) async {
    try {
      await _doc.set({'at': save.at, 'save': save.json});
      return true;
    } catch (_) {
      return false;
    }
  }
}
