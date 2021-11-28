import argparse;

static struct Extended
{
	// Positional arguments are required by default
	@PositionalArgument(0)
	string name;

	// Named arguments can be attributed in bulk (parentheses can be omitted)
	@NamedArgument
	{
		string unused = "some default value";
		int number;
		bool boolean;
	}

	// Named argument can have custom or multiple names
	@NamedArgument("apple","appl")
	int apple;

	@NamedArgument(["b","banana","ban"])
	int banana;
}

// This mixin defines standard main function that parses command line and calls the provided function:
mixin Main.parseCLIArgs!(Extended, (args)
{
	// 'args' has 'Extended' type
	static assert(is(typeof(args) == Extended));

	// do whatever you need
	import std.stdio: writeln;
	args.writeln;
	return 0;
});