-- agentos Hyprland config (Lua: Hyprland 0.57 drops the .conf format).
-- LIVE FILE: save and Hyprland reloads it, no rebuild needed. Loaded with require()
-- from the Home Manager-generated ~/.config/hypr/hyprland.lua (home/hyprland.nix),
-- after Stylix's colours, so settings here win. Border colours: home/hyprland.nix.
-- Check for mistakes with: hyprctl configerrors
-- The API: /run/current-system/sw/share/hypr/stubs/hl.meta.lua and the Hyprland wiki.

-- ── Display ──────────────────────────────────────────────────────────────────
-- Samsung 1920×1200 OLED, 60 Hz (UM3406KA panel, read from EDID).
-- Scale 1.25 → 1536×960 of workspace. Try 1 for more space; this file is live.
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.25 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Quickshell (also the polkit agent and notification daemon) and hypridle start as
-- systemd user services, so nothing is started from here.

-- ── Look & feel ──────────────────────────────────────────────────────────────
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },

    general = {
        gaps_in = 6,
        gaps_out = 12,
        -- Console panels: thin borders, small corners (the shell's cards match: 8 px).
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding = 8,
        active_opacity = 1.0,
        inactive_opacity = 0.94,

        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = true,
            vibrancy = 0.18,
            popups = true,
        },

        shadow = {
            enabled = true,
            range = 14,
            render_power = 4,
            color = "rgba(00000088)",
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- The internal panel is fixed 60 Hz; VRR only matters for external monitors,
        -- and then only fullscreen (VRR on the desktop can flicker on OLED).
        vrr = 2,
        focus_on_activate = true,
    },
})

hl.curve("smooth", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("snappy", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "snappy", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "smooth" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "smooth", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "smooth", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "smooth", style = "slidevert" })

-- Frosted glass behind the Quickshell bar, panels and cards.
-- ignore_alpha 0: blur wherever the shell draws (its transparent margins stay clear);
-- 0.5: blur the card (alpha 0.72+) but not the dimmed backdrop (0.35) around it.
local function blur(namespace, ignore_alpha)
    hl.layer_rule({ match = { namespace = namespace }, blur = true, ignore_alpha = ignore_alpha })
end
blur("agentos-bar", 0)
blur("agentos-claude", 0)
blur("agentos-osd", 0)
blur("agentos-overview", 0)
blur("agentos-switcher", 0) -- the whole dimmed backdrop, like the overview
blur("agentos-cheatsheet", 0.5)
blur("agentos-polkit", 0.5)
blur("agentos-system", 0.5)
blur("agentos-calendar", 0.5)
blur("agentos-clipboard", 0.5)
blur("agentos-missionlog", 0.5)
blur("agentos-launcher", 0.5)
blur("agentos-toasts", 0.5)
-- fuzzel (the Super+P password menu) calls its layer "launcher".
blur("^launcher$", 0.5)

-- Open / Save As dialogs (the file-chooser portal, used by satty, Chromium and others):
-- they open taller than the space below the bar; a calmer size, centred.
hl.window_rule({
    name = "file-dialogs",
    match = { class = "xdg-desktop-portal-gtk" },
    float = true,
    size = "(monitor_w*0.55) (monitor_h*0.65)",
    center = true,
})

-- The screenshot editor floats over your work, centred.
hl.window_rule({
    name = "screenshot-editor",
    match = { class = "com\\.gabm\\.satty" },
    float = true,
    center = true,
})

-- The system monitor (btop, from the bar's telemetry): a floating console, not a tile.
hl.window_rule({
    name = "system-monitor",
    match = { class = "agentos\\.btop" },
    float = true,
    size = "(monitor_w*0.6) (monitor_h*0.65)",
    center = true,
})

-- ── Input ────────────────────────────────────────────────────────────────────
hl.config({
    input = {
        -- US layout with AltGr accents (AltGr+e = é) and no dead keys: handy for Dutch + code.
        kb_layout = "us",
        kb_variant = "altgr-intl",
        follow_mouse = 1,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            clickfinger_behavior = true,
            disable_while_typing = true,
        },
    },
})

