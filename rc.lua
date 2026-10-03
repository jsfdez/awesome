-- Standard awesome library
local gears = require('gears')
local awful = require('awful')
require('awful.autofocus')
-- Widget and layout library
local wibox = require('wibox')
-- Theme handling library
local beautiful = require('beautiful')
-- Notification library
local naughty = require('naughty')
local menubar = require('menubar')
local hotkeys_popup = require('awful.hotkeys_popup').widget

naughty.config.defaults['icon_size'] = 100

-- Load menu
local freedesktop = require('freedesktop')

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({
        preset = naughty.config.presets.critical,
        title = 'Oops, there were errors during startup!',
        text = awesome.startup_errors
    })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal('debug::error', function(err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({
            preset = naughty.config.presets.critical,
            title = 'Oops, an error happened!',
            text = tostring(err)
        })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Initialize theme
beautiful.init(gears.filesystem.get_themes_dir() .. 'default/theme.lua')

local function reload_module(name)
    package.loaded[name] = nil
    return require(name)
end

function reload_theme_overrides()
    reload_module('theme_overrides')(beautiful)
end

-- Default applications
local terminal = 'gnome-terminal'
local editor = os.getenv('EDITOR') or 'nano'
local editor_cmd = terminal .. ' -e ' .. editor

-- Default modkey (Super/Windows key)
local modkey = 'Mod4'

function reload_layouts()
    reload_module('layouts')()
end
reload_layouts()

-- {{{ Quake Terminal
local quake_terminal = nil

function toggle_quake_terminal()
    local screen = awful.screen.focused()

    if quake_terminal and quake_terminal.valid then
        if quake_terminal.hidden then
            -- Show terminal
            quake_terminal.hidden = false
            quake_terminal:geometry({
                x = 0,
                y = 0,
                width = screen.geometry.width,
                height = screen.geometry.height * 0.5
            })
            quake_terminal.ontop = true
            quake_terminal:raise()
            client.focus = quake_terminal
        else
            -- Hide terminal
            quake_terminal.hidden = true
            quake_terminal:geometry({x = -9999, y = -9999, width = 1, height = 1})
        end
    else
        -- Create new quake terminal
        awful.spawn(terminal .. ' --title=QuakeTerminal', {
            floating = true,
            ontop = true,
            sticky = true,
            skip_taskbar = true,
            callback = function(c)
                quake_terminal = c
                c:geometry({
                    x = 0,
                    y = 0,
                    width = screen.geometry.width,
                    height = screen.geometry.height * 0.5
                })
                c.hidden = false
                c:raise()
                client.focus = c
            end
        })
    end
end
-- }}}

-- {{{ Helper functions
local function client_menu_toggle_fn()
    local instance = nil
    return function()
        if instance and instance.wibox.visible then
            instance:hide()
            instance = nil
        else
            instance = awful.menu.clients({theme = {width = 250}})
        end
    end
end

-- Improved lock screen function with fallbacks
function lock_screen()
    awful.spawn.easy_async('which light-locker-command', function(stdout, stderr, reason, exit_code)
        if exit_code == 0 then
            awful.spawn('light-locker-command -l')
        else
            awful.spawn.easy_async('which gnome-screensaver-command', function(stdout, stderr, reason, exit_code)
                if exit_code == 0 then
                    awful.spawn('gnome-screensaver-command -l')
                else
                    naughty.notify({
                        preset = naughty.config.presets.critical,
                        title = 'Lock Screen Error',
                        text = 'No screen locker found!'
                    })
                end
            end)
        end
    end)
end

-- Power management functions

local function power_action(prompt_text, action_text, command)
    awful.prompt.run {
        prompt = prompt_text,
        textbox = awful.screen.focused().mypromptbox.widget,
        exe_callback = function(answer)
            if answer:lower() == 'yes' or answer:lower() == 'y' then
                naughty.notify({
                    preset = naughty.config.presets.info,
                    title = 'Power Management',
                    text = action_text,
                    timeout = 2
                })
                awful.spawn.with_shell(command)
            else
                naughty.notify({
                    preset = naughty.config.presets.info,
                    title = 'Power Management',
                    text = 'Action cancelled',
                    timeout = 2
                })
            end
        end
    }
end

function hibernate()
    power_action('Hibernate system? (yes/no): ', 'Hibernating system...',
        'dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager.Hibernate boolean:true')
end

function suspend(answer)
    if answer == true or answer == 1 then
        awful.spawn.with_shell('systemctl suspend')
        return true
    end
    power_action('Suspend system? (yes/no): ', 'Suspending system...', 'systemctl suspend')
end

function reboot()
    power_action('Reboot system? (yes/no): ', 'Rebooting system...', 'systemctl reboot')
end

function poweroff()
    power_action('Power off system? (yes/no): ', 'Powering off system...', 'systemctl poweroff')
end

-- Auto-start applications function
local function autostart()
    local apps = {
        'nm-applet',
        'xfce4-power-manager',
        'xfsettingsd',
        'light-locker',
        'blueman-applet',
        'pasystray',
        'pamac-tray'
    }

    for _, app in ipairs(apps) do
        awful.spawn('killall ' .. app .. ' 2>/dev/null; ' .. app)
    end
end
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
    {'hotkeys', function() return false, hotkeys_popup.show_help end},
    {'manual', terminal .. ' -e man awesome'},
    {'edit config', editor_cmd .. ' ' .. awesome.conffile},
    {'restart', awesome.restart},
    {'quit', function() awesome.quit() end}
}

mymainmenu = freedesktop.menu.build({
    icon_size = 32,
    before = {
        {'Awesome', myawesomemenu, '/usr/share/awesome/icons/awesome32.png'}
    },
    after = {}
})

mylauncher = awful.widget.launcher({
    image = beautiful.awesome_icon,
    menu = mymainmenu
})

-- Menubar configuration
menubar.utils.terminal = terminal
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- Brightness widget with status checking
local brightness_widget = wibox.widget.textbox()

local function check_brightness_setup()
    local handle = io.popen('which brightnessctl 2>/dev/null')
    local result = handle:read("*a")
    handle:close()

    if result == "" then
        return false, "brightnessctl not installed"
    end

    local handle = io.popen('sudo -n brightnessctl -m 2>/dev/null')
    local result = handle:read("*a")
    handle:close()

    if result == "" then
        return false, "sudo access not configured"
    end

    return true, nil
end

local brightness_ok, brightness_error = check_brightness_setup()
if not brightness_ok then
    naughty.notify({
        preset = naughty.config.presets.critical,
        title = 'Brightness Control Error',
        text = brightness_error .. '\n\nTo fix: sudo visudo and add:\n%wheel ALL=(ALL) NOPASSWD: /usr/bin/brightnessctl',
        timeout = 0
    })
    brightness_widget:set_text('⚠️')
else
    brightness_widget:set_text('🖵 ' .. get_brightness() .. '%')
end

local function get_brightness()
    local handle = io.popen('brightnessctl -m')
    local result = handle:read("*a")
    handle:close()

    local current, max = result:match("([^,]+),[^,]+,([^,]+)")
    if current and max then
        local percentage = math.floor((tonumber(current) / tonumber(max)) * 100)
        return percentage
    end
    return 0
end

local function update_brightness_icon()
    if not brightness_ok then
        brightness_widget:set_text('⚠️')
        return
    end

    local brightness = get_brightness()
    brightness_widget:set_text('🖵 ' .. brightness .. '%')
end

update_brightness_icon()

brightness_widget:buttons(gears.table.join(
    awful.button({}, 1, function()
        naughty.notify({
            preset = naughty.config.presets.info,
            title = 'Screen Brightness',
            text = 'Current: ' .. get_brightness() .. '%',
            timeout = 2
        })
    end),
    awful.button({}, 4, function()
        awful.spawn('sudo brightnessctl set +10%')
        update_brightness_icon()
    end),
    awful.button({}, 5, function()
        awful.spawn('sudo brightnessctl set 10%-')
        update_brightness_icon()
    end)
))

gears.timer({
    timeout = 2,
    autostart = true,
    callback = function()
        update_brightness_icon()
    end
})

-- Power profile widget
-- Requires sudo access to system76-power without password.
-- Set up with: sudo visudo
-- Then add: %wheel ALL=(ALL) NOPASSWD: /usr/bin/system76-power
-- (or replace %wheel with your username if not in wheel group)
local power_manager = nil
local function detect_power_manager()
    local function file_exists(path)
        local f = io.open(path, "r")
        if f then
            f:close()
            return true
        end
        return false
    end

    if file_exists("/usr/bin/system76-power") or file_exists("/usr/local/bin/system76-power") then
        return "system76-power"
    elseif file_exists("/usr/bin/powerprofilesctl") or file_exists("/usr/local/bin/powerprofilesctl") then
        return "powerprofilesctl"
    elseif file_exists("/usr/bin/cpupower") or file_exists("/usr/local/bin/cpupower") then
        return "cpupower"
    end
    return nil
end

power_manager = detect_power_manager()

-- Power profile menu with dynamic commands
local function get_power_commands()
    if power_manager == "system76-power" then
        return {
            {'🔋 Battery', function() awful.spawn('sudo system76-power profile battery') end},
            {'⚡ Balanced', function() awful.spawn('sudo system76-power profile balanced') end},
            {'🔥 Performance', function() awful.spawn('sudo system76-power profile performance') end}
        }
    elseif power_manager == "powerprofilesctl" then
        return {
            {'🔋 Power Saver', function() awful.spawn('powerprofilesctl set power-saver') end},
            {'⚡ Balanced', function() awful.spawn('powerprofilesctl set balanced') end},
            {'🔥 Performance', function() awful.spawn('powerprofilesctl set performance') end}
        }
    else
        return {
            {'⚠️ No power manager found', function() end}
        }
    end
end

local powerprofile_menu = awful.menu({
    items = get_power_commands()
})

local powerprofile_widget = wibox.widget.textbox()

-- Battery info function
local function get_battery_info()
    local handle = io.popen('upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null')
    local result = handle:read("*a")
    handle:close()

    local percentage = result:match("percentage:%s+(%d+)")
    local hours_str = result:match("time to empty:%s+([%d,%.]+)%s+hours")

    local time_str = "N/A"
    if hours_str then
        hours_str = hours_str:gsub(",", ".")
        local hours_decimal = tonumber(hours_str)
        if hours_decimal then
            local hours = math.floor(hours_decimal)
            local minutes = math.floor((hours_decimal - hours) * 60)
            time_str = hours .. "h" .. minutes .. "m"
        end
    end

    if percentage then
        return "🔋 " .. percentage .. "%\n⏱️ " .. time_str
    end
    return "Battery info unavailable"
end

local function update_power_icon()
    if not power_manager then
        powerprofile_widget:set_text('❌')
        return
    end

    local handle = io.popen('system76-power profile 2>/dev/null | head -1')
    local result = handle:read("*a")
    handle:close()

    local icon = '⚡'
    if result:find("Battery") then
        icon = '🔋'
    elseif result:find("Performance") then
        icon = '🔥'
    end

    -- Get battery info
    local battery_info = get_battery_info()
    local percentage = battery_info:match("(%d+)%%")
    local time_str = battery_info:match("⏱️%s+([^\n]+)")

    if percentage and time_str then
        powerprofile_widget:set_text(icon .. ' ' .. percentage .. '% ' .. time_str)
    else
        powerprofile_widget:set_text(icon)
    end
end

update_power_icon()

-- Poll power profile and battery every 2 seconds
gears.timer({
    timeout = 2,
    autostart = true,
    callback = function()
        update_power_icon()
    end
})

powerprofile_widget:buttons(gears.table.join(
    awful.button({}, 1, function()
        powerprofile_menu:toggle()
    end),
    awful.button({}, 3, function()
        update_power_icon()
    end)
))

-- Audio control widget
local audio_widget = wibox.widget.textbox()
audio_widget:set_text('🔊')

local function get_volume()
    local handle = io.popen('pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null')
    local result = handle:read("*a")
    handle:close()

    local volume = tonumber(result:match("(%d+)%%"))
    return math.floor(volume or 0)
end

local function is_muted()
    local handle = io.popen('pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null')
    local result = handle:read("*a")
    handle:close()

    return result:find("yes") ~= nil
end

local function update_audio_icon()
    if is_muted() then
        audio_widget:set_text('🔇')
    else
        local vol = get_volume()
        if vol == 0 then
            audio_widget:set_text('🔇')
        elseif vol < 50 then
            audio_widget:set_text('🔉')
        else
            audio_widget:set_text('🔊')
        end
    end
end

update_audio_icon()

-- Audio control - simple mute toggle + scroll volume
audio_widget:buttons(gears.table.join(
    awful.button({}, 1, function()
        awful.spawn('pactl set-sink-mute @DEFAULT_SINK@ toggle')
        update_audio_icon()
    end),
    awful.button({}, 4, function()
        awful.spawn('pactl set-sink-volume @DEFAULT_SINK@ +5%')
        update_audio_icon()
    end),
    awful.button({}, 5, function()
        awful.spawn('pactl set-sink-volume @DEFAULT_SINK@ -5%')
        update_audio_icon()
    end)
))

-- Poll audio state every 1 second
gears.timer({
    timeout = 1,
    autostart = true,
    callback = function()
        update_audio_icon()
    end
})

-- Keyboard backlight widget
local kbd_backlight_widget = wibox.widget.textbox()

local function get_kbd_brightness()
    local f = io.open('/sys/class/leds/tpacpi::kbd_backlight/brightness', 'r')
    if not f then return 0 end
    local val = tonumber(f:read("*a"))
    f:close()
    return val or 0
end

local function update_kbd_icon()
    local brightness = get_kbd_brightness()
    if brightness == 0 then
        kbd_backlight_widget:set_text('☀️')
    else
        kbd_backlight_widget:set_text('🌙')
    end
end

update_kbd_icon()

-- Keyboard backlight control
kbd_backlight_widget:buttons(gears.table.join(
    awful.button({}, 1, function()
        local brightness = get_kbd_brightness()
        local new_brightness = (brightness == 0) and 1 or 0
        awful.spawn('sudo /home/jsfernandez/.config/awesome/kbd-backlight.sh ' .. new_brightness)
        update_kbd_icon()
    end),
    awful.button({}, 4, function()
        local brightness = get_kbd_brightness()
        if brightness < 2 then
            awful.spawn('sudo /home/jsfernandez/.config/awesome/kbd-backlight.sh ' .. (brightness + 1))
            update_kbd_icon()
        end
    end),
    awful.button({}, 5, function()
        local brightness = get_kbd_brightness()
        if brightness > 0 then
            awful.spawn('sudo /home/jsfernandez/.config/awesome/kbd-backlight.sh ' .. (brightness - 1))
            update_kbd_icon()
        end
    end)
))

-- Poll keyboard backlight state every 2 seconds
gears.timer({
    timeout = 2,
    autostart = true,
    callback = function()
        update_kbd_icon()
    end
})

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock()

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
    awful.button({}, 1, function(t) t:view_only() end),
    awful.button({modkey}, 1, function(t)
        if client.focus then
            client.focus:move_to_tag(t)
        end
    end),
    awful.button({}, 3, awful.tag.viewtoggle),
    awful.button({modkey}, 3, function(t)
        if client.focus then
            client.focus:toggle_tag(t)
        end
    end),
    awful.button({}, 4, function(t) awful.tag.viewnext(t.screen) end),
    awful.button({}, 5, function(t) awful.tag.viewprev(t.screen) end)
)

local tasklist_buttons = gears.table.join(
    awful.button({}, 1, function(c)
        if c == client.focus then
            c.minimized = true
        else
            c.minimized = false
            if not c:isvisible() and c.first_tag then
                c.first_tag:view_only()
            end
            client.focus = c
            c:raise()
        end
    end),
    awful.button({}, 3, client_menu_toggle_fn()),
    awful.button({}, 4, function() awful.client.focus.byidx(1) end),
    awful.button({}, 5, function() awful.client.focus.byidx(-1) end)
)

function set_wallpaper(s)
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        if type(wallpaper) == 'function' then
            wallpaper = wallpaper(s)
        end
        -- If wallpaper is a string, check if it's a color or file path
        if type(wallpaper) == 'string' then
            if wallpaper:find('^#') or not wallpaper:find('/') then
                -- It's a color name or hex code
                gears.wallpaper.set(wallpaper)
            else
                -- It's a file path
                gears.wallpaper.maximized(wallpaper, s, true)
            end
        else
            gears.wallpaper.maximized(wallpaper, s, true)
        end
    end
end

-- Re-set wallpaper when a screen's geometry changes
screen.connect_signal('property::geometry', set_wallpaper)

-- Load theme overrides after set_wallpaper is defined
reload_theme_overrides()

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table
    local layout = awful.layout.layouts[1]
    if s.geometry.width < s.geometry.height then
        layout = awful.layout.layouts[3]
    end
    awful.tag({'1', '2', '3', '4', '5', '6', '7', '8', '9'}, s, layout)

    -- Create widgets for each screen
    s.mypromptbox = awful.widget.prompt()
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({}, 1, function() awful.layout.inc(1) end),
        awful.button({}, 3, function() awful.layout.inc(-1) end),
        awful.button({}, 4, function() awful.layout.inc(1) end),
        awful.button({}, 5, function() awful.layout.inc(-1) end)
    ))

    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, tasklist_buttons)

    -- Create the wibox
    s.mywibox = awful.wibar({position = 'top', screen = s, bg = beautiful.bg_normal})

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            wibox.widget.textbox('Screen: <b>' .. s.index .. '</b> '),
            s.mytaglist,
            s.mypromptbox
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
            wibox.widget.systray(),
            brightness_widget,
            kbd_backlight_widget,
            audio_widget,
            wibox.widget.textbox(" | "),
            powerprofile_widget,
            wibox.widget.textbox(" | "),
            mytextclock,
            s.mylayoutbox
        }
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({}, 3, function() mymainmenu:toggle() end),
    awful.button({}, 4, awful.tag.viewnext),
    awful.button({}, 5, awful.tag.viewprev)
))
-- }}}

