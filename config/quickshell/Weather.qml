pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Weather from agentos-weather (home/weather.nix, wttr.in every 30 minutes), shared by
// the bar, the calendar and the screensaver.
Singleton {
    id: root

    property var data: null
    readonly property bool ready: data !== null

    // Stale after 3 hours (offline): the bar hides the temperature rather than lie.
    property real now: Date.now()
    readonly property bool fresh: ready && now / 1000 - data.updated < 3 * 3600
    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // Night between sunset and sunrise (HH:MM strings compare correctly).
    function isNight(date) {
        if (!data?.sunrise)
            return false;
        const hm = Qt.formatTime(date, "HH:mm");
        return hm < data.sunrise || hm >= data.sunset;
    }

    // wttr.in (WWO) condition codes to Lucide icons.
    function icon(code, night) {
        if (code === 113)
            return night ? "moon" : "sun";
        if (code === 116)
            return night ? "cloud-moon" : "cloud-sun";
        if ([119, 122].includes(code))
            return "cloud";
        if ([143, 248, 260].includes(code))
            return "cloud-fog";
        if ([200, 386, 389, 392, 395].includes(code))
            return "cloud-lightning";
        if ([176, 263, 266, 281, 284, 293, 296, 311, 353].includes(code))
            return "cloud-drizzle";
        if ([299, 302, 305, 308, 314, 356, 359].includes(code))
            return "cloud-rain";
        if (code >= 179)
            return "cloud-snow"; // what's left: snow, sleet, ice pellets
        return "cloud";
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/agentos/weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {}
        }
    }
}