-- Three-finger swipe between workspaces.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ── Keybinds ─────────────────────────────────────────────────────────────────
local mod = "SUPER"
local term = "ghostty"

-- bind(keys, "Group: description", dispatcher[, options]). The cheat sheet (Super+/)
-- reads the descriptions live from hyprctl; binds with the same description merge
-- into one row.
local function bind(keys, description, dispatcher, opts)
    opts = opts or {}
    opts.description = description
    hl.bind(keys, dispatcher, opts)
end
local run = hl.dsp.exec_cmd

bind(mod .. " + SLASH", "Help: Show this cheat sheet", run("qs ipc call cheatsheet toggle"))
-- Herdr runs inside the terminal and keeps agent sessions alive; `herdr` attaches to
-- the running session or starts it. Detach with Ctrl+b then q.
bind(mod .. " + RETURN", "Apps: Terminal with Herdr (agent sessions)", run("uwsm app -- " .. term .. " -e herdr"))
bind(mod .. " + SHIFT + RETURN", "Apps: Plain terminal", run("uwsm app -- " .. term))
bind(mod .. " + SPACE", "Apps: App launcher (=calc · else ask Claude)", run("qs ipc call launcher toggle"))
bind(mod .. " + A", "Apps: Ask Claude", run("qs ipc call claude toggle"))
-- Bitwarden via rofi-rbw (home/apps.nix): type into the focused app, or copy (cleared after 20 s).
-- Pressed again while the menu is open: close it (as Super+Space does for the launcher).
bind(mod .. " + P", "Apps: Password: type into the focused app", run("pkill -x fuzzel || rofi-rbw --action type --target password"))
bind(mod .. " + SHIFT + P", "Apps: Password: copy (cleared after 20 s)", run("pkill -x fuzzel || rofi-rbw --action copy --target password"))
bind(mod .. " + B", "Apps: Chromium", run("uwsm app -- chromium"))
bind(mod .. " + E", "Apps: Files (Yazi in the terminal)", run("uwsm app -- " .. term .. " -e yazi"))
bind(mod .. " + SHIFT + E", "Apps: Files (Thunar)", run("uwsm app -- thunar"))
bind(mod .. " + TAB", "Workspaces: Overview (click / drag / arrows)", run("qs ipc call overview toggle"))
-- Window switcher (config/quickshell/Switcher.qml): letting go of Alt switches.
bind("ALT + TAB", "Windows: Switch window (hold Alt and tap Tab)", run("qs ipc call switcher next"))
bind("ALT + SHIFT + TAB", "Windows: Switch window backwards", run("qs ipc call switcher prev"))
bind(mod .. " + grave", "Workspaces: Previous workspace", hl.dsp.focus({ workspace = "previous" }))

