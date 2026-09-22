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

// port 0 makes the operating system pick a random free port that the library cannot discover,
// and ports below 1024 require elevated privileges on macOS and Linux
const communicationServiceMinPort = 1024;
const communicationServiceMaxPort = 65535;

final communicationServiceInstance = CommunicationService();

class CommunicationService {
  static const _maxRequestBodyBytes = 128 * 1024 * 1024;
  static const _parseInIsolateThresholdBytes = 256 * 1024;

  DateTime? _lastCommunication;

  HttpServer? server;

  CommunicationService() {
    Timer.periodic(const Duration(milliseconds: 1000), (x) => _checkConnection());
  }

  Future tryToStartTheServer(int port) async {
    try {
      await startServer(port);
    } catch (e) {
      applicationStateProviderInstance.changeCommunicationStatus(CommunicationStatus.error);
    }
  }

  Future startServer(int port) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    applicationStateProviderInstance.changeCommunicationStatus(CommunicationStatus.active);

    await for (HttpRequest request in server!) {
      _handleRequest(request);
    }
  }

  Future stopServer() async {
    await server?.close(force: true);
    server = null;
  }

  void _checkConnection() {
    if (_lastCommunication == null) return;

    if (DateTime.now().difference(_lastCommunication!).inSeconds < 1) return;

    _lastCommunication = null;
    applicationStateProviderInstance.changeMode(ApplicationMode.welcomeScreen);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final handler = _findHandler(request);

      if (handler == null) {
        request.response.statusCode = HttpStatus.notFound;
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

    if (path == '/ping' && method == 'GET') return _handlePingRequest;

    if (path == '/version' && method == 'GET') return _handleVersionRequest;

    // API versions 2 and 3 are nearly identical: version 3 introduced new license type (evaluation),
    // this change requires new API version to avoid breaking changes in newer library versions,
    // but implementation can be backwards compatible, so both versions are handled in the same way.
    for (var i in [2, 3]) {
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

  Future<void> _handlePingRequest(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
  }

  Future<void> _handleNotifyRequest(HttpRequest request) async {
    _lastCommunication = DateTime.now();

    final body = await _readRequestBody(request);
    final notifyCommand = ApplicationNotifyCommand.fromJson(jsonDecode(utf8.decode(body)));

    applicationStateProviderInstance.setCurrentLicense(notifyCommand.license);

    request.response.statusCode = HttpStatus.ok;
  }

  Future<void> _handleVersionRequest(HttpRequest request) async {
    final response = ApplicationSupportedApiResponse([2, 3]);

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
    applicationStateProviderInstance.checkIfDisplayComplexDocumentWarningBasedOnJsonLength(body.length);
    applicationStateProviderInstance.setDocumentAsHotReloaded(documentStructure.isDocumentHotReloaded);

    request.response.statusCode = HttpStatus.ok;
  }

  Future<void> _handleGetRenderingRequests(HttpRequest request) async {
    List<PageSnapshotIndex> neededImages = [];

    for (int i = 0; i < 100; i++) {
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
