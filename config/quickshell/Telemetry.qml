pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// System telemetry for the bar: CPU load, CPU temperature, memory, battery drain.
// Read straight from /proc and /sys (no helper processes), every 2 s, 5 s in battery mode.
Singleton {
    id: root

    property real cpu: 0 // 0–1
    property real temp: 0 // °C, k10temp Tctl
    property real memUsed: 0 // GiB
    property real memTotal: 0 // GiB
    property real watts: 0 // battery drain, only meaningful on battery

    property var lastStat: null
    // hwmon numbers change between boots, so find k10temp by name once.
    property string tempPath: ""

    // btop in its own terminal window (app id agentos.btop, floated by hyprland.lua):
    // close it if it's open, else open it.
    function toggleMonitor() {
        const open = ToplevelManager.toplevels.values.find(t => t.appId === "agentos.btop");
        if (open)
            open.close();
        else
            // Own process: a window handed to the running Ghostty would ignore --class.
            Quickshell.execDetached(["uwsm", "app", "--", "ghostty", "--gtk-single-instance=false", "--class=agentos.btop", "--title=System monitor", "-e", "btop"]);
    }

    Timer {
        interval: ShellState.mode === "battery" ? 5000 : 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            if (root.tempPath)
                tempFile.reload();
            if (UPower.onBattery)
                power.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // cpu  user nice system idle iowait irq softirq steal …
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastStat) {
                const dt = total - root.lastStat.total;
                if (dt > 0)
                    root.cpu = 1 - (idle - root.lastStat.idle) / dt;
            }
            root.lastStat = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number((text().match(new RegExp("^" + key + ":\\s+(\\d+)", "m")) ?? [0, 0])[1]);
            root.memTotal = kb("MemTotal") / 1048576;
            root.memUsed = (kb("MemTotal") - kb("MemAvailable")) / 1048576;
        }
    }

    FileView {
        id: tempFile
        path: root.tempPath
        onLoaded: root.temp = Number(text()) / 1000
    }

    FileView {
        id: power
        path: "/sys/class/power_supply/BAT0/power_now"
        onLoaded: root.watts = Number(text()) / 1e6
    }

    Process {
        running: true
        command: ["sh", "-c", "grep -lx k10temp /sys/class/hwmon/hwmon*/name | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim().replace(/\/name$/, "");
                if (dir)
                    root.tempPath = dir + "/temp1_input";
            }
        }
    }
}
