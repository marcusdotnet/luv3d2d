if SERVER then return end

---@class luv3d2d The main luv3d2d table
---@realm client
luv3d2d = luv3d2d or {}

---Creates a 3D2D canvas
---@param origin? Vector The position of the canvas. Optional.
---@param ang? Angle The angle of the canvas. Optional.
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

    -- Set pos if provided
    if origin then
        canvas:SetPos(origin)
    end

    -- Set ang if provided
    if ang then
        canvas:SetAngles(ang)
    end

    canvas:Spawn()
    canvas:Activate()
    canvas:SetupPanel(w, h, scale, useFocus)

    return canvas
end

---Creates a 3D2D canvas attached to an entity
---@param ent Entity The entity to attach the canvas to
---@param offset? Vector The local position offset from the entity. Optional.
---@param angOffset? Angle The local angle offset relative to the entity. Optional.
---@param w number The width of the canvas. Optional.
---@param h number The height of the canvas. Optional.
---@param scale? number The scale of the canvas. Optional.
---@param useFocus? boolean Whether to use the focus system. Optional.
---@return luv3d2d.CanvasEntity canvas The created canvas
function luv3d2d:CreateCanvasForEntity(ent, offset, angOffset, w, h, scale, useFocus)
    local canvas = self:CreateCanvas(nil, nil, w, h, scale, useFocus)
    canvas:AttachToEntity(ent, offset or vector_origin, angOffset or angle_zero)

    return canvas
end
