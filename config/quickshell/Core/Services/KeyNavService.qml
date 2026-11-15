import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: root

    // Modal keyboard navigation for the theme selector. While the popup is
    // open in the bottom host, plain arrow/enter/escape binds are registered
    // through Hyprland's Lua API that call back into the shell over IPC.
    // This bypasses layer-shell keyboard focus entirely: the binds fire no
    // matter which surface holds the keyboard, so the popup can be driven
    // right after being opened by IPC or a keybind without any click.
    // Binds are removed when the popup closes.
    property bool bindsActive: false

    readonly property var _navBinds: [{
            "key": "RIGHT",
            "action": "right"
        }, {
            "key": "LEFT",
            "action": "left"
        }, {
            "key": "DOWN",
            "action": "down"
        }, {
            "key": "UP",
            "action": "up"
        }, {
            "key": "RETURN",
            "action": "enter"
        }, {
            "key": "ESCAPE",
            "action": "esc"
        }]

    signal navigate(string action)

    function activate() {
        if (bindsActive)
            return ;

        bindsActive = true;
        let cmds = "";
        for (let i = 0; i < _navBinds.length; i++) {
            let b = _navBinds[i];
            cmds += "hyprctl eval 'hl.bind(\"" + b.key + "\", hl.dsp.exec_cmd(\"qs -p " + Quickshell.shellDir + " ipc call keynav " + b.action + "\"))' >/dev/null; ";
        }

        bindProc.command = ["bash", "-c", cmds];
        bindProc.running = true;
    }

    function deactivate() {
        if (!bindsActive)
            return ;

        bindsActive = false;
        let cmds = "";
        for (let i = 0; i < _navBinds.length; i++) {
            cmds += "hyprctl eval 'hl.unbind(\"" + _navBinds[i].key + "\")' >/dev/null; ";
        }

        bindProc.command = ["bash", "-c", cmds];
        bindProc.running = true;
    }

    function dispatch(action) {
        root.navigate(action);
    }

    Process {
        id: bindProc
    }

}
