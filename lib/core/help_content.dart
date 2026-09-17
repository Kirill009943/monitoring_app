class HelpEntry {
  final String title;
  final String body;
  const HelpEntry(this.title, this.body);
}

class HelpContent {
  static const Map<String, List<HelpEntry>> pages = {
    'dashboard': [
      HelpEntry('Monitoring switch',
          'Starts or stops the background service that records your selected sensors, battery and app usage. While on, a small persistent notification is shown (required by Android).'),
      HelpEntry('Sensor cards',
          'Each card shows the latest reading of one sensor you picked on the Sensors tab. Values refresh automatically every few seconds while this screen is open.'),
      HelpEntry('Battery card',
          'Shows charge level, battery temperature and charging state. Tap it to open the full battery page with history graphs.'),
      HelpEntry('Top apps today',
          'The apps you track, with how long they were in the foreground today. Manage the list on the Apps tab.'),
      HelpEntry('No data yet?',
          'Graphs fill in while monitoring runs. If you just started, come back in a few minutes.'),
    ],
    'sensors': [
      HelpEntry('Sensor list',
          'All thermal zones found on your phone (CPU clusters, GPU, battery, modem, etc.). Names come from the phone itself and vary by model.'),
      HelpEntry('Monitor toggle',
          'Only sensors you switch on are recorded in the background and shown on the dashboard. Fewer sensors = less battery.'),
      HelpEntry('Temperature limit',
          'Tap a sensor to set an alert temperature. When the sensor reaches it (while monitored), you get a notification. Alerts repeat at most every 10 minutes and only after the temperature dropped 3 °C below the limit again.'),
      HelpEntry('"battery" sensor',
          'This pseudo-sensor reads the battery temperature from Android itself and works on every phone.'),
      HelpEntry('Unreadable sensors',
          'Some phones (Android 10+) block apps from reading raw sensor files. Those sensors show as unavailable — this is a system restriction, not a bug.'),
      HelpEntry('Thermal status',
          'Android\'s overall heat level (none → severe) when the system provides it (Android 10+).'),
    ],
    'battery': [
      HelpEntry('Current status',
          'Live charge level, temperature, voltage, charging current (if the phone reports it) and whether the phone is charging, discharging or full.'),
      HelpEntry('History graph',
          'Recorded while monitoring is on. Switch between level, temperature, voltage and current, and pick 24 h / 7 d / 30 d ranges.'),
      HelpEntry('Charging current',
          'Negative values usually mean discharging. Many phones report 0 while idle — that is normal.'),
    ],
    'apps': [
      HelpEntry('Usage access',
          'Android requires a special permission to see which apps you use. Tap the banner to open system settings and allow "Usage access" for Phone Monitor. Nothing leaves your phone.'),
      HelpEntry('Track toggle',
          'Tracked apps are recorded in the background and appear in stats and on the dashboard.'),
      HelpEntry('Daily limit',
          'Tap an app to set a daily limit in minutes. When the app passes the limit today, you get one notification. Set the limit to 0 to track time without alerts.'),
      HelpEntry('Today column',
          'Foreground time so far today, straight from Android usage stats.'),
    ],
    'stats': [
      HelpEntry('Metric picker',
          'Choose what to graph: any monitored sensor, battery level/temperature/voltage/current, or daily usage of a tracked app.'),
      HelpEntry('Range',
          '24 h shows raw samples. 7 d and 30 d are automatically averaged into hourly/daily buckets so graphs stay fast.'),
      HelpEntry('Min / Avg / Max',
          'Summary of the visible range.'),
      HelpEntry('Customize',
          'Per-metric graph options: line or bar chart, color, grid, and fixed Y range. Saved automatically for each metric.'),
      HelpEntry('Where is my data?',
          'Only time while monitoring was on is recorded. Older data is deleted automatically after the retention period you set in Settings.'),
    ],
    'settings': [
      HelpEntry('Theme',
          'Five built-in themes. AMOLED black saves a bit of power on OLED screens.'),
      HelpEntry('Units',
          'Temperatures in °C or °F, applied everywhere including graphs and notifications.'),
      HelpEntry('Poll interval',
          'How often the background service reads sensors. Shorter = smoother graphs but more battery. 60 s is a good default; 15 s minimum.'),
      HelpEntry('Data retention',
          'Samples older than this are permanently deleted, keeping the app tiny and fast.'),
      HelpEntry('Notification style',
          'Separately for temperature and app-time alerts: enable/disable, sound, vibration and importance (how intrusive Android makes them). Use "Send test" to preview.'),
      HelpEntry('Battery optimization',
          'Exempting the app stops Android from killing the background service. Recommended if monitoring stops by itself. On Xiaomi/MIUI also open "System app settings", enable Autostart and set Battery saver to "No restrictions".'),
      HelpEntry('Everything stays local',
          'No account, no internet permission, no analytics. Your data never leaves the phone.'),
    ],
    'onboarding': [
      HelpEntry('Why permissions?',
          'Notifications let alerts reach you. Usage access lets the app measure app screen time. Battery-optimization exemption keeps background recording alive.'),
      HelpEntry('All optional',
          'You can skip any step — features that need a permission will simply wait until you grant it later in Settings.'),
    ],
  };
}
