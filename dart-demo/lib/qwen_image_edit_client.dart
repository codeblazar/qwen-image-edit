import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

/// Minimal client for the Qwen Image Edit API.
///
/// This is intentionally small and "FlutterFlow-friendly": it shows exactly
/// what the request/headers/fields look like.
class QwenImageEditClient {
  QwenImageEditClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _normalizeApiBase(Uri apiBase) {
    if (apiBase.path.endsWith('/')) return apiBase;
    return apiBase.replace(path: '${apiBase.path}/');
  }

  /// Calls POST {apiBase}/edit and returns the edited PNG bytes.
  ///
  /// [apiBase] should look like: http://HOST:8000/api/v1
  ///
  /// NOTE: This is the synchronous endpoint intended for admin/testing.
  Future<EditImageResponse> editImage({
    required Uri apiBase,
    required String apiKey,
    required File imageFile,
    required String instruction,
    String? systemPrompt,
    String? preset,
    int? seed,
  }) async {
    final base = _normalizeApiBase(apiBase);
    final uri = base.resolve('edit');

    final request = http.MultipartRequest('POST', uri);
    request.headers['X-API-Key'] = apiKey;

    request.fields['instruction'] = instruction;
    request.fields['return_image'] = 'true';

    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      request.fields['system_prompt'] = systemPrompt;
    }
    if (preset != null && preset.trim().isNotEmpty) {
      request.fields['preset'] = preset;
    }
    if (seed != null) {
      request.fields['seed'] = seed.toString();
    }

