import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: settingsService

    property bool settingsLoaded: false
    property string packageManagerMode: "install"
    property string aurHelper: "yay"
    property int clipboardMaxItems: 100
    property var enabledKbLayouts: ["us", "latam"]
    property string musicPlayer: "none"
    property string musicPlayerCommand: ""
    property var availableBrowsers: []
    property string launcherBrowser: ""
    property bool isSettingsLoading: settingsLoader.running
    property string quoteCategory: "All"
    property string fontFamily: "Geist"
    property real fontScale: 1
    // The terminal font is a setting of its own, because a terminal needs a
    // monospace font while the system font does not have to be one.
    property string kittyFontFamily: "JetbrainsMono NF"
    property bool clock24h: true
    property bool clockSeconds: false
    property bool clockShowDate: true
    property string cursorTheme: "Bibata-Modern-Classic"
    property int cursorSize: Constants.size2Xl
    // The bar style is fixed to Convex: no selector, no Island mode.
    property string barStyle: "convex"
    property bool barConvexMode: true
    readonly property int barWidgetHeight: 28
    property int numberOfWorkspaces: 10
    // Workspace indicator style: "dots" (minimal) or "numbers" (mini
    // capsules with the workspace number).
    property string workspaceDisplayMode: "dots"
    property string deviceBatteryPosition: "left"
    property string deviceBatteryDisplayMode: "auto"
    property bool deviceBatteryUseBatteryHub: true
    // Folder scanned by the wallpaper selector / shuffle. Changed from the
    // wallpaper settings page; absolute paths are preferred, "~" is expanded
    // by resolveWallpaperFolder() before it reaches any command.
    property string wallpaperFolder: Quickshell.env("HOME") + "/.local/share/wallpapers"

    function resolveWallpaperFolder() {
        let folder = wallpaperFolder;
        if (folder === "~" || folder.startsWith("~/"))
            folder = Quickshell.env("HOME") + folder.substring(1);
        if (folder === "")
            folder = Quickshell.env("HOME") + "/.local/share/wallpapers";
        return folder;
    }

    function saveSettings() {
        saveTimer.restart();
    }

    function load() {
        if (!settingsLoaded && !isSettingsLoading)
            settingsLoader.running = true;

    }

    function applyCursor(theme, size) {
        let t = theme !== undefined ? theme : cursorTheme;
        let s = size !== undefined ? size : cursorSize;
        applyCursorProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_cursor.py", t, s.toString()];
        applyCursorProc.running = false;
        applyCursorProc.running = true;
    }

    function applyFont(font, size) {
        let f = font !== undefined ? font : fontFamily;
        let s = size !== undefined ? size : Math.round(11 * fontScale);
        applyFontProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_font.py", f, s.toString()];
        applyFontProc.running = false;
        applyFontProc.running = true;
    }

    // The terminal font is a setting of its own, so it is applied on its own
    // instead of together with the global font.
    function applyKittyFont(family) {
        let f = family !== undefined ? family : kittyFontFamily;
        applyKittyFontProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_font.py", "--kitty", f];
        applyKittyFontProc.running = false;
        applyKittyFontProc.running = true;
    }

    // Drops a saved browser that is no longer installed, falling back to the
    // system default instead of opening a stale command.
    function syncLauncherBrowser() {
        if (!launcherBrowser)
            return ;

        let list = availableBrowsers || [];
        if (list.length === 0)
            return ;

        for (let i = 0; i < list.length; i++) {
            if (list[i].id === launcherBrowser)
                return ;

        }
        launcherBrowser = "";
    }

    Component.onCompleted: {
        load();
        browsersProc.running = true;
        aurHelperProc.running = true;
    }
    onClipboardMaxItemsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onEnabledKbLayoutsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onMusicPlayerChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onMusicPlayerCommandChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onLauncherBrowserChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onQuoteCategoryChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onFontFamilyChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyFont(fontFamily, Math.round(11 * fontScale));
        }
    }
    onFontScaleChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyFont(fontFamily, Math.round(11 * fontScale));
        }
    }
    onKittyFontFamilyChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClock24hChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClockSecondsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClockShowDateChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onCursorThemeChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyCursor(cursorTheme, cursorSize);
        }
    }
    onCursorSizeChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyCursor(cursorTheme, cursorSize);
        }
    }
    onBarStyleChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onNumberOfWorkspacesChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onWorkspaceDisplayModeChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onDeviceBatteryPositionChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDeviceBatteryDisplayModeChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onDeviceBatteryUseBatteryHubChanged: {
        if (settingsLoaded)
            saveSettings();
    }
    onWallpaperFolderChanged: {
        if (settingsLoaded)
            saveSettings();

    }

    // Wallpaper preferences live on HyprlandService and the UI writes them
    // there directly, so without this watcher they would never reach the
    // prefs file (and a stale value would come back after a restart).
    Connections {
        function onWpAutoShuffleChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpShuffleIntervalChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpEnableTransitionsChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpTransitionTypeChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpTransitionPosChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpTransitionStepChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpTransitionAngleChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpResizeModeChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        function onWpCropGravityChanged() {
            if (settingsLoaded)
                saveSettings();

        }

        target: HyprlandService
    }

    Timer {
        id: saveTimer

        interval: 500
        repeat: false
        onTriggered: {
            let data = {
                "performanceInterval": SystemInfoService.performanceInterval,
                "powerProfile": SystemInfoService.powerProfile,
                "packageManagerChecksEnabled": UpdateService.packageManagerChecksEnabled,
                "packageManagerCheckInterval": UpdateService.packageManagerCheckInterval,
                "clipboardMaxItems": settingsService.clipboardMaxItems,
                "enabledKbLayouts": settingsService.enabledKbLayouts,
                "animationSpeedFactor": HyprlandService.animationSpeedFactor,
                "musicPlayer": settingsService.musicPlayer,
                "musicPlayerCommand": settingsService.musicPlayerCommand,
                "launcherBrowser": settingsService.launcherBrowser,
                "nightLightActive": DisplayProfileService.nightLightActive,
                "caffeineActive": DisplayProfileService.caffeineActive,
                "gameModeActive": DisplayProfileService.gameModeActive,
                "nightLightTemperature": DisplayProfileService.nightLightTemperature,
                "keyboardLayout": CompositorService.keyboardLayout,
                "wpAutoShuffle": HyprlandService.wpAutoShuffle,
                "wpShuffleInterval": HyprlandService.wpShuffleInterval,
                "wpEnableTransitions": HyprlandService.wpEnableTransitions,
                "wpTransitionType": HyprlandService.wpTransitionType,
                "wpTransitionPos": HyprlandService.wpTransitionPos,
                "wpTransitionStep": HyprlandService.wpTransitionStep,
                "wpTransitionAngle": HyprlandService.wpTransitionAngle,
                "wpResizeMode": HyprlandService.wpResizeMode,
                "wpCropGravity": HyprlandService.wpCropGravity,
                "micMuted": AudioService.micMuted,
                "micVolume": AudioService.micVolume,
                "quoteCategory": settingsService.quoteCategory,
                "fontFamily": settingsService.fontFamily,
                "fontScale": settingsService.fontScale,
                "kittyFontFamily": settingsService.kittyFontFamily,
                "clock24h": settingsService.clock24h,
                "clockSeconds": settingsService.clockSeconds,
                "clockShowDate": settingsService.clockShowDate,
                "cursorTheme": settingsService.cursorTheme,
                "cursorSize": settingsService.cursorSize,
                "barStyle": settingsService.barStyle,
                "numberOfWorkspaces": settingsService.numberOfWorkspaces,
                "workspaceDisplayMode": settingsService.workspaceDisplayMode,
                "deviceBatteryPosition": settingsService.deviceBatteryPosition,
                "deviceBatteryDisplayMode": settingsService.deviceBatteryDisplayMode,
                "deviceBatteryUseBatteryHub": settingsService.deviceBatteryUseBatteryHub
            };
            // SDDM only reads fontFamily from its preferences file, so credentials
            // are never written to /var/tmp (it is world readable and persists
            // across reboots).
            let sddmData = {
                "fontFamily": settingsService.fontFamily
            };
            settingsSaver.running = false;
            // Preferences are created with a restrictive umask so they are
            // never readable by another user, not even for an instant.
            settingsSaver.command = ["sh", "-c", "umask 077 && mkdir -p ~/.cache/quickshell && cat << 'EOF' > ~/.cache/quickshell/settings_prefs.json.tmp
" + JSON.stringify(data) + "
EOF
mv -f ~/.cache/quickshell/settings_prefs.json.tmp ~/.cache/quickshell/settings_prefs.json
chmod 600 ~/.cache/quickshell/settings_prefs.json
if ! grep -qxF sddm \"$HOME/.config/mewline/preferences.conf\" 2>/dev/null; then
  umask 022 && mkdir -p /var/tmp/sddm-theme
  cat << 'EOF' > /var/tmp/sddm-theme/settings_prefs.json.tmp
" + JSON.stringify(sddmData) + "
EOF
  mv -f /var/tmp/sddm-theme/settings_prefs.json.tmp /var/tmp/sddm-theme/settings_prefs.json
  chmod 644 /var/tmp/sddm-theme/settings_prefs.json || true
fi"];
            settingsSaver.running = true;
        }
    }

    Process {
        id: settingsLoader

        command: ["cat", Quickshell.env("HOME") + "/.cache/quickshell/settings_prefs.json"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                let raw = settingsOutput.text ? settingsOutput.text.trim() : "";
                if (raw.length > 0) {
                    try {
                        let prefs = JSON.parse(raw);
                        if (prefs.powerProfile !== undefined) {
                            SystemInfoService.powerProfile = prefs.powerProfile;
                            SystemInfoService.applyProfile(prefs.powerProfile);
                        } else {
                            SystemInfoService.applyProfile("balanced");
                        }
                        if (prefs.performanceInterval !== undefined)
                            SystemInfoService.performanceInterval = prefs.performanceInterval;

                        if (prefs.packageManagerChecksEnabled !== undefined)
                            UpdateService.packageManagerChecksEnabled = prefs.packageManagerChecksEnabled;

                        if (prefs.packageManagerCheckInterval !== undefined)
                            UpdateService.packageManagerCheckInterval = prefs.packageManagerCheckInterval;

                        if (prefs.clipboardMaxItems !== undefined)
                            settingsService.clipboardMaxItems = prefs.clipboardMaxItems;

                        if (prefs.animationSpeedFactor !== undefined)
                            HyprlandService.animationSpeedFactor = prefs.animationSpeedFactor;

                        if (prefs.musicPlayer !== undefined)
                            settingsService.musicPlayer = prefs.musicPlayer;

                        if (prefs.musicPlayerCommand !== undefined)
                            settingsService.musicPlayerCommand = prefs.musicPlayerCommand;

                        if (prefs.launcherBrowser !== undefined)
                            settingsService.launcherBrowser = prefs.launcherBrowser;

                        if (prefs.nightLightActive !== undefined)
                            DisplayProfileService.nightLightActive = prefs.nightLightActive;

                        if (prefs.caffeineActive !== undefined)
                            DisplayProfileService.caffeineActive = prefs.caffeineActive;

                        if (prefs.gameModeActive !== undefined)
                            DisplayProfileService.gameModeActive = prefs.gameModeActive;

                        if (prefs.nightLightTemperature !== undefined)
                            DisplayProfileService.nightLightTemperature = prefs.nightLightTemperature;

                        // keyboardLayout is not restored: the compositor
                        // backend reports the real active layout within a
                        // second of startup.
                        if (prefs.enabledKbLayouts !== undefined)
                            settingsService.enabledKbLayouts = prefs.enabledKbLayouts;

                        if (prefs.wpAutoShuffle !== undefined)
                            HyprlandService.wpAutoShuffle = prefs.wpAutoShuffle;

                        if (prefs.wpShuffleInterval !== undefined)
                            HyprlandService.wpShuffleInterval = prefs.wpShuffleInterval;

                        if (prefs.wpEnableTransitions !== undefined)
                            HyprlandService.wpEnableTransitions = prefs.wpEnableTransitions;

                        if (prefs.wpTransitionType !== undefined)
                            HyprlandService.wpTransitionType = prefs.wpTransitionType;

                        if (prefs.wpTransitionPos !== undefined)
                            HyprlandService.wpTransitionPos = prefs.wpTransitionPos;

                        if (prefs.wpTransitionStep !== undefined)
                            HyprlandService.wpTransitionStep = prefs.wpTransitionStep;

                        if (prefs.wpTransitionAngle !== undefined)
                            HyprlandService.wpTransitionAngle = prefs.wpTransitionAngle;

                        if (prefs.wpResizeMode !== undefined)
                            HyprlandService.wpResizeMode = prefs.wpResizeMode;

                        if (prefs.wpCropGravity !== undefined)
                            HyprlandService.wpCropGravity = prefs.wpCropGravity;

                        // The microphone can appear after the settings were
                        // read, so the values are handed over and applied
                        // as soon as the device exists.
                        if (prefs.micVolume !== undefined || prefs.micMuted !== undefined)
                            AudioService.restoreMic(prefs.micVolume, prefs.micMuted);

                        if (prefs.quoteCategory !== undefined)
                            settingsService.quoteCategory = prefs.quoteCategory;

                        if (prefs.fontFamily !== undefined)
                            settingsService.fontFamily = prefs.fontFamily;

                        if (prefs.fontScale !== undefined)
                            settingsService.fontScale = prefs.fontScale;

                        if (prefs.kittyFontFamily !== undefined)
                            settingsService.kittyFontFamily = prefs.kittyFontFamily;

                        if (prefs.clock24h !== undefined)
                            settingsService.clock24h = prefs.clock24h;

                        if (prefs.clockSeconds !== undefined)
                            settingsService.clockSeconds = prefs.clockSeconds;

                        if (prefs.clockShowDate !== undefined)
                            settingsService.clockShowDate = prefs.clockShowDate;

                        if (prefs.cursorTheme !== undefined)
                            settingsService.cursorTheme = prefs.cursorTheme;

                        if (prefs.cursorSize !== undefined)
                            settingsService.cursorSize = prefs.cursorSize;

                        // Cursor and fonts are only pushed to the system when
                        // the user changes them in the settings UI, never at
                        // startup: this shell must not rewrite system config.
                        // barStyle is fixed to Convex, so a saved value is
                        // ignored on purpose.
                        if (prefs.numberOfWorkspaces !== undefined)
                            settingsService.numberOfWorkspaces = prefs.numberOfWorkspaces;
                        if (["dots", "numbers"].indexOf(prefs.workspaceDisplayMode) !== -1)
                            settingsService.workspaceDisplayMode = prefs.workspaceDisplayMode;
                        if (["left", "right", "off"].indexOf(prefs.deviceBatteryPosition) !== -1)
                            settingsService.deviceBatteryPosition = prefs.deviceBatteryPosition;
                        if (["auto", "percent", "bar"].indexOf(prefs.deviceBatteryDisplayMode) !== -1)
                            settingsService.deviceBatteryDisplayMode = prefs.deviceBatteryDisplayMode;
                        if (typeof prefs.deviceBatteryUseBatteryHub === "boolean")
                            settingsService.deviceBatteryUseBatteryHub = prefs.deviceBatteryUseBatteryHub;

                    } catch (e) {
                        console.error("Error loading settings: " + e);
                        SystemInfoService.applyProfile("balanced");
                    }
                } else {
                    SystemInfoService.applyProfile("balanced");
                    settingsService.saveSettings();
                }
            } else {
                SystemInfoService.applyProfile("balanced");
                settingsService.saveSettings();
            }
            settingsService.settingsLoaded = true;
            settingsService.syncLauncherBrowser();
            HyprlandService.triggerStartupTimer();
        }

        stdout: StdioCollector {
            id: settingsOutput
        }

    }

    Process {
        id: settingsSaver
    }

    Process {
        id: aurHelperProc

        command: ["python3", Quickshell.shellDir + "/Scripts/aur_helper.py"]

        stdout: SplitParser {
            onRead: data => {
                let value = data.trim();
                if (value === "yay" || value === "paru")
                    settingsService.aurHelper = value;

            }
        }

    }

    Process {
        id: browsersProc

        command: ["python3", Quickshell.shellDir + "/Modules/Launcher/scripts/get_browsers.py"]
        onExited: function(exitCode) {
            if (exitCode !== 0)
                return ;

            try {
                let parsed = JSON.parse(browsersOutput.text ? browsersOutput.text.trim() : "[]");
                if (Array.isArray(parsed)) {
                    settingsService.availableBrowsers = parsed;
                    settingsService.syncLauncherBrowser();
                }
            } catch (e) {
                console.error("Error parsing browsers JSON: " + e);
            }
        }

        stdout: StdioCollector {
            id: browsersOutput
        }

    }

    Process {
        id: applyCursorProc
    }

    Process {
        id: applyFontProc
    }

    Process {
        id: applyKittyFontProc
    }

}
