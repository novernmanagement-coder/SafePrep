import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class MixpanelService {
  static final MixpanelService instance = MixpanelService._();
  MixpanelService._();

  Mixpanel? _mixpanel;

  static const String _token = 'f0e26131548137dd7fb8522bd6b88536';

  Future<void> init() async {
    _mixpanel = await Mixpanel.init(_token, trackAutomaticEvents: true);
  }

  void track(String event, {Map<String, dynamic>? properties}) {
    try {
      _mixpanel?.track(event, properties: properties);
    } catch (e) {
      // Silent fail — never crash the app over analytics
    }
  }

  void identify(String userId) {
    try {
      _mixpanel?.identify(userId);
    } catch (e) {}
  }

  void reset() {
    try {
      _mixpanel?.reset();
    } catch (e) {}
  }
}
