import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder until the sign-up design is ready.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The sign-up screen comes next.'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
