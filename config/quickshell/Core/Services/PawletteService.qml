import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: root

    // Paths owned by pawlette and the meowrch dynamic-theme flag.
    readonly property string palettePath: Quickshell.env("HOME") + "/.local/state/pawlette/active_palette.json"
    readonly property string themesDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/pawlette/themes"
    readonly property string dynamicStatePath: Quickshell.env("HOME") + "/.local/state/meowrch/dynamic_theme"
    // The meowrch wallpaper helper stores the active wallpaper next to the
    // collection; the shell cache is only a fallback for fresh sessions.
    readonly property string meowrchCurrentWall: Quickshell.env("HOME") + "/.local/share/wallpapers/.current.wall"

    // Active palette (keys from pawlette's active_palette.json).
    property var palette: ({})
    readonly property bool paletteReady: Object.keys(palette).length > 0
    readonly property bool installed: themes.length > 0

    // Colors mapped for Theme.qml. Every accessor falls back to the shell
    // default scheme so a missing palette never blanks the UI.
    readonly property string bg: paletteReady ? palette.color_bg : "#030107"
    readonly property string fg: paletteReady ? palette.color_text : "#d1d1d1"
    readonly property string accent: paletteReady ? palette.color_primary : "#a77ef5"
    readonly property string accentComplementary: paletteReady ? palette.color_secondary : "#f57eb6"
    readonly property string muted: paletteReady ? palette.color_text_muted : ""
    readonly property string border: paletteReady ? palette.color_border_inactive : ""
    readonly property string bgSecondary: paletteReady ? palette.color_surface : ""
    readonly property string bgTertiary: paletteReady ? palette.color_bg_alt : ""

    // Theme catalog from `pawlette list` + colors.toml (via pawlette_info.py).
    // Items: {name, logo (string|null), variants ({name: hex|null})}
    property var themes: []
    property bool themesLoading: false

    // Dynamic (wallpaper-driven) theme toggle state.
    property bool dynamicEnabled: false

    // Theme applied most recently from this shell, for the "current" marker.
    property string lastAppliedTheme: ""
    property string lastAppliedVariant: ""

    signal themesRefreshed()
    signal applied()

    function applyTheme(name, variant) {
        if (!name || !installed)
            return ;

        let cmd = ["pawlette", "apply", "theme", name];
        if (variant && variant !== "default" && variant !== "")
            cmd.push("--variant", variant);

        applyProc.running = false;
        applyProc.command = cmd;
        applyProc.running = true;
        lastAppliedTheme = name;
        lastAppliedVariant = variant || "default";
        writeMarker(name, variant || "default");
    }

    function applyImage(wallPath) {
        if (!wallPath || !installed)
            return ;

        imageProc.running = false;
        imageProc.command = ["pawlette", "apply", "image", wallPath];
        imageProc.running = true;
        lastAppliedTheme = "__dynamic__";
        lastAppliedVariant = "";
        writeMarker("__dynamic__", "");
    }

    function toggleDynamic() {
        setDynamic(!dynamicEnabled);
        if (dynamicEnabled) {
            let wall = currentWallpaperPath();
            if (wall !== "")
                applyImage(wall);

        }
    }

    function setDynamic(enabled) {
        dynamicEnabled = enabled;
        dynamicWriter.payload = enabled ? "1" : "0";
        dynamicWriter.running = false;
        dynamicWriter.running = true;
    }

    function applyRandom() {
        if (themes.length === 0)
            return ;

        let theme = themes[Math.floor(Math.random() * themes.length)];
        let variantNames = Object.keys(theme.variants || {});
        let variant = "default";
        if (variantNames.length > 0)
            variant = variantNames[Math.floor(Math.random() * variantNames.length)];

        applyTheme(theme.name, variant);
    }

    // Resolves the wallpaper that dynamic theming should use.
    function currentWallpaperPath() {
        if (WallpaperManager.currentWallpaperPath !== "")
            return WallpaperManager.currentWallpaperPath;

        if (WallpaperManager.currentWallpaper !== "") {
            let name = WallpaperManager.currentWallpaper;
            return name.startsWith("/") ? name : SettingsService.wallpaperFolder + "/" + name;
        }

        return meowrchCurrentWall;
    }

    function refreshThemes() {
        // Restarting a running collector mixes a partial stdout with the new
        // run, so a refresh while a scan is in flight is a no-op.
        if (infoProc.running)
            return ;

        infoProc.running = true;
    }

    function writeMarker(name, variant) {
        markerProc.payload = name + "\n" + (variant || "");
        markerProc.running = false;
        markerProc.running = true;
    }

    Component.onCompleted: {
        refreshThemes();
        lastThemeLoader.running = true;
    }

    // The palette is the single source of truth for the shell colors. When it
    // flips to a usable state (or changes), Theme.qml re-applies the scheme.
    onPaletteReadyChanged: {
        if (paletteReady)
            root.applied();

    }

    // ---- palette watching ------------------------------------------------
    FileView {
        id: paletteFile

        path: root.palettePath
        watchChanges: true
        onFileChanged: paletteFile.reload()
        onLoaded: {
            try {
                let data = JSON.parse(paletteFile.text());
                if (data && typeof data === "object") {
                    root.palette = data;
                    root.applied();
                }
            } catch (e) {
                console.warn("PawletteService: invalid palette json:", e);
            }
        }
    }

    // ---- theme catalog ---------------------------------------------------
    Process {
        id: infoProc

        command: ["python3", Quickshell.shellDir + "/Scripts/theme/pawlette_info.py"]
        onRunningChanged: {
            if (running)
                root.themesLoading = true;

        }
        onExited: {
            root.themesLoading = false;
            root.themesRefreshed();
        }
        stdout: StdioCollector {
            id: infoOutput

            onStreamFinished: {
                try {
                    let doc = JSON.parse(text);
                    if (doc.installed)
                        root.themes = doc.themes;

                } catch (e) {
                    console.warn("PawletteService: invalid info json:", e);
                }
            }
        }

    }

    Process {
        id: applyProc
    }

    Process {
        id: imageProc
    }

    // Writes the "last applied" marker via python so file names and shell
    // metacharacters can never leak into a command string.
    Process {
        id: markerProc

        property string payload: ""

        command: ["python3", "-c", "import pathlib,sys; pathlib.Path(sys.argv[1]).parent.mkdir(parents=True, exist_ok=True); pathlib.Path(sys.argv[1]).write_text(sys.argv[2])", Quickshell.env("HOME") + "/.cache/quickshell/last_pawlette_theme", payload]
    }

    Process {
        id: dynamicWriter

        property string payload: ""

        command: ["python3", "-c", "import pathlib,sys; p = pathlib.Path(sys.argv[1]); p.parent.mkdir(parents=True, exist_ok=True); p.write_text(sys.argv[2])", root.dynamicStatePath, payload]
    }

    // ---- last applied marker (read back at startup) -----------------------
    Process {
        id: lastThemeLoader

        command: ["cat", Quickshell.env("HOME") + "/.cache/quickshell/last_pawlette_theme"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split("\n");
                if (lines.length >= 1 && lines[0] !== "")
                    root.lastAppliedTheme = lines[0];

                if (lines.length >= 2 && lines[1] !== "")
                    root.lastAppliedVariant = lines[1];

            }
        }

    }

}
