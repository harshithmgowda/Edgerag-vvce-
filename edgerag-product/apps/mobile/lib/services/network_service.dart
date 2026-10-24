import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  String _hqBaseUrl = 'http://192.168.137.1:8000/api/v1';
  NetworkState _currentState = NetworkState.offlineAirgap;
  final _stateController = StreamController<NetworkState>.broadcast();

  Stream<NetworkState> get stateStream => _stateController.stream;
  NetworkState get currentState => _currentState;
  String get hqBaseUrl => _hqBaseUrl;

  /// Derived Headquarters Web Portal URL (typically port 3000 on the same host)
  String get hqWebUrl {
    try {
      final uri = Uri.parse(_hqBaseUrl);
      final port = (uri.port == 8000 || uri.port == 0) ? 3000 : (uri.port == 443 ? 443 : 3000);
      return '${uri.scheme}://${uri.host}:$port';
    } catch (_) {
      return 'http://192.168.137.1:3000';
    }
  }

  /// Extracted hostname or IP of the current HQ connection
  String get hqHost {
    try {
      return Uri.parse(_hqBaseUrl).host;
    } catch (_) {
      return '192.168.137.1';
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('hq_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _hqBaseUrl = savedUrl;
    }
    await checkConnectivity();

    // Periodic network sentinel probe every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (_) => checkConnectivity());
  }

  Future<void> updateHqUrl(String newUrl) async {
    _hqBaseUrl = newUrl.endsWith('/') ? newUrl.substring(0, newUrl.length - 1) : newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hq_base_url', _hqBaseUrl);
    await checkConnectivity();
  }

  /// Test whether the Next.js Headquarters Web Portal (port 3000) is reachable over Hotspot/LAN
  Future<bool> probeWebPortal() async {
    try {
      final res = await http.get(Uri.parse(hqWebUrl)).timeout(const Duration(milliseconds: 2500));
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Dynamically discover active gateway candidates from local network interfaces + known hotspot IP presets
  Future<List<String>> getDiscoveryCandidates() async {
    final candidates = <String>{
      'http://192.168.137.1:8000/api/v1', // Windows Mobile Hotspot default
      'http://192.168.43.1:8000/api/v1',  // Android Wi-Fi Hotspot default
      'http://172.20.10.1:8000/api/v1',   // iOS Personal Hotspot default
      'http://192.168.1.85:8000/api/v1',  // Wi-Fi LAN preset
      'http://10.34.205.224:8000/api/v1', // Depot Office LAN preset
      'http://10.0.2.2:8000/api/v1',      // Android Emulator host loopback
      'http://127.0.0.1:8000/api/v1',     // Localhost
    };

    // Inspect local device interfaces to detect current subnet gateway
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.')) continue;
          final parts = ip.split('.');
          if (parts.length == 4) {
            // Probe .1 (standard default gateway on this subnet)
            candidates.add('http://${parts[0]}.${parts[1]}.${parts[2]}.1:8000/api/v1');
          }
        }
      }
    } catch (_) {}

    return candidates.toList();
  }

  /// Automatically probe all candidate hotspot & LAN endpoints and adopt the first responding server
  Future<String?> autoDiscoverHotspotGateway() async {
    final candidates = await getDiscoveryCandidates();
    for (final candidate in candidates) {
      try {
        final probe = await http.get(Uri.parse('$candidate/health')).timeout(const Duration(milliseconds: 1200));
        if (probe.statusCode == 200) {
          await updateHqUrl(candidate);
          return candidate;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Probe both HQ LAN server and public internet independently
  Future<NetworkState> checkConnectivity() async {
    bool hqReachable = false;
    bool internetReachable = false;

    // 1. Probe HQ LAN endpoint (with fast auto-discovery fallback if active URL fails)
    try {
      final res = await http.get(Uri.parse('$_hqBaseUrl/health')).timeout(const Duration(milliseconds: 2000));
      if (res.statusCode == 200) {
        hqReachable = true;
      }
    } catch (_) {
      hqReachable = false;
      final candidates = await getDiscoveryCandidates();
      for (final candidate in candidates) {
        if (candidate == _hqBaseUrl) continue;
        try {
          final probe = await http.get(Uri.parse('$candidate/health')).timeout(const Duration(milliseconds: 1200));
          if (probe.statusCode == 200) {
            _hqBaseUrl = candidate;
            hqReachable = true;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('hq_base_url', _hqBaseUrl);
            break;
          }
        } catch (_) {}
      }
    }

    // 2. Probe public internet (DNS lookup to 8.8.8.8)
    try {
      final lookup = await InternetAddress.lookup('dns.google').timeout(const Duration(milliseconds: 2500));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        internetReachable = true;
      }
    } catch (_) {
      internetReachable = false;
    }

    // Determine state
    NetworkState newState;
    if (hqReachable && internetReachable) {
      newState = NetworkState.fullyConnected;
    } else if (hqReachable) {
      newState = NetworkState.hqLanHotspot;
    } else if (internetReachable) {
      newState = NetworkState.publicInternetOnly;
    } else {
      newState = NetworkState.offlineAirgap;
    }

    if (newState != _currentState) {
      _currentState = newState;
      _stateController.add(_currentState);
    }

    return _currentState;
  }
}
