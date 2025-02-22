module argparse.internal.argumentuda;

import argparse.api: Config;
import argparse.internal.arguments: ArgumentInfo;
import argparse.internal.utils: formatAllowedValues;
import argparse.internal.enumhelpers: getEnumValues;

import std.traits;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

package(argparse) struct ArgumentUDA(ValueParseFunctions)
{
    ArgumentInfo info;

    alias parsingFunc = ValueParseFunctions;

    auto addDefaults(T)(ArgumentUDA!T uda)
    {
        auto newInfo = info;

        if(newInfo.names.length == 0) newInfo.names = uda.info.names;
        if(newInfo.placeholder.length == 0) newInfo.placeholder = uda.info.placeholder;
        if(!newInfo.description.isSet()) newInfo.description = uda.info.description;
        if(newInfo.position.isNull()) newInfo.position = uda.info.position;
        if(newInfo.minValuesCount.isNull()) newInfo.minValuesCount = uda.info.minValuesCount;
        if(newInfo.maxValuesCount.isNull()) newInfo.maxValuesCount = uda.info.maxValuesCount;

        return ArgumentUDA!(parsingFunc.addDefaults!(uda.parsingFunc))(newInfo);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

private template defaultValuesCount(TYPE)
if(!is(TYPE == void))
{
    static if(is(typeof(*TYPE) == function) || is(typeof(*TYPE) == delegate))
        alias T = typeof(*TYPE);
    else
        alias T = TYPE;

    static if(isBoolean!T)
    {
        enum min = 0;
        enum max = 0;
    }
    else static if(isSomeString!T || isScalarType!T)
    {
        enum min = 1;
        enum max = 1;
    }
    else static if(isStaticArray!T)
    {
        enum min = 1;
        enum max = T.length;
    }
    else static if(isArray!T || isAssociativeArray!T)
    {
        enum min = 1;
        enum max = ulong.max;
    }
    else static if(is(T == function))
    {
        // ... function()
        static if(__traits(compiles, { T(); }))
        {
            enum min = 0;
            enum max = 0;
        }
            // ... function(string value)
        else static if(__traits(compiles, { T(string.init); }))
        {
            enum min = 1;
            enum max = 1;
        }
            // ... function(string[] value)
        else static if(__traits(compiles, { T([string.init]); }))
        {
            enum min = 0;
            enum max = ulong.max;
        }
            // ... function(RawParam param)
        else static if(__traits(compiles, { T(RawParam.init); }))
        {
            enum min = 1;
            enum max = ulong.max;
        }
        else
            static assert(false, "Unsupported callback: " ~ T.stringof);
    }
    else
        static assert(false, "Type is not supported: " ~ T.stringof);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

package template getArgumentUDA(Config config, MEMBERTYPE, string defaultName)
{
    auto finalize(alias initUDA)()
    {
        import std.array: array;
        import std.algorithm: map, each;
        import std.conv: text;

        auto uda = initUDA;

        static if(!isBoolean!MEMBERTYPE)
            uda.info.allowBooleanNegation = false;

        static if(initUDA.info.names.length == 0)
            uda.info.names = [ defaultName ];

        static if(initUDA.info.placeholder.length == 0)
        {
            static if(is(MEMBERTYPE == enum))
                uda.info.placeholder = formatAllowedValues!(getEnumValues!MEMBERTYPE);
            else static if(initUDA.info.positional)
                uda.info.placeholder = defaultName;
            else
            {
                import std.uni : toUpper;
                uda.info.placeholder = defaultName.toUpper;
            }
        }

        static if(initUDA.info.positional)
            uda.info.displayNames = [ uda.info.placeholder ];
        else
        {
            alias toDisplayName = _ => ( _.length == 1 ? text(config.namedArgChar, _) : text(config.namedArgChar, config.namedArgChar, _));

            uda.info.displayNames = uda.info.names.map!toDisplayName.array;
        }

        static if(!config.caseSensitive)
            uda.info.names.each!((ref _) => _ = config.convertCase(_));

        static if(initUDA.info.minValuesCount.isNull) uda.info.minValuesCount = defaultValuesCount!MEMBERTYPE.min;
        static if(initUDA.info.maxValuesCount.isNull) uda.info.maxValuesCount = defaultValuesCount!MEMBERTYPE.max;

        return uda;
    }

    static if(__traits(compiles, getUDAs!(MEMBERTYPE, ArgumentUDA)) && getUDAs!(MEMBERTYPE, ArgumentUDA).length == 1)
        alias fromUDA(alias initUDA) = finalize!(initUDA.addDefaults(getUDAs!(MEMBERTYPE, ArgumentUDA)[0]));
    else
        alias fromUDA(alias initUDA) = finalize!initUDA;
}

package alias getArgumentUDA(Config config, MEMBERTYPE, string defaultName, alias initUDA) = getArgumentUDA!(config, MEMBERTYPE, defaultName).fromUDA!initUDA;


unittest
{
    auto createUDA(string placeholder = "")()
    {
        ArgumentInfo info;
        info.allowBooleanNegation = true;
        info.position = 0;
        info.placeholder = placeholder;
        return ArgumentUDA!void(info);
    }
    assert(createUDA().info.allowBooleanNegation); // make codecov happy

    auto res = getArgumentUDA!(Config.init, int, "default_name", createUDA()).info;
    assert(!res.allowBooleanNegation);
    assert(res.names == ["default_name"]);
    assert(res.displayNames == ["default_name"]);
    assert(res.minValuesCount == defaultValuesCount!int.min);
    assert(res.maxValuesCount == defaultValuesCount!int.max);
    assert(res.placeholder == "default_name");

    res = getArgumentUDA!(Config.init, int, "default_name", createUDA!"myvalue"()).info;
    assert(res.placeholder == "myvalue");
    assert(res.displayNames == ["myvalue"]);
}

unittest
{
    auto createUDA(string placeholder = "")()
    {
        ArgumentInfo info;
        info.allowBooleanNegation = true;
        info.placeholder = placeholder;
        return ArgumentUDA!void(info);
    }
    assert(createUDA().info.allowBooleanNegation); // make codecov happy

    auto res = getArgumentUDA!(Config.init, bool, "default_name", createUDA()).info;
    assert(res.allowBooleanNegation);
    assert(res.names == ["default_name"]);
    assert(res.displayNames == ["--default_name"]);
    assert(res.minValuesCount == defaultValuesCount!bool.min);
    assert(res.maxValuesCount == defaultValuesCount!bool.max);
    assert(res.placeholder == "DEFAULT_NAME");

    res = getArgumentUDA!(Config.init, bool, "default_name", createUDA!"myvalue"()).info;
    assert(res.placeholder == "myvalue");
    assert(res.displayNames == ["--default_name"]);
}

unittest
{
    enum E { a=1, b=1, c }

    auto createUDA(string placeholder = "")()
    {
        ArgumentInfo info;
        info.placeholder = placeholder;
        return ArgumentUDA!void(info);
    }
    assert(createUDA().info.allowBooleanNegation); // make codecov happy

    auto res = getArgumentUDA!(Config.init, E, "default_name", createUDA()).info;
    assert(res.placeholder == "{a,b,c}");

    res = getArgumentUDA!(Config.init, E, "default_name", createUDA!"myvalue"()).info;
    assert(res.placeholder == "myvalue");
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
package enum getMemberArgumentUDA(alias config, TYPE, alias symbol, alias defaultUDA) = {
    alias member = __traits(getMember, TYPE, symbol);

    enum udas = getUDAs!(member, ArgumentUDA);
    static assert(udas.length <= 1, "Member "~TYPE.stringof~"."~symbol~" has multiple '*Argument' UDAs");

    static if(udas.length > 0)
        return getArgumentUDA!(config, typeof(member), symbol, udas[0]);
    else
        return getArgumentUDA!(config, typeof(member), symbol, defaultUDA);
}();

