

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "fuzzel"



hl.on("hyprland.start", function ()
  hl.exec_cmd("hyprpaper & waybar & mako & hyprctl setcursor Simp1e-Dark 24")
end)



hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")



hl.config({
    input = {
        kb_layout  = "us",

        follow_mouse = 1,

        sensitivity = -0.25,

        touchpad = {
            natural_scroll = true,
        },
    },
})


hl.config({
    misc = {
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        background_color           = "rgba(15130fff)",
    },
})



hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 12,
        border_size = 3,
        col = {
            active_border   = "rgba(9e948966)",
            inactive_border = "rgba(9e948922)",
        },
        layout = "dwindle",
    },
})



hl.config({
    decoration = {
        rounding = 0,

        blur = {
            enabled   = true,
            size      = 6,
            passes    = 3,
            vibrancy  = 0,
            noise     = 0.09,
            contrast  = 1,
            brightness = 0.9,
        },

        shadow = {
            enabled      = true,
            range        = 10,
            render_power = 2,
            color        = "rgba(1c1d1588)",
        },
    },
})

hl.config({
    layerrule = {
        "blur,waybar",
        "blur,launcher",
        "xray,launcher",
    },
})



hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })



hl.config({
    dwindle = {
        force_split    = 2,
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_on_top = true,
    },
})


hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})



local mainMod = "SUPER"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + Q", hl.dsp.exit())
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)"'))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("~/.config/waybar/scripts/clip.sh copy"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/waybar/scripts/clip.sh paste"))

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/waybar/scripts/osd.sh bri-up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/waybar/scripts/osd.sh bri-down"))
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("~/.config/waybar/scripts/osd.sh vol-up"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("~/.config/waybar/scripts/osd.sh vol-down"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("~/.config/waybar/scripts/osd.sh mute"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })