import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: hyprlandService

    // Read-mostly mirror of the compositor state the shell itself renders
    // against. The shell never writes Hyprland config: animations, shadows
    // etc. belong to the user's hyprland.lua / workflow presets.
    property bool enableAnimations: true
    property real animationSpeedFactor: 1
    property int hyprShadowRange: 8
    property int hyprShadowRenderPower: 3
    property bool hyprShadow: true
    property string keyboardLayout: "us"
    // The full XKB layout list of the main keyboard ("us,ru") — read from
    // hyprctl devices on every activelayout event.
    property string layoutList: ""
    readonly property var layoutCodes: layoutList !== "" ? layoutList.split(",") : []
    property bool wpAutoShuffle: false
    property int wpShuffleInterval: 10
    property bool wpEnableTransitions: true
    property string wpTransitionType: "grow"
    property string wpTransitionPos: "center"
    // Fast by default: 180 matches the "Fast" step of the wallpaper
    // transition selector.
    property int wpTransitionStep: 180
    property int wpTransitionAngle: 30
    property string wpResizeMode: "crop"
    property string wpCropGravity: "center"
    property bool hyprPrefsLoaded: false
    property bool isSyncing: false
    property bool isTrueFullscreen: false

    function reloadHyprPrefs() {
        // Only meaningful on Hyprland: niri/bspwm keep the defaults below.
        if (CompositorService.wm !== "hyprland")
            return ;

        if (!readHyprPrefsProc.running)
            readHyprPrefsProc.running = true;

    }

    function checkFullscreen() {
        if (CompositorService.wm !== "hyprland")
            return ;

        if (checkFullscreenProc.running)
            checkFullscreenProc.running = false;

        checkFullscreenProc.running = true;
    }

    function setPowerSaverMode(enabled) {
        // Intentionally empty: power profiles activate meowrch workflow
        // presets (workflows/{default,powersaver,gaming}.lua) from
        // SystemInfoService.applyProfile — the shell never writes or evals
        // decoration/animation config itself.
    }

    function triggerStartupTimer() {
        // Intentionally does nothing: the startup layout/animation push was
        // removed because Hyprland input config belongs to hyprland.lua.
    }

    Process {
        id: checkFullscreenProc

        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null | jq -r '(.fullscreen == 2) // false' 2>/dev/null"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                hyprlandService.isTrueFullscreen = (data.trim() === "true");
            }
        }

    }

    Timer {
        id: reapplyGameModeTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (DisplayProfileService.gameModeActive)
                DisplayProfileService.applyGameMode(true);

        }
    }

    Connections {
        function onRawEvent(event) {
            if (CompositorService.wm !== "hyprland")
                return ;

            if (event.name === "activelayout") {
                activeLayoutProc.running = true;
            } else if (event.name === "fullscreen") {
                if (event.data === "0")
                    hyprlandService.isTrueFullscreen = false;
                else
                    hyprlandService.checkFullscreen();
            } else if (event.name === "activewindow" || event.name === "activewindowv2" || event.name === "workspace" || event.name === "workspacev2") {
                hyprlandService.checkFullscreen();
            } else if (event.name === "configreloaded") {
                if (DisplayProfileService.gameModeActive)
                    reapplyGameModeTimer.restart();
                else
                    hyprlandService.reloadHyprPrefs();
            }
        }

        target: Hyprland
    }

    Process {
        id: activeLayoutProc

        // Emits: active xkb code | keymap display name | full layout list |
        // active layout index (all from the main keyboard in one read).
        command: ["sh", "-c", "hyprctl devices -j | jq -r '(.keyboards | (map(select(.main == true))[0] // .[0])) | (((.layout // \"\") | split(\",\"))[(.active_layout_index // 0)] // \"\") + \"|\" + (.active_keymap // \"\") + \"|\" + (.layout // \"\") + \"|\" + ((.active_layout_index // 0) | tostring)'"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                let parts = data.trim().split("|");
                let xkbCode = parts[0] ? parts[0].trim() : "";
                let raw = parts[1] ? parts[1].trim() : "";
                if (parts[2] !== undefined && parts[2].trim() !== "")
                    hyprlandService.layoutList = parts[2].trim();
                let code = "us";
                // Keymap display name → XKB code (shared with NiriService
                // via CompositorService.layoutNameMap)
                const layoutMap = CompositorService.layoutNameMap;
                // Prefer the exact XKB layout code already reported by Hyprland
                if (xkbCode !== "" && xkbCode !== "null" && xkbCode !== "undefined") {
                    code = xkbCode;
                } else if (layoutMap[raw] !== undefined) {
                    code = layoutMap[raw];
                } else {
                    let matched = false;
                    for (let key of Object.keys(layoutMap)) {
                        if (raw.indexOf(key) !== -1) {
                            code = layoutMap[key];
                            matched = true;
                            break;
                        }
                    }
                    if (!matched) {
                        let candidate = raw.toLowerCase().split(" ")[0];
                        if (candidate.length >= 2 && candidate.length <= 4)
                            code = candidate;
                        else
                            code = "us";
                    }
                }
                if (hyprlandService.keyboardLayout !== code) {
                    hyprlandService.isSyncing = true;
                    hyprlandService.keyboardLayout = code;
                    hyprlandService.isSyncing = false;
                }
            }
        }

    }

    Process {
        id: readHyprPrefsProc

        command: ["python3", Quickshell.shellDir + "/Core/Services/scripts/read_hypr_prefs.py"]
        onExited: (code) => {
            hyprlandService.isSyncing = false;
            hyprlandService.hyprPrefsLoaded = true;
        }

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() !== "") {
                    if (DisplayProfileService.gameModeActive)
                        return ;

                    try {
                        let prefs = JSON.parse(data.trim());
                        hyprlandService.isSyncing = true;
                        // Only the values the shell mirrors for its own
                        // rendering are synced; everything else stays in the
                        // user's hyprland.lua.
                        if (prefs["decoration:shadow:enabled"] !== undefined)
                            hyprShadow = prefs["decoration:shadow:enabled"];

                        if (prefs["decoration:shadow:range"] !== undefined)
                            hyprShadowRange = prefs["decoration:shadow:range"];

                        if (prefs["decoration:shadow:render_power"] !== undefined)
                            hyprShadowRenderPower = prefs["decoration:shadow:render_power"];

                        if (prefs["animations:enabled"] !== undefined)
                            enableAnimations = prefs["animations:enabled"];

                    } catch (e) {
                        console.error("Error parsing hypr prefs: " + e);
                    }
                }
            }
        }

    }

    Component.onCompleted: {
        // Seed the layout list once at startup — the activelayout event only
        // fires on switches, not on shell reloads. Hyprland only: niri and
        // bspwm expose their layouts through their own backends.
        if (CompositorService.wm === "hyprland")
            activeLayoutProc.running = true;
    }

}
