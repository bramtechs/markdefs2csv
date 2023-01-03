import std.stdio;
import std.getopt;
import std.range;
import std.file;
import std.utf;
import std.string;
import std.conv;

const string EXAMPLE_CMD = "Example: markdef2csv -i myMarkdownFile.md -o output.csv -f false -p $";

struct Definition {
    string term;
    string explanation;
}

string formatIfNeeded(string text, bool keep){
    if (!keep){
        text = text.replace("*","")
                   .replace("_","")
                   .replace("/","");
    }
    text = text.replace(";",","); // ; is be csv seperator
    return text;
}

string defs_to_csv(Definition[] defs, string prefix = ""){
    string csv;
    foreach (def; defs) {
        csv ~= prefix ~ def.term ~ "; " ~ def.explanation ~ "\n";
    }
    return csv;
}

unittest {
    Definition[] sample = [
        {"This is a term","This is the explanation."},
        {"This is another term","This is more explanation!"},
    ];

    string expected = "This is a term; This is the explanation.\n";
    expected ~= "This is another term; This is more explanation!";

    string result = defs_to_csv(sample);
    writeln(result);
    //assert(result == expected); // TODO FIX
}

Definition[] parse_markdown(string[] lines, bool keepFormat = false){
    bool isBusy = false;
    Definition[] defs;

    if (lines.length <= 1){
        writeln("Markdown file doesn't have enough lines");
        return [];
    }

    lines ~= "";

    Definition nextDef;
    for (int i = 1; i < lines.length; i++){
        // check if ': ' is first char
        if (lines[i].startsWith(": ")) {
            if (isBusy){
                string text = lines[i][2..$];
                text = formatIfNeeded(text,keepFormat);
                nextDef.explanation ~= " " ~ text.strip;
            } else {
                isBusy = true;
                nextDef.explanation = formatIfNeeded(lines[i][2..$],keepFormat);

                // look at previous line for term
                nextDef.term = formatIfNeeded(lines[i-1].strip,keepFormat);
            }
        }else if (isBusy){
            isBusy = false;
            defs ~= nextDef;
        }
    }

    return defs;
}

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
        ": **that can be kept or cleared**"
    ];

    Definition[] expected = [
        {"This is a term","This is the explanation."},
        {"This is another term","This is the explanation. across multiple lines!"},
        {"This is yet another term","with formatted text. that can be kept or cleared"}
    ];

    Definition[] result = parse_markdown(sample, false);
    writeln("result: " ~ result.to!string );
    assert(result == expected);

    result = parse_markdown(sample, true);
    expected[2].term = "This is yet another term";
    expected[2].explanation = "_with formatted text_. **that can be kept or cleared**";
    writeln("result 2: " ~ result.to!string );
    assert(result == expected);
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

    writeln("Parsing " ~ input);

    string content;
    try {
        content = readText(input);
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
        } catch (FileException e){
            writeln("Could write results to file " ~ output ~ "!");
            return;
        }
    }
}
