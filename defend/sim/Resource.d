module defend.sim.Resource;

private
{
	const _resourceTypes = `["gold", "iron", "wood"]`;

	char[] genEnum()
	{
		char[] result = "enum ResourceType {";
		
		foreach(type; mixin(_resourceTypes))
		{
			result ~= cast(char)(type[0] + 'A' - 'a') ~ type[1 .. $] ~ ", ";
		}
			
		result ~= "}";
		
		return result;
	}
}

mixin(genEnum());
const resourceTypes = mixin(_resourceTypes);

alias int[ResourceType.max + 1] ResourceArray;
