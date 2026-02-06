-- InspectBubbles.lua
-- Run this in your executor to see what properties determine if a bubble is "Active"

local landmarks = workspace.Map.Landmarks:GetChildren()
local found = 0

print("🔍 Scanning for Hotspot Bubbles...")

for _, landmark in ipairs(landmarks) do
    local zone = landmark:FindFirstChild("FishingZone")
    if zone then
        local hotspots = zone:FindFirstChild("Hotspots")
        if hotspots then
            for _, hotspot in ipairs(hotspots:GetChildren()) do
                local bubbles = hotspot:FindFirstChild("Bubbles")
                if bubbles then
                    found = found + 1
                    print("-----------------------------")
                    print("📍 Location: " .. landmark.Name)
                    print("   Type: " .. bubbles.ClassName)
                    
                    if bubbles:IsA("BasePart") then
                        print("   Transparency: " .. bubbles.Transparency)
                        print("   CanCollide: " .. tostring(bubbles.CanCollide))
                    elseif bubbles:IsA("ParticleEmitter") then
                        print("   Enabled: " .. tostring(bubbles.Enabled))
                        print("   Rate: " .. bubbles.Rate)
                    end
                    
                    -- Check if it has children like "ParticleEmitter" or "Beam"
                    for _, child in ipairs(bubbles:GetChildren()) do
                        if child:IsA("ParticleEmitter") then
                            print("   > Child Particle: " .. child.Name .. " | Enabled: " .. tostring(child.Enabled))
                        end
                    end
                end
            end
        end
    end
end

if found == 0 then
    print("❌ No bubbles found using this path structure.")
else
    print("✅ Found " .. found .. " bubble objects.")
end
