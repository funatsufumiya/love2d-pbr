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
    -- (flags will be initialized after default textures are created)
    self.model = identity4()
    self.normal = identity3()

    -- create a 1x1 Image from a numeric grayscale value or an RGB(A) table
    local function make1x1Image(v)
        local id = love.image.newImageData(1,1)
        if type(v) == "number" then
            local c = math.max(0, math.min(1, v))
            id:setPixel(0,0, c, c, c, 1)
            return love.graphics.newImage(id)
        end
        if type(v) == "table" then
            local r = v[1] or 0
            local g = v[2] or r
            local b = v[3] or r
            local a = v[4] or 1
            r = math.max(0, math.min(1, r))
            g = math.max(0, math.min(1, g))
            b = math.max(0, math.min(1, b))
            a = math.max(0, math.min(1, a))
            id:setPixel(0,0, r, g, b, a)
            return love.graphics.newImage(id)
        end
        return nil
    end

    -- normalize incoming texture-like values to an Image/Texture or nil
    local function ensureTexture(v)
        if not v then return nil end
        local t = type(v)
        if t == "string" then
            return love.graphics.newImage(v)
        end
        if t == "number" or t == "table" then
            return make1x1Image(v)
        end
        if t == "userdata" then
            return v
        end
        error(("ensureTexture: unsupported texture type '%s'"):format(t))
    end

    -- create sensible defaults so pbr.new() works with nil textures
    local default_albedo = make1x1Image({1,1,1})
    local default_metallic = make1x1Image(0)
    local default_roughness = make1x1Image(1)
    local default_ao = make1x1Image(1)
    local default_normal = make1x1Image({0.5, 0.5, 1.0}) -- flat normal in tangent space
    local default_emissive = make1x1Image(0)
    -- store defaults and send to shader
    self._albedo = default_albedo
    self._metallic = default_metallic
    self._roughness = default_roughness
    self._ao = default_ao
    self._normal = default_normal
    self._emissive = default_emissive
    self._emissiveIntensity = 0
    self._alpha = nil
    pcall(function()
        if default_albedo then self.shader:send("albedoMap", default_albedo) end
        if default_normal then self.shader:send("normalMap", default_normal) end
        if default_metallic then self.shader:send("metallicMap", default_metallic) end
        if default_roughness then self.shader:send("roughnessMap", default_roughness) end
        if default_ao then self.shader:send("aoMap", default_ao) end
        if default_emissive then self.shader:send("emissiveMap", default_emissive) end
        self.shader:send("emissiveIntensity", 0)
        self.shader:send("useEmissiveMap", 0)
        self.shader:send("useAlphaMap", 0)
        self.shader:send("enableTransparency", 0)
        pcall(function() self.shader:send("debugShowFaces", 0) end)
        pcall(function() self.shader:send("debugShowNormals", 0) end)
    end)

    -- directional light defaults (single directional light)
    self._dirLightDir = {0, -1, 0}
    self._dirLightColor = {1, 1, 1}
    self._useDirectionalLight = false
    -- ambient intensity default
    self._ambientIntensity = 0.03
    pcall(function()
        self.shader:send("dirLightDir", self._dirLightDir)
        self.shader:send("dirLightColor", self._dirLightColor)
        self.shader:send("useDirectionalLight", 0)
        self.shader:send("ambientIntensity", self._ambientIntensity)
    end)

    function self:setTextures(textures)
        local function loadImage(v)
            return ensureTexture(v)
        end

        local albedo = loadImage(textures.albedo)
        local normal = loadImage(textures.normal)
        local metallic = loadImage(textures.metallic)
        local roughness = loadImage(textures.roughness)
        local alpha = loadImage(textures.alpha)
        local ao = loadImage(textures.ao)
        local emissive = loadImage(textures.emissive)
        local emissiveIntensity = textures.emissiveIntensity

        if albedo then self.shader:send("albedoMap", albedo) end
        if normal then self.shader:send("normalMap", normal) end
        if metallic then self.shader:send("metallicMap", metallic) end
        if roughness then self.shader:send("roughnessMap", roughness) end
        if ao then self.shader:send("aoMap", ao) end
        if emissive then self.shader:send("emissiveMap", emissive) end
        if type(emissiveIntensity) == "number" then self.shader:send("emissiveIntensity", emissiveIntensity) end
        if alpha then self.shader:send("alphaMap", alpha) end

        -- store references for accessors, but preserve existing values when callers pass nil
        if albedo then self._albedo = albedo end
        if normal then self._normal = normal end
        if metallic then self._metallic = metallic end
        if roughness then self._roughness = roughness end
        if ao then self._ao = ao end
        if emissive then self._emissive = emissive end
        if type(emissiveIntensity) == "number" then self._emissiveIntensity = emissiveIntensity end
        if alpha then self._alpha = alpha end
        -- update shader flag for whether an alpha map is present
        if self._alpha then
            pcall(function() self.shader:send("useAlphaMap", 1) end)
        else
            pcall(function() self.shader:send("useAlphaMap", 0) end)
        end
        -- update emissive flag
        if self._emissive then
            pcall(function() self.shader:send("useEmissiveMap", 1) end)
        else
            pcall(function() self.shader:send("useEmissiveMap", 0) end)
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

    function self:getEmissiveTexture()
        return self._emissive
    end

    function self:setEmissiveValue(v)
        local img = make1x1Image(v)
        if not img then error("setEmissiveValue: expected number or color table") end
        self._emissive = img
        pcall(function() self.shader:send("emissiveMap", img) end)
    end

    function self:setEmissiveTexture(v)
        local img = ensureTexture(v)
        if not img then error("setEmissiveTexture: invalid texture") end
        self._emissive = img
        pcall(function() self.shader:send("emissiveMap", img) end)
    end

    function self:setEmissiveIntensity(v)
        if type(v) ~= "number" then error("setEmissiveIntensity: expected number") end
        self._emissiveIntensity = v
        pcall(function() self.shader:send("emissiveIntensity", self._emissiveIntensity) end)
    end

    function self:getEmissiveIntensity()
        return self._emissiveIntensity
    end

    -- Debug: show front/back faces in shader when enabled
    function self:setDebugShowFaces(enabled)
        self._debugShowFaces = enabled and true or false
        pcall(function() self.shader:send("debugShowFaces", self._debugShowFaces and 1 or 0) end)
    end

    function self:getDebugShowFaces()
        return self._debugShowFaces
    end

        -- Debug: visualize normals in shader when enabled
        function self:setDebugShowNormals(enabled)
            self._debugShowNormals = enabled and true or false
            pcall(function() self.shader:send("debugShowNormals", self._debugShowNormals and 1 or 0) end)
        end

        function self:getDebugShowNormals()
            return self._debugShowNormals
        end

    -- Explicit setter aliases that create 1x1 images from numbers or color tables
    function self:setBaseColor(color)
        local img = make1x1Image(color)
        if not img then error("setBaseColor: expected number or color table") end
        self._albedo = img
        pcall(function() self.shader:send("albedoMap", img) end)
    end

    function self:setMetallicValue(v)
        local img = make1x1Image(v)
        if not img then error("setMetallicValue: expected number or color table") end
        self._metallic = img
        pcall(function() self.shader:send("metallicMap", img) end)
    end

    function self:setRoughnessValue(v)
        local img = make1x1Image(v)
        if not img then error("setRoughnessValue: expected number or color table") end
        self._roughness = img
        pcall(function() self.shader:send("roughnessMap", img) end)
    end

    function self:setAOValue(v)
        local img = make1x1Image(v)
        if not img then error("setAOValue: expected number or color table") end
        self._ao = img
        pcall(function() self.shader:send("aoMap", img) end)
    end

    function self:setAlphaValue(v)
        local img = make1x1Image(v)
        if not img then error("setAlphaValue: expected number or color table") end
        self._alpha = img
        pcall(function() self.shader:send("alphaMap", img) end)
        pcall(function() self.shader:send("useAlphaMap", self._alpha and 1 or 0) end)
    end

    -- Accept an existing Texture/Image userdata or create from string/number/table
    function self:setAlbedoTexture(v)
        local img = ensureTexture(v)
        if not img then error("setAlbedoTexture: invalid texture") end
        self._albedo = img
        pcall(function() self.shader:send("albedoMap", img) end)
    end

    function self:setNormalTexture(v)
        local img = ensureTexture(v)
        if not img then error("setNormalTexture: invalid texture") end
        self._normal = img
        pcall(function() self.shader:send("normalMap", img) end)
    end

    function self:setMetallicTexture(v)
        local img = ensureTexture(v)
        if not img then error("setMetallicTexture: invalid texture") end
        self._metallic = img
        pcall(function() self.shader:send("metallicMap", img) end)
    end

    function self:setRoughnessTexture(v)
        local img = ensureTexture(v)
        if not img then error("setRoughnessTexture: invalid texture") end
        self._roughness = img
        pcall(function() self.shader:send("roughnessMap", img) end)
    end

    function self:setAOTexture(v)
        local img = ensureTexture(v)
        if not img then error("setAOTexture: invalid texture") end
        self._ao = img
        pcall(function() self.shader:send("aoMap", img) end)
    end

    function self:setAlphaTexture(v)
        local img = ensureTexture(v)
        if not img then error("setAlphaTexture: invalid texture") end
        self._alpha = img
        pcall(function() self.shader:send("alphaMap", img) end)
        pcall(function() self.shader:send("useAlphaMap", self._alpha and 1 or 0) end)
    end

    function self:setLights(positions, colors)
        pcall(function() self.shader:send("lightPositions", positions) end)
        pcall(function() self.shader:send("lightColors", colors) end)
    end

    -- single directional light API
    function self:setDirectionalLight(dir, color)
        if type(dir) ~= "table" or type(color) ~= "table" then error("setDirectionalLight: expected tables for dir and color") end
        self._dirLightDir = dir
        self._dirLightColor = color
        self._useDirectionalLight = true
        pcall(function() self.shader:send("dirLightDir", self._dirLightDir) end)
        pcall(function() self.shader:send("dirLightColor", self._dirLightColor) end)
        pcall(function() self.shader:send("useDirectionalLight", 1) end)
    end

    function self:disableDirectionalLight()
        self._useDirectionalLight = false
        pcall(function() self.shader:send("useDirectionalLight", 0) end)
    end

    function self:getDirectionalLight()
        return self._dirLightDir, self._dirLightColor, self._useDirectionalLight
    end

    -- ambient intensity API
    function self:setAmbientIntensity(v)
        if type(v) ~= "number" then error("setAmbientIntensity: expected number") end
        self._ambientIntensity = v
        pcall(function() self.shader:send("ambientIntensity", self._ambientIntensity) end)
    end

    function self:getAmbientIntensity()
        return self._ambientIntensity
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
        -- (texture samplers are sent when set via setters; no per-frame resend)
        if self._camPos then self.shader:send("camPos", self._camPos) end
        if self._projection then self.shader:send("projectionMatrix", self._projection) end
        if self._view then self.shader:send("viewMatrix", self._view) end
        if self.model then self.shader:send("modelMatrix", self.model) end
        if self.normal then self.shader:send("normalMatrix", self.normal) end
        -- directional light uniforms
        if self._dirLightDir then pcall(function() self.shader:send("dirLightDir", self._dirLightDir) end) end
        if self._dirLightColor then pcall(function() self.shader:send("dirLightColor", self._dirLightColor) end) end
        pcall(function() self.shader:send("useDirectionalLight", self._useDirectionalLight and 1 or 0) end)
        -- ambient intensity
        pcall(function() self.shader:send("ambientIntensity", self._ambientIntensity) end)
        -- ensure shader knows current alpha map / transparency state
        if self._alpha then pcall(function() self.shader:send("useAlphaMap", 1) end) else pcall(function() self.shader:send("useAlphaMap", 0) end) end
        if self._enableTransparency then pcall(function() self.shader:send("enableTransparency", 1) end) else pcall(function() self.shader:send("enableTransparency", 0) end) end
        -- emissive map and intensity
        if self._emissive then pcall(function() self.shader:send("useEmissiveMap", 1) end) else pcall(function() self.shader:send("useEmissiveMap", 0) end) end
        pcall(function() self.shader:send("emissiveIntensity", self._emissiveIntensity or 0) end)
        pcall(function() self.shader:send("useBloom", self._useBloom and 1 or 0) end)
        pcall(function() self.shader:send("bloomIntensity", self._bloomIntensity or 1.0) end)
        love.graphics.draw(mesh)
        love.graphics.setShader()
    end

    return self
end

return pbr
