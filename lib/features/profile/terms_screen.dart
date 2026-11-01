import 'package:flutter/material.dart';
import '../../core/widgets/sub_page.dart';
import 'legal_content.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Terms & Condition',
      fadeBottom: true,
      children: [
        for (final section in kLegalSections) ...[
          Text(
            section.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black),
          ),
          const SizedBox(height: 10),
          for (final paragraph in section.paragraphs) ...[
            Text(
              paragraph,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF4A4E5A)),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}