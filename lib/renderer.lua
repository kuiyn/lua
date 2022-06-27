local Vector3 = Vector3
local draw_Color, draw_Text, draw_TextShadow, draw_Triangle, draw_Line, draw_RoundedRectFill =
    draw.Color,
    draw.Text,
    draw.TextShadow,
    draw.Triangle,
    draw.Line,
    draw.RoundedRectFill
local client_WorldToScreen = client.WorldToScreen
local math_floor, math_abs, math_max, math_min, math_cos, math_sin, math_pi, math_rad =
    math.floor,
    math.abs,
    math.max,
    math.min,
    math.cos,
    math.sin,
    math.pi,
    math.rad

local function color(r, g, b, a)
    draw_Color(
        math_max(math_min(r or 255, 255), 0),
        math_max(math_min(g or 255, 255), 0),
        math_max(math_min(b or 255, 255), 0),
        math_max(math_min(a or 255, 255), 0)
    )
end

local function text(x, y, r, g, b, a, flags, ...)
    local str = ""
    for k, v in pairs({...}) do
        str = str .. v
    end

    local _text = flags:find("s") and draw_TextShadow or draw_Text
    local w, h = draw.GetTextSize(str)

    color(r, g, b, a)
    _text(math_floor(flags:find("c") and x - w * 0.5 or flags:find("r") and x - w or x), math_floor(flags:find("c") and y - h * 0.5 or y), str)
end

local function circle_outline(x, y, r, g, b, a, radius, start_degrees, percentage, thickness, accuracy)
    local ts = radius - thickness
    local pi = math_pi / 180
    local ac = accuracy or 1
    local sa = math_floor(start_degrees)

    color(r, g, b, a)
    for i = sa, math_floor(sa + math_abs(percentage * 360) - ac), ac do
        local cos_1 = math_cos(i * pi)
        local sin_1 = math_sin(i * pi)
        local cos_2 = math_cos((i + ac) * pi)
        local sin_2 = math_sin((i + ac) * pi)

        local xa = x + cos_1 * radius
        local ya = y + sin_1 * radius
        local xb = x + cos_2 * radius
        local yb = y + sin_2 * radius
        local xc = x + cos_1 * ts
        local yc = y + sin_1 * ts
        local xd = x + cos_2 * ts
        local yd = y + sin_2 * ts

        draw_Triangle(xa, ya, xb, yb, xc, yc)
        draw_Triangle(xc, yc, xb, yb, xd, yd)
    end
end

local function circle3d(x, y, z, r, g, b, a, radius, start_degrees, percentage, width, accuracy)
    local ac = accuracy or 1
    local wx, wy = client_WorldToScreen(Vector3(x, y, z))

    color(r, g, b, a)
    local x_line_old, y_line_old
    for i = start_degrees, math_floor(start_degrees + math_abs(percentage * 360) + ac - 1), ac do
        local rot = math_rad(i)
        local x_line, y_line = client_WorldToScreen(Vector3(radius * math_cos(rot) + x, radius * math_sin(rot) + y, z))

        if x_line and x_line_old and wx and wy then
            draw_Triangle(x_line, y_line, x_line_old, y_line_old, wx, wy)

            if width and width ~= 0 then
                for i = 0, width do
                    draw_Line(x_line, y_line - i, x_line_old, y_line_old - i)
                end
            end
        end

        x_line_old, y_line_old = x_line, y_line
    end
end

local function gradient(x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, ltr)
    local sz = ltr and h or w

    for i = 0, math_floor(math_abs(sz)) - 1 do
        local _x = ltr and x or x + i + 0.5
        local _y = ltr and y + i + 0.5 or y

        draw_Color(r1 * (1 - i / sz) + r2 * i / sz, g1 * (1 - i / sz) + g2 * i / sz, b1 * (1 - i / sz) + b2 * i / sz, a1 * (1 - i / sz) + a2 * i / sz)
        draw_Line(_x, _y, _x + (ltr and w or 0), _y + (ltr and 0 or h))
    end
end

local function rounded_gradient(x, y, w, h, radius, r1, g1, b1, a1, r2, g2, b2, a2, tl, tr, bl, br, ltr)
    color(r1, g1, b1, a1)
    if ltr then
        draw_RoundedRectFill(x, y, x + w, y + radius * 2, radius, tl, tr, false, false)
        color(r2, g2, b2, a2)
        draw_RoundedRectFill(x, y + h - radius * 2, x + w, y + h, radius, false, false, bl, br)
        gradient(x, y + radius * 2, w, h - radius * 4, r1, g1, b1, a1, r2, g2, b2, a2, ltr)
    else
        draw_RoundedRectFill(x, y, x + radius * 2, y + h, radius, tl, false, bl, false)
        color(r2, g2, b2, a2)
        draw_RoundedRectFill(x + w - radius * 2, y, x + w, y + h, radius, false, tr, false, br)
        gradient(x + radius * 2, y, w - radius * 4, h, r1, g1, b1, a1, r2, g2, b2, a2, ltr)
    end
end

return {
    text = text,
    circle = function(x, y, r, g, b, a, radius, start_degrees, percentage, accuracy)
        circle_outline(x, y, r, g, b, a, radius, start_degrees, percentage, radius, accuracy)
    end,
    circle_outline = circle_outline,
    circle3d = circle3d,
    gradient = gradient,
    rounded_gradient = rounded_gradient
}
