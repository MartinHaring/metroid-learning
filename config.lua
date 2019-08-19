local _M = {}

_M.BizhawkDir = "C:/bizhawk/"
_M.StateDir = _M.BizhawkDir .. "Lua/SNES/metroid-learning/state/"
_M.PoolDir = _M.BizhawkDir .. "Lua/SNES/metroid-learning/pool/"
_M.Filename = "default.State"

_M.NeatConfig = {
	Population = 300,
	DeltaDisjoint = 2.0,
	DeltaWeights = 0.4,
	DeltaThreshold = 1.0,
	StaleSpecies = 15,
	MutateConnectionsChance = 0.25,
	PerturbChance = 0.90,
	CrossoverChance = 0.75,
	LinkMutationChance = 2.0,
	NodeMutationChance = 0.50,
	BiasMutationChance = 0.40,
	StepSize = 0.1,
	DisableMutationChance = 0.4,
	EnableMutationChance = 0.2,
	TimeoutConstant = 30,
	MaxNodes = 100000
}

_M.ButtonNames = {
	"A",
	"B",
	"X",
	"Y",
	"Up",
	"Down",
	"Left",
	"Right",
	"L",
	"R"
}
	
_M.BoxRadius = 6
_M.InputSize = (_M.BoxRadius*2+1)*(_M.BoxRadius*2+1)

_M.Running = false

return _M
