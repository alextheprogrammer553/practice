@@ -1,26 +1,32 @@

local love11 = love.getVersion() == 11
local getDPI = love11 and love.window.getDPIScale or love.window.getPixelScale
local windowUpdateMode = love11 and love.window.updateMode or function(width, height, settings)
  local _, _, flags = love.window.getMode()
  for k, v in pairs(settings) do flags[k] = v end
  love.window.setMode(width, height, flags)
end

local push = {

  defaults = {
    fullscreen = false,
    resizable = false,
    pixelperfect = false,
    highdpi = true,
    canvas = true
    canvas = true,
    stencil = true
  }

}
setmetatable(push, push)


function push:applySettings(settings)
  for k, v in pairs(settings) do
    self["_" .. k] = v
@@ -39,11 +45,11 @@ function push:setupScreen(WWIDTH, WHEIGHT, RWIDTH, RHEIGHT, settings)
  self:applySettings(self.defaults) --set defaults first
  self:applySettings(settings) --then fill with custom settings

  love.window.setMode( self._RWIDTH, self._RHEIGHT, {
  windowUpdateMode(self._RWIDTH, self._RHEIGHT, {
    fullscreen = self._fullscreen,
    resizable = self._resizable,
    highdpi = self._highdpi
  } )
  })

  self:initValues()

@@ -62,25 +68,31 @@ function push:setupScreen(WWIDTH, WHEIGHT, RWIDTH, RHEIGHT, settings)
end

function push:setupCanvas(canvases)
  table.insert(canvases, { name = "_render" }) --final render
  table.insert(canvases, { name = "_render", private = true }) --final render

  self._canvas = true
  self.canvases = {}

  for i = 1, #canvases do
    self.canvases[i] = {
      name = canvases[i].name,
      shader = canvases[i].shader,
      canvas = love.graphics.newCanvas(self._WWIDTH, self._WHEIGHT)
    }
    push:addCanvas(canvases[i])
  end

  return self
end
function push:addCanvas(params)
  table.insert(self.canvases, {
    name = params.name,
    private = params.private,
    shader = params.shader,
    canvas = love.graphics.newCanvas(self._WWIDTH, self._WHEIGHT),
    stencil = params.stencil or self._stencil
  })
end

function push:setCanvas(name)
  if not self._canvas then return true end
  return love.graphics.setCanvas( self:getCanvasTable(name).canvas )
  local canvasTable = self:getCanvasTable(name)
  return love.graphics.setCanvas({ canvasTable.canvas, stencil = canvasTable.stencil })
end
function push:getCanvasTable(name)
  for i = 1, #self.canvases do
@@ -98,7 +110,7 @@ function push:setShader(name, shader)
end

