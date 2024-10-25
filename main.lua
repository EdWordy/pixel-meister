-- PIXEL MEISTER
--------------------------------
-- mit license
-- taylor edwards
-- 2024
--------------------------------

-- this program is meant to provide a simple pixel art interface, uncomplicated and unrestrained, for uninhibited creativity.

-- setup --------

Core = require("src.core")

function love.conf(t)
    -- properties
    t.window.width = 900
    t.window.height = 600
    -- unused modules
    t.modules.joystick = false
    t.modules.physics = false
end

-- loading --------

function love.load()
    Core.load()
end

-- rendering --------

function love.update(dt)
    Core.update(dt)
end

function love.draw()
    Core.draw()
end

-- input handling --------

function love.mousepressed(x, y, button)
    Core.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    Core.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    Core.mousemoved(x, y, dx, dy)
end

function love.keypressed(key, scancode, isrepeat)
    Core.keypressed(key, scancode, isrepeat)
end

-- cleanup --------