// vim: set tw=100:
module engine.rend.Vertex;

import engine.util.Meta : lowerString, toString;

/*
	generic vertex:

	Vertex is a template struct taking a typelist as parameter

	to create a vertex, use the Member templates available here
	e.g. Member!(BaseType, Format, Size) (Size defaults to 1)
	a Member contains some aliases
		* type is the supplied BaseType
		* size is the supplied Size
		* format is the supplied Format
		* name is the name of the Format in a char[]

	once the vertex is created it will contain the supplied members
	in the order supplied
	the vertex will have an alias "members" in which all
	types (members) are stored
	the members are accessible through the lowercase Format name,
	e.g. Member!(float, Format.Position) will be accessible through
		vertex.position
	if the Size of the member is larger then 1 it will be an array
	e.g. Member!(float, Format.Position, 2) will be accessible through
		vertex.position[0 - 1]
	a default opCall is created for the vertex which can construct a vertex
	say the members are Member!(float, A) and Member!(float, B, 2)
	then the constructor will look like
		typeof(*this) opCall(float, float, float);
	whereas the last two floats represent the second member

	to check if a vertex contains a format you can use the traits generated
	e.g. to check if Format.AbCdEf is available in the vertex one would use
	hasAbCdEf(Vertex), it will evaluate to "true" or "false"

	BUGS:
		const Name = .....[];
		isMember!(..)

*/

enum Format
{
	Position,
	Diffuse,
	Normal,
	Texture
}

struct Member(T, Format F, size_t S = 1)
{
	alias T type;
	alias F format;
	alias S size;
}

/* FIXME: COMPILER ISSUE
template isMember(A : Member!(T, F, S))
{
	const isMember = true;
}

template isMember(A)
{
	const isMember = false;
}
*/

template isMember(A)
{
	const isMember = true;
}

private
{
	template FormatName(Format F : Format.Position)
	{
		const FormatName = "Position";
	}

	template FormatName(Format F : Format.Texture)
	{
		const FormatName = "Texture";
	}

	template FormatName(Format F : Format.Normal)
	{
		const FormatName = "Normal";
	}

	template FormatName(Format F : Format.Diffuse)
	{
		const FormatName = "Diffuse";
	}

	template checkFormat(Format F, List...)
	{
		static assert (isMember!(List[0]));

		static if (1 < List.length)
		{
			static if (F != List[0].format)
			{
				const checkFormat = checkFormat!(F, List[1 .. $]);
			}
			else
			{
				const checkFormat = "true";
			}
		}
		else
		{
			const checkFormat = (F == List[0].format);
		}
	}

	template FormatTrait(Format F)
	{
		const FormatTrait =
			"template has" ~ FormatName!(F) ~ "(T)\n" ~
			"{\n" ~
				"const has" ~ FormatName!(F) ~ " = " ~
					"checkFormat!(Format." ~ FormatName!(F) ~ ", T.Members);\n" ~
			"}\n";
	}

	template FormatTraits(Format F = Format.min)
	{
		static if (Format.max > F) {
			const FormatTraits = FormatTrait!(F) ~ FormatTraits!(cast(Format)(F + 1));
		} else {
			const FormatTraits = FormatTrait!(F);
		}
	}
}

align(1) struct Vertex(T...)
{
	private template GenerateVariables(size_t I = 0)
	{
		static if (T.length > I) {
			const Name = FormatName!(T[I].format)[];
			const VariableType = (1 == T[I].size) ? Name : (Name ~ "[" ~ toString(T[I].size) ~ "]");
			const VariableName = lowerString(Name);

			/* e.g.
				priviate alias T[0] PositionMember;
				alias PositionMember.type Position;
			*/
			const PrivateAlias = "private alias T[" ~ toString(I) ~ "] " ~ Name ~ "Member;  ";
			const Alias = "alias " ~ Name ~ "Member.type " ~ Name ~ ";";
			const Lines =
				"\t" ~ PrivateAlias ~ "\n" ~
				"\t" ~ Alias ~ "\n" ~
				"\t" ~ VariableType ~ " " ~ VariableName ~ ";\n" ~
				((T.length - 1 == I) ? "" : "\n") ~
				GenerateVariables!(I + 1).Lines;
		} else {
			const Lines = "";
		}
	}

	private template GenerateAssignment(size_t I = 0, size_t A = 1)
	{
		const Name = FormatName!(T[I].format)[];
		const LowerName = lowerString(Name);
		const ArrayAccessor = "[" ~ toString(A - 1) ~ "]";
		const Value = LowerName ~ toString(A);

		static if (T[I].size == 1) {
			const Lines = "\t\tobject." ~ LowerName ~ " = " ~ Value ~ ";\n";
		} else {
			static if (T[I].size > A) {
				const Lines = "\t\tobject." ~ LowerName ~ ArrayAccessor ~ " = " ~ Value ~ ";\n" ~
				              GenerateAssignment!(I, A + 1).Lines;
			} else {
				const Lines = "\t\tobject." ~ LowerName ~ ArrayAccessor ~ " = " ~ Value ~ ";\n";
			}
		}
	}

	private template GenerateAssignments(size_t I = 0)
	{
		static if (I == T.length) {
			const GenerateAssignments = "";
		} else {
			const GenerateAssignments = GenerateAssignment!(I).Lines ~ GenerateAssignments!(I + 1);
		}
	}

	private template GenerateParameters(size_t I, size_t A = 1)
	{
		const Name = FormatName!(T[I].format)[];
		const LowerName = lowerString(Name);

		static if (T[I].size >= A) {
			const Lines = Name ~ " " ~ LowerName ~ toString(A) ~
			              ((T[I].size > A) ? (", " ~ GenerateParameters!(I, A + 1).Lines) : "");
		} else {
			const Lines = "";
		}
	}

	private template GenerateConstructor(size_t I = 0)
	{
		const ReturnType = "typeof(*this)";

		static if (!I) {
			const Lines = "\tstatic " ~ ReturnType ~ " opCall(" ~ GenerateParameters!(I).Lines ~
			              GenerateConstructor!(I + 1).Lines;
		} else static if(I < T.length) {
			const Lines = ", " ~  GenerateParameters!(I).Lines ~
			              GenerateConstructor!(I + 1).Lines;
		} else {
			const Lines = ")\n" ~
				"\t{\n" ~
					"\t\t" ~ ReturnType ~ " object;\n" ~
					GenerateAssignments!() ~
					"\t\treturn object;\n" ~
				"\t}\n";
		}
	}

	mixin (GenerateVariables!().Lines);
	mixin (GenerateConstructor!().Lines);

	alias T Members;

	static char[] string()
	{
		return "(align 1) struct " ~ typeof(*this).stringof ~ "\n" ~
			"{\n" ~
			GenerateVariables!().Lines ~
			"\n" ~
			GenerateConstructor!().Lines ~
			"\n" ~
			"\talias T Members;\n" ~
			"}";
	}

	debug(VertexInstance) {
		pragma(msg, "instantiated a vertex:\n" ~ string());
	}
}

mixin(FormatTraits!());
