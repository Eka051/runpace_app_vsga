import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runpace_app/providers/auth_provider.dart';
import 'package:runpace_app/views/activity_detail_view.dart';
import 'package:runpace_app/views/home_view.dart';
import 'package:runpace_app/views/login_view.dart';
import 'package:runpace_app/views/tracking_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => AppAuth())],
      child: const Runpace(),
    ),
  );
}

class Runpace extends StatelessWidget {
  const Runpace({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppAuth(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const LoginView(),
        routes: {
          '/login': (context) => const LoginView(),
          '/home': (context) => const HomeView(),
          '/tracking': (context) => const TrackingView(),
        },
        initialRoute: '/login',
        onGenerateRoute: (settings) {
          if (settings.name == '/activity_detail') {
            final args = settings.arguments as int;
            return MaterialPageRoute(
              builder: (context) => ActivityDetailView(activityId: args),
            );
          }
          return null;
        },
      ),
    );
  }
}
