import 'dart:io';

import 'package:qwen_image_edit_dart_demo/qwen_image_edit_client.dart';

void printUsage() {
  stdout.writeln('Qwen Image Edit API - Dart Demo');
  stdout.writeln('');
  stdout.writeln('Required:');
  stdout.writeln('  --image <path>');
  stdout.writeln('  --instruction <text>');
  stdout.writeln('');
  stdout.writeln('Optional:');
  stdout.writeln('  --api-base <url>         (default: http://localhost:8000/api/v1)');
  stdout.writeln('  --api-key <key>          (or env QWEN_API_KEY)');
  stdout.writeln('  --system-prompt <text>');
  stdout.writeln('  --preset <4-step|8-step|40-step>');
  stdout.writeln('  --seed <int>');
  stdout.writeln('  --out <path>             (default: edited.png)');
  stdout.writeln('  --poll-seconds <int>     (default: 5)');
  stdout.writeln('  --timeout-minutes <int>  (default: 15)');
  stdout.writeln('');
  stdout.writeln('Example:');
  stdout.writeln('  dart run bin/qwen_api_demo.dart --api-key YOUR_KEY --image C:/in.png --instruction "Make the model have short hair" --out C:/out.png');
}

Map<String, String?> parseArgs(List<String> args) {
  final map = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    final next = (i + 1 < args.length) ? args[i + 1] : null;
    if (next != null && !next.startsWith('--')) {
      map[key] = next;
      i++;
    } else {
      map[key] = 'true';
    }
  }
  return map;
}

Future<int> main(List<String> args) async {
  final a = parseArgs(args);

  final apiBase = a['api-base'] ?? 'http://localhost:8000/api/v1';
  final apiKey = a['api-key'] ?? Platform.environment['QWEN_API_KEY'];
  final imagePath = a['image'];
  final instruction = a['instruction'];
  final systemPrompt = a['system-prompt'];
  final preset = a['preset'];
  final seedStr = a['seed'];
  final outPath = a['out'] ?? 'edited.png';
  final pollSecondsStr = a['poll-seconds'] ?? '5';
  final timeoutMinutesStr = a['timeout-minutes'] ?? '15';

  if (imagePath == null || instruction == null) {
    printUsage();
    exitCode = 2;
    return 2;
  }
  if (apiKey == null || apiKey.trim().isEmpty) {
    stderr.writeln('Missing API key. Provide --api-key or set QWEN_API_KEY.');
    exitCode = 2;
    return 2;
  }

  final imageFile = File(imagePath);
  if (!await imageFile.exists()) {
    stderr.writeln('Image not found: $imagePath');
    exitCode = 2;
    return 2;
  }

  final client = QwenImageEditClient();
  final apiBaseUri = Uri.parse(apiBase);
  final apiBaseNormalized = apiBaseUri.path.endsWith('/') ? apiBaseUri : apiBaseUri.replace(path: '${apiBaseUri.path}/');

  int? seed;
  if (seedStr != null && seedStr.trim().isNotEmpty) {
    seed = int.tryParse(seedStr);
    if (seed == null) {
      stderr.writeln('Invalid --seed value: $seedStr (must be int)');
      exitCode = 2;
      return 2;
    }
  }

  final pollSeconds = int.tryParse(pollSecondsStr);
  if (pollSeconds == null || pollSeconds <= 0) {
    stderr.writeln('Invalid --poll-seconds value: $pollSecondsStr (must be > 0)');
    exitCode = 2;
    return 2;
  }

  final timeoutMinutes = int.tryParse(timeoutMinutesStr);
  if (timeoutMinutes == null || timeoutMinutes <= 0) {
    stderr.writeln('Invalid --timeout-minutes value: $timeoutMinutesStr (must be > 0)');
    exitCode = 2;
    return 2;
  }

  stdout.writeln('POST ${apiBaseNormalized.resolve('submit')}');
  stdout.writeln('Uploading: $imagePath');

  QueuedEditResponse resp;
  try {
    resp = await client.submitAndWait(
      apiBase: apiBaseUri,
      apiKey: apiKey,
      imageFile: imageFile,
      instruction: instruction,
      systemPrompt: systemPrompt,
      preset: preset,
      seed: seed,
      pollInterval: Duration(seconds: pollSeconds),
      timeout: Duration(minutes: timeoutMinutes),
    );
  } on ApiException catch (e) {
    stderr.writeln('HTTP ${e.statusCode}: ${e.message}');
    exitCode = 1;
    return 1;
  } catch (e) {
    stderr.writeln('Request failed: $e');
    exitCode = 1;
    return 1;
  }

  final outFile = File(outPath);
  await outFile.writeAsBytes(resp.pngBytes);

  stdout.writeln('Job: ${resp.jobId}');
  stdout.writeln('Saved edited image: ${outFile.absolute.path}');
  if (resp.resultSeed != null) stdout.writeln('Seed: ${resp.resultSeed}');
  if (resp.preset != null) stdout.writeln('Model/preset: ${resp.preset}');
  if (resp.serverSavedPath != null) stdout.writeln('Server saved path: ${resp.serverSavedPath}');

  exitCode = 0;
  return 0;
}
