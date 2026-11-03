"""Original assets implementing the documented CustomStencil post-process technique.
Reference: Epic Post Process Materials / CustomDepth Stencil; no external asset files copied.
"""
import json,unreal
from pathlib import Path
def main():
 ROOT=Path(__file__).resolve().parent
 PATH='/Game/Mods/ItemContours'
 tools=unreal.AssetToolsHelpers.get_asset_tools()
 def struct(cls,**properties):
  value=cls()
  for key,item in properties.items():value.set_editor_property(key,item)
  return value
 def asset(name,cls,factory):
  found=unreal.EditorAssetLibrary.load_asset(PATH+'/'+name)if unreal.EditorAssetLibrary.does_asset_exist(PATH+'/'+name)else None
  return found or tools.create_asset(name,PATH,cls,factory)
 collection=asset('MPC_ItemContours',unreal.MaterialParameterCollection,unreal.MaterialParameterCollectionFactoryNew())
 assert collection
 vectors=[]
 for name,color in [('WeaponsColor',(1,0,0,1)),('ValuablesColor',(0,1,0,1)),('MissionColor',(1,1,0,1))]:
  p=unreal.CollectionVectorParameter();p.set_editor_property('parameter_name',name);p.set_editor_property('default_value',unreal.LinearColor(*color));vectors.append(p)
 scalars=[]
 for name,value in [('Thickness',2.0),('Opacity',1.0),('WeaponsStencil',201.0),('ValuablesStencil',202.0),('MissionStencil',203.0)]:
  p=unreal.CollectionScalarParameter();p.set_editor_property('parameter_name',name);p.set_editor_property('default_value',value);scalars.append(p)
 collection.set_editor_property('vector_parameters',vectors);collection.set_editor_property('scalar_parameters',scalars)
 unreal.EditorAssetLibrary.save_loaded_asset(collection)
 material=asset('M_ItemContours',unreal.Material,unreal.MaterialFactoryNew());assert material
 material.set_editor_property('material_domain',unreal.MaterialDomain.MD_POST_PROCESS)
 material.set_editor_property('blendable_location',unreal.BlendableLocation.BL_SCENE_COLOR_AFTER_TONEMAPPING)
 unreal.MaterialEditingLibrary.delete_all_material_expressions(material)
 create=unreal.MaterialEditingLibrary.create_material_expression
 scene=create(material,unreal.MaterialExpressionSceneTexture,-1000,-400);scene.set_editor_property('scene_texture_id',unreal.SceneTextureId.PPI_POST_PROCESS_INPUT0)
 stencil=create(material,unreal.MaterialExpressionSceneTexture,-1000,-200);stencil.set_editor_property('scene_texture_id',unreal.SceneTextureId.PPI_CUSTOM_STENCIL)
 custom=create(material,unreal.MaterialExpressionCustom,0,0)
 inputs=['Scene','CenterStencil','Texel','WeaponsColor','ValuablesColor','MissionColor','Thickness','Opacity','WeaponsStencil','ValuablesStencil','MissionStencil']
 custom.set_editor_property('inputs',[struct(unreal.CustomInput,input_name=name)for name in inputs])
 custom.set_editor_property('output_type',unreal.CustomMaterialOutputType.CMOT_FLOAT3)
 custom.set_editor_property('description','ItemContours: independent RGB palette; CustomStencil edges include occluded items; no SceneDepth rejection')
 code=r'''
 float2 uv = GetDefaultSceneTextureUV(Parameters, 25);
 float2 delta = Texel.xy * clamp(Thickness, 1.0, 8.0);
 float center = round(CenterStencil.r);
 float3 ids = round(float3(WeaponsStencil, ValuablesStencil, MissionStencil));
 float3 centerMatch = 1.0 - step(0.5, abs(center.xxx - ids));
 float centerKnown = saturate(dot(centerMatch, float3(1,1,1)));
 float chosen = center;
 float edge = 0.0;
 [unroll] for (int y = -1; y <= 1; ++y) {
  [unroll] for (int x = -1; x <= 1; ++x) {
   if (x == 0 && y == 0) continue;
   float neighbor = round(SceneTextureLookup(uv + float2(x,y)*delta, 25, false).r);
   float3 matches = 1.0 - step(0.5, abs(neighbor.xxx - ids));
   float known = saturate(dot(matches, float3(1,1,1)));
   if (abs(neighbor - center) > 0.5 && max(centerKnown,known) > 0.5) {
    edge = 1.0;
    if (centerKnown < 0.5 && known > 0.5) chosen = neighbor;
   }
  }
 }
 float3 pick = 1.0 - step(0.5, abs(chosen.xxx - ids));
 float3 color = pick.x*WeaponsColor.rgb + pick.y*ValuablesColor.rgb + pick.z*MissionColor.rgb;
 float alpha = pick.x*WeaponsColor.a + pick.y*ValuablesColor.a + pick.z*MissionColor.a;
 return lerp(Scene.rgb, color, edge*saturate(Opacity)*saturate(alpha));
 '''
 custom.set_editor_property('code',code)
 connect=unreal.MaterialEditingLibrary.connect_material_expressions
 assert connect(scene,'Color',custom,'Scene')
 assert connect(stencil,'Color',custom,'CenterStencil')
 assert connect(stencil,'InvSize',custom,'Texel')
 for i,name in enumerate(inputs[3:]):
  node=create(material,unreal.MaterialExpressionCollectionParameter,-700,100+i*120)
  node.set_editor_property('collection',collection);node.set_editor_property('parameter_name',name)
  assert connect(node,'',custom,name)
 assert unreal.MaterialEditingLibrary.connect_material_property(custom,'',unreal.MaterialProperty.MP_EMISSIVE_COLOR)
 unreal.MaterialEditingLibrary.recompile_material(material)
 unreal.EditorAssetLibrary.save_loaded_asset(material)
 factory=unreal.BlueprintFactory();factory.set_editor_property('parent_class',unreal.Actor)
 blueprint=asset('ModActor',unreal.Blueprint,factory);assert blueprint
 subsystem=unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
 lib=unreal.SubobjectDataBlueprintFunctionLibrary
 handles=subsystem.k2_gather_subobject_data_for_blueprint(blueprint)
 component=None
 for h in handles:
  obj=lib.get_object(lib.get_data(h))
  if isinstance(obj,unreal.PostProcessComponent):component=obj;break
 if component is None:
  handle,reason=subsystem.add_new_subobject(struct(unreal.AddNewSubobjectParams,parent_handle=handles[0],new_class=unreal.PostProcessComponent,blueprint_context=blueprint))
  component=lib.get_object(lib.get_data(handle));assert isinstance(component,unreal.PostProcessComponent),str(reason)
 component.set_editor_property('unbound',True);component.set_editor_property('enabled',False)
 component.set_editor_property('priority',200.0);component.set_editor_property('blend_weight',1.0)
 component.set_editor_property('component_tags',['ItemContours.Renderer.v1'])
 settings=component.get_editor_property('settings')
 settings.set_editor_property('weighted_blendables',struct(unreal.WeightedBlendables,array=[struct(unreal.WeightedBlendable,weight=1.0,object=material)]))
 component.set_editor_property('settings',settings)
 unreal.BlueprintEditorLibrary.compile_blueprint(blueprint)
 cdo=unreal.get_default_object(blueprint.generated_class());cdo.set_editor_property('replicates',False)
 unreal.EditorAssetLibrary.save_loaded_asset(blueprint)
 assert collection.get_path_name()==PATH+'/MPC_ItemContours.MPC_ItemContours'
 report={'engine':unreal.SystemLibrary.get_engine_version(),'assets':[x.get_path_name()for x in [collection,material,blueprint]],'stencils':{'weapons':201,'valuables':202,'mission':203},'defaultEnabled':False,'throughWallDesign':'CustomStencil neighbor edges; no SceneDepth comparison','sourceReferences':['https://dev.epicgames.com/documentation/en-us/unreal-engine/post-process-materials-in-unreal-engine'],'externalAssetsCopied':False}
 (ROOT/'authoring-result.json').write_text(json.dumps(report,indent=2))
 (ROOT/'outline.hlsl').write_text(code)
 unreal.log('ITEM_CONTOURS_ASSETS_AUTHORED')

main()
import gc
gc.collect()
unreal.log('ITEM_CONTOURS_AUTHORING_CLEANUP_COMPLETE')
