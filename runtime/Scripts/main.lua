-- Continuous cooked contours in explicitly allowlisted mission worlds; Alt+7 toggles.
-- Renderer actor/components are owned by the cooked Blueprint and standard UE4SS Blueprint loader.
local Helpers=require('UEHelpers')
local Catalogue=require('ItemContours.catalogue')
local Renderer=require('ItemContours.renderer')
local Config=require('ItemContours.config')
local Preferences=require('ItemContours.settings').normalize({colors=Config.colors,categories=Config.categories},'configuration')
assert(type(Config.thickness)=='number'and Config.thickness==Config.thickness and Config.thickness>=1 and Config.thickness<=8,'thickness must be1..8')
assert(type(Config.opacity)=='number'and Config.opacity==Config.opacity and Config.opacity>=0 and Config.opacity<=1,'opacity must be0..1')
local groupFor={weapon='weapons',money='valuables',hard_drive='valuables',key_item='mission',mission_item='mission'}
local byClass,classes={},{}
for _,row in ipairs(Catalogue)do
 if row.identityVerified and not row.excluded then
  byClass[row.classPath]=row.kind;classes[#classes+1]=row.classPath:match('([^%.]+)$')
 end
end
local stencilFor={weapon=201,money=202,hard_drive=202,key_item=203,mission_item=203}
local state=nil
local queued=false
local function log(message)print('[ItemContours] '..message..'\n')end
local function lifetime(object)
 if object==nil then return false end
 local ok,value=pcall(function()return object:IsValid()end)
 if not ok or type(value)~='boolean'then return nil end
 return value
end
local function valid(object)return lifetime(object)==true end
local function read(object,key)
 local ok,value=pcall(function()return object[key]end)
 if ok then return value end
end
local function scalar(value)
 local kind=type(value)
 if kind=='boolean'or kind=='number'or kind=='string'or kind=='nil'then return kind..':'..tostring(value)end
 return '<'..kind..'>'
end
local function queue(fn)
 if EngineTickAvailable~=true or not EGameThreadMethod or not EGameThreadMethod.EngineTick then log('EngineTick unavailable; no changes made');return false end
 ExecuteInGameThread(fn,EGameThreadMethod.EngineTick);return true
end
local function restoreField(object,key,expected,before,setter)
 local current=read(object,key)
 if current==nil then return false end
 if current~=expected then return true end -- Preserve a changed owner.
 local ok=pcall(function()if setter then object[setter](object,before)else object[key]=before end end)
 return ok and read(object,key)==before
end
local function stop()
 if not state then return end
 state.closing=true
 local pending={}
 for _,entry in ipairs(state.items)do
  local alive=lifetime(entry.component)
  if alive==nil then pending[#pending+1]=entry
  elseif alive then
   local a,b=true,true
   if entry.depthAttempted then a=restoreField(entry.component,'bRenderCustomDepth',true,entry.depth,'SetRenderCustomDepth')end
   if entry.stencilAttempted then b=restoreField(entry.component,'CustomDepthStencilValue',entry.afterStencil,entry.stencil,'SetCustomDepthStencilValue')end
   if not a or not b then pending[#pending+1]=entry end
  end
 end
 state.items=pending
 if #pending>0 then log('Cleanup pending; retained '..#pending..' component records');return end
 local pp=state.pp
 local ppAlive=lifetime(pp)
 if ppAlive==nil then log('Post-process lifetime unknown; cleanup retained');return end
 if ppAlive then
  local complete=true
  for _,key in ipairs({'bEnabled','bUnbound','BlendWeight','Priority'})do
   if state.ppAttempted[key]then local restored=restoreField(pp,key,state.after[key],state.before[key]);complete=restored and complete end
  end
  if not complete then log('Post-process cleanup pending');return end
 end
 if state.cvarChanged and state.cvarAttempted then
  if not valid(state.library)then state.library=Helpers.GetKismetSystemLibrary()end
  if not valid(state.library)then log('Renderer settings API unavailable; cleanup retained');return end
  local current=state.library:GetConsoleVariableIntValue('r.CustomDepth')
  if type(current)~='number'or current%1~=0 or current<0 or current>3 then log('Renderer mode unknown; cleanup retained');return end
  if current==3 then
   local world=Helpers.GetWorld();if not valid(world)then return end
   state.library:ExecuteConsoleCommand(world,'r.CustomDepth '..state.cvarBefore,nil)
   if state.library:GetConsoleVariableIntValue('r.CustomDepth')~=state.cvarBefore then log('Renderer mode restore pending');return end
  end
 end
 state=nil;log('Stopped; owned changes restored or left to their new owner')
end
local function component(actor,primitive)
 for _,key in ipairs({'SkeletalMeshComponent','StaticMeshComponent','StaticMesh','Mesh'})do
  local value=read(actor,key)
  if valid(value)then
   local ok,isPrimitive=pcall(function()return value:IsA(primitive)end)
   if ok and isPrimitive==true then return value end
  end
 end
end
local renderer=Renderer.new({valid=valid,lifetime=lifetime,find=StaticFindObject,findAll=FindAllOf,name=FName,log=log})
local observedWorld,manualOff,failedWorld,stateRendererWait
local scanClass,scanOffset=1,1
local function mission(world)
 if not valid(world)or type(Config.missionMaps)~='table'then return false end
 local ok,name=pcall(function()return world:GetFullName()end)
 if not ok or type(name)~='string'then return false end
 return Config.missionMaps[name]==true
end
local function available(actor,world)
 if not valid(actor)or not Renderer.sameWorld(actor:GetWorld(),world)then return nil end
 local cls=actor:GetClass()
 local path=valid(cls)and cls:GetFullName():match('(/Game/[^ ]+)$')or nil
 local kind=path and byClass[path]
 if not kind or Preferences.categories[groupFor[kind]]~=true or read(actor,'IsGrabbed')~=false then return nil end
 if kind=='weapon'then
  if read(actor,'Locked')~=false or read(actor,'IsGrabbedOnHands')~=false then return nil end
 elseif kind=='mission_item'then
  if read(actor,'CanBeGrabbed')~=true or read(actor,'CoolDown')~=false then return nil end
 elseif read(actor,'bReplicates')~=true then return nil end
 return kind
end
local function release(entry)
 local alive=lifetime(entry.component)
 if alive==nil then return false end
 if not alive then return true end
 local a,b=true,true
 if entry.depthAttempted then a=restoreField(entry.component,'bRenderCustomDepth',true,entry.depth,'SetRenderCustomDepth')end
 if entry.stencilAttempted then b=restoreField(entry.component,'CustomDepthStencilValue',entry.afterStencil,entry.stencil,'SetCustomDepthStencilValue')end
 return a and b
end
local function refresh()
 local primitive=StaticFindObject('/Script/Engine.PrimitiveComponent')
 assert(valid(primitive),'Primitive component class unavailable')
 local retained,owned={},{}
 for _,entry in ipairs(state.items)do
  local actorAlive=lifetime(entry.actor)
  local meshAlive=lifetime(entry.component)
  local eligible=actorAlive==true and available(entry.actor,state.world)
  local current=eligible and component(entry.actor,primitive)
  local matching=current and tostring(current:GetAddress())..' '..current:GetFullName()==entry.name
  local depth,stencil
  if meshAlive==true then depth=read(entry.component,'bRenderCustomDepth');stencil=read(entry.component,'CustomDepthStencilValue')end
  local unknown=depth==nil or stencil==nil
  local intact=depth==true and stencil==entry.afterStencil
  if meshAlive==true and not unknown and not intact then state.ceded[entry.name]=true end
  if actorAlive==nil or meshAlive==nil or (meshAlive==true and unknown)or (eligible and meshAlive and matching and intact)or not release(entry)then
   retained[#retained+1]=entry;owned[entry.name]=true
  end
 end
 state.items=retained
 -- Shared inspection budget across a bounded catalogue cycle; carry offsets
 -- across ticks so dense classes cannot starve later actors or item types.
 local budget,visited=Config.maxActorsPerScan or 2048,0
 while budget>0 and visited<#classes do
 local actors=FindAllOf(classes[scanClass])or{}
 local last=math.min(#actors,scanOffset+budget-1)
 local inspected=math.max(0,last-scanOffset+1)
 for i=scanOffset,last do
  local actor=actors[i]
  local kind=available(actor,state.world)
  if kind then
   local mesh=component(actor,primitive)
   if mesh and read(mesh,'bRenderCustomDepth')==false then
    local name=mesh:GetFullName();local address=mesh:GetAddress();local stencil=read(mesh,'CustomDepthStencilValue')
    if #state.items<(Config.maxItems or 1024)and type(name)=='string'and type(address)=='number'and address>0 and address%1==0 and address<math.huge and not owned[tostring(address)..' '..name]and not state.ceded[tostring(address)..' '..name]and type(stencil)=='number'and stencil%1==0 and stencil>=0 and stencil<=255 then
     local entry={actor=actor,component=mesh,name=tostring(address)..' '..name,depth=false,stencil=stencil,afterStencil=stencilFor[kind]}
     state.items[#state.items+1]=entry;owned[entry.name]=true
     entry.stencilAttempted=true;mesh:SetCustomDepthStencilValue(entry.afterStencil)
     entry.depthAttempted=true;mesh:SetRenderCustomDepth(true)
     assert(read(mesh,'bRenderCustomDepth')==true and read(mesh,'CustomDepthStencilValue')==entry.afterStencil,'Item write failed')
    end
   end
  end
 end
 budget=budget-inspected;visited=visited+1
 if last>=#actors then scanClass=scanClass%#classes+1;scanOffset=1 else scanOffset=last+1 end
 end
 if #state.items>=(Config.maxItems or 1024)and not state.capLogged then state.capLogged=true;log('Owned item safety cap reached; new items wait for released records')end
end
local function start(world)
 local player=Helpers.GetPlayerController()
 if not mission(world)or not valid(player)or not valid(read(player,'Pawn'))then return end
 local pp,err=renderer:ensure(world)
 if not valid(pp)then
  if err~=stateRendererWait then log('Waiting for owned renderer: '..tostring(err));stateRendererWait=err end
  return
 end
 stateRendererWait=nil
 assert(read(pp,'bEnabled')==false,'Owned renderer already enabled')
 local before={}
 for _,key in ipairs({'bEnabled','bUnbound','BlendWeight','Priority'})do before[key]=pp[key]end
 assert(type(before.bUnbound)=='boolean'and type(before.BlendWeight)=='number'and type(before.Priority)=='number','Native post-process state unavailable')
 local library=Helpers.GetKismetSystemLibrary();assert(valid(library),'Renderer settings API unavailable')
 local mode=library:GetConsoleVariableIntValue('r.CustomDepth')
 assert(type(mode)=='number'and mode%1==0 and mode>=0 and mode<=3,'Unknown custom depth mode')
 state={world=world,player=player,pp=pp,library=library,cvarBefore=mode,cvarChanged=mode~=3,before=before,after={bEnabled=true,bUnbound=true,BlendWeight=1.0,Priority=500.0},ppAttempted={},items={},ceded={}}
 local materialLibrary=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary')
 local collection=StaticFindObject('/Game/Mods/ItemContours/MPC_ItemContours.MPC_ItemContours')
 assert(valid(materialLibrary)and valid(collection),'Owned color collection/API unavailable')
 for group,name in pairs({weapons='WeaponsColor',valuables='ValuablesColor',mission='MissionColor'})do
  local c=Preferences.colors[group]
  materialLibrary:SetVectorParameterValue(world,collection,FName(name),{R=c[1],G=c[2],B=c[3],A=c[4]})
  local value=materialLibrary:GetVectorParameterValue(world,collection,FName(name))
  for i,key in ipairs({'R','G','B','A'})do assert(type(value[key])=='number'and math.abs(value[key]-c[i])<0.0001,'Color readback failed')end
 end
 materialLibrary:SetScalarParameterValue(world,collection,FName('Thickness'),Config.thickness)
 materialLibrary:SetScalarParameterValue(world,collection,FName('Opacity'),Config.opacity)
 if state.cvarChanged then state.cvarAttempted=true;library:ExecuteConsoleCommand(world,'r.CustomDepth 3',player);assert(library:GetConsoleVariableIntValue('r.CustomDepth')==3,'Custom depth mode not accepted')end
 for _,key in ipairs({'bUnbound','BlendWeight','Priority','bEnabled'})do state.ppAttempted[key]=true;pp[key]=state.after[key];assert(pp[key]==state.after[key],'Post-process write failed')end
 scanClass,scanOffset=1,1
 log('ACTIVE: automatic continuous mission contours')
end
local function monitor(toggle)
 local current=Helpers.GetWorld()
 if valid(current)and(not observedWorld or not Renderer.sameWorld(current,observedWorld))then
  observedWorld=current;manualOff=false;failedWorld=nil
 end
 if toggle then manualOff=not manualOff;if not manualOff then failedWorld=nil end end
 if state and(state.closing or manualOff or not mission(current)or not Renderer.sameWorld(current,state.world)or not valid(state.pp))then stop()end
 if state and state.closing then return end
 if not state and not manualOff and not failedWorld and mission(current)then start(current)end
 if state then refresh()end
end
local function dispatch(toggle)
 if queued then return end
 queued=true
 local ok=queue(function()
  local success,err=pcall(function()monitor(toggle)end)
  if not success then
   failedWorld=true;log('Continuous update failed: '..tostring(err))
   local cleaned,message=pcall(stop);if not cleaned then log('Cleanup retry needed: '..tostring(message))end
  end
  queued=false
 end)
 if not ok then queued=false end
end
RegisterKeyBind(Key.SEVEN,{ModifierKey.ALT},function()dispatch(true)end)
LoopAsync(Config.scanIntervalMs or 1000,function()dispatch(false)end)
log('Loaded. Mission contours automatic; Alt+7 toggles OFF/ON until world changes.')
