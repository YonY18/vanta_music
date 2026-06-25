import 'dart:io';

final _focusedPatterns = <RegExp>[
  RegExp(r'\b(?:test|group)\s*\.\s*only\s*\('),
  RegExp(r'\bsolo_(?:test|group|testWidgets)\s*\('),
  RegExp(r'\bsoloTestWidgets\s*\('),
];

void main(List<String> arguments) {
  final roots = arguments.isEmpty ? <String>['test', 'packages'] : arguments;
  final findings = <String>[];

  for (final root in roots) {
    final entity = Directory(root);
    if (!entity.existsSync()) continue;

    for (final file in entity.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('_test.dart')) continue;
      final relativePath = file.path.replaceAll('\\', '/');
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (_focusedPatterns.any((pattern) => pattern.hasMatch(line))) {
          findings.add('$relativePath:${index + 1}: ${line.trim()}');
        }
      }
    }
  }

  if (findings.isEmpty) return;

  stderr.writeln('Focused Flutter/Dart tests are not allowed in CI:');
  for (final finding in findings) {
    stderr.writeln('  $finding');
  }
  exitCode = 1;
}