bind(mod .. " + Q", "Windows: Close window", hl.dsp.window.close())
bind(mod .. " + F", "Windows: Fullscreen", hl.dsp.window.fullscreen())
bind(mod .. " + T", "Windows: Float / tile", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + J", "Windows: Flip split direction", hl.dsp.layout("togglesplit"))

bind(mod .. " + Escape", "System: System menu (Wi-Fi / Bluetooth / sound / power)", run("qs ipc call system toggle"))
bind(mod .. " + N", "System: Night light pause / resume", run("systemctl --user kill -s USR1 gammastep.service"))
bind(mod .. " + L", "System: Mission log (what changed and why)", run("qs ipc call missionlog toggle"))
bind(mod .. " + C", "System: Calendar and weather", run("qs ipc call calendar toggle"))
bind(mod .. " + SHIFT + Escape", "System: System monitor (btop) open / close", run("qs ipc call monitor toggle"))
bind(mod .. " + M", "System: Next mode (normal / battery / presentation / focus)", run("agentos-mode next"))
bind(mod .. " + CTRL + L", "System: Lock screen", run("loginctl lock-session"))
-- Log out is hard to hit by accident: next to the file manager keys, and in the system menu.
bind(mod .. " + CTRL + SHIFT + E", "System: Log out", run("uwsm stop"))
bind(mod .. " + V", "Tools: Clipboard history", run("qs ipc call clipboard toggle"))
bind(mod .. " + SHIFT + S", "Tools: Screenshot area to clipboard", run('grim -g "$(slurp)" - | wl-copy'))
-- Into the editor (satty, home/screenshots.nix); Esc in slurp cancels without opening it.
local toEditor = 'g=$(slurp) && grim -g "$g" - | satty --filename -'
bind(mod .. " + CTRL + S", "Tools: Screenshot area to the editor (draw / crop)", run(toEditor))
bind("Print", "Tools: Screenshot area to the editor (draw / crop)", run(toEditor))
bind("SHIFT + Print", "Tools: Screenshot whole screen to the editor", run("grim - | satty --filename -"))
bind(mod .. " + SHIFT + C", "Tools: Pick colour to clipboard", run("hyprpicker -a"))

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + " .. dir, "Windows: Focus window in direction", hl.dsp.focus({ direction = dir }))
    bind(mod .. " + SHIFT + " .. dir, "Windows: Move window in direction", hl.dsp.window.move({ direction = dir }))
    -- Snap to a screen half (floats the window; Super+T tiles it again). See snap.sh.
    bind(mod .. " + ALT + " .. dir, "Windows: Snap to left / right / upper / lower half", run("bash ~/agentos/config/hypr/snap.sh " .. dir))
end

-- Resize (hold to repeat). Tiled windows move the split; floating ones change size.
local function resize(keys, description, x, y)
    bind(keys, description, hl.dsp.window.resize({ x = x, y = y, relative = true }), { repeating = true })
end
local resizeDesc = "Windows: Resize: wider / narrower / taller / shorter"
resize(mod .. " + equal", "Windows: Bigger", 40, 40)
resize(mod .. " + minus", "Windows: Smaller", -40, -40)
resize(mod .. " + CTRL + right", resizeDesc, 40, 0)
resize(mod .. " + CTRL + left", resizeDesc, -40, 0)
resize(mod .. " + CTRL + down", resizeDesc, 0, 40)
resize(mod .. " + CTRL + up", resizeDesc, 0, -40)

for i = 1, 9 do
    bind(mod .. " + " .. i, "Workspaces: Go to workspace", hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. i, "Workspaces: Send window to workspace", hl.dsp.window.move({ workspace = i }))
end

bind(mod .. " + S", "Workspaces: Show / hide scratchpad", hl.dsp.workspace.toggle_special("scratch"))
bind(mod .. " + ALT + S", "Workspaces: Send window to scratchpad", hl.dsp.window.move({ workspace = "special:scratch" }))

bind(mod .. " + mouse:272", "Mouse: Drag window", hl.dsp.window.drag())
bind(mod .. " + mouse:273", "Mouse: Resize window", hl.dsp.window.resize())

-- Hardware keys: work on the lock screen too; volume and brightness repeat when held.
local function key(k, cmd, repeating)
    hl.bind(k, run(cmd), { locked = true, repeating = repeating })
end
key("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", true)
key("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true)
key("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
key("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
key("XF86MonBrightnessUp", "brightnessctl -e4 -n2 set 5%+ && qs ipc call osd brightness", true)
key("XF86MonBrightnessDown", "brightnessctl -e4 -n2 set 5%- && qs ipc call osd brightness", true)
key("XF86AudioPlay", "playerctl play-pause")
key("XF86AudioNext", "playerctl next")
key("XF86AudioPrev", "playerctl previous")
