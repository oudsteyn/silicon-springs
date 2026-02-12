Modern HUD architecture notes
- `MainHUD` is a CanvasLayer-driven UI root.
- Bottom-docked build menu: `build_menu_panel.tscn`.
- Top-right data panel: `city_stats_panel.tscn`.
- Dynamic popup: `building_info_popup.tscn` + `building_info_popup.gd`.
- Event decoupling via `/root/CityEventBus` signals.
- Glass-style blur uses BackBufferCopy + `ui_glass_blur.gdshader`.
