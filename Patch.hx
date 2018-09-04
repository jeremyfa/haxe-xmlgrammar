package;

import sys.FileSystem;
import yaml.Yaml;
import haxe.io.Path;
import sys.io.File;

using StringTools;

class Patch {

    var ORIGINAL_GRAMMAR_URL = 'https://raw.githubusercontent.com/vshaxe/haxe-TmLanguage/master/haxe.YAML-tmLanguage';

    var LINE_SEP = computeLineSeparator();

    var patchedGrammarYaml:String = null;

    var patchedGrammarPlist:String = null;

    public static function main():Void {

        new Patch();

    } //main

    static function computeLineSeparator():String {

        return (Sys.systemName() == 'Windows' ? '\r\n' : '\n');

    } //computeLineSeparator

    public function new() {

        var argv = Sys.args();
        var exportYaml = argv.indexOf('--yaml') != -1;
        var exportPlist = argv.indexOf('--plist') != -1;
        var exportVSCode = argv.indexOf('--vscode') != -1;

        var vscodeExtPath:String = null;
        if (argv.indexOf('--vscode-ext-path') != -1) {
            vscodeExtPath = argv[argv.indexOf('--vscode-ext-path') + 1];
        }

        if (exportYaml || exportPlist || exportVSCode) {
            generatePatchedGrammar();

            if (exportVSCode) {
                patchVSCode(vscodeExtPath);
            }
            else if (exportPlist) {
                Sys.println(patchedGrammarPlist);
            }
            else if (exportYaml) {
                Sys.println(patchedGrammarYaml);
            }
        }
        else {
            trace('Error: you must specify required options: --yaml, --plist or --vscode');
            Sys.exit(1);
        }

    } //new

    function generatePatchedGrammar() {

        // Download original haxe grammar
        var grammar:String = null;
        var http = new haxe.Http(ORIGINAL_GRAMMAR_URL);
        http.onData = function(data:String) {
            grammar = data;
        };
        http.onError = function(error) {
            trace('$error');
        };
        http.request();
        if (grammar == null) {
            trace('Error: failed to fetch original haxe grammar');
            Sys.exit(1);
        }

        // Read xml grammar
        var xmlGrammar = File.getContent(Path.join([Path.directory(Sys.programPath()), 'haxe-xml.YAML-tmLanguage']));

        // Patch
        var lines = [];
        var inStrings = false;
        var inSingleQuotedStrings = false;
        for (line in grammar.split("\n")) {
            if (inStrings && line.trim() == "- begin: (')") {
                inSingleQuotedStrings = true;
            }
            else if (line.trim() == 'strings:') {
                inStrings = true;
            }
            lines.push(line);
            if (inSingleQuotedStrings && line.trim() == 'patterns:') {
                inSingleQuotedStrings = false;
                lines.push(line.rtrim().replace('patterns:', '') + "- include: '#xml-in-single-quoted'");
            }
        }
        
        // Generate yaml
        patchedGrammarYaml = lines.join(LINE_SEP).replace('\r\r', '\r') + LINE_SEP + xmlGrammar;

        // Parse yaml
        var parsed = Yaml.parse(patchedGrammarYaml, yaml.Parser.options().useObjects());

        // Generate plist
        patchedGrammarPlist = plist.Writer.write(parsed);

    } //generatePatchedGrammar

    function patchVSCode(?vscodeExtPath:String) {

        if (vscodeExtPath == null) {
            if (Sys.systemName() == 'Windows') {
                // Windows
                // TODO list `%USERPROFILE%\.vscode\extensions`
                trace('Error: Windows automatic vscode extension path resolution is not supported yet.');
                Sys.exit(1);
            }
            else {
                // Unix
                var proc = new sys.io.Process("whoami", []);
                var user = proc.stdout.readAll().toString().trim();
                proc.close();
                vscodeExtPath = '/Users/$user/.vscode/extensions';
            }
        }

        // Get extensions list
        var extensionsList = FileSystem.readDirectory(vscodeExtPath);

        for (extension in extensionsList) {
            if (extension.startsWith('nadako.vshaxe-')) {
                var grammarPath = Path.join([vscodeExtPath, extension, 'syntaxes', 'haxe.tmLanguage']);
                Sys.println('Patch file at path: $grammarPath');
                File.saveContent(grammarPath, patchedGrammarPlist);
            }
        }

    } //patchVSCode

} //Patch
