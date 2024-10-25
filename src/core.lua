-- setup --------

local core = {}
local Button = require("src.ui.button")
local json = require("libs.json")

-- global vars --------

local canvasWidth, canvasHeight = 900, 600  -- Default canvas size
local layers = {}
local layerProperties = {}  -- New table to store layer properties
local buttons = {top = {}, bottom = {}}
local currentBrushSize = 10
local isDrawing = false
local currentLayer = 1
local currentTool = "brush"
local lastX, lastY

local minBrushSize = 1
local maxBrushSize = 50

local undoStack = {}
local maxUndoSteps = 20

-- Color palette
local colorPalette = {
    {0, 0, 0},     -- Black
    {1, 1, 1},     -- White
    {1, 0, 0},     -- Red
    {0, 1, 0},     -- Green
    {0, 0, 1},     -- Blue
    {1, 1, 0},     -- Yellow
    {1, 0, 1},     -- Magenta
    {0, 1, 1}      -- Cyan
}
local currentColorIndex = 1

-- loading --------

function core.load()
    -- Top toolbar buttons
    buttons.top.brush = Button.new(10, 0, 64, 64, "assets/icons/brush.png", function() currentTool = "brush" end)
    buttons.top.eraser = Button.new(86, 0, 64, 64, "assets/icons/eraser.png", function() currentTool = "eraser" end)
    
    -- Bottom toolbar buttons
    buttons.bottom.clearCanvas = Button.new(10, love.graphics.getHeight() - 64, 64, 64, "assets/icons/clear.png", function()
        clearAllLayers()
    end)
    buttons.bottom.newLayer = Button.new(86, love.graphics.getHeight() - 64, 64, 64, "assets/icons/new_layer.png", function()
        addNewLayer()
    end)
    buttons.bottom.deleteLayer = Button.new(162, love.graphics.getHeight() - 64, 64, 64, "assets/icons/delete_layer.png", function()
        deleteCurrentLayer()
    end)
    buttons.bottom.prevLayer = Button.new(238, love.graphics.getHeight() - 64, 64, 64, "assets/icons/prev_layer.png", function()
        currentLayer = math.max(1, currentLayer - 1)
    end)
    buttons.bottom.nextLayer = Button.new(314, love.graphics.getHeight() - 64, 64, 64, "assets/icons/next_layer.png", function()
        currentLayer = math.min(#layers, currentLayer + 1)
    end)
    buttons.bottom.undo = Button.new(390, love.graphics.getHeight() - 64, 64, 64, "assets/icons/undo.png", function()
        undo()
    end)
    
    addNewLayer()
end

-- rendering --------

function core.update(dt)
    if isDrawing then
        local x, y = love.mouse.getPosition()
        if not isClickOnUI(x, y) then
            x, y = x - 0, y - 64  -- Adjust for canvas position
            if lastX and lastY then
                interpolateAndDraw(lastX, lastY, x, y)
            else
                drawOnLayer(x, y)
            end
            lastX, lastY = x, y
        end
    end
end

function core.draw()
    love.graphics.setBackgroundColor(1, 1, 1)
    
    -- Draw all layers
    for _, layer in ipairs(layers) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(layer, 0, 64)
    end
    
    drawUI()
    drawCursor()
end

-- input handling --------

function core.mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        if isClickOnUI(x, y) then
            handleUIClick(x, y)
        else
            startNewStroke(x - 0, y - 64)  -- Adjust for canvas position
        end
    end
end

function core.mousereleased(x, y, button)
    if button == 1 then 
        isDrawing = false
        lastX, lastY = nil, nil
    end
end

function core.mousemoved(x, y, dx, dy)
    if isDrawing and not isClickOnUI(x, y) then
        x, y = x - 0, y - 64  -- Adjust for canvas position
        if lastX and lastY then
            interpolateAndDraw(lastX, lastY, x, y)
        else
            drawOnLayer(x, y)
        end
        lastX, lastY = x, y
    end
end

function core.keypressed(key, scancode, isrepeat)
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        if key == "s" then
            core.saveProject("project.json")
            print("Project saved successfully!")
        elseif key == "o" then
            core.loadProject("project.json")
            print("Project loaded successfully!")
        elseif key == "e" then
            core.exportImage("exported_image.png")
            print("Image exported successfully!")
        elseif key == "z" then
            undo()
        end
    elseif key == "]" then
        increaseBrushSize()
    elseif key == "[" then
        decreaseBrushSize()
    end
end

-- helper functions --------

function isClickOnUI(x, y)
    return y < 64 or y > love.graphics.getHeight() - 64
end

function handleUIClick(x, y)
    for _, btn in pairs(buttons.top) do
        if btn:isClicked(x, y) then
            btn.onClick()
            return
        end
    end
    for _, btn in pairs(buttons.bottom) do
        if btn:isClicked(x, y) then
            btn.onClick()
            return
        end
    end
    -- Color palette selection
    local paletteX = love.graphics.getWidth() - 274
    local paletteY = 0
    for i, _ in ipairs(colorPalette) do
        if x >= paletteX + (i-1)*30 and x < paletteX + i*30 and y >= paletteY and y < paletteY + 64 then
            currentColorIndex = i
            return
        end
    end
end

function startNewStroke(x, y)
    addUndoStep()
    isDrawing = true
    lastX, lastY = x, y
    drawOnLayer(x, y)
end

function interpolateAndDraw(x1, y1, x2, y2)
    local dist = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    local steps = math.floor(dist / (currentBrushSize / 4))  -- Adjust this value to control smoothness
    
    for i = 0, steps do
        local t = i / steps
        local x = x1 + (x2 - x1) * t
        local y = y1 + (y2 - y1) * t
        drawOnLayer(x, y)
    end
end

function drawOnLayer(x, y)
    layers[currentLayer]:renderTo(function()
        if currentTool == "brush" then
            love.graphics.setColor(colorPalette[currentColorIndex])
            love.graphics.circle("fill", x, y, currentBrushSize / 2)
        elseif currentTool == "eraser" then
            love.graphics.setBlendMode("replace")
            love.graphics.setColor(0, 0, 0, 0)  -- Transparent
            love.graphics.circle("fill", x, y, currentBrushSize / 2)
            love.graphics.setBlendMode("alpha")
        end
    end)
end

function drawUI()
    -- Top toolbar
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 64)
    for _, btn in pairs(buttons.top) do btn:draw() end
    
    -- Color palette
    local paletteX = love.graphics.getWidth() - 274
    local paletteY = 0
    for i, color in ipairs(colorPalette) do
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", paletteX + (i-1)*30, paletteY, 30, 64)
        if i == currentColorIndex then
            love.graphics.setColor(1, 1, 1, 0.5)  -- Semi-transparent white
            love.graphics.rectangle("fill", paletteX + (i-1)*30, paletteY, 30, 64)
        end
    end
    
    -- Bottom toolbar
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 0, love.graphics.getHeight() - 64, love.graphics.getWidth(), 64)
    for _, btn in pairs(buttons.bottom) do btn:draw() end
    
    -- Display current brush size, tool, and layer
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Brush Size: " .. currentBrushSize, love.graphics.getWidth() - 200, love.graphics.getHeight() - 60)
    love.graphics.print("Current Tool: " .. currentTool, love.graphics.getWidth() - 200, love.graphics.getHeight() - 40)
    love.graphics.print("Current Layer: " .. currentLayer .. "/" .. #layers, love.graphics.getWidth() - 200, love.graphics.getHeight() - 20)
end

function drawCursor()
    love.graphics.setColor(colorPalette[currentColorIndex])
    love.graphics.circle("line", love.mouse.getX(), love.mouse.getY(), currentBrushSize / 2)
end

function addNewLayer()
    local newCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    newCanvas:renderTo(function()
        love.graphics.clear()
    end)
    table.insert(layers, newCanvas)
    table.insert(layerProperties, {
        visible = true,
        opacity = 1,
        blendMode = "alpha"
    })
    currentLayer = #layers
end

function clearAllLayers()
    addUndoStep()
    for i, layer in ipairs(layers) do
        layer:renderTo(function()
            love.graphics.clear()
        end)
    end
end

function deleteCurrentLayer()
    addUndoStep()
    if #layers > 1 then
        table.remove(layers, currentLayer)
        table.remove(layerProperties, currentLayer)
        currentLayer = math.min(currentLayer, #layers)
    else
        -- If it's the last layer, clear it instead of deleting
        layers[1]:renderTo(function()
            love.graphics.clear()
        end)
    end
end

function increaseBrushSize()
    currentBrushSize = math.min(maxBrushSize, currentBrushSize + 1)
end

function decreaseBrushSize()
    currentBrushSize = math.max(minBrushSize, currentBrushSize - 1)
end

function addUndoStep()
    local currentState = {}
    for i, layer in ipairs(layers) do
        currentState[i] = layer:newImageData()
    end
    table.insert(undoStack, currentState)
    if #undoStack > maxUndoSteps then
        table.remove(undoStack, 1)
    end
end

function undo()
    if #undoStack > 0 then
        local previousState = table.remove(undoStack)
        for i, layerData in ipairs(previousState) do
            layers[i] = love.graphics.newCanvas(canvasWidth, canvasHeight)
            layers[i]:renderTo(function()
                love.graphics.draw(love.graphics.newImage(layerData), 0, 0)
            end)
        end
    end
end

function core.saveProject(filename)
    local projectData = {
        layers = {},
        layerProperties = layerProperties,
        canvasWidth = canvasWidth,
        canvasHeight = canvasHeight
    }
    
    for i, layer in ipairs(layers) do
        local imageData = layer:newImageData()
        projectData.layers[i] = love.data.encode("string", "base64", imageData:encode("png"))
    end
    
    local jsonString = json.encode(projectData)
    love.filesystem.write(filename, jsonString)
end

function core.loadProject(filename)
    if not love.filesystem.getInfo(filename) then
        print("No saved project found.")
        return
    end

    local jsonString = love.filesystem.read(filename)
    local projectData = json.decode(jsonString)
    
    canvasWidth = projectData.canvasWidth
    canvasHeight = projectData.canvasHeight
    layerProperties = projectData.layerProperties
    
    layers = {}
    for i, encodedImageData in ipairs(projectData.layers) do
        local decodedImageData = love.data.decode("string", "base64", encodedImageData)
        local imageData = love.image.newImageData(love.filesystem.newFileData(decodedImageData, "layer" .. i .. ".png"))
        local newCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
        newCanvas:renderTo(function()
            love.graphics.draw(love.graphics.newImage(imageData), 0, 0)
        end)
        table.insert(layers, newCanvas)
    end
    
    currentLayer = 1
end

function core.exportImage(filename)
    local finalCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    finalCanvas:renderTo(function()
        love.graphics.clear(1, 1, 1, 0) -- Clear with transparent background
        for i, layer in ipairs(layers) do
            local props = layerProperties[i]
            if props.visible then
                love.graphics.setBlendMode(props.blendMode)
                love.graphics.setColor(1, 1, 1, props.opacity)
                love.graphics.draw(layer, 0, 0)
            end
        end
    end)
    
    local imageData = finalCanvas:newImageData()
    imageData:encode("png", filename)
end

return core