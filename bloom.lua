local bloom = {}

-- Bloom post-process was removed for now; this module now only captures
-- the original scene and the emissive-only render into canvases for
-- debugging/inspection. Keep the API minimal and deterministic.

function bloom.new(opts)
    opts = opts or {}
    local self = {}
    self.enabled = opts.enabled ~= false
    self.threshold = opts.threshold or 0.8
    -- use blurRadius to control blur amount (pixels). Accept legacy `radius`.
    self.blurRadius = opts.blurRadius or opts.radius or 2.5
    -- blur ping/pong canvases and shader are created after resize below

    -- module only captures emissive into `brightCanvas` and draws it additively

    function self:resize(w,h)
        self.width = w
        self.height = h
        self.brightCanvas = love.graphics.newCanvas(w,h)
        if self._blurA then self._blurA = love.graphics.newCanvas(w,h) end
        if self._blurB then self._blurB = love.graphics.newCanvas(w,h) end
    end

    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    self:resize(w,h)
    -- create ping/pong canvases for blur (now that width/height are known)
    self._blurA = love.graphics.newCanvas(w,h)
    self._blurB = love.graphics.newCanvas(w,h)
    -- load blur shader (fragment-only; use default vertex shader)
    local ok, sh = pcall(love.graphics.newShader, "shader/blur.frag")
    if ok then self._blurShader = sh end

    -- Debug: control whether debugShowBright displays the emissive pass by
    -- rendering into the internal canvas (true) or by switching the shader to
    -- emissive-only and drawing directly to the screen (false).
    self.debugUseCanvas = true

    function self:setDebugUseCanvas(enabled)
        self.debugUseCanvas = enabled and true or false
    end

    function self:getDebugUseCanvas()
        return self.debugUseCanvas
    end

    function self:setEnabled(e)
        self.enabled = e and true or false
    end

    function self:isEnabled()
        return self.enabled
    end

    function self:setBlurRadius(r)
        self.blurRadius = r
    end

    function self:getBlurRadius()
        return self.blurRadius
    end

    function self:setThreshold(v)
        self.threshold = v
    end

    -- Render the scene by running drawFunc into the given target canvas (or
    -- into the internal sceneCanvas by default). Useful for capturing either
    -- the full linear scene or an emissive-only pass.
    function self:renderToScene(drawFunc, target)
        local canvas = target or self.brightCanvas
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0,0,0,0)
        drawFunc()
        love.graphics.setCanvas()
    end
    function self:getBrightCanvas()
        return self.brightCanvas
    end

    local function doBlur(self)
        if not self._blurShader or (not self.blurRadius) or self.blurRadius <= 0 then
            return self.brightCanvas
        end
        -- horizontal pass
        self._blurShader:send("direction", {1.0, 0.0})
        self._blurShader:send("radius", self.blurRadius)
        self._blurShader:send("texelSize", {1.0 / self.width, 1.0 / self.height})
        love.graphics.setCanvas(self._blurA)
        love.graphics.clear(0,0,0,0)
        love.graphics.setShader(self._blurShader)
        love.graphics.draw(self.brightCanvas)
        love.graphics.setShader()
        love.graphics.setCanvas()
        -- vertical pass
        self._blurShader:send("direction", {0.0, 1.0})
        love.graphics.setCanvas(self._blurB)
        love.graphics.clear(0,0,0,0)
        love.graphics.setShader(self._blurShader)
        love.graphics.draw(self._blurA)
        love.graphics.setShader()
        love.graphics.setCanvas()
        return self._blurB
    end

    -- Render emissive-only into `brightCanvas` and additively draw over screen.
    function self:renderEmissiveOverScene(pbrInstance, drawFunc)
        if not self.enabled then return end
        pcall(function() pbrInstance.shader:send("renderEmissiveOnly", 1) end)
        -- When rendering to a Canvas, inform the shader so vertex shader can flip Y
        pcall(function() pbrInstance.shader:send("isCanvasEnabled", 1) end)
        -- capture emissive-only
        self:renderToScene(drawFunc, self.brightCanvas)
        pcall(function() pbrInstance.shader:send("isCanvasEnabled", 0) end)
        pcall(function() pbrInstance.shader:send("renderEmissiveOnly", 0) end)

        -- blur the captured emissive
        local blurred = doBlur(self)

        -- additively composite emissive over current screen
        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(blurred)
        love.graphics.setColor(1,1,1,1)
        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
    end

    -- Debug: clear `brightCanvas` to opaque black, capture emissive-only, and
    -- draw it directly to the screen (no additive blend). Use this to inspect
    -- the raw emissive image and verify orientation/backsides.
    function self:debugShowBright(pbrInstance, drawFunc)
        if not self.enabled then return end
        if self.debugUseCanvas then
            pcall(function() pbrInstance.shader:send("renderEmissiveOnly", 1) end)
            -- Tell shader we're rendering to a Canvas
            pcall(function() pbrInstance.shader:send("isCanvasEnabled", 1) end)
            -- render emissive into brightCanvas
            self:renderToScene(drawFunc, self.brightCanvas)
            pcall(function() pbrInstance.shader:send("isCanvasEnabled", 0) end)
            pcall(function() pbrInstance.shader:send("renderEmissiveOnly", 0) end)

            -- blur then draw the captured emissive canvas directly for inspection
            local blurred = doBlur(self)
            love.graphics.push("all")
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(blurred)
            love.graphics.setColor(1,1,1,1)
            love.graphics.pop()
        else
            -- Switch shader to emissive-only mode and draw directly to screen
            pcall(function() pbrInstance.shader:send("renderEmissiveOnly", 1) end)
            drawFunc()
            pcall(function() pbrInstance.shader:send("renderEmissiveOnly", 0) end)
        end
    end

    return self
end

return bloom
