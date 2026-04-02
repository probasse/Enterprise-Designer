import 'package:flutter/material.dart';

import '../../core/app_controller.dart';

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final message =
        controller.viewState.errorMessage ?? controller.flashMessage;
    if (message == null) {
      return const SizedBox.shrink();
    }

    final isError = controller.viewState.errorMessage != null;
    final color = isError ? const Color(0xFF7A1F1F) : const Color(0xFF255F4A);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
              IconButton(
                onPressed: controller.clearFlashMessage,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
