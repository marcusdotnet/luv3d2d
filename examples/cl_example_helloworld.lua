---@type Player
local ply = LocalPlayer()

---@type Vector
local hitPos = util.TraceLine({
    start = ply:EyePos(),
    endpos = ply:EyePos() + ply:GetAimVector() * 100,
    filter = ply
}).HitPos

-- Create the canvas at hitPos with our eye angles, 512x512 resolution, 1 scale, and use the focus system
local canvas = luv3d2d:CreateCanvas(hitPos, ply:GetAngles(), 512, 512, 1, true)

-- Attach some vgui elements to the canvas
local label = canvas:GetPanel():Add("DLabel")
label:SetText("luv3d2d")
label:SetFont("DermaLarge")
label:SetTextColor(Color(0, 0, 0))
label:SizeToContents()
label:SetContentAlignment(5)
label:Dock(TOP)

local button = canvas:GetPanel():Add("DButton")
button:SetText("Hello, World!")
button:SizeToContents()
button:SetTextColor(Color(255, 255, 255))
button:Dock(TOP)
button.DoClick = function(s)
    print("Hello, World!")
end
button.Paint = function(s, w, h)
    if s:IsDown() then
        draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 10))
    elseif s:IsHovered() then
        draw.RoundedBox(0, 0, 0, w, h, Color(200, 0, 255))
    else
        draw.RoundedBox(0, 0, 0, w, h, Color(22, 20, 25))
    end
end