function push:initValues()
  self._PSCALE = self._highdpi and love.window.getPixelScale() or 1
  self._PSCALE = (not love11 and self._highdpi) and getDPI() or 1

  self._SCALE = {
    x = self._RWIDTH/self._WWIDTH * self._PSCALE,
@@ -119,19 +131,15 @@ function push:initValues()
  self._GHEIGHT = self._RHEIGHT * self._PSCALE - self._OFFSET.y * 2
end

function push:apply(operation, shader)
  if operation == "start" then
    self:start()
  elseif operation == "finish" or operation == "end" then
    self:finish(shader)
  end
  self._drawFunctions[operation](self, shader)
end

function push:start()
  if self._canvas then
    love.graphics.push()
    love.graphics.setCanvas(self.canvases[1].canvas)
    love.graphics.setCanvas({ self.canvases[1].canvas, stencil = self.canvases[1].stencil })

  else
    love.graphics.translate(self._OFFSET.x, self._OFFSET.y)
    love.graphics.setScissor(self._OFFSET.x, self._OFFSET.y, self._WWIDTH*self._SCALE.x, self._WHEIGHT*self._SCALE.y)
@@ -140,32 +148,73 @@ function push:start()
  end
end

function push:applyShaders(canvas, shaders)
  local _shader = love.graphics.getShader()
  if #shaders <= 1 then
    love.graphics.setShader(shaders[1])
    love.graphics.draw(canvas)
  else
    local _canvas = love.graphics.getCanvas()

    local _tmp = self:getCanvasTable("_tmp")
    if not _tmp then --create temp canvas only if needed
      self:addCanvas({ name = "_tmp", private = true, shader = nil })
      _tmp = self:getCanvasTable("_tmp")
    end

    love.graphics.push()
    love.graphics.origin()
    local outputCanvas
    for i = 1, #shaders do
      local inputCanvas = i % 2 == 1 and canvas or _tmp.canvas
      outputCanvas = i % 2 == 0 and canvas or _tmp.canvas
      love.graphics.setCanvas(outputCanvas)
      love.graphics.clear()
      love.graphics.setShader(shaders[i])
      love.graphics.draw(inputCanvas)
      love.graphics.setCanvas(inputCanvas)
    end
    love.graphics.pop()

    love.graphics.setCanvas(_canvas)
    love.graphics.draw(outputCanvas)
  end
  love.graphics.setShader(_shader)
end

function push:finish(shader)
  love.graphics.setBackgroundColor(unpack(self._borderColor))
  if self._canvas then
    local _render = self:getCanvasTable("_render")

    love.graphics.pop()

    love.graphics.setColor(255, 255, 255)
    local white = love11 and 1 or 255
    love.graphics.setColor(white, white, white)

    --draw canvas
    love.graphics.setCanvas(_render.canvas)
    for i = 1, #self.canvases - 1 do --do not draw _render yet
    for i = 1, #self.canvases do --do not draw _render yet
      local _table = self.canvases[i]
      love.graphics.setShader(_table.shader)
      love.graphics.draw(_table.canvas)
      if not _table.private then
        local _canvas = _table.canvas
        local _shader = _table.shader
        self:applyShaders(_canvas, type(_shader) == "table" and _shader or { _shader })
      end
    end
    love.graphics.setCanvas()

    
    --draw render
    love.graphics.translate(self._OFFSET.x, self._OFFSET.y)
    love.graphics.setShader(shader or self:getCanvasTable("_render").shader)
    love.graphics.draw(self:getCanvasTable("_render").canvas, 0, 0, 0, self._SCALE.x, self._SCALE.y)
    local shader = shader or _render.shader
    love.graphics.push()
    love.graphics.scale(self._SCALE.x, self._SCALE.y)
    self:applyShaders(_render.canvas, type(shader) == "table" and shader or { shader })
    love.graphics.pop()

    for i = 1, #self.canvases do
      love.graphics.setCanvas( self.canvases[i].canvas )
      love.graphics.setCanvas(self.canvases[i].canvas)
      love.graphics.clear()
    end

@@ -193,7 +242,7 @@ end

--doesn't work - TODO
function push:toReal(x, y)
  return x+self._OFFSET.x, y+self._OFFSET.y
  return x + self._OFFSET.x, y + self._OFFSET.y
end

function push:switchFullscreen(winw, winh)
@@ -213,13 +262,12 @@ function push:switchFullscreen(winw, winh)

  love.window.setFullscreen(self._fullscreen, "desktop")
  if not self._fullscreen and (winw or winh) then
    love.window.setMode(self._RWIDTH, self._RHEIGHT) --set window dimensions
    windowUpdateMode(self._RWIDTH, self._RHEIGHT) --set window dimensions
  end
end

function push:resize(w, h)
  local pixelScale = love.window.getPixelScale()
  if self._highdpi then w, h = w / pixelScale, h / pixelScale end
  if self._highdpi then w, h = w / self._PSCALE, h / self._PSCALE end
  self._RWIDTH = w
  self._RHEIGHT = h
  self:initValues()