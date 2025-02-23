if SERVER then return end

---@class luv3d2d The main luv3d2d table
---@realm client
luv3d2d = luv3d2d or {}

---Creates a 3D2D canvas
---@param origin Vector|Entity The position of the canvas. Or the entity to attach to.
---@param ang Angle The angle of the canvas
---@param w number The width of the canvas
---@param h number The height of the canvas
---@param scale? number The scale of the canvas
---@param useFocus? boolean Whether to use the focus system
---@return luv3d2d.CanvasEntity canvas The created canvas
function luv3d2d:CreateCanvas(origin, ang, w, h, scale, useFocus)
    local canvas = ents.CreateClientside("luv3d2d_canvas") --[[@as luv3d2d.CanvasEntity]]
    if not IsValid(canvas) then
        error("luv3d2d failed to create canvas entity because it is probably not defined!")
    end
    if isvector(origin) then
        canvas:SetPos(origin)
    elseif isentity(origin) then
        origin = origin --[[@as Entity]]
        canvas:SetPos(origin:GetPos())
        canvas:SetParent(origin)
    end
    canvas:SetAngles(ang)
    canvas:Spawn()
    canvas:Activate()
    canvas:SetupPanel(w, h, scale, useFocus)

    return canvas
end
