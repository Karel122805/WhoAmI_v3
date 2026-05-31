import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whoami_app/src/features/home/presentation/pages/home_caregiver.dart';
import 'package:whoami_app/src/features/home/presentation/pages/home_consultant.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FutureBuilder(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!.data() ?? {};
        final role = (data['role'] as String?)?.trim() ?? 'Consultante';
        return role == 'Cuidador'
            ? const HomeCaregiverPage()
            : const HomeConsultantPage();
      },
    );
  }
}






