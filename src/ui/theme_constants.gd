class_name ThemeConstants
extends RefCounted
## Centralized UI style constants for consistent theming across all components

# ============================================
# CORNER RADII
# ============================================

const RADIUS_SMALL: int = 4
const RADIUS_MEDIUM: int = 6
const RADIUS_LARGE: int = 8
const RADIUS_PILL: int = 25

# ============================================
# FONT SIZES
# ============================================

const FONT_SMALL: int = 14
const FONT_NORMAL: int = 16
const FONT_MEDIUM: int = 18
const FONT_LARGE: int = 20
const FONT_TITLE: int = 24

# ============================================
# MARGINS AND PADDING
# ============================================

const MARGIN_SMALL: int = 4
const MARGIN_NORMAL: int = 8
const MARGIN_LARGE: int = 16

const PADDING_SMALL: int = 4
const PADDING_NORMAL: int = 8
const PADDING_LARGE: int = 12

# ============================================
# STATUS COLORS
# ============================================

const STATUS_GOOD = Color(0.3, 0.75, 0.5)
const STATUS_WARNING = Color(0.85, 0.65, 0.25)
const STATUS_CRITICAL = Color(0.85, 0.3, 0.3)
const STATUS_NEUTRAL = Color(0.6, 0.65, 0.7)

# ============================================
# TEXT COLORS (WCAG AA+ compliant)
# ============================================

## Primary text - high contrast (9.8:1 on dark panels)
const TEXT_PRIMARY = Color(0.85, 0.88, 0.92)
## Secondary/dim text - improved contrast (5.1:1 on dark panels)
const TEXT_SECONDARY = Color(0.60, 0.65, 0.75)
## Disabled text - reduced visibility
const TEXT_DISABLED = Color(0.40, 0.42, 0.48)

# ============================================
# BORDER WIDTHS
# ============================================

const BORDER_THIN: int = 1
const BORDER_NORMAL: int = 2
const BORDER_THICK: int = 3

# ============================================
# SHADOW SETTINGS
# ============================================

const SHADOW_SIZE_SMALL: int = 4
const SHADOW_SIZE_NORMAL: int = 8
const SHADOW_SIZE_LARGE: int = 12
const SHADOW_COLOR = Color(0, 0, 0, 0.5)

# ============================================
# ANIMATION DURATIONS
# ============================================

const ANIM_FAST: float = 0.1
const ANIM_NORMAL: float = 0.15
const ANIM_SLOW: float = 0.2
const ANIM_PANEL_SLIDE: float = 0.2

# ============================================
# COMPONENT SIZES
# ============================================

const BUTTON_MIN_SIZE = Vector2(40, 40)
const ICON_SIZE_SMALL: int = 20
const ICON_SIZE_NORMAL: int = 32
const ICON_SIZE_LARGE: int = 40
