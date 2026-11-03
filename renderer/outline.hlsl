
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
 