    final filePath = imageFile.path;
    final ext = p.extension(filePath).toLowerCase();
    final MediaType contentType;
    if (ext == '.png') {
      contentType = MediaType('image', 'png');
    } else if (ext == '.jpg' || ext == '.jpeg') {
      contentType = MediaType('image', 'jpeg');
    } else {
      // The API will reject this; we keep the behavior explicit.
      contentType = MediaType('application', 'octet-stream');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        filePath,
        contentType: contentType,
      ),
    );

    final streamed = await request.send();
    final status = streamed.statusCode;
    final bytes = await streamed.stream.toBytes();

    if (status != 200) {
      final bodyText = utf8.decode(bytes, allowMalformed: true);
      throw ApiException(statusCode: status, message: _extractDetail(bodyText) ?? bodyText);
    }

    return EditImageResponse(
      pngBytes: bytes,
      seed: streamed.headers['x-seed'],
      preset: streamed.headers['x-preset'] ?? streamed.headers['x-model'],
      serverSavedPath: streamed.headers['x-saved-path'],
    );
  }

  /// Calls POST {apiBase}/submit, then polls /status/{job_id} until completion,
  /// then downloads the PNG bytes from /status/{job_id}/result.
  ///
  /// This is the recommended workflow for public/client use.
  Future<QueuedEditResponse> submitAndWait({
    required Uri apiBase,
    required String apiKey,
    required File imageFile,
    required String instruction,
    String? systemPrompt,
    String? preset,
    int? seed,
    Duration pollInterval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 15),
  }) async {
    final submit = await submitJob(
      apiBase: apiBase,
      apiKey: apiKey,
      imageFile: imageFile,
      instruction: instruction,
      systemPrompt: systemPrompt,
      preset: preset,
      seed: seed,
    );

    final deadline = DateTime.now().add(timeout);
    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        throw ApiException(
          statusCode: 408,
          message: 'Timed out waiting for job ${submit.jobId} to complete.',
        );
      }

      final status = await getJobStatus(apiBase: apiBase, apiKey: apiKey, jobId: submit.jobId);

      if (status.status == 'completed') {
        final pngBytes = await downloadJobResult(apiBase: apiBase, apiKey: apiKey, jobId: submit.jobId);
        return QueuedEditResponse(
          jobId: submit.jobId,
          pngBytes: pngBytes,
          resultSeed: status.resultSeed,
          preset: status.model,
          serverSavedPath: status.resultPath,
        );
      }

      if (status.status == 'failed') {
        throw ApiException(
          statusCode: 500,
          message: status.error ?? 'Job failed (no error message).',
        );
      }

      await Future<void>.delayed(pollInterval);
    }
  }

  Future<JobSubmitResponse> submitJob({
    required Uri apiBase,
    required String apiKey,
    required File imageFile,
    required String instruction,
    String? systemPrompt,
    String? preset,
    int? seed,
  }) async {
    final base = _normalizeApiBase(apiBase);
    final uri = base.resolve('submit');

    final request = http.MultipartRequest('POST', uri);
    request.headers['X-API-Key'] = apiKey;

    request.fields['instruction'] = instruction;

    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      request.fields['system_prompt'] = systemPrompt;
    }
    if (preset != null && preset.trim().isNotEmpty) {
      request.fields['preset'] = preset;
    }
    if (seed != null) {
      request.fields['seed'] = seed.toString();
    }

    final filePath = imageFile.path;
    final ext = p.extension(filePath).toLowerCase();
    final MediaType contentType;
    if (ext == '.png') {
      contentType = MediaType('image', 'png');
    } else if (ext == '.jpg' || ext == '.jpeg') {
      contentType = MediaType('image', 'jpeg');
    } else {
      contentType = MediaType('application', 'octet-stream');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        filePath,
        contentType: contentType,
      ),
    );

    final streamed = await request.send();
    final status = streamed.statusCode;
    final bytes = await streamed.stream.toBytes();

    final bodyText = utf8.decode(bytes, allowMalformed: true);
    if (status != 200) {
      throw ApiException(statusCode: status, message: _extractDetail(bodyText) ?? bodyText);
    }

    final decoded = jsonDecode(bodyText);
    if (decoded is! Map) {
      throw ApiException(statusCode: 500, message: 'Unexpected submit response: $bodyText');
    }

    return JobSubmitResponse(
      jobId: decoded['job_id']?.toString() ?? '',
      status: decoded['status']?.toString(),
      position: _toInt(decoded['position']),
      message: decoded['message']?.toString(),
      estimatedWaitSeconds: _toInt(decoded['estimated_wait_seconds']),
    );
  }

  Future<JobStatus> getJobStatus({
    required Uri apiBase,
    required String apiKey,
    required String jobId,
  }) async {
    final base = _normalizeApiBase(apiBase);
    final uri = base.resolve('status/$jobId');
    final resp = await _http.get(
      uri,
      headers: {
        'X-API-Key': apiKey,
        // Uvicorn's default keep-alive timeout is short; with a 5s poll interval
        // persistent connections can race against server-side idle close.
        'Connection': 'close',
      },
    );
    final bodyText = resp.body;
    if (resp.statusCode != 200) {
      throw ApiException(statusCode: resp.statusCode, message: _extractDetail(bodyText) ?? bodyText);
    }

    final decoded = jsonDecode(bodyText);
    if (decoded is! Map) {
      throw ApiException(statusCode: 500, message: 'Unexpected status response: $bodyText');
    }

    return JobStatus(
      jobId: decoded['job_id']?.toString() ?? jobId,
      status: decoded['status']?.toString() ?? 'unknown',
      position: _toInt(decoded['position']),
      resultPath: decoded['result_path']?.toString(),
      resultSeed: _toInt(decoded['result_seed']),
      error: decoded['error']?.toString(),
      model: decoded['model']?.toString(),
    );
  }

  Future<List<int>> downloadJobResult({
    required Uri apiBase,
    required String apiKey,
    required String jobId,
  }) async {
    final base = _normalizeApiBase(apiBase);
    final uri = base.resolve('status/$jobId/result');
    final resp = await _http.get(
      uri,
      headers: {
        'X-API-Key': apiKey,
        'Connection': 'close',
      },
    );
    if (resp.statusCode != 200) {
      final bodyText = utf8.decode(resp.bodyBytes, allowMalformed: true);
      throw ApiException(statusCode: resp.statusCode, message: _extractDetail(bodyText) ?? bodyText);
    }
    return resp.bodyBytes;
  }

  String? _extractDetail(String bodyText) {
    try {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail']?.toString();
      }
    } catch (_) {
      // ignore
    }
    return null;
  }
}

class JobSubmitResponse {
  JobSubmitResponse({
    required this.jobId,
    this.status,
    this.position,
    this.message,
    this.estimatedWaitSeconds,
  });

  final String jobId;
  final String? status;
  final int? position;
  final String? message;
  final int? estimatedWaitSeconds;
}

class JobStatus {
  JobStatus({
    required this.jobId,
    required this.status,
    this.position,
    this.resultPath,
    this.resultSeed,
    this.error,
    this.model,
  });

  final String jobId;
  final String status; // queued, processing, completed, failed
  final int? position;
  final String? resultPath;
  final int? resultSeed;
  final String? error;
  final String? model;
}

class QueuedEditResponse {
  QueuedEditResponse({
    required this.jobId,
    required this.pngBytes,
    this.resultSeed,
    this.preset,
    this.serverSavedPath,
  });

  final String jobId;
  final List<int> pngBytes;
  final int? resultSeed;
  final String? preset;
  final String? serverSavedPath;
}

class EditImageResponse {
  EditImageResponse({
    required this.pngBytes,
    this.seed,
    this.preset,
    this.serverSavedPath,
  });

  final List<int> pngBytes;
  final String? seed;
  final String? preset;
  final String? serverSavedPath;
}

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}
