local pbr = {}

local function identity4()
    return {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}
end

local function identity3()
    return {1,0,0, 0,1,0, 0,0,1}
end

function pbr.new(fragPath, vertPath)
    local self = {}
    self.shader = love.graphics.newShader(fragPath, vertPath)
    self.model = identity4()
    self.normal = identity3()

    function self:setTextures(basePath)
        local albedo = love.graphics.newImage(basePath .. "albedo.png")
        local normal = love.graphics.newImage(basePath .. "normal.png")
        local metallic = love.graphics.newImage(basePath .. "metallic.png")
        local roughness = love.graphics.newImage(basePath .. "roughness.png")
        local ao = love.graphics.newImage(basePath .. "ao.png")

        self.shader:send("albedoMap", albedo)
        self.shader:send("normalMap", normal)
        self.shader:send("metallicMap", metallic)
        self.shader:send("roughnessMap", roughness)
        self.shader:send("aoMap", ao)

        self.albedo = albedo
        return albedo
    end

    function self:setLights(positions, colors)
        self.shader:send("lightPositions", positions)
        self.shader:send("lightColors", colors)
    end

    function self:setCamera(camPos)
        self.shader:send("camPos", camPos)
    end

    function self:sendMatrices(proj, view, model, normal)
        if proj then self.shader:send("projectionMatrix", proj) end
        if view then self.shader:send("viewMatrix", view) end
        if model then self.model = model; self.shader:send("modelMatrix", model) end
        if normal then self.normal = normal; self.shader:send("normalMatrix", normal) end
    end

    function self:draw(mesh)
        love.graphics.setShader(self.shader)
        if self.model then self.shader:send("modelMatrix", self.model) end
        if self.normal then self.shader:send("normalMatrix", self.normal) end
        love.graphics.draw(mesh)
        love.graphics.setShader()
    end

    return self
end

return pbr
