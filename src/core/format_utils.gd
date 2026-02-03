class_name FormatUtils
extends RefCounted
## Static utility class for formatting numbers, currency, and text
##
## Use these methods instead of duplicating formatting code across UI classes.

## Format an integer with thousands separators (e.g., 1234567 -> "1,234,567")
static func format_number(num: int) -> String:
	var str_num = str(abs(num))
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result


## Format currency with sign (e.g., 1000 -> "+$1,000", -500 -> "-$500")
static func format_currency(amount: int, show_sign: bool = true) -> String:
	if show_sign:
		if amount >= 0:
			return "+$%s" % format_number(amount)
		else:
			return "-$%s" % format_number(abs(amount))
	else:
		return "$%s" % format_number(abs(amount))


## Format currency per month (e.g., 1000 -> "+$1,000/mo")
static func format_monthly(amount: int) -> String:
	if amount >= 0:
		return "+$%s/mo" % format_number(amount)
	else:
		return "-$%s/mo" % format_number(abs(amount))


## Format a percentage (e.g., 0.75 -> "75%")
static func format_percent(ratio: float) -> String:
	return "%d%%" % int(ratio * 100)


## Format a ratio with sign (e.g., 0.05 -> "+5%", -0.03 -> "-3%")
static func format_percent_change(ratio: float) -> String:
	var sign_str = "+" if ratio > 0 else ""
	return "%s%d%%" % [sign_str, int(ratio * 100)]


## Compact number format (e.g., 1500 -> "1.5K", 2000000 -> "2M")
static func format_compact(num: int) -> String:
	var abs_num = abs(num)
	var sign_str = "" if num >= 0 else "-"

	if abs_num >= 1_000_000_000:
		return "%s%.1fB" % [sign_str, abs_num / 1_000_000_000.0]
	elif abs_num >= 1_000_000:
		return "%s%.1fM" % [sign_str, abs_num / 1_000_000.0]
	elif abs_num >= 1_000:
		return "%s%.1fK" % [sign_str, abs_num / 1_000.0]
	else:
		return "%s%d" % [sign_str, abs_num]


## Format a resource value with unit (e.g., 100.5, "MW" -> "101 MW")
static func format_resource(value: float, unit: String) -> String:
	return "%d %s" % [int(value), unit]


## Format a ratio as supply/demand (e.g., 80, 100, "MW" -> "80/100 MW (80%)")
static func format_supply_demand(supply: float, demand: float, unit: String) -> String:
	var ratio = supply / max(1, demand)
	return "%d/%d %s (%d%%)" % [int(supply), int(demand), unit, int(ratio * 100)]
