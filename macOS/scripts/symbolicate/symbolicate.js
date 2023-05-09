#!/usr/bin/env node
/**
 * See README.md for instructions.
 */

const fs = require('fs');
const path = require('path');
const execSync = require('child_process').execSync;

if (process.argv.length < 3) {
    console.log(`usage: node ./symbolicate.js <ips file or folder of ips files>`);
    return;
}

function symbolicateFolder(folderName) {
    const files = fs.readdirSync(folderName);

    files
        .filter(f => f.endsWith(".ips") || f.endsWith(".crash"))
        .forEach(file => {
            let filePath = path.resolve(folderName, file);
            try {
                symbolicateFile(filePath);
            } catch (err) {
                console.log(`FAILED to symbolicate ${filePath}`);
                console.log(err);
                console.log();
            }
        });
}

function symbolicateFile(filePath) {

    console.log(`symbolicating ${filePath}`);

    let fileData = fs.readFileSync(filePath);
    let lines = fileData.toString().split("\n");

    let ipsMetadata = extractIPSMetadata(filePath, lines);

    if (ipsMetadata) {
        symbolicateIPSFile(filePath, ipsMetadata, lines);
    } else {
        symbolicateCrashFile(filePath, lines);
    }
}

// https://stackoverflow.com/a/35008327/73479
function fileExistsSync(filepath) {
    let flag = true;
    try {
        fs.accessSync(filepath, fs.constants.F_OK);
    } catch(e) {
        flag = false;
    }
    return flag;
}

function checkDWARFFile(version) {
    let dwarf = `binaries/${version}/DuckDuckGo.app.dSYM/Contents/Resources/DWARF/DuckDuckGo`;
    if (!fileExistsSync(dwarf)) {
        console.log(`WARN missing dwarf binary for ${version}`);
        console.log();
        return;
    }

    return dwarf;
}

function symbolicateCrashFile(crashFile, lines) {
    const versionLine = lines.find((l) => l.startsWith("Version:"));
    if (!versionLine) {
        console.log(`WARN incorrect crash file format`);
        console.log();
        return;
    }
    const version = versionLine.match(/Version:\s+([\d\.]+) .*/)[1]

    const codeTypeLine = lines.find((l) => l.startsWith("Code Type:"));
    if (!codeTypeLine) {
        console.log(`WARN incorrect crash file format`);
        console.log();
        return;
    }
    const codeType = codeTypeLine.match(/Code Type:\s+(X86-64|ARM-64).*/)[1]
    const arch = {
        "X86-64": "x86_64",
        "ARM-64": "arm64"
    }[codeType];

    const dwarf = checkDWARFFile(version);
    if (!dwarf) {
        return;
    }

    const binaryImagesLineIndex = lines.findIndex((l) => l.startsWith("Binary Images:"));
    let lineIndex = binaryImagesLineIndex + 1;
    const binaryImageRegex = /\s+0x([0-9a-fA-F]+) - \s+0x[0-9a-fA-F]+.*com\.duckduckgo\.(macos\.browser|mobile\.ios)/;

    let ddgBaseAddress;
    while (lineIndex < lines.length) {
        const match = lines[lineIndex].match(binaryImageRegex);
        if (match && match.length > 1) {
            ddgBaseAddress = match[1];
            break;
        }
        lineIndex += 1;
    }

    if (!ddgBaseAddress) {
        console.log(`WARN DuckDuckGo image not found in ${crashFile}, skipping`);
        console.log();
        return;
    }

    lineIndex = 0;
    const stackFrameRegex = /\d+\s+com\.duckduckgo\.(macos\.browser|mobile\.ios)\s+(0x[0-9a-fA-F]+) (0x[0-9a-fA-F]+ \+ \d+)/;
    let changes = [];

    while (lineIndex < binaryImagesLineIndex) {
        const match = lines[lineIndex].match(stackFrameRegex);
        if (match && match.length > 2) {
            const change = {
                lineIndex,
                symbolAddress: match[1],
                symbolPlaceholder: match[2]
            };

            changes.push(change);
        }
        lineIndex += 1;
    }

    if (changes.length > 0) {

        const command = `atos -arch ${arch} -o ${dwarf} -l 0x${ddgBaseAddress} ${changes.map((c) => c.symbolAddress).join(" ")}`
        console.log(command);
        let symbols = execSync(command).toString().trim().split('\n');

        for (const i in changes) {
            const change = changes[i];
            lines[change.lineIndex] = lines[change.lineIndex].replace(change.symbolPlaceholder, symbols[i]);
        }

        const updatedBacktrace = lines.join('\n');
        fs.writeFileSync(crashFile, updatedBacktrace);

        console.log(`SUCCESS updated ${crashFile}`);
    } else {
        console.log(`WARN no changes made to ${crashFile}`);
    }
    console.log();
}

