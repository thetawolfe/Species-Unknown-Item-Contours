from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
from lupa import LuaRuntime
l=LuaRuntime(unpack_returned_tuples=True)
l.execute(r'''
logs={};print=function(s)logs[#logs+1]=s end
local nextAddress=0
local function object(o)o=o or{};nextAddress=nextAddress+1;o._address=nextAddress;o.GetAddress=function(self)return self._address end;o.IsValid=function(self)return self.valid~=false end;return o end
world=object();otherWorld=object();primitive=object()
pp=object({bEnabled=false,bUnbound=false,BlendWeight=0.3,Priority=2})
mesh=object({bRenderCustomDepth=false,CustomDepthStencilValue=9})
function mesh:GetFullName()return 'StaticMeshComponent diagnostic-test-money'end
function mesh:IsA(c)return c==primitive end
function mesh:SetRenderCustomDepth(v)self.bRenderCustomDepth=v end
function mesh:SetCustomDepthStencilValue(v)self.CustomDepthStencilValue=v end
local actorClass=object();function actorClass:GetFullName()return 'BlueprintGeneratedClass /Game/Blueprints/Interact/Item/BP_Item_Credit_1.BP_Item_Credit_1_C'end
actor=object({StaticMesh=mesh,IsGrabbed=false,bReplicates=true});function actor:GetClass()return actorClass end;function actor:GetWorld()return world end
function actor:K2_GetActorLocation()return {X=10,Y=0,Z=0}end
local rendererClass=object();function rendererClass:GetFullName()return 'BlueprintGeneratedClass /Game/Mods/ItemContours/ModActor.ModActor_C'end
postProcessClass=object()
local renderer=object();function renderer:GetClass()return rendererClass end;function renderer:GetWorld()return world end
function renderer:GetComponentByClass(c)assert(c==postProcessClass);return pp end
function pp:GetOwner()return renderer end;function pp:GetWorld()return world end
pawn=object({PostProcessOutlineDebug=pp});function pawn:K2_GetActorLocation()return {X=0,Y=0,Z=0}end;player=object({Pawn=pawn});library=object({mode=1})
function library:GetConsoleVariableIntValue(n)assert(n=='r.CustomDepth');return self.mode end
function library:ExecuteConsoleCommand(w,cmd,p)self.commands=(self.commands or 0)+1;assert(w==world or w==otherWorld);self.mode=tonumber(cmd:match('(%d+)$'))end
currentWorld=world
package.preload.UEHelpers=function()return {GetWorld=function()return currentWorld end,GetPlayerController=function()return player end,GetKismetSystemLibrary=function()return library end}end
collection=object();materialLibrary=object({colors={},scalars={}})
function materialLibrary:SetVectorParameterValue(w,c,name,value)assert(c==collection);self.colors[name]=value end
function materialLibrary:GetVectorParameterValue(w,c,name)return self.colors[name]end
function materialLibrary:SetScalarParameterValue(w,c,name,value)self.scalars[name]=value end
FName=function(name)return name end
StaticFindObject=function(p)
 if p=='/Script/Engine.PostProcessComponent'then return postProcessClass
 elseif p=='/Script/Engine.PrimitiveComponent'then return primitive
 elseif p=='/Script/Engine.Default__KismetMaterialLibrary'then return materialLibrary
 elseif p=='/Game/Mods/ItemContours/MPC_ItemContours.MPC_ItemContours'then return collection end
 error('Unexpected lookup')
end
FindAllOf=function(c)if c=='PostProcessComponent'then return{pp}end;if c=='BP_Item_Credit_1_C'then return extraActors or{actor}else return{}end end
Key={SEVEN=7};ModifierKey={ALT=1};EngineTickAvailable=true;EGameThreadMethod={EngineTick=2}
ExecuteInGameThread=function(fn,method)assert(method==2);fn()end
RegisterKeyBind=function(k,m,fn)toggle=fn end
ExecuteWithDelay=function()error('Unexpected expiry')end
LoopAsync=function(ms,fn)tick=fn end
''')
for name in ['catalogue','settings','policy','config','renderer']:
    l.globals().module_name='ItemContours.'+name
    l.globals().module_path=str(root/'runtime/Scripts/ItemContours'/(name+'.lua'))
    l.execute('local p=module_path;package.preload[module_name]=function()return dofile(p)end')
