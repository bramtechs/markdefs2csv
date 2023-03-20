import std.stdio;
import std.getopt;
import std.range;
import std.file;
import std.utf;
import std.string;
import std.conv;
import std.format;

const string EXAMPLE_CMD = "Example: markdef2csv -i myMarkdownFile.md -o output.csv -f false -p $";

const string[] MD_LIST_SYMBOLS = ["-", "+", "* "]; // <-- NOTE: the space after star
// This is needed for situations like this: ``` * **Hello List Item** ```.

struct Definition
{
    string term;
    string explanation;

    string toString() {
        return format("\n%s\n%s", term, explanation);
    }
}

string format_if_needed(string text, bool keep)
{
    // NOTE: remove list symbols
    // TODO: Add support for numbered list
    foreach (symb; MD_LIST_SYMBOLS){
        string formText = text.chompPrefix(symb);
        if (formText != text) {
            text = formText.strip;
            break;
        }
    }
    
    if (!keep){
        text = text.replace("*","")
                   .replace("_","")
                   .replace("/","");
    }
    text = text.replace(";",","); // ; is be csv seperator
    return text;
}

string defs_to_csv(Definition[] defs, string prefix = "")
{
    string csv;
    foreach (def; defs) {
        csv ~= prefix ~ def.term ~ "; " ~ def.explanation ~ "\n";
    }
    return csv;
}

Definition[] parse_markdown(string[] lines, bool keepFormat = false)
{
    bool isBusy = false;
    Definition[] defs;

    if (lines.length <= 1){
        writeln("Markdown file doesn't have enough lines");
        return [];
    }

    lines ~= "";

    Definition nextDef;
    for (int i = 1; i < lines.length; i++){
        // NOTE: Trim the line first before checking
        lines[i] = lines[i].strip;

        // check if ':' is first char
        if (lines[i].startsWith(":")) {
            if (isBusy){
                string text = lines[i][1..$].strip;
                text = format_if_needed(text,keepFormat);
                nextDef.explanation ~= " " ~ text.strip;
            } else {
                isBusy = true;
                nextDef.explanation = format_if_needed(lines[i][1..$].strip,keepFormat);

                // look at previous line for term
                nextDef.term = format_if_needed(lines[i-1].strip,keepFormat);
            }
        }else if (isBusy){
            isBusy = false;
            defs ~= nextDef;
        }
    }

    return defs;
}

void main(string[] args)
{
    string input = "";
    string output = "";
    string prefix = "";
    bool keepFormat = false;

    auto helpInfo = getopt(
        args,
        "input|i", &input,
        "output|o", &output,
        "formatting|f", &keepFormat,
        "prefix|p", &prefix
    );

    if (helpInfo.helpWanted){
        defaultGetoptPrinter(EXAMPLE_CMD,
            helpInfo.options);
    }

    if (input.empty){
        writeln("No input provided!");
        writeln(EXAMPLE_CMD);
        return;
    }

    if (input == output) {
        writeln("Input and output file (" ~ input ~ ") cannot be the same!");
        return;
    }


    string content;
    try {
        content = readText(input);
        writeln("Parsing " ~ input ~ "...");
    } catch (FileException e){
        writeln("Could not find file " ~ input ~ "!");
        return;
    } catch (UTFException e){
        writeln("Could not find read file " ~ input ~ " (non-standard characters?)");
        return;
    }

    string[] lines = splitLines(content);
    Definition[] defs = parse_markdown(lines);
    string csv = defs_to_csv(defs,prefix);

    if (output == ""){ // if no output specified, print to standard output
        writeln(csv);
    }else{
        try {
            alias write = std.file.write;
            write(output, csv);
            writeln("Wrote table into " ~ output);
        } catch (FileException e){
            writeln("Could write results to file " ~ output ~ "!");
            return;
        }
    }
}

// ===================================================
//                      UNIT TESTS
// ===================================================
// defs_to_csv
unittest {
    Definition[] sample = [
        {"This is a term","This is the explanation."},
        {"This is another term","This is more explanation!"},
    ];

    string expected = "This is a term; This is the explanation.\n";
    expected ~= "This is another term; This is more explanation!\n";

    string result = defs_to_csv(sample);
    assert(result == expected, "\n'%s'\ndoes not equal\n'%s'".format(result, expected)); 
}

// Oneliner
unittest {
    string[] sample = [
         "This is a term",
         ": This is the explanation."
    ];

    Definition expected = {
        "This is a term",
        "This is the explanation."
    };

    Definition[] result = parse_markdown(sample, false);
    assert(result.length == 1);
    assert(result[0] == expected, "'%s'\ndoes not equal to\n'%s'".format(result[0], expected));
}

// Multiple lines
unittest {
    string[] sample = [
        "This is another term      ",
        ": This is the explanation.",
        ": across multiple lines!",
    ];

    Definition expected = {
        "This is another term",
        "This is the explanation. across multiple lines!"
    };

    Definition[] result = parse_markdown(sample, false);
    assert(result.length == 1);
    assert(result[0] == expected, "'%s'\ndoes not equal to\n'%s'".format(result[0], expected));
}

// Remove any markdown styling
unittest {
    string[] sample = [
        "  This is yet another term      ",
        ": _with formatted text_.",
        ": **that can be kept or cleared**",
    ];

    Definition expected = {
        "This is yet another term",
        "with formatted text. that can be kept or cleared",
    };

    Definition[] result = parse_markdown(sample, false);
    assert(result.length == 1);
    assert(result[0] == expected, "'%s'\ndoes not equal to\n'%s'".format(result[0], expected));
}

// Keep any markdown styling
unittest {
    string[] sample = [
        "  This is yet another term      ",
        ": _with formatted text_.",
        ": **that can be kept or cleared**",
    ];

    Definition expected = {
        "This is yet another term",
        "_with formatted text_. **that can be kept or cleared**",
    };

    Definition[] result = parse_markdown(sample, true);
    assert(result.length == 1);
    assert(result[0] == expected, "'%s'\ndoes not equal to\n'%s'".format(result[0], expected));
}

// Misaligned
unittest {
    string[] sample = [
        "     - This is another term but indented and part of a list!",
        "      : It's explanation is also indented.",
        "    :But it's misaligned!",
    ];

    Definition expected = {
        "This is another term but indented and part of a list!",
        "It's explanation is also indented. But it's misaligned!"
    };

    Definition[] result = parse_markdown(sample, false);
    assert(result.length == 1);
    assert(result[0] == expected, "'%s'\ndoes not equal to\n'%s'".format(result[0], expected));
}

// Multiple test
unittest {
    string[] sample = [
        "This is a term",
        ": This is the explanation.",
        "",                         
        "This is another term      ",
        ": This is the explanation.",
        ": across multiple lines!",
        " ",
        "  This is yet another term      ",
        ": _with formatted text_.",
        ": **that can be kept or cleared**",
    ];

    Definition[] expected = [
        {"This is a term","This is the explanation."},
        {"This is another term","This is the explanation. across multiple lines!"},
        {"This is yet another term","with formatted text. that can be kept or cleared"},
    ];

    Definition[] result = parse_markdown(sample, false);

    assert(expected.length == result.length);
    for (int i = 0; i < result.length; i++) {
        assert(result[i] == expected[i], "'%s'\ndoes not equal to\n'%s'".format(result[i], expected[i]));
    }

    result = parse_markdown(sample, true);
    expected[2].term = "This is yet another term";
    expected[2].explanation = "_with formatted text_. **that can be kept or cleared**";
    assert(result == expected);
}

