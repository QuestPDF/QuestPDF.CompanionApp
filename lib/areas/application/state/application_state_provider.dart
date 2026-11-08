import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:questpdf_companion/communication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final applicationStateProviderInstance = ApplicationStateProvider();
final applicationStateProvider = ChangeNotifierProvider((ref) => applicationStateProviderInstance);

enum ApplicationMode { welcomeScreen, documentPreview, genericException }

enum CodeEditor { rider, visualCode, visualStudio }

enum LicenseType { evaluation, community, professional, enterprise }

class ApplicationStateProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  ThemeMode themeMode = ThemeMode.system;
  ApplicationMode currentMode = ApplicationMode.welcomeScreen;
  CodeEditor defaultCodeEditor = CodeEditor.visualCode;
  bool showDocumentHierarchy = true;
  int communicationPort = communicationServiceDefaultPort;
  LicenseType? currentLicense;
  bool isDocumentHotReloaded = false;

  Future loadDefaultSettings({int? communicationPortOverride}) async {
    _prefs ??= await SharedPreferences.getInstance();

    themeMode = ThemeMode.values[_prefs!.getInt('themeMode') ?? 0];
    defaultCodeEditor = CodeEditor.values[_prefs!.getInt('defaultCodeEditor') ?? 0];
    showDocumentHierarchy = _prefs!.getBool('showDocumentHierarchy') ?? true;

    communicationPort =
        communicationPortOverride ?? _prefs!.getInt('communicationPort') ?? communicationServiceDefaultPort;

    notifyListeners();
  }

  void setCurrentLicense(LicenseType? license) {
    if (currentLicense == license) return;

    currentLicense = license;
    notifyListeners();
  }

  void changeThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs?.setInt('themeMode', themeMode.index);
    notifyListeners();
  }

  void changeDefaultCodeEditor(CodeEditor editor) {
    defaultCodeEditor = editor;
    _prefs?.setInt('defaultCodeEditor', defaultCodeEditor.index);
    notifyListeners();
  }

  void toggleDocumentHierarchyVisibility() {
    showDocumentHierarchy = !showDocumentHierarchy;
    _prefs?.setBool('showDocumentHierarchy', showDocumentHierarchy);
    notifyListeners();
  }

  static int sanitizePortNumber(String portText) {
    final port = int.tryParse(portText);

    if (port == null || port < communicationServiceMinPort || port > communicationServiceMaxPort) {
      return communicationServiceDefaultPort;
    }

    return port;
  }

  Future<void> changeCommunicationPort(int newPort) async {
    if (communicationPort == newPort && communicationServiceInstance.failedPort.value == null) return;

    communicationPort = newPort;
    _prefs?.setInt('communicationPort', communicationPort);

    await communicationServiceInstance.tryToStartTheServer(newPort);

    notifyListeners();
  }

  void changeMode(ApplicationMode mode) {
    currentMode = mode;
    notifyListeners();
  }

  void setDocumentAsHotReloaded(bool hotReloaded) {
    isDocumentHotReloaded = hotReloaded;
    notifyListeners();
  }
}
