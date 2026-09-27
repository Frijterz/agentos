pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon (replaces mako): receives desktop notifications, keeps a
// history of up to 50 (shown in the system menu) and decides what pops up (Toasts.qml).
// Focus and presentation modes are "do not disturb": no pop-ups except critical ones,
// but everything still lands in the history.
Singleton {
    id: root

    readonly property var history: server.trackedNotifications.values.slice().reverse() // newest first
    property int unread: 0
    property var toasts: [] // notifications currently popped up
    property var arrived: ({}) // id -> time it arrived (ms)

    readonly property bool dnd: ShellState.mode === "presentation" || ShellState.mode === "focus"

    function isCritical(n) {
        return n.urgency === NotificationUrgency.Critical;
    }

    function hideToast(n) {
        toasts = toasts.filter(t => t !== n);
        if (n.transient)
            n.dismiss(); // "don't keep me" notifications leave no history
    }

    function dismiss(n) {
        toasts = toasts.filter(t => t !== n);
        n.dismiss();
    }

    function clearAll() {
        toasts = [];
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        unread = 0;
    }

    // The action a click on the notification itself triggers ("default"), if any.
    function activate(n) {
        const a = n.actions.find(x => x.identifier === "default");
        if (a)
            a.invoke();
        dismiss(n);
    }

    // A soft sonar ping (transmission-in) when a notification pops up; at most one per
    // 1.5 s so a burst doesn't pile up. Through PipeWire: follows volume and mute.
    property real lastTone: 0
    Process {
        id: tone
        command: ["pw-play", Theme.soundDir + "/transmission-in.wav"]
    }
    function beep() {
        if (!Theme.soundDir || tone.running || Date.now() - lastTone < 1500)
            return;
        lastTone = Date.now();
        tone.running = true;
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const a = Object.assign({}, root.arrived);
            a[n.id] = Date.now();
            root.arrived = a;
            root.unread++;
            if (!root.dnd || root.isCritical(n)) {
                root.toasts = [n].concat(root.toasts).slice(0, 4);
                root.beep();
            }
            // Keep the history bounded: drop the oldest beyond 50.
            const all = server.trackedNotifications.values;
            for (let i = 0; i < all.length - 50; i++)
                all[i].dismiss();
        }
    }
}
