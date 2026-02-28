local cube_verts = { -- back face
    {-1, -1, -1, 0, 0, -1, 0, 0}, -- bottom-left
    {1, 1, -1, 0, 0, -1, 1, 1}, -- top-right
    {1, -1, -1, 0, 0, -1, 1, 0}, -- bottom-right         
    {1, 1, -1, 0, 0, -1, 1, 1}, -- top-right
    {-1, -1, -1, 0, 0, -1, 0, 0}, -- bottom-left
    {-1, 1, -1, 0, 0, -1, 0, 1}, -- top-left
    -- front face
    {-1, -1, 1, 0, 0, 1, 0, 0}, -- bottom-left
    {1, -1, 1, 0, 0, 1, 1, 0}, -- bottom-right
    {1, 1, 1, 0, 0, 1, 1, 1}, -- top-right
    {1, 1, 1, 0, 0, 1, 1, 1}, -- top-right
    {-1, 1, 1, 0, 0, 1, 0, 1}, -- top-left
    {-1, -1, 1, 0, 0, 1, 0, 0}, -- bottom-left
    -- left face
    {-1, 1, 1, -1, 0, 0, 1, 0}, -- top-right
    {-1, 1, -1, -1, 0, 0, 1, 1}, -- top-left
    {-1, -1, -1, -1, 0, 0, 0, 1}, -- bottom-left
    {-1, -1, -1, -1, 0, 0, 0, 1}, -- bottom-left
    {-1, -1, 1, -1, 0, 0, 0, 0}, -- bottom-right
    {-1, 1, 1, -1, 0, 0, 1, 0}, -- top-right
    -- right face
    {1, 1, 1, 1, 0, 0, 1, 0}, -- top-left
    {1, -1, -1, 1, 0, 0, 0, 1}, -- bottom-right
    {1, 1, -1, 1, 0, 0, 1, 1}, -- top-right         
    {1, -1, -1, 1, 0, 0, 0, 1}, -- bottom-right
    {1, 1, 1, 1, 0, 0, 1, 0}, -- top-left
    {1, -1, 1, 1, 0, 0, 0, 0}, -- bottom-left     
    -- bottom face
    {-1, -1, -1, 0, -1, 0, 0, 1}, -- top-right
    {1, -1, -1, 0, -1, 0, 1, 1}, -- top-left
    {1, -1, 1, 0, -1, 0, 1, 0}, -- bottom-left
    {1, -1, 1, 0, -1, 0, 1, 0}, -- bottom-left
    {-1, -1, 1, 0, -1, 0, 0, 0}, -- bottom-right
    {-1, -1, -1, 0, -1, 0, 0, 1}, -- top-right
    -- top face
    {-1, 1, -1, 0, 1, 0, 0, 1}, -- top-left
    {1, 1, 1, 0, 1, 0, 1, 0}, -- bottom-right
    {1, 1, -1, 0, 1, 0, 1, 1}, -- top-right     
    {1, 1, 1, 0, 1, 0, 1, 0}, -- bottom-right
    {-1, 1, -1, 0, 1, 0, 0, 1}, -- top-left
    {-1, 1, 1, 0, 1, 0, 0, 0} -- bottom-left        
}
-- //
local quad_raws = {{-1, 1, 0, 0, 1}, {-1, -1, 0, 0, 0}, {1, 1, 0, 1, 1}, {1, -1, 0, 1, 0}}
-- 为了保持统一，添加了法线数据
for i = 1, #quad_raws, 1 do
    local vert = quad_raws[i]
    table.insert(vert, 4, 2)
    table.insert(vert, 4, 2)
    table.insert(vert, 4, 2)
end
local quad_verts = {}
table.insert(quad_verts, quad_raws[1])
table.insert(quad_verts, quad_raws[2])
table.insert(quad_verts, quad_raws[3])
table.insert(quad_verts, quad_raws[3])
table.insert(quad_verts, quad_raws[2])
table.insert(quad_verts, quad_raws[4])
-- //
local sphere_verts = {}
local vertDatas = {}
local indices = {}
local pi = 3.14159265359
local X_SEGMENTS = 64
local Y_SEGMENTS = 64
for x = 0, X_SEGMENTS, 1 do
    for y = 0, Y_SEGMENTS, 1 do
        local xSegment = x / X_SEGMENTS
        local ySegment = y / Y_SEGMENTS
        local xPos = math.cos(xSegment * 2 * pi) * math.sin(ySegment * pi)
        local yPos = math.cos(ySegment * pi)
        local zPos = math.sin(xSegment * 2 * pi) * math.sin(ySegment * pi)
        table.insert(vertDatas, {xPos, yPos, zPos, xPos, yPos, zPos, xSegment, ySegment}) -- pos,normal,uv
    end
end
-- indices
local oddRow = false
for y = 0, Y_SEGMENTS - 1, 1 do
    if not oddRow then -- even rows: y == 0, y == 2; and so on
        for x = 0, X_SEGMENTS, 1 do
            table.insert(indices, y * (X_SEGMENTS + 1) + x)
            table.insert(indices, (y + 1) * (X_SEGMENTS + 1) + x)
        end
    else
        for x = X_SEGMENTS, 0, -1 do
            table.insert(indices, (y + 1) * (X_SEGMENTS + 1) + x)
            table.insert(indices, y * (X_SEGMENTS + 1) + x)
        end
    end
    oddRow = not oddRow
end
-- triangle
-- 这里我们使用的是GL_TRIANGLES模式，教程使用的是GL_TRIANGLE_STRIP模式，
-- 两者的区别在于，GL_TRIANGLE_STRIP会自动连接相邻的三角形，而GL_TRIANGLES则需要我们手动连接。
for i = 1, #indices - 2, 1 do
    local i1 = indices[i] + 1
    local i2 = indices[i + 1] + 1
    local i3 = indices[i + 2] + 1
    -- Use face normal orientation to ensure consistent winding (prevent alternating flipped triangles)
    local v1 = vertDatas[i1]
    local v2 = vertDatas[i2]
    local v3 = vertDatas[i3]
    local x1, y1, z1 = v1[1], v1[2], v1[3]
    local x2, y2, z2 = v2[1], v2[2], v2[3]
    local x3, y3, z3 = v3[1], v3[2], v3[3]
    local ux, uy, uz = x2 - x1, y2 - y1, z2 - z1
    local vx, vy, vz = x3 - x1, y3 - y1, z3 - z1
    local nx = uy * vz - uz * vy
    local ny = uz * vx - ux * vz
    local nz = ux * vy - uy * vx
    -- vertex normal stored in components 4-6; use it to decide outward-facing
    local dot = nx * v1[4] + ny * v1[5] + nz * v1[6]
    if dot >= 0 then
        table.insert(sphere_verts, v1)
        table.insert(sphere_verts, v2)
        table.insert(sphere_verts, v3)
    else
        table.insert(sphere_verts, v2)
        table.insert(sphere_verts, v1)
        table.insert(sphere_verts, v3)
    end
end

return {
    quad = quad_verts,
    cube = cube_verts,
    sphere= sphere_verts
}