l.execute("function world:GetFullName()return 'World /Game/Maps/SpaceShip.SpaceShip'end; function otherWorld:GetFullName()return 'World /Game/Maps/PolarMap.PolarMap'end")
l.execute("require('ItemContours.config').missionMaps={['World /Game/Maps/SpaceShip.SpaceShip']=true,['World /Game/Maps/PolarMap.PolarMap']=true}")
l.execute((root/'runtime/Scripts/main.lua').read_text())
l.execute(r'''
function cycle()for i=1,100 do tick()end end
assert(not pp.bEnabled);cycle();assert(pp.bEnabled and mesh.bRenderCustomDepth)
-- No expiry exists; sustained refresh leaves renderer and item active.
assert(expire==nil);cycle();assert(pp.bEnabled and mesh.bRenderCustomDepth)
-- A destroyed primitive is released while its actor survives; a replacement is discovered.
local originalMesh=mesh;local replacement={}
for k,v in pairs(mesh)do replacement[k]=v end
replacement._address=999;replacement.bRenderCustomDepth=false;replacement.CustomDepthStencilValue=9
mesh.valid=false;actor.StaticMesh=replacement;cycle();assert(replacement.bRenderCustomDepth)
actor.IsGrabbed=true;cycle();assert(not replacement.bRenderCustomDepth)
actor.IsGrabbed=false;mesh.valid=true;actor.StaticMesh=originalMesh
mesh.bRenderCustomDepth=false;mesh.CustomDepthStencilValue=9;cycle();assert(mesh.bRenderCustomDepth)
-- Active ownership takeover releases only our depth and stays relinquished.
mesh.CustomDepthStencilValue=77;tick();assert(mesh.CustomDepthStencilValue==77 and not mesh.bRenderCustomDepth)
cycle();assert(mesh.CustomDepthStencilValue==77 and not mesh.bRenderCustomDepth)
toggle();mesh.CustomDepthStencilValue=9;toggle();cycle();assert(mesh.bRenderCustomDepth)
-- Unknown readback retains the journal until the field recovers.
mesh.CustomDepthStencilValue=nil;tick();assert(mesh.bRenderCustomDepth)
mesh.CustomDepthStencilValue=202;cycle();assert(mesh.bRenderCustomDepth)
actor.IsGrabbed=true;cycle();assert(not mesh.bRenderCustomDepth and mesh.CustomDepthStencilValue==9 and pp.bEnabled)
actor.IsGrabbed=false;cycle();assert(mesh.bRenderCustomDepth)
toggle();assert(not pp.bEnabled and not mesh.bRenderCustomDepth);cycle();assert(not pp.bEnabled)
toggle();cycle();assert(pp.bEnabled and mesh.bRenderCustomDepth)
-- New item appears after activation; all eight qualify (no five-item cap).
extraActors={actor};local meshes={}
for i=1,8 do
 local m={};for k,v in pairs(mesh)do m[k]=v end;m._address=100+i;m.bRenderCustomDepth=false;m.CustomDepthStencilValue=9;m.GetFullName=function()return 'StaticMeshComponent new-'..i end
 local a={};for k,v in pairs(actor)do a[k]=v end;a.StaticMesh=m
 meshes[i]=m;extraActors[#extraActors+1]=a
end
cycle();for i=1,8 do assert(meshes[i].bRenderCustomDepth)end
mesh.CustomDepthStencilValue=77;toggle();assert(mesh.CustomDepthStencilValue==77 and not mesh.bRenderCustomDepth);mesh.CustomDepthStencilValue=9
extraActors=nil;toggle();cycle()
local real=mesh.IsValid;mesh.IsValid=function()return nil end;toggle();assert(pp.bEnabled);mesh.IsValid=real;cycle();assert(not pp.bEnabled)
-- Manual OFF survives same-world wrappers, but new mission resets preference.
local oldWorld=world;function pp:GetWorld()return currentWorld end;local owner=pp:GetOwner();function owner:GetWorld()return currentWorld end;function actor:GetWorld()return currentWorld end;currentWorld=otherWorld;tick();assert(pp.bEnabled);cycle();assert(pp.bEnabled)
toggle();currentWorld=oldWorld;cycle();assert(pp.bEnabled and mesh.bRenderCustomDepth)
-- Stormrock raw material uses SimpleItem eligibility and yellow stencil203.
local originalFind=FindAllOf
local rawMesh={};for k,v in pairs(mesh)do rawMesh[k]=v end
rawMesh._address=8888;rawMesh.bRenderCustomDepth=false;rawMesh.CustomDepthStencilValue=9
rawMesh.GetFullName=function()return 'StaticMeshComponent raw-material'end
local rawClass={IsValid=function()return true end};function rawClass:GetFullName()return 'BlueprintGeneratedClass /Game/Blueprints/Interact/Item/BP_Item_RawMaterial.BP_Item_RawMaterial_C'end
local rawActor={};for k,v in pairs(actor)do rawActor[k]=v end
rawActor.StaticMesh=rawMesh;rawActor.GetClass=function()return rawClass end
FindAllOf=function(c)if c=='BP_Item_RawMaterial_C'then return{rawActor}else return originalFind(c)end end
cycle();assert(rawMesh.bRenderCustomDepth and rawMesh.CustomDepthStencilValue==203)
rawActor.IsGrabbed=true;cycle();assert(not rawMesh.bRenderCustomDepth and rawMesh.CustomDepthStencilValue==9)
FindAllOf=originalFind
-- Mutation then exception rolls back every journaled field and blocks retries.
toggle();local setter=mesh.SetRenderCustomDepth
mesh.SetRenderCustomDepth=function(self,v)self.bRenderCustomDepth=v;if v then error('partial')end end
toggle();cycle();assert(not pp.bEnabled and not mesh.bRenderCustomDepth and mesh.CustomDepthStencilValue==9 and library.mode==1)
mesh.SetRenderCustomDepth=setter;cycle();assert(not pp.bEnabled)
-- Unallowlisted map fails closed.
function world:GetFullName()return 'World /Game/Maps/Lobby.Lobby'end
toggle();cycle();assert(not pp.bEnabled)
''')
print('Continuous runtime mocked checks passed: auto mission, sticky toggle, refresh/add/remove, uncapped items, no expiry, travel, ownership, unknown lifetime, partial-write rollback, fail-closed gate')
