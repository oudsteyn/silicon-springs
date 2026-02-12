Modern HUD architecture notes
- `MainHUD` is a CanvasLayer-driven UI root.
- Bottom-docked build menu: `build_menu_panel.tscn`.
- Top-right data panel: `city_stats_panel.tscn`.
- Dynamic popup: `building_info_popup.tscn` + `building_info_popup.gd`.
- Event decoupling via `/root/CityEventBus` signals.
- Glass-style blur uses BackBufferCopy + `ui_glass_blur.gdshader`.

Visual Target Baseline (AAA parity gate)
- Day:
  exposure `1.00-1.15`, white point `1.05-1.30`, fog density `0.008-0.014`, sun energy `0.95-1.35`
- Dusk:
  exposure `0.95-1.10`, white point `1.00-1.20`, fog density `0.012-0.022`, sun energy `0.28-0.75`
- Night:
  exposure `0.85-1.00`, white point `0.95-1.15`, fog density `0.018-0.030`, sun energy `0.02-0.20`

Quality Tier Contract
- Low: SSR off, SSAO off, volumetric fog off, shadows orthogonal, reduced distance.
- Medium: SSR off, SSAO on, volumetric fog on, 2-split shadows.
- High: SSR on, SSAO on, volumetric fog on, 4-split shadows.
- Ultra: High + stronger SSAO + extended shadow distance + cinematic grade.
