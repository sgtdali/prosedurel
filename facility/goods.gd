extends RefCounted

## Names and colours of the goods that move through facilities, shared by the machines, the
## facility drawing and the UI.

const NAMES := {"iron": "Demir", "copper": "Bakır", "coal": "Kömür", "pig_iron": "Pik demir", "steel": "Çelik", "machine_parts": "Makine parçası"}
const COLORS := {"iron": Color("#913926"), "copper": Color("#d0703a"), "coal": Color("#2b2b2e"),
	"pig_iron": Color("#8d8f8c"), "steel": Color("#8fb1c9"), "machine_parts": Color("#d9bd68")}


static func name_of(good: String) -> String:
	return NAMES.get(good, good)


static func color_of(good: String) -> Color:
	return COLORS.get(good, Color.WHITE)


## "2 Demir + 1 Kömür → 1 Pik demir"
static func recipe_text(inputs: Dictionary, outputs: Dictionary) -> String:
	var ins: Array[String] = []
	for good in inputs:
		ins.append("%d %s" % [inputs[good], name_of(good)])
	var outs: Array[String] = []
	for good in outputs:
		outs.append("%d %s" % [outputs[good], name_of(good)])
	return "%s → %s" % [" + ".join(ins), " + ".join(outs)]