function extractIPSMetadata(crashFile, fileLines) {
    try {
        let metadata = JSON.parse(fileLines[0]);
        fileLines.shift();
        return metadata;
    } catch (err) {
        console.log(`INFO ${crashFile} does not appear to be IPS format`);
    }
}

function symbolicateIPSFile(crashFile, metaJSON, lines) {

    let version = metaJSON.app_version;
    let crashJSON = JSON.parse(lines.join("\n"));
    let arch;
    let ddgBaseAddress;
    let ddgImageIndex;

    for (const i in crashJSON.usedImages) {
        let image = crashJSON.usedImages[i];
        if (image.name === "DuckDuckGo") {
            arch = image.arch;
            ddgBaseAddress = image.base.toString(16);
            ddgImageIndex = i;
            break;
        }
    }

    if (!arch) {
        console.log(`WARN DuckDuckGo image not found in ${crashFile}, skipping`);
        console.log();
        return;
    }

    let dwarf = checkDWARFFile(version);
    if (!dwarf) {
        return;
    }

    let changes = 0;
    if (crashJSON.asiBacktraces) {
        changes += symbolicateAsiBacktraces(crashJSON, dwarf, arch, ddgBaseAddress);
    }
    if (crashJSON.threads) {
        changes += symbolicateThreads(crashJSON, dwarf, arch, ddgBaseAddress, ddgImageIndex);
    }

    if (changes > 0) {
        let updatedJSON = JSON.stringify(metaJSON) + "\n" + JSON.stringify(crashJSON, null, '\t');

        let fileInfo = path.parse(crashFile);
        if (fileInfo.ext === ".ips") {
            fs.writeFileSync(crashFile, updatedJSON);
            console.log(`SUCCESS updated ${crashFile}`);
        } else {
            fileInfo.base = undefined;
            fileInfo.ext = ".ips";
            const newCrashFile = path.format(fileInfo);
            fs.writeFileSync(newCrashFile, updatedJSON);
            fs.unlinkSync(crashFile);
            console.log(`SUCCESS updated ${crashFile} (renamed as ${newCrashFile})`);
        }

    } else {
        console.log(`WARN no changes made to ${crashFile}`);
    }
    console.log();
}

function symbolicateAsiBacktraces(crashJSON, dwarf, arch, ddgBaseAddress) {
    let backtrace = crashJSON.asiBacktraces[0].split("\n");

    let regex = /(0x[0-9a-f]*) DuckDuckGo \+ \d*/

    let changes = 0;
    let symbolicatedCrash = backtrace.map((e) => { 
        let matches = e.match(regex);

        if (matches) {
            changes += 1;
            let symbolAddress = matches[1];
            let command = `atos -arch ${arch} -o ${dwarf} -l 0x${ddgBaseAddress} ${symbolAddress}`
            console.log(command);
            let symbol = execSync(command);
            return e.replace(symbolAddress, `${symbolAddress} ${symbol}`).replace("DuckDuckGo + ", "+ ").replace("\n", "");
        }

        return e;
    }).join('\n');

    crashJSON.asiBacktraces[0] = symbolicatedCrash;

    return changes;
}

function symbolicateThreads(crashJSON, dwarf, arch, ddgBaseAddress, ddgImageIndex) {
    let threads = crashJSON.threads;

    let changes = [];

    for (let threadIndex in threads) {
        let thread = threads[threadIndex];
        for (let frameIndex in thread.frames) {
            let frame = thread.frames[frameIndex];

            if (frame.imageIndex == ddgImageIndex) {

                let offset = frame.imageOffset;
                let symbolOffset = parseInt(ddgBaseAddress, 16) + offset;
                let symbolAddress = symbolOffset.toString(16);

                changes.push({
                    threadIndex,
                    frameIndex,
                    symbolAddress: `0x${symbolAddress}`
                });
            }
        }
    }

    let command = `atos -arch ${arch} -o ${dwarf} -l 0x${ddgBaseAddress} ${changes.map((c) => c.symbolAddress).join(" ")}`
    console.log(command);
    let symbols = execSync(command).toString().trim().split('\n');

    for (let i in changes) {
        const change = changes[i];
        threads[change.threadIndex].frames[change.frameIndex].symbol = symbols[i];
    }

    return changes.length;
}

let location = process.argv[2];
if (fs.lstatSync(location).isDirectory()) {
    symbolicateFolder(location);
} else {
    symbolicateFile(location);
}
