import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:questpdf_companion/areas/application/models/application_notify_command.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_structure.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_search_state.dart';
import 'package:questpdf_companion/areas/generic_exception/generic_exception_view_state_provider.dart';

import 'areas/application/models/application_supported_api_response.dart';
import 'areas/document_hierarchy/models/page_snapshot_index.dart';
import 'areas/document_hierarchy/state/document_layout_error_provider.dart';
import 'areas/document_preview/models/page_snapshot_rendered.dart';
import 'areas/document_preview/models/update_page_snapshots_command.dart';
import 'areas/document_preview/state/document_viewer_state_provider.dart';
import 'areas/generic_exception/models/show_generic_exception_command.dart';

const communicationServiceDefaultPort = 12500;
const communicationServiceBindRetryInterval = Duration(seconds: 5);

// port 0 makes the operating system pick a random free port that the library cannot discover,
// and ports below 1024 require elevated privileges on macOS and Linux
const communicationServiceMinPort = 1024;
const communicationServiceMaxPort = 65535;

final communicationServiceInstance = CommunicationService();

class CommunicationService {
  static const _maxRequestBodyBytes = 128 * 1024 * 1024;
  static const _parseInIsolateThresholdBytes = 256 * 1024;
  static const _supportedApiVersions = [2, 3, 4];
  static const _clientIdHeader = 'X-QuestPDF-Client-Id';
  static const _codeLocationIdHeader = 'X-QuestPDF-Code-Location-Id';

  // The preview session belongs to a single ShowInCompanion call, identified by its client id.
  // The code location id is shared by all runs of the same application; it does not affect who holds the session.
  String? _currentClientId;
  String? _currentCodeLocationId;

  final _rejectedClientIds = <String>{};

  DateTime? _lastCommunication;
  Timer? _connectionTimer;
  Timer? _bindRetryTimer;
  int _serverRevision = 0;

  Future<void> _serverOperation = Future.value();
  final failedPort = ValueNotifier<int?>(null);

  HttpServer? server;

  Future<void> tryToStartTheServer(int port) async {
    try {
      await startServer(port);
    } catch (e) {
      // startServer records the failure and schedules another attempt.
    }
  }

  Future<void> startServer(int port) {
    final revision = ++_serverRevision;
    _cancelBindRetry();
    return _enqueueServerOperation(() => _bindServer(port, revision));
  }

