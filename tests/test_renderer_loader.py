from pathlib import Path
import sys
r=Path(__file__).resolve().parents[1]
from lupa import LuaRuntime
l=LuaRuntime(unpack_returned_tuples=True);l.globals().module=str(r/'runtime/Scripts/ItemContours/renderer.lua')
l.execute(r'''
local R=dofile(module);local current;local spawned=0;local findExisting=false;local unknown=false;local fail=false
local cls={};function cls:IsValid()return true end;function cls:GetFullName()return 'BlueprintGeneratedClass /Game/Mods/ItemContours/ModActor.ModActor_C'end
local ppClass={IsValid=function()return true end}
local function world(id)
 local w={};function w:IsValid()return true end;function w:GetAddress()return id end
 function w:SpawnActor(c,location,rotation)
  assert(c==cls and next(location)==nil and next(rotation)==nil);spawned=spawned+1
  if fail then return nil end
  local a={};function a:IsValid()if unknown then error('unknown')end;return true end
  function a:GetWorld()return w end;function a:GetClass()return cls end
  local p={IsValid=function()return true end};function p:GetWorld()return w end;function p:GetOwner()return a end
  function a:GetComponentByClass(c)assert(c==ppClass);return p end
  current=p;return a
 end
 return w
end
local function valid(o)if not o then return false end;local ok,v=pcall(o.IsValid,o);return ok and v==true end
local function lifetime(o)local ok,v=pcall(o.IsValid,o);if not ok then return nil end;return v end
local api={valid=valid,lifetime=lifetime,name=function(n)return n end,log=function()end,
 findAll=function()return findExisting and current and{current}or{}end,
 find=function(p)if p=='/Script/Engine.PostProcessComponent'then return ppClass else return cls end end}
local loader=R.new(api);local a=world(1);local b=world(2)
assert(loader:ensure(a)==current and spawned==1)
assert(loader:ensure(a)==current and spawned==1)
unknown=true;local p,err=loader:ensure(a);assert(not p and err:find('unknown')and spawned==1);unknown=false
assert(loader:ensure(b)==current and spawned==2)
-- A loader started after native BPModLoader reuses its existing actor.
findExisting=true;local another=R.new(api);assert(another:ensure(b)==current and spawned==2);findExisting=false
-- Failed spawn cannot cause repeated native creations in the same world.
fail=true;local c=world(3);assert(not loader:ensure(c));assert(spawned==3);assert(not loader:ensure(c));assert(spawned==3)
-- The proven AssetRegistry path can reload a class after travel/GC.
fail=false;local registry={IsValid=function()return true end};function registry:GetAsset(d)assert(d.PackageName=='/Game/Mods/ItemContours/ModActor'and d.AssetName=='ModActor_C');return cls end
local api2={};for k,v in pairs(api)do api2[k]=v end
api2.find=function(p)if p=='/Script/Engine.PostProcessComponent'then return ppClass elseif p=='/Script/AssetRegistry.Default__AssetRegistryHelpers'then return registry end end
local d=world(4);assert(R.new(api2):ensure(d)==current and spawned==4)
-- A foreign class returned by resolution is never passed to SpawnActor.
local foreign={IsValid=function()return true end,GetFullName=function()return 'BlueprintGeneratedClass /Game/Other.Other_C'end}
local api3={};for k,v in pairs(api)do api3[k]=v end;api3.find=function(p)if p=='/Script/Engine.PostProcessComponent'then return ppClass else return foreign end end
assert(not R.new(api3):ensure(world(5))and spawned==4)
-- Unexpected returned actor identity is refused and cannot trigger repeated spawns.
local bad=world(6);function bad:SpawnActor()spawned=spawned+1;return {IsValid=function()return true end,GetClass=function()return foreign end,GetWorld=function()return bad end}end
local loader3=R.new(api);assert(not loader3:ensure(bad)and spawned==5);assert(not loader3:ensure(bad)and spawned==5)
-- Unknown/invalid/zero identities cannot match or authorize spawning.
assert(not R.sameWorld({},{}))
local strange=world(42);function strange:IsValid()return 'unknown'end;assert(not R.sameWorld(strange,world(42)))
local zero=world(0);assert(not R.new(api):ensure(zero))
local broken=world(9);function broken:GetAddress()error('unavailable')end
assert(not R.new(api):ensure(broken))
local dead=world(10);function dead:IsValid()return false end
assert(not R.sameWorld(dead,dead))
-- Distinct Lua wrappers can identify the same native UWorld.
local alias=world(7);local native=world(7)
function alias:SpawnActor(c,l,r)return native:SpawnActor(c,l,r)end
local aliasLoader=R.new(api);assert(aliasLoader:ensure(alias)==current,'same native world must survive wrapper aliasing')
assert(aliasLoader:ensure(alias)==current,'cached actor must survive wrapper aliasing')
findExisting=true;assert(R.new(api):ensure(alias)==current,'existing renderer must survive wrapper aliasing');findExisting=false
local wrong=world(8);function wrong:SpawnActor(c,l,r)return native:SpawnActor(c,l,r)end
local rejected,message=R.new(api):ensure(wrong);assert(not rejected and message:find('identity mismatch'),'different native world must remain blocked')
print('Mission renderer loader: one engine-owned spawn per world, existing actor reuse, cached lookup, unknown-lifetime retention and failed-spawn suppression passed; engine mocked')
''')
