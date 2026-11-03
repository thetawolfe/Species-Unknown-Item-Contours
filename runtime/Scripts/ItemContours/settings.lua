-- Validated user settings only; renderer verification/stencil reservations are not settings.
local Policy=require('ItemContours.policy')
local Settings={}
local function default(v,fallback)if v==nil then return fallback end;return v end
local names={weapons='weapon',valuables='money',mission='key_item'}
local function integer(v,low,high)return type(v)=='number' and v==v and v%1==0 and v>=low and v<=high end
function Settings.normalize(raw,world)
 assert(type(raw)=='table' and type(world)=='string' and #world>0,'Settings and authoritative world ID required')
 local allowed={schemaVersion=true,enabled=true,categories=true,colors=true,capacity=true,maxBatch=true,pollIntervalMs=true}
 for key in pairs(raw) do assert(allowed[key],'Unknown setting: '..tostring(key)) end
 assert(raw.schemaVersion==nil or raw.schemaVersion==1,'Unsupported settings version')
 local out={schemaVersion=1,world=world,enabled=false,categories={},colors={},capacity=default(raw.capacity,2048),pollIntervalMs=default(raw.pollIntervalMs,100)}
 if raw.enabled~=nil then assert(type(raw.enabled)=='boolean','enabled must be boolean');out.enabled=raw.enabled end
 assert(integer(out.capacity,1,10000),'capacity must be 1..10000')
 out.maxBatch=default(raw.maxBatch,math.min(32,out.capacity))
 assert(integer(out.maxBatch,1,256) and out.maxBatch<=out.capacity,'maxBatch must be 1..256 and <= capacity')
 assert(integer(out.pollIntervalMs,50,10000),'pollIntervalMs must be 50..10000')
 assert(raw.categories==nil or type(raw.categories)=='table','categories must be a table')
 assert(raw.colors==nil or type(raw.colors)=='table','colors must be a table')
 for key in pairs(raw.categories or {})do assert(names[key],'Unknown category')end
 for key in pairs(raw.colors or {})do assert(names[key],'Unknown color group')end
 for group,kind in pairs(names) do
  local value=raw.categories and raw.categories[group]
  assert(value==nil or type(value)=='boolean','Category setting must be boolean')
  out.categories[group]=value~=false
  local color=raw.colors and raw.colors[group]
  if color~=nil then
   assert(type(color)=='table','Color must be RGBA table')
   local count=0;for k in pairs(color)do assert(integer(k,1,4),'Color requires exactly four indexed channels');count=count+1 end
   assert(count==4,'Color requires exactly four channels')
  end
  out.colors[group]=Policy.style({kind=kind,classificationVerified=true},{colors=raw.colors}).rgba
 end
 return out
end
return Settings