  Future<void> _bindServer(int port, int revision) async {
    // A newer start/stop was requested while this one was waiting in the queue.
    if (revision != _serverRevision) return;

    // Keep the error visible throughout retries; clear it when changing ports
    // or after a successful bind so the message does not blink every five seconds.
    if (failedPort.value != port) failedPort.value = null;

    try {
      await _closeServer();
      final newServer = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

      // A newer start/stop may have been requested while the bind was pending.
      if (revision != _serverRevision) {
        await newServer.close(force: true);
        return;
      }

      server = newServer;
      newServer.listen(_handleRequest);
      _connectionTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) => _checkConnection());
      failedPort.value = null;
    } catch (e) {
      if (revision == _serverRevision) {
        failedPort.value = port;
        _scheduleBindRetry(port, revision);
      }
      rethrow;
    }
  }

  Future<void> stopServer() {
    ++_serverRevision;
    _cancelBindRetry();
    return _enqueueServerOperation(() async {
      await _closeServer();
      failedPort.value = null;
    });
  }

  void _cancelBindRetry() {
    _bindRetryTimer?.cancel();
    _bindRetryTimer = null;
  }

  void _scheduleBindRetry(int port, int revision) {
    _cancelBindRetry();
    // Schedule after each failed attempt, rather than periodically, so a slow
    // bind cannot accumulate overlapping retry operations.
    _bindRetryTimer = Timer(communicationServiceBindRetryInterval, () {
      _bindRetryTimer = null;
      // A failed retry schedules the next one itself, so its error needs no handling here.
      _enqueueServerOperation(() => _bindServer(port, revision)).ignore();
    });
  }

  // Closing and binding are one operation: a newer port change must wait for
  // an in-flight bind, otherwise its listener can be overwritten and leaked.
  Future<void> _enqueueServerOperation(Future<void> Function() operation) {
    final result = _serverOperation.then((_) => operation());
    // A failed bind must not prevent later port changes or retries.
    _serverOperation = result.then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {});
    return result;
  }

  Future<void> _closeServer() async {
    _connectionTimer?.cancel();
    _connectionTimer = null;
    _endSession();

    final previousServer = server;
    server = null;
    await previousServer?.close(force: true);
  }

  void _checkConnection() {
    if (_lastCommunication == null) return;

    // the library notifies about its presence every 250 ms; a much longer silence is tolerated,
    // so the content stays displayed while the application restarts,
    // e.g. when dotnet watch rebuilds it after a code change that cannot be hot reloaded
    if (DateTime.now().difference(_lastCommunication!).inSeconds < 5) return;

    _endSession();
    applicationStateProviderInstance.changeMode(ApplicationMode.welcomeScreen);
  }

  // The client that held the session is rejected when it comes back, so its ShowInCompanion call ends.
  void _endSession() {
    if (_currentClientId != null) _rejectedClientIds.add(_currentClientId!);

    _currentClientId = null;
    _currentCodeLocationId = null;
    _lastCommunication = null;
  }

  bool _acceptClient(HttpRequest request) {
    final clientId = request.headers.value(_clientIdHeader);

    if (clientId != _currentClientId) {
      // libraries using API versions 2 and 3 send no id, and wait until the identified application is gone
      if (clientId == null || _rejectedClientIds.contains(clientId)) return false;

      // the newest ShowInCompanion call takes over, whether it comes from another application
      // or from a new run of the same one (e.g. restarted by dotnet watch): ending the session rejects the previous client
      _endSession();
      _currentClientId = clientId;
      _currentCodeLocationId = request.headers.value(_codeLocationIdHeader);
    }

    _lastCommunication = DateTime.now();
    return true;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final handler = _findHandler(request);

      if (handler == null) {
        request.response.statusCode = HttpStatus.notFound;
        return;
      }

      // versioned requests belong to the preview session; the other ones only discover the application
      final isSessionRequest = request.uri.path.startsWith(RegExp(r'/v\d+/'));

      if (isSessionRequest && !_acceptClient(request)) {
        request.response.statusCode = HttpStatus.conflict;
        return;
      }

      await handler(request);
    } on FormatException {
      _tryToSetResponseStatusCode(request, HttpStatus.badRequest);
    } on TypeError {
      _tryToSetResponseStatusCode(request, HttpStatus.badRequest);
    } catch (e) {
      _tryToSetResponseStatusCode(request, HttpStatus.internalServerError);
    } finally {
      try {
        await request.response.close();
      } catch (e) {
        // the connection is already closed or broken
      }
    }
  }

  void _tryToSetResponseStatusCode(HttpRequest request, int statusCode) {
    try {
      request.response.statusCode = statusCode;
    } catch (e) {
      // headers were already sent; the status code cannot be changed anymore
    }
  }

  Future<void> Function(HttpRequest)? _findHandler(HttpRequest request) {
    final path = request.uri.path;
    final method = request.method;

    if (path == '/questpdf-companion' && method == 'GET') return _handleIdentityRequest;

    if (path == '/ping' && method == 'GET') return _handlePingRequest;

    if (path == '/version' && method == 'GET') return _handleVersionRequest;

    // API versions 2 and 3 are nearly identical: version 3 introduced new license type (evaluation),
    // this change requires new API version to avoid breaking changes in newer library versions,
    // but implementation can be backwards compatible, so both versions are handled in the same way.
    // Version 4 identifies the client in request headers, and expects a conflict response once it is rejected.
    for (var i in _supportedApiVersions) {
      if (path == '/v$i/notify' && method == 'POST') return _handleNotifyRequest;

      if (path == '/v$i/documentPreview/update' && method == 'POST') return _handlePreviewUpdate;

      if (path == '/v$i/documentPreview/getRenderingRequests' && method == 'GET') return _handleGetRenderingRequests;

      if (path == '/v$i/documentPreview/provideRenderedImages' && method == 'POST') return _handleProvideRenderedImages;

      if (path == '/v$i/genericException/show' && method == 'POST') return _handleGenericException;
    }

    return null;
  }

  Future<Uint8List> _readRequestBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);

    await for (final chunk in request) {
      builder.add(chunk);

      if (builder.length > _maxRequestBodyBytes) {
        throw const FormatException('The request body exceeds the maximum supported size');
      }
    }

    return builder.takeBytes();
  }

  Future<T> _parseBody<T>(Uint8List body, T Function(Uint8List) parser) {
    if (body.length < _parseInIsolateThresholdBytes) return Future.value(parser(body));

    // large payloads are parsed in a separate isolate to keep the UI responsive
    // and to avoid delaying the connection heartbeat
    return compute(parser, body);
  }

  static DocumentStructure _parseDocumentStructure(Uint8List body) =>
      DocumentStructure.fromJson(jsonDecode(utf8.decode(body)));

  static List<PageSnapshotRendered> _parseRenderedPages(Uint8List body) =>
      UpdatePageSnapshotsCommand.fromJson(jsonDecode(utf8.decode(body))).pages;

  // Lets the library tell the Companion app apart from any other program listening on the port.
  Future<void> _handleIdentityRequest(HttpRequest request) async {
    request.response
      ..headers.contentType = ContentType.text
      ..write('QuestPDF Companion');
  }

  Future<void> _handlePingRequest(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
  }

  Future<void> _handleNotifyRequest(HttpRequest request) async {
    final body = await _readRequestBody(request);
    final notifyCommand = ApplicationNotifyCommand.fromJson(jsonDecode(utf8.decode(body)));

    applicationStateProviderInstance.setCurrentLicense(notifyCommand.license);

    request.response.statusCode = HttpStatus.ok;
  }

  Future<void> _handleVersionRequest(HttpRequest request) async {
    final response = ApplicationSupportedApiResponse(_supportedApiVersions);

    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(response.toJson()));
  }

  Future<void> _handlePreviewUpdate(HttpRequest request) async {
    final body = await _readRequestBody(request);
    final documentStructure = await _parseBody(body, _parseDocumentStructure);

    documentPreviewImageCacheStateInstance.updateDocumentStructure(documentStructure.pages);
    documentHierarchyProviderInstance.setHierarchy(documentStructure.hierarchy);
    documentHierarchySearchStateInstance.reset();
    documentLayoutErrorProviderInstance.update();

    applicationStateProviderInstance.changeMode(ApplicationMode.documentPreview);
    applicationStateProviderInstance.setDocumentAsHotReloaded(documentStructure.isDocumentHotReloaded);

    request.response.statusCode = HttpStatus.ok;
  }

  Future<void> _handleGetRenderingRequests(HttpRequest request) async {
    List<PageSnapshotIndex> neededImages = [];

    for (int i = 0; i < 100; i++) {
      // the session may have been taken over or ended while this client was waiting
      if (request.headers.value(_clientIdHeader) != _currentClientId) break;

      neededImages = documentPreviewImageCacheStateInstance.getNeededImages();

      if (neededImages.isNotEmpty) break;

      await Future.delayed(const Duration(milliseconds: 25));
    }

    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(neededImages));
  }

  Future<void> _handleProvideRenderedImages(HttpRequest request) async {
    final body = await _readRequestBody(request);
    final renderedPages = await _parseBody(body, _parseRenderedPages);

    await documentPreviewImageCacheStateInstance.addImages(renderedPages);

    request.response.statusCode = HttpStatus.ok;
  }

  Future<void> _handleGenericException(HttpRequest request) async {
    final body = await _readRequestBody(request);
    final genericException = ShowGenericExceptionCommand.fromJson(jsonDecode(utf8.decode(body)));

    applicationStateProviderInstance.changeMode(ApplicationMode.genericException);
    genericExceptionViewStateInstance.setException(genericException);

    request.response.statusCode = HttpStatus.ok;
  }
}
