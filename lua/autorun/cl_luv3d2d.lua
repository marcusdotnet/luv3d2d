if SERVER then return end

---@class luv3d2d The main luv3d2d table
---@realm client
luv3d2d = luv3d2d or {
    ---@type luv3d2d.CanvasEntity[]
    canvases = {},
}

---Creates a 3D2D canvas
---@param origin Vector The position of the canvas
---@param ang Angle The angle of the canvas
---@param w number The width of the canvas
---@param h number The height of the canvas
---@param scale? number The scale of the canvas
---@param useFocus? boolean Whether to use the focus system
---@return luv3d2d.CanvasEntity The created canvas
function luv3d2d:Create3D2DCanvas(origin, ang, w, h, scale, useFocus)
    local canvas = ents.CreateClientside("luv3d2d_canvas") --[[@as luv3d2d.CanvasEntity]]
    canvas:SetPos(origin)
    canvas:SetAngles(ang)
    canvas:Spawn()
    canvas:Activate()
    canvas:SetupPanel(w, h, scale, useFocus)

    table.insert(self.canvases, canvas)
    return canvas
end

for k, v in ipairs(ents.FindByClass("item_suitcharger")) do
    print("Creating canvas for", v)
    luv3d2d:Create3D2DCanvas(v:GetPos(), v:GetAngles(), 512, 256, 0.1, true)
end