-- Original simple run function
local function run()
    awful.screen.focused().mypromptbox:run()
end

-- Rofi application launcher
local function rofi_launcher()
    awful.spawn('rofi -show drun')
end

-- {{{ Key bindings
local globalkeys = gears.table.join(
    awful.key({modkey}, 'F1', hotkeys_popup.show_help, {description = 'show help', group = 'awesome'}),
    awful.key({modkey}, 'Left', awful.tag.viewprev, {description = 'view previous', group = 'tag'}),
    awful.key({modkey}, 'Right', awful.tag.viewnext, {description = 'view next', group = 'tag'}),
    awful.key({modkey}, 'Escape', awful.tag.history.restore, {description = 'go back', group = 'tag'}),
    awful.key({modkey}, 'j', function() awful.client.focus.byidx(1) end,
        {description = 'focus next by index', group = 'client'}),
    awful.key({modkey}, 'k', function() awful.client.focus.byidx(-1) end,
        {description = 'focus previous by index', group = 'client'}),
    awful.key({modkey}, 'q', function() awful.spawn('qutebrowser') end,
        {description = 'execute browser', group = 'awesome'}),
    awful.key({modkey}, 'w', function() mymainmenu:show() end,
        {description = 'show main menu', group = 'awesome'}),

    -- Layout manipulation
    awful.key({modkey, 'Shift'}, 'j', function() awful.client.swap.byidx(1) end,
        {description = 'swap with next client by index', group = 'client'}),
    awful.key({modkey, 'Shift'}, 'k', function() awful.client.swap.byidx(-1) end,
        {description = 'swap with previous client by index', group = 'client'}),
    awful.key({modkey, 'Control'}, 'j', function() awful.screen.focus_relative(1) end,
        {description = 'focus the next screen', group = 'screen'}),
    awful.key({modkey, 'Control'}, 'k', function() awful.screen.focus_relative(-1) end,
        {description = 'focus the previous screen', group = 'screen'}),
    awful.key({modkey}, 'u', awful.client.urgent.jumpto, {description = 'jump to urgent client', group = 'client'}),
    awful.key({modkey}, 'Tab', function()
        awful.client.focus.history.previous()
        if client.focus then client.focus:raise() end
    end, {description = 'go back', group = 'client'}),

    -- Screen lock and layouts
    awful.key({modkey}, 'Scroll_Lock', function() lock_screen() end,
        {description = 'lock the screen', group = 'screen'}),
    awful.key({modkey}, 'F3', function() awful.spawn('xrandr_detached_layout') end,
        {description = 'switch to detached layout', group = 'screen'}),
    awful.key({modkey}, 'F2', function() awful.spawn('xrandr_office_layout') end,
        {description = 'switch to office layout', group = 'screen'}),

    -- Standard program
    awful.key({modkey}, 'Return', function() awful.spawn(terminal) end,
        {description = 'open a terminal', group = 'launcher'}),
    awful.key({modkey, 'Control'}, 'r', awesome.restart, {description = 'reload awesome', group = 'awesome'}),

    -- Quake Terminal
    awful.key({}, 'F12', toggle_quake_terminal, {description = 'toggle quake terminal', group = 'launcher'}),
    awful.key({modkey}, 'grave', toggle_quake_terminal, {description = 'toggle quake terminal', group = 'launcher'}),

    -- Layout controls
    awful.key({modkey}, 'l', function() awful.tag.incmwfact(0.05) end,
        {description = 'increase master width factor', group = 'layout'}),
    awful.key({modkey}, 'h', function() awful.tag.incmwfact(-0.05) end,
        {description = 'decrease master width factor', group = 'layout'}),
    awful.key({modkey, 'Shift'}, 'h', function() awful.tag.incnmaster(1, nil, true) end,
        {description = 'increase the number of master clients', group = 'layout'}),
    awful.key({modkey, 'Shift'}, 'l', function() awful.tag.incnmaster(-1, nil, true) end,
        {description = 'decrease the number of master clients', group = 'layout'}),
    awful.key({modkey, 'Control'}, 'h', function() awful.tag.incncol(1, nil, true) end,
        {description = 'increase the number of columns', group = 'layout'}),
    awful.key({modkey, 'Control'}, 'l', function() awful.tag.incncol(-1, nil, true) end,
        {description = 'decrease the number of columns', group = 'layout'}),
    awful.key({modkey}, 'space', function() awful.layout.inc(1) end,
        {description = 'select next', group = 'layout'}),
    awful.key({modkey, 'Shift'}, 'space', function() awful.layout.inc(-1) end,
        {description = 'select previous', group = 'layout'}),
    awful.key({modkey, 'Control'}, 'n', function()
        local c = awful.client.restore()
        if c then
            client.focus = c
            c:raise()
        end
    end, {description = 'restore minimized', group = 'client'}),

    -- Notifications toggle
    awful.key({modkey}, ',', function()
        if naughty.is_suspended() then
            naughty.resume()
            naughty.notify({
                preset = naughty.config.presets.info,
                title = 'naughty',
                text = 'Notifications are back!'
            })
        else
            naughty.notify({
                preset = naughty.config.presets.info,
                title = 'naughty',
                text = 'Notifications are suspended!'
            })
            naughty.suspend()
        end
    end, {description = 'toggle notifications', group = 'awesome'}),

    -- Brightness control (Function keys)
    awful.key({}, 'XF86MonBrightnessUp', function()
        awful.spawn('sudo brightnessctl set +10%')
    end, {description = 'increase brightness', group = 'awesome'}),
    awful.key({}, 'XF86MonBrightnessDown', function()
        awful.spawn('sudo brightnessctl set 10%-')
    end, {description = 'decrease brightness', group = 'awesome'}),

    -- Prompt and launcher
    awful.key({modkey}, 'r', run, {description = 'run prompt', group = 'launcher'}),
    awful.key({modkey}, '.', rofi_launcher, {description = 'rofi application launcher', group = 'launcher'}),
    --awful.key({modkey}, '.', app_launcher, {description = 'application launcher', group = 'launcher'}),
    awful.key({modkey, 'Control'}, '.', function() menubar.show() end, {description = 'show the menubar', group = 'launcher'}),
    awful.key({modkey}, 'x', function()
        awful.prompt.run {
            prompt = 'Run Lua code: ',
            textbox = awful.screen.focused().mypromptbox.widget,
            exe_callback = awful.util.eval,
            history_path = awful.util.get_cache_dir() .. '/history_eval',
            completion_callback = awful.completion.shell
        }
    end, {description = 'lua execute prompt', group = 'awesome'})
)

local clientkeys = gears.table.join(
    awful.key({modkey}, 'f', function(c)
        c.fullscreen = not c.fullscreen
        c:raise()
    end, {description = 'toggle fullscreen', group = 'client'}),
    awful.key({modkey, 'Shift'}, 'c', function(c) c:kill() end,
        {description = 'close', group = 'client'}),
    awful.key({modkey, 'Control'}, 'space', awful.client.floating.toggle,
        {description = 'toggle floating', group = 'client'}),
    awful.key({modkey, 'Control'}, 'Return', function(c) c:swap(awful.client.getmaster()) end,
        {description = 'move to master', group = 'client'}),
    awful.key({modkey}, 'o', function(c) c:move_to_screen() end,
        {description = 'move to next screen', group = 'client'}),
    awful.key({modkey, 'Shift'}, 'o', function(c) c:move_to_screen(c.screen.index - 1) end,
        {description = 'move to previous screen', group = 'client'}),
    awful.key({modkey}, 't', function(c) c.ontop = not c.ontop end,
        {description = 'toggle keep on top', group = 'client'}),
    awful.key({modkey}, 's', function(c) c.sticky = not c.sticky end,
        {description = 'toggle sticky', group = 'client'}),
    awful.key({modkey}, 'n', function(c) c.minimized = true end,
        {description = 'minimize', group = 'client'}),
    awful.key({modkey}, 'm', function(c)
        c.maximized = not c.maximized
        c:raise()
    end, {description = 'maximize', group = 'client'})
)

-- Bind all key numbers to tags
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only
        awful.key({modkey}, '#' .. i + 9, function()
            local screen = awful.screen.focused()
            local tag = screen.tags[i]
            if tag then tag:view_only() end
        end, {description = 'view tag #' .. i, group = 'tag'}),

        -- Toggle tag display
        awful.key({modkey, 'Control'}, '#' .. i + 9, function()
            local screen = awful.screen.focused()
            local tag = screen.tags[i]
            if tag then awful.tag.viewtoggle(tag) end
        end, {description = 'toggle tag #' .. i, group = 'tag'}),

        -- Move client to tag
        awful.key({modkey, 'Shift'}, '#' .. i + 9, function()
            if client.focus then
                local tag = client.focus.screen.tags[i]
                if tag then client.focus:move_to_tag(tag) end
            end
        end, {description = 'move focused client to tag #' .. i, group = 'tag'}),

        -- Toggle tag on focused client
        awful.key({modkey, 'Control', 'Shift'}, '#' .. i + 9, function()
            if client.focus then
                local tag = client.focus.screen.tags[i]
                if tag then client.focus:toggle_tag(tag) end
            end
        end, {description = 'toggle focused client on tag #' .. i, group = 'tag'})
    )
end

clientbuttons = gears.table.join(
    awful.button({}, 1, function(c)
        client.focus = c
        c:raise()
    end),
    awful.button({modkey}, 1, awful.mouse.client.move),
    awful.button({modkey}, 3, awful.mouse.client.resize)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule
    {
        rule = {},
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus = awful.client.focus.filter,
            raise = true,
            keys = clientkeys,
            buttons = clientbuttons,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap + awful.placement.no_offscreen
        }
    },
    -- Floating clients
    {
        rule_any = {
            instance = {
                'DTA', -- Firefox addon DownThemAll
                'copyq' -- Includes session name in class
            },
            class = {
                'Arandr', 'Gpick', 'kruler', 'MessageWin', 'Sxiv',
                'Wpa_gui', 'pinentry', 'veromix', 'xtightvncviewer'
            },
            name = {
                'Event Tester', -- xev
                'Control Bar ' -- Squish Control Bar
            },
            role = {
                'AlarmWindow', -- Thunderbird's calendar
                'pop-up' -- e.g. Google Chrome's (detached) Developer Tools
            }
        },
        properties = {floating = true}
    },
    -- Quake terminal rule
    {
        rule = {name = 'QuakeTerminal'},
        properties = {
            floating = true,
            ontop = true,
            sticky = true,
            skip_taskbar = true,
            titlebars_enabled = false
        }
    },
    -- Add titlebars to normal clients and dialogs
    {
        rule_any = {type = {'normal', 'dialog'}},
        properties = {titlebars_enabled = false}
    }
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears
client.connect_signal('manage', function(c)
    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules
client.connect_signal('request::titlebars', function(c)
    local buttons = gears.table.join(
        awful.button({}, 1, function()
            client.focus = c
            c:raise()
            awful.mouse.client.move(c)
        end),
        awful.button({}, 3, function()
            client.focus = c
            c:raise()
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c):setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align = 'center',
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton(c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton(c),
            awful.titlebar.widget.ontopbutton(c),
            awful.titlebar.widget.closebutton(c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus
client.connect_signal('mouse::enter', function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier and awful.client.focus.filter(c) then
        client.focus = c
    end
end)

client.connect_signal('focus', function(c)
    c.border_color = beautiful.border_focus
end)

client.connect_signal('unfocus', function(c)
    c.border_color = beautiful.border_normal
end)
-- }}}

-- Start applications only on initial startup, not on reload
if awesome.startup then
    autostart()
end
