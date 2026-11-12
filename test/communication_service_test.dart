import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/communication_service.dart';

final class NativeIO extends IOOverrides {}

// Advance only the bind-retry timer; socket operations still use real localhost
// sockets, so retry and cancellation tests do not need to sleep for five seconds.
final class BindRetryTimer implements Timer {
  final Duration delay;
  final Zone zone;
  final void Function() callback;

  @override
  bool isActive = true;
  @override
  int tick = 0;

  BindRetryTimer(this.delay, this.zone, this.callback);

  @override
  void cancel() => isActive = false;

  void fire() {
    if (!isActive) return;
    isActive = false;
    tick++;
    zone.runGuarded(callback);
  }
}

Future<void> withBindRetryTimers(Future<void> Function(List<BindRetryTimer>) body) {
  final timers = <BindRetryTimer>[];
  return runZoned(
    () => body(timers),
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        if (duration != communicationServiceBindRetryInterval) return parent.createTimer(zone, duration, callback);
        final timer = BindRetryTimer(duration, zone, callback);
        timers.add(timer);
        return timer;
      },
    ),
  );
}

Future<List<int>> freePorts(int count) async {
  final reservations = <ServerSocket>[];
  try {
    for (var i = 0; i < count; i++) {
      reservations.add(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
    }
    return reservations.map((socket) => socket.port).toList();
  } finally {
    for (final reservation in reservations) {
      await reservation.close();
    }
  }
}

Future<bool> isListening(int port) async {
  try {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 1));
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  }
}

Future<int> notify(int port, {String? clientId, String? codeLocationId, int apiVersion = 4}) async {
  final client = HttpClient();

  try {
    final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/v$apiVersion/notify'));
    if (clientId != null) request.headers.set('X-QuestPDF-Client-Id', clientId);
    if (codeLocationId != null) request.headers.set('X-QuestPDF-Code-Location-Id', codeLocationId);
    request.write('{"license":"community"}');

    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

void main() {
  final service = communicationServiceInstance;
  setUp(service.stopServer);
  tearDown(service.stopServer);

  test('overlapping setting changes leave only the latest port listening', () async {
    final ports = await freePorts(2);
    final settings = ApplicationStateProvider();
    addTearDown(settings.dispose);
    final firstBindStarted = Completer<void>();
    final releaseFirstBind = Completer<void>();
    final nativeIO = NativeIO();
    var secondBindStarted = false;

    await IOOverrides.runZoned(
      () async {
        final firstChange = settings.changeCommunicationPort(ports[0]);
        await firstBindStarted.future;
        final secondChange = settings.changeCommunicationPort(ports[1]);
        await Future<void>.value();
        expect(secondBindStarted, isFalse);
        releaseFirstBind.complete();
        await Future.wait([firstChange, secondChange]);

        expect(settings.communicationPort, ports[1]);
        expect(service.server!.port, ports[1]);
        expect(await isListening(ports[0]), isFalse);
        expect(await isListening(ports[1]), isTrue);
      },
      serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) async {
        if (port == ports[0]) {
          firstBindStarted.complete();
          await releaseFirstBind.future;
        } else if (port == ports[1]) {
          secondBindStarted = true;
        }
        return nativeIO.serverSocketBind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
      },
    );
  });

  test('stopping during a pending bind closes the resulting listener', () async {
    final port = (await freePorts(1)).single;
    final bindStarted = Completer<void>();
    final releaseBind = Completer<void>();
    final nativeIO = NativeIO();
    await IOOverrides.runZoned(
      () async {
        final start = service.startServer(port);
        await bindStarted.future;
        final stop = service.stopServer();
        releaseBind.complete();
        await Future.wait([start, stop]);
        expect(service.server, isNull);
        expect(await isListening(port), isFalse);
      },
      serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) async {
        bindStarted.complete();
        await releaseBind.future;
        return nativeIO.serverSocketBind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
      },
    );
  });

  test('a failed port is reported and retrying the same setting recovers', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);
    final settings = ApplicationStateProvider();
    addTearDown(settings.dispose);

    await settings.changeCommunicationPort(blocker.port);
    expect(service.server, isNull);
    expect(service.failedPort.value, blocker.port);

    final port = blocker.port;
    await blocker.close();
    await settings.changeCommunicationPort(port);
    expect(service.failedPort.value, isNull);
    expect(service.server!.port, port);
    expect(await isListening(port), isTrue);
  });

  test('a rejected start does not block the next queued start', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);
    final nextPort = (await freePorts(1)).single;
    final rejected = service.startServer(blocker.port);
    final rejection = expectLater(rejected, throwsA(isA<SocketException>()));
    // Let the first bind begin; a start superseded while still queued is skipped.
    await Future<void>.value();
    final next = service.startServer(nextPort);
    await Future.wait([rejection, next]);
    expect(service.failedPort.value, isNull);
    expect(service.server!.port, nextPort);
  });

  test('ping, version and error responses still complete after a restart', () async {
    final ports = await freePorts(2);
    await service.startServer(ports[0]);
    await service.startServer(ports[1]);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final base = 'http://127.0.0.1:${ports[1]}';

    final identity = await (await client.getUrl(Uri.parse('$base/questpdf-companion'))).close();
    expect(identity.statusCode, HttpStatus.ok);
    expect(await utf8.decoder.bind(identity).join(), 'QuestPDF Companion');
    final ping = await (await client.getUrl(Uri.parse('$base/ping'))).close();
    expect(ping.statusCode, HttpStatus.ok);
    await ping.drain<void>();
    final version = await (await client.getUrl(Uri.parse('$base/version'))).close();
    expect(version.statusCode, HttpStatus.ok);
    expect(jsonDecode(await utf8.decoder.bind(version).join()), {
      'supportedVersions': [2, 3, 4],
    });
    final missing = await (await client.getUrl(Uri.parse('$base/missing'))).close();
    expect(missing.statusCode, HttpStatus.notFound);
    await missing.drain<void>();
    final malformedRequest = await client.postUrl(Uri.parse('$base/v3/documentPreview/update'));
    malformedRequest.write('{');
    final malformed = await malformedRequest.close();
    expect(malformed.statusCode, HttpStatus.badRequest);
    await malformed.drain<void>();
    expect(await isListening(ports[0]), isFalse);
  });

  test('only one application holds the preview session', () async {
    final port = (await freePorts(1)).single;
    await service.startServer(port);

    // libraries using API versions 2 and 3 send no client id
    expect(await notify(port, apiVersion: 3), HttpStatus.ok);

    expect(await notify(port, clientId: 'invoice-1', codeLocationId: '%2Fapps%2Finvoice%2F'), HttpStatus.ok);
    expect(await notify(port, clientId: 'report-1', codeLocationId: '%2Fapps%2Freport%2F'), HttpStatus.conflict);
    expect(await notify(port, apiVersion: 3), HttpStatus.conflict);
    expect(await notify(port, clientId: 'invoice-1', codeLocationId: '%2Fapps%2Finvoice%2F'), HttpStatus.ok);

    // discovery requests carry no client id, and are answered regardless of the session
    for (final path in ['questpdf-companion', 'ping', 'version']) {
      final response = await (await HttpClient().getUrl(Uri.parse('http://127.0.0.1:$port/$path'))).close();
      expect(response.statusCode, HttpStatus.ok);
      await response.drain<void>();
    }
  });

  test('a new run of the same application takes over the preview session', () async {
    final port = (await freePorts(1)).single;
    await service.startServer(port);

    expect(await notify(port, clientId: 'restart-1', codeLocationId: '%2Fapps%2Frestart%2F'), HttpStatus.ok);
    expect(await notify(port, clientId: 'restart-2', codeLocationId: '%2Fapps%2Frestart%2F'), HttpStatus.ok);
    expect(await notify(port, clientId: 'restart-1', codeLocationId: '%2Fapps%2Frestart%2F'), HttpStatus.conflict);
    expect(await notify(port, clientId: 'restart-2', codeLocationId: '%2Fapps%2Frestart%2F'), HttpStatus.ok);
  });

  test('a silent client is rejected once the welcome screen is back', () async {
    final port = (await freePorts(1)).single;
    await service.startServer(port);

    expect(await notify(port, clientId: 'silent-1', codeLocationId: '%2Fapps%2Fsilent%2F'), HttpStatus.ok);
    expect(await notify(port, clientId: 'other-0', codeLocationId: '%2Fapps%2Fother%2F'), HttpStatus.conflict);
    applicationStateProviderInstance.changeMode(ApplicationMode.documentPreview);

    // the real inactivity timeout: five seconds, checked every second
    final welcomeScreenIsBack = Completer<void>();
    void onModeChanged() {
      if (applicationStateProviderInstance.currentMode != ApplicationMode.welcomeScreen) return;
      if (!welcomeScreenIsBack.isCompleted) welcomeScreenIsBack.complete();
    }

    applicationStateProviderInstance.addListener(onModeChanged);
    addTearDown(() => applicationStateProviderInstance.removeListener(onModeChanged));
    await welcomeScreenIsBack.future.timeout(const Duration(seconds: 10));

    expect(await notify(port, clientId: 'silent-1', codeLocationId: '%2Fapps%2Fsilent%2F'), HttpStatus.conflict);
    expect(await notify(port, clientId: 'other-0', codeLocationId: '%2Fapps%2Fother%2F'), HttpStatus.conflict);
    expect(await notify(port, clientId: 'other-1', codeLocationId: '%2Fapps%2Fother%2F'), HttpStatus.ok);
  });

  test('bind failures retry every five seconds and recover without clearing the error between attempts', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);
    final port = blocker.port;
    final nativeIO = NativeIO();
    final failedAgain = Completer<void>();
    final recovered = Completer<void>();
    var attempts = 0;
    final errors = <int?>[];
    void onFailureChanged() {
      errors.add(service.failedPort.value);
      if (service.failedPort.value == null && service.server?.port == port) recovered.complete();
    }

    service.failedPort.addListener(onFailureChanged);
    addTearDown(() => service.failedPort.removeListener(onFailureChanged));

    await withBindRetryTimers((timers) async {
      await IOOverrides.runZoned(
        () async {
          await service.tryToStartTheServer(port);
          expect(attempts, 1);
          expect(timers.single.delay, const Duration(seconds: 5));
          expect(errors, [port]);

          timers.single.fire();
          await failedAgain.future;
          await Future<void>.delayed(Duration.zero);
          expect(attempts, 2);
          expect(timers, hasLength(2));
          expect(timers.last.isActive, isTrue);
          expect(errors, [port]);

          await blocker.close();
          timers.last.fire();
          await recovered.future;
          expect(attempts, 3);
          expect(service.server!.port, port);
          expect(errors, [port, null]);
          expect(timers.where((timer) => timer.isActive), isEmpty);
        },
        serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) async {
          attempts++;
          try {
            return await nativeIO.serverSocketBind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
          } catch (e) {
            if (attempts == 2) failedAgain.complete();
            rethrow;
          }
        },
      );
    });
  });

  test('stopping cancels pending automatic recovery', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);
    final port = blocker.port;
    await withBindRetryTimers((timers) async {
      await service.tryToStartTheServer(port);
      final retry = timers.single;
      await service.stopServer();
      expect(retry.isActive, isFalse);
      await blocker.close();
      retry.fire();
      await Future<void>.delayed(Duration.zero);
      expect(service.server, isNull);
      expect(service.failedPort.value, isNull);
      expect(await isListening(port), isFalse);
    });
  });

  test('changing ports cancels automatic retries of the previous port', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);
    final previousPort = blocker.port;
    final nextPort = (await freePorts(1)).single;
    await withBindRetryTimers((timers) async {
      await service.tryToStartTheServer(previousPort);
      final retry = timers.single;
      await service.startServer(nextPort);
      expect(retry.isActive, isFalse);
      await blocker.close();
      retry.fire();
      await Future<void>.delayed(Duration.zero);
      expect(service.server!.port, nextPort);
      expect(service.failedPort.value, isNull);
      expect(await isListening(previousPort), isFalse);
    });
  });

  for (final stop in [true, false]) {
    test('an already queued retry cannot override a newer ${stop ? 'stop' : 'port change'}', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(blocker.close);
      final previousPort = blocker.port;
      final nextPort = (await freePorts(1)).single;
      final nativeIO = NativeIO();
      var oldPortAttempts = 0;
      await withBindRetryTimers((timers) async {
        await IOOverrides.runZoned(
          () async {
            await service.tryToStartTheServer(previousPort);
            timers.single.fire();
            // Invalidate the retry after it is queued but before it can bind.
            await (stop ? service.stopServer() : service.startServer(nextPort));
            expect(oldPortAttempts, 1);
            expect(service.server?.port, stop ? null : nextPort);
            expect(service.failedPort.value, isNull);
            expect(timers.where((timer) => timer.isActive), isEmpty);
          },
          serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) {
            if (port == previousPort) oldPortAttempts++;
            return nativeIO.serverSocketBind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
          },
        );
      });
    });
  }

  test('a retry already binding cannot replace a newer port', () async {
    final ports = await freePorts(2);
    final nativeIO = NativeIO();
    final retryStarted = Completer<void>();
    final releaseRetry = Completer<void>();
    var firstPortAttempts = 0;
    await withBindRetryTimers((timers) async {
      await IOOverrides.runZoned(
        () async {
          await service.tryToStartTheServer(ports[0]);
          timers.single.fire();
          await retryStarted.future;
          final change = service.startServer(ports[1]);
          releaseRetry.complete();
          await change;
          expect(service.server!.port, ports[1]);
          expect(await isListening(ports[0]), isFalse);
          expect(service.failedPort.value, isNull);
          expect(timers.where((timer) => timer.isActive), isEmpty);
        },
        serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) async {
          if (port == ports[0]) {
            firstPortAttempts++;
            if (firstPortAttempts == 1) throw const SocketException('Initial bind failed');
            retryStarted.complete();
            await releaseRetry.future;
          }
          return nativeIO.serverSocketBind(address, port, backlog: backlog, v6Only: v6Only, shared: shared);
        },
      );
    });
  });

  test('a late bind failure after stopping does not schedule a retry', () async {
    final port = (await freePorts(1)).single;
    final bindStarted = Completer<void>();
    final failBind = Completer<void>();
    await withBindRetryTimers((timers) async {
      await IOOverrides.runZoned(
        () async {
          final start = service.tryToStartTheServer(port);
          await bindStarted.future;
          final stop = service.stopServer();
          failBind.complete();
          await Future.wait([start, stop]);
          expect(service.server, isNull);
          expect(service.failedPort.value, isNull);
          expect(timers, isEmpty);
        },
        serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) async {
          bindStarted.complete();
          await failBind.future;
          throw const SocketException('Delayed bind failure');
        },
      );
    });
  });
}
