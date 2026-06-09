extends Node
## Stats autoload — pure math for the character skill / stat system.
##
## Six skills are trained with skill points (1 point per level gained,
## 84 points total at the level cap of 85). Maxing every skill costs
## exactly 84 points: early ranks cost 1 point, late ranks cost 2.
## Equipment (armor / implant / two amulets) adds or subtracts stat
## points on top of the trained ranks; derived values are computed from
## the combined total, then clamped to the design caps below.
##
##   Skill         Ranks  Trained range         Per rank
##   resilience      12   200 -> 500 HP          +25 HP
##   firepower       12   x1.00/5% -> x1.60/17%  +0.05 dmg, +1% crit
##   speed            8   120 -> 160             +5
##   intelligence     8   1 -> 9                 +1 (4% shop discount each)
##   accuracy         8   70% -> 94%             +3%
##   defense          8   0% -> 24%              +3%
##
## Gear-inclusive caps: 700 HP, x1.90 dmg / 23% crit, speed 175,
## 100% accuracy, 42% defense, intelligence 11 (44% discount).

const MAX_LEVEL := 85

const SKILLS: Dictionary = {
	"resilience": {
		"name": "Resilience",
		"max_rank": 12,
		"cheap_ranks": 6,    # ranks 1..6 cost 1 point, the rest cost 2
		"level_step": 6,     # rank N needs player level N*6-5
		"description": "+25 max HP per rank",
	},
	"firepower": {
		"name": "Firepower",
		"max_rank": 12,
		"cheap_ranks": 6,
		"level_step": 6,
		"description": "+5% damage and +1% crit chance per rank",
	},
	"speed": {
		"name": "Speed",
		"max_rank": 8,
		"cheap_ranks": 4,
		"level_step": 9,     # rank N needs player level N*9-8
		"description": "+5 movement per rank",
	},
	"intelligence": {
		"name": "Intelligence",
		"max_rank": 8,
		"cheap_ranks": 4,
		"level_step": 9,
		"description": "+4% shop discount and better medkits per rank",
	},
	"accuracy": {
		"name": "Accuracy",
		"max_rank": 8,
		"cheap_ranks": 4,
		"level_step": 9,
		"description": "+3% weapon accuracy per rank",
	},
	"defense": {
		"name": "Defense",
		"max_rank": 8,
		"cheap_ranks": 4,
		"level_step": 9,
		"description": "+3% damage absorption per rank",
	},
}

const BASE_HP := 200
const HP_PER_POINT := 25
const DAMAGE_PER_POINT := 0.05
const BASE_CRIT_CHANCE := 0.05
const CRIT_PER_POINT := 0.01
const BASE_CRIT_DAMAGE := 2.0
const BASE_SPEED_VALUE := 120
const SPEED_PER_POINT := 5
const MAX_SPEED_VALUE := 175
const BASE_INTELLIGENCE := 1
const MAX_INTELLIGENCE := 11
const DISCOUNT_PER_INT := 0.04
const BASE_ACCURACY := 0.70
const ACCURACY_PER_POINT := 0.03
const DEFENSE_PER_POINT := 0.03
const MAX_DEFENSE := 0.42
const MEDKIT_BASE_HEAL := 50
const MEDKIT_HEAL_PER_INT := 2


## Skill points granted by reaching `level` (1 per level after the first).
func points_for_level(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL) - 1


## Point cost of buying rank `rank` (1-based) of a skill.
func rank_cost(skill: String, rank: int) -> int:
	var info: Dictionary = SKILLS.get(skill, {})
	if info.is_empty() or rank < 1 or rank > int(info["max_rank"]):
		return 0
	return 1 if rank <= int(info["cheap_ranks"]) else 2


## Minimum player level required to buy rank `rank` of a skill.
func rank_level_required(skill: String, rank: int) -> int:
	var info: Dictionary = SKILLS.get(skill, {})
	if info.is_empty():
		return MAX_LEVEL
	return maxi(1, rank * int(info["level_step"]) - int(info["level_step"]) + 1)


## Total points needed to take a skill from rank 0 to `rank`.
func total_cost(skill: String, rank: int) -> int:
	var sum := 0
	for r in range(1, rank + 1):
		sum += rank_cost(skill, r)
	return sum


## Points to max out every skill (84 by design — reachable at level 85).
func total_cost_all() -> int:
	var sum := 0
	for skill: String in SKILLS:
		sum += total_cost(skill, int(SKILLS[skill]["max_rank"]))
	return sum


# -------------------------------------------------- derived values ---------
# `points` is a Dictionary of total stat points (trained ranks + gear mods),
# e.g. {"resilience": 14, "firepower": 6, ...}. Missing keys count as 0.

func _pts(points: Dictionary, skill: String) -> int:
	return int(points.get(skill, 0))


func max_hp(points: Dictionary) -> int:
	return BASE_HP + HP_PER_POINT * maxi(0, _pts(points, "resilience"))


func damage_mult(points: Dictionary) -> float:
	return 1.0 + DAMAGE_PER_POINT * maxf(0.0, float(_pts(points, "firepower")))


func crit_chance(points: Dictionary) -> float:
	return BASE_CRIT_CHANCE + CRIT_PER_POINT * maxf(0.0, float(_pts(points, "firepower")))


## Crit damage multiplier; gear can add to it via "crit_bonus" (e.g. 0.2).
func crit_damage_mult(points: Dictionary) -> float:
	return BASE_CRIT_DAMAGE + float(points.get("crit_bonus", 0.0))


## Abstract speed value (120 base). The player converts it to px/s.
func speed_value(points: Dictionary) -> int:
	return mini(BASE_SPEED_VALUE + SPEED_PER_POINT * _pts(points, "speed"), MAX_SPEED_VALUE)


func speed_scale(points: Dictionary) -> float:
	return float(speed_value(points)) / float(BASE_SPEED_VALUE)


func intelligence_value(points: Dictionary) -> int:
	return clampi(BASE_INTELLIGENCE + _pts(points, "intelligence"), 1, MAX_INTELLIGENCE)


## Shop discount fraction, 4% per intelligence (max 44% at INT 11).
func price_discount(points: Dictionary) -> float:
	return DISCOUNT_PER_INT * float(intelligence_value(points))


func discounted_price(base_price: int, points: Dictionary) -> int:
	if base_price <= 0:
		return base_price
	return maxi(1, int(roundf(float(base_price) * (1.0 - price_discount(points)))))


## Hit accuracy fraction: 70% base, +3% per point, hard-capped at 100%.
func accuracy(points: Dictionary) -> float:
	return clampf(BASE_ACCURACY + ACCURACY_PER_POINT * float(_pts(points, "accuracy")), 0.0, 1.0)


## Fraction of incoming damage absorbed (max 42%).
func defense_ratio(points: Dictionary) -> float:
	return clampf(DEFENSE_PER_POINT * float(_pts(points, "defense")), 0.0, MAX_DEFENSE)


## HP restored by a mini-medkit: 52 at INT 1 up to 72 at INT 11.
func medkit_heal(points: Dictionary) -> int:
	return MEDKIT_BASE_HEAL + MEDKIT_HEAL_PER_INT * intelligence_value(points)
