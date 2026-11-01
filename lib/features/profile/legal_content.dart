class LegalSection {
  const LegalSection(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
}

// TODO: replace with your real Terms & Conditions and Privacy Policy.
// Keep TERMS_VERSION on the API in step with this text.
const _lorem =
    'Lorem ipsum dolor sit amet consectetur. Aliquet nulla dignissim mollis diam sit nibh proin sollicitudin. '
    'Morbi massa mattis leo facilisis netus arcu. Ut malesuada pharetra vel tempor dui. Sed vestibulum elit nec '
    'senectus aenean egestas in. Pharetra urna tempor elementum velit rutrum. Cursus molestie leo a quis tempus '
    'non sit velit cursus. Ac.';

const kLegalSections = [
  LegalSection('Terms & Condition', [_lorem, _lorem, _lorem]),
  LegalSection('Privacy Policy', [_lorem, _lorem, _lorem]),
];