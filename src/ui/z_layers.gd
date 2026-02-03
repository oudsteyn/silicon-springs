class_name ZLayers
extends RefCounted
## Centralized Z-index constants for consistent layering across all visual elements
## Higher values render on top of lower values

# ============================================
# WORLD LAYERS (Below UI)
# ============================================

## Base terrain (grass, water, etc.) - rendered first/behind everything
const TERRAIN: int = -2

## Zone overlay (residential, commercial, etc.)
const ZONE_LAYER: int = -1

## Grid lines (above zones, below buildings)
const GRID_LINES: int = 0

## Buildings and structures (default layer for placed buildings)
const BUILDINGS: int = 1

## Infrastructure connections (power lines, pipes visible through roads)
const INFRASTRUCTURE: int = 2

## Heat map and data visualization overlays
const HEAT_MAP_OVERLAY: int = 4

## Selection and hover highlights
const CELL_HIGHLIGHT: int = 10

## Placement preview ghost
const PLACEMENT_PREVIEW: int = 13

## Utility connection indicators
const UTILITY_INDICATORS: int = 15

## Building hover glow effect
const BUILDING_HOVER: int = 20

## Action feedback effects (rings, particles)
const ACTION_FEEDBACK: int = 50

# ============================================
# UI LAYERS (CanvasLayer indices)
# ============================================

## HUD elements (status pill, tool palette)
const UI_HUD: int = 95

## Panels and dialogs
const UI_PANEL: int = 96

## Modal overlays (dashboard, settings)
const UI_MODAL: int = 100

## Tooltips
const UI_TOOLTIP: int = 105

## Notifications and alerts
const UI_NOTIFICATION: int = 110

## Debug overlays (highest priority)
const UI_DEBUG: int = 200
