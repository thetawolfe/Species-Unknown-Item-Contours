-- Pure eligibility/restoration policy. No engine calls or actor-name guessing.
local Policy={}
local groups={weapon='weapons',money='valuables',hard_drive='valuables',key_item='mission',mission_item='mission'}
local defaults={weapons={1,0,0,1},valuables={0,1,0,1},mission={1,1,0,1}}
function Policy.style(item,settings)
 if type(item)~='table' or item.classificationVerified~=true then return nil end
 -- Explicit kind takes precedence over broad category/mission-role metadata.
 local group=groups[item.kind]
 if not group then return nil end -- Ammo and health stations have no supported style.
 local color=defaults[group]
 if type(settings)=='table' and settings.colors and settings.colors[group] then color=settings.colors[group] end
 assert(type(color)=='table','RGBA color table required')
 local result={group=group,rgba={}}
 for i=1,4 do local v=color[i];assert(type(v)=='number' and v==v and v>=0 and v<=1,'RGBA channels must be finite values from 0 to 1');result.rgba[i]=v end
 return result
end
function Policy.eligible(item,settings)
 if type(item)~='table' or type(settings)~='table' then return false end
 if type(settings.categories)~='table' then return false end
 local style=Policy.style(item,settings)
 if settings.enabled~=true or not style or settings.categories[style.group]~=true then return false end
 return item.classificationVerified==true and item.alive==true and item.available==true
  and item.carried==false and item.equipped==false and item.isCharacter==false
  and item.isPreview==false and item.world==settings.world and type(item.world)=='string'
end
local function validState(s)
 return type(s)=='table' and type(s.depth)=='boolean' and type(s.stencil)=='number'
  and s.stencil==s.stencil and s.stencil%1==0 and s.stencil>=0 and s.stencil<=255
end
function Policy.planApply(before,stencil,materialVerified)
 assert(validState(before),'Verified component state required')
 assert(materialVerified==true,'Through-wall material/stencil behavior not verified')
 assert(type(stencil)=='number' and stencil%1==0 and stencil>=1 and stencil<=255,'Verified nonzero stencil required')
 -- Existing custom-depth users are left to their owner, even if their stencil is zero.
 if before.depth then return nil,'Existing custom-depth owner' end
 return {before={depth=before.depth,stencil=before.stencil},after={depth=true,stencil=stencil}}
end
function Policy.planRestore(change,current)
 assert(type(change)=='table' and validState(change.before) and validState(change.after),'Recorded change required')
 assert(validState(current),'Current component state required')
 if current.depth~=change.after.depth or current.stencil~=change.after.stencil then return nil,'Component changed by another owner' end
 return {depth=change.before.depth,stencil=change.before.stencil}
end
return Policy


