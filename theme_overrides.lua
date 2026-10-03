local gears = require('gears')

return function(beautiful)
    beautiful.icon_theme = 'Papirus-Dark'
    beautiful.bg_normal = '#FFFFFF00'
    beautiful.bg_focus = '#2EB39855'
    beautiful.fg_focus = 'white'
    beautiful.font = 'Noto Sans Regular 11'
    beautiful.notification_font = 'Noto Sans Regular 11'
    beautiful.notification_icon_size = 64
    beautiful.menu_font = 'Noto Sans Regular 13'
    beautiful.menu_height = 28
    beautiful.menu_width = 200

    beautiful.wallpaper = function(s)
        gears.wallpaper.set("black")
    end
end