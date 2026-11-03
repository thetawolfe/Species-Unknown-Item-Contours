-- Adapt the game's already-working loader pattern: resolve a cooked Blueprint and
-- let UWorld spawn/own its components. No StaticConstructObject or manual teardown.
local Renderer={}
-- UE4SS may expose different Lua wrappers for one native UObject.
local function address(object)
 local ok,value=pcall(function()
  if object:IsValid()~=true then return nil end
  return object:GetAddress()
 end)
 if ok and type(value)=='number'and value~=0 and value==value and value~=math.huge and value~=-math.huge and value%1==0 then return value end
end
function Renderer.sameWorld(a,b)
 local first,second=address(a),address(b)
 return first~=nil and second~=nil and first==second
end
local function describe(object)
 local ok,name=pcall(function()return object:GetFullName()end)
 return tostring(address(object))..' '..(ok and tostring(name)or '<unavailable>')
end
local CLASS='/Game/Mods/ItemContours/ModActor.ModActor_C'
local PACKAGE='/Game/Mods/ItemContours/ModActor'
function Renderer.new(api)
 local cachedWorld,cachedActor,attemptedWorld
 local function fullClass(object)
  local ok,value=pcall(function()return object:GetClass():GetFullName()end)
  return ok and type(value)=='string'and value or nil
 end
 local function owned(object)
  local name=fullClass(object)
  return name=='BlueprintGeneratedClass '..CLASS or name=='Class '..CLASS
 end
 local function getComponent(actor,world)
  local cls=api.find('/Script/Engine.PostProcessComponent')
  if not api.valid(cls)then return nil,'Post-process class unavailable' end
  local ok,component=pcall(function()return actor:GetComponentByClass(cls)end)
  if ok and api.valid(component)and Renderer.sameWorld(component:GetWorld(),world) then return component end
  return nil,'Owned renderer spawned; waiting for its post-process component'
 end
 local self={}
 function self:ensure(world)
  assert(api.valid(world),'Current world required')
  local key=address(world)
  if not key then return nil,'Current world native identity unavailable' end
  if cachedWorld==key and cachedActor then
   local alive=api.lifetime(cachedActor)
   if alive==nil then return nil,'Renderer lifetime unknown; not spawning a duplicate' end
   if alive then
    if not Renderer.sameWorld(cachedActor:GetWorld(),world) or not owned(cachedActor)then return nil,'Cached renderer identity changed; spawn refused' end
    return getComponent(cachedActor,world)
   end
  end
  for _,component in ipairs(api.findAll('PostProcessComponent')or{})do
   if api.valid(component)and Renderer.sameWorld(component:GetWorld(),world) then
    local actor=component:GetOwner()
    if api.valid(actor)and owned(actor)then cachedWorld=key;cachedActor=actor;return component end
   end
  end
  local cls=api.find(CLASS)
  if not api.valid(cls)then
   local helpers=api.find('/Script/AssetRegistry.Default__AssetRegistryHelpers')
   if api.valid(helpers)then
    local ok,value=pcall(function()return helpers:GetAsset({PackageName=api.name(PACKAGE),AssetName=api.name('ModActor_C')})end)
    if ok then cls=value end
   end
  end
  if not api.valid(cls)then return nil,'Cooked renderer Blueprint class unavailable' end
  local className=cls:GetFullName()
  if className~='BlueprintGeneratedClass '..CLASS and className~='Class '..CLASS then return nil,'Unexpected renderer Blueprint class' end
  -- This matches the successful SpecimenHealthBars/L0sts loader API path.
  if attemptedWorld==key then return nil,'Renderer spawn already attempted in this world; restart before retrying' end
  attemptedWorld=key
  local ok,actor=pcall(function()return world:SpawnActor(cls,{},{})end)
  if not ok or not api.valid(actor)then return nil,'Renderer spawn did not return a valid actor' end
  cachedWorld=key;cachedActor=actor
  if not owned(actor)or not Renderer.sameWorld(actor:GetWorld(),world) then return nil,'Renderer spawn identity mismatch: class='..tostring(fullClass(actor))..' expectedWorld='..describe(world)..' actorWorld='..describe(actor:GetWorld()) end
  api.log('Spawned owned renderer in current world')
  return getComponent(actor,world)
 end
 return self
end
return Renderer
