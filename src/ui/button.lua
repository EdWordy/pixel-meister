local Button = {}
Button.__index = Button

function Button.new(x, y, width, height, iconPath, onClick)
    local self = setmetatable({}, Button)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.icon = love.graphics.newImage(iconPath)
    self.onClick = onClick
    self.isHovered = false
    return self
end

function Button:update(mouseX, mouseY)
    self.isHovered = mouseX > self.x and mouseX < self.x + self.width and
                     mouseY > self.y and mouseY < self.y + self.height
end

function Button:draw()
    love.graphics.setColor(self.isHovered and {0.8, 0.8, 0.8} or {0.6, 0.6, 0.6})
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.icon, self.x, self.y)
end

function Button:isClicked(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.height
end

return Button