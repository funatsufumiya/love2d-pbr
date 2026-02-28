-- Example using the root-level `pbr` wrapper module

local vertexFormat = {{"VertexPosition", "float", 3}, {"VertexNormal", "float", 3}, {"VertexTexCoord", "float", 2}}

local pbr = require "pbr"
local obj = require "obj"

local function flatten4(m)
    local out = {}
    for i = 1, 4 do
        for j = 1, 4 do
            out[#out + 1] = m[i][j]
        end
    end
    return out
end

local function ortho(l, r, b, t, n, f)
    local m = {
        {2/(r-l), 0, 0, -(r+l)/(r-l)},
        {0, 2/(t-b), 0, -(t+b)/(t-b)},
        {0,0,-2/(f-n), -(f+n)/(f-n)},
        {0,0,0,1}
    }
    return flatten4(m)
end

local function identity4()
    return {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}
end

local function identity3()
    return {1,0,0, 0,1,0, 0,0,1}
end

-- rotation state
local rotY = 0
local rotX = 0
local rotSpeedY = 0.6 -- radians/sec
local rotSpeedX = 0.3

local function rotationXYMatrix(rx, ry)
    local cx = math.cos(rx)
    local sx = math.sin(rx)
    local cy = math.cos(ry)
    local sy = math.sin(ry)
    local Rx = {
        1, 0, 0,
        0, cx, -sx,
        0, sx, cx
    }
    local Ry = {
        cy, 0, sy,
        0, 1, 0,
        -sy, 0, cy
    }
    local R = {}
    for i = 0, 2 do
        for j = 0, 2 do
            local sum = 0
            for k = 0, 2 do
                sum = sum + Ry[i*3 + k + 1] * Rx[k*3 + j + 1]
            end
            R[i*3 + j + 1] = sum
        end
    end
    local model4 = {
        R[1], R[2], R[3], 0,
        R[4], R[5], R[6], 0,
        R[7], R[8], R[9], 0,
        0,    0,    0,    1
    }
    local normal3 = {R[1], R[2], R[3], R[4], R[5], R[6], R[7], R[8], R[9]}
    return model4, normal3
end

function love.load()
    love.graphics.setDepthMode("lequal", true)
    if love.graphics.setMeshCullMode then
        love.graphics.setMeshCullMode("back")
    end

    mesh = love.graphics.newMesh(vertexFormat, obj.sphere, "triangles")
    currentMeshType = 'sphere'

    -- local shaderBaseFrag = "shader/texture.frag"
    -- local shaderBaseVert = "shader/texture.vert"
    -- pbrInstance = pbr.new(shaderBaseFrag, shaderBaseVert)

    pbrInstance = pbr.new()

    local base = "assets/pbr/rusted_iron/"
    local texs = {
        albedo = base .. "albedo.png",
        normal = base .. "normal.png",
        metallic = base .. "metallic.png",
        roughness = base .. "roughness.png",
        ao = base .. "ao.png",
        -- alpha = base .. "alpha.png",
    }
    pbrInstance:setTextures(texs)
    mesh:setTexture(pbrInstance:getAlbedoTexture())

    -- Enable transparency processing in the PBR shader. Comment out to disable.
    -- pbrInstance:setTransparencyEnabled(true)

    pbrInstance:setLights({0, 0, 10,  5, 5, 10,  -5, 5, 10, 0, -5, 10}, {400,400,400, 250,250,250, 250,250,250, 200,200,200})
    pbrInstance:setCamera({0,0,3})

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local aspect = w / h
    projection = ortho(-2 * aspect, 2 * aspect, -2, 2, -10, 10)
    view = identity4()
    model = identity4()
    normalMat = identity3()
end

local function drawCheckerboard(w, h, tile)
    tile = tile or 32
    local cols = math.ceil(w / tile)
    local rows = math.ceil(h / tile)
    for y = 0, rows - 1 do
        for x = 0, cols - 1 do
            if ((x + y) % 2) == 0 then
                love.graphics.setColor(0.85, 0.85, 0.85)
            else
                love.graphics.setColor(0.6, 0.6, 0.6)
            end
            love.graphics.rectangle("fill", x * tile, y * tile, tile, tile)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function love.resize(w, h)
    local aspect = w / h
    projection = ortho(-2 * aspect, 2 * aspect, -2, 2, -10, 10)
end

function love.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- drawCheckerboard(w, h, 48) -- larger tiles to make alpha easier to see
    pbrInstance:draw(mesh)
end

function love.update(dt)
    rotY = rotY + rotSpeedY * dt
    rotX = rotX + rotSpeedX * dt
    local m4, n3 = rotationXYMatrix(rotX, rotY)
    model = m4
    normalMat = n3

    pbrInstance:setMatrices(projection, identity4(), model, normalMat)
    -- animate metallic value over time (0..1)
    local t = love.timer.getTime()

    -- local metal = 0.5 + 0.5 * math.sin(t * 0.5) -- adjust frequency as desired
    -- pbrInstance:setMetallicValue(metal)

    -- local roughness = 0.5 + 0.5 * math.cos(t * 0.5) -- adjust frequency as desired
    -- pbrInstance:setRoughnessValue(roughness)
end

function love.keypressed(key)
    if key == '1' then
        mesh = love.graphics.newMesh(vertexFormat, obj.sphere, "triangles")
        mesh:setTexture(pbrInstance:getAlbedoTexture())
        currentMeshType = 'sphere'
        if love.graphics.setMeshCullMode then love.graphics.setMeshCullMode("back") end
    elseif key == '2' then
        mesh = love.graphics.newMesh(vertexFormat, obj.cube, "triangles")
        mesh:setTexture(pbrInstance:getAlbedoTexture())
        currentMeshType = 'cube'
        if love.graphics.setMeshCullMode then love.graphics.setMeshCullMode("back") end
    elseif key == '3' then
        mesh = love.graphics.newMesh(vertexFormat, obj.quad, "triangles")
        mesh:setTexture(pbrInstance:getAlbedoTexture())
        currentMeshType = 'quad'
        if love.graphics.setMeshCullMode then love.graphics.setMeshCullMode("none") end
    end
end
