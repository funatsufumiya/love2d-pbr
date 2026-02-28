local pbr = {}

local function identity4()
    return {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}
end

local function identity3()
    return {1,0,0, 0,1,0, 0,0,1}
end

function pbr.new(fragPath, vertPath)
    local self = {}
    -- allow omission of shader paths; use defaults if not provided
    if fragPath and type(fragPath) == "userdata" then
        -- caller provided a Shader object
        self.shader = fragPath
    else
        local frag = fragPath or "shader/texture.frag"
        local vert = vertPath or "shader/texture.vert"
        local ok, sh = pcall(love.graphics.newShader, frag, vert)
        if not ok then error(("pbr.new: failed to create shader: %s"):format(tostring(sh))) end
        self.shader = sh
    end
    -- defaults for alpha/transparent handling
    -- use integer flags to avoid GLSL/LÖVE boolean inconsistencies
    pcall(function() self.shader:send("useAlphaMap", 0); self.shader:send("enableTransparency", 0) end)
    self.model = identity4()
    self.normal = identity3()

    function self:setTextures(textures)
        local function loadImage(v)
            if not v then return nil end
            if type(v) == "string" then
                return love.graphics.newImage(v)
            end
            return v
        end

        local albedo = loadImage(textures.albedo)
        local normal = loadImage(textures.normal)
        local metallic = loadImage(textures.metallic)
        local roughness = loadImage(textures.roughness)
        local alpha = loadImage(textures.alpha)
        local ao = loadImage(textures.ao)

        if albedo then self.shader:send("albedoMap", albedo); self.albedo = albedo end
        if normal then self.shader:send("normalMap", normal) end
        if metallic then self.shader:send("metallicMap", metallic) end
        if roughness then self.shader:send("roughnessMap", roughness) end
        if ao then self.shader:send("aoMap", ao) end
        if alpha then self.shader:send("alphaMap", alpha) end

        -- store references for accessors
        self._albedo = albedo
        self._normal = normal
        self._metallic = metallic
        self._roughness = roughness
        self._ao = ao
        self._alpha = alpha
        -- update shader flag for whether an alpha map is present
        if self._alpha then
            pcall(function() self.shader:send("useAlphaMap", 1) end)
        else
            pcall(function() self.shader:send("useAlphaMap", 0) end)
        end
        -- do not require callers to use the return value; use getters instead
    end

    function self:getAlphaTexture()
        return self._alpha
    end

    function self:setTransparencyEnabled(enabled)
        self._enableTransparency = enabled and true or false
        pcall(function() self.shader:send("enableTransparency", self._enableTransparency and 1 or 0) end)
    end

    function self:getAlbedoTexture()
        return self._albedo
    end

    function self:getNormalTexture()
        return self._normal
    end

    function self:getMetallicTexture()
        return self._metallic
    end

    function self:getRoughnessTexture()
        return self._roughness
    end

    function self:getAOTexture()
        return self._ao
    end

    function self:setLights(positions, colors)
        self.shader:send("lightPositions", positions)
        self.shader:send("lightColors", colors)
    end

    function self:setCamera(camPos)
        self._camPos = camPos
    end

    function self:getCamera()
        return self._camPos
    end

    function self:setMatrices(proj, view, model, normal)
        -- store matrices but do not immediately send to shader
        -- this preserves previous values when callers pass nil
        if proj then self._projection = proj end
        if view then self._view = view end
        if model then self._model = model; self.model = model end
        if normal then self._normal = normal; self.normal = normal end
    end

    function self:draw(mesh)
        love.graphics.setShader(self.shader)
        if self._camPos then self.shader:send("camPos", self._camPos) end
        if self._projection then self.shader:send("projectionMatrix", self._projection) end
        if self._view then self.shader:send("viewMatrix", self._view) end
        if self.model then self.shader:send("modelMatrix", self.model) end
        if self.normal then self.shader:send("normalMatrix", self.normal) end
        -- ensure shader knows current alpha map / transparency state
        if self._alpha then pcall(function() self.shader:send("useAlphaMap", 1) end) else pcall(function() self.shader:send("useAlphaMap", 0) end) end
        if self._enableTransparency then pcall(function() self.shader:send("enableTransparency", 1) end) else pcall(function() self.shader:send("enableTransparency", 0) end) end
        love.graphics.draw(mesh)
        love.graphics.setShader()
    end

    return self
end

return pbr
