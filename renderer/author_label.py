import unreal,json,gc
from pathlib import Path
def main():
 path='/Game/Mods/ItemContours/ContourChunk'
 label=unreal.EditorAssetLibrary.load_asset(path)if unreal.EditorAssetLibrary.does_asset_exist(path)else None
 if label is None:
  factory=unreal.DataAssetFactory();factory.set_editor_property('data_asset_class',unreal.PrimaryAssetLabel)
  label=unreal.AssetToolsHelpers.get_asset_tools().create_asset('ContourChunk','/Game/Mods/ItemContours',unreal.PrimaryAssetLabel,factory)
 rules=unreal.PrimaryAssetRules()
 for key,value in {'priority':1,'chunk_id':3713,'apply_recursively':True,'cook_rule':unreal.PrimaryAssetCookRule.ALWAYS_COOK}.items():rules.set_editor_property(key,value)
 label.set_editor_property('rules',rules)
 label.set_editor_property('label_assets_in_my_directory',True)
 label.set_editor_property('is_runtime_label',False)
 unreal.EditorAssetLibrary.save_loaded_asset(label)
 (Path(__file__).resolve().parent/'chunk.json').write_text(json.dumps({'chunkId':3713,'label':path,'runtimeLabel':False}))
main();gc.collect()
