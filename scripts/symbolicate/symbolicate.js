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

// https://stackoverflow.com/a/35008327/73479
function fileExistsSync(filepath){
  let flag = true;
  try{
    fs.accessSync(filepath, fs.constants.F_OK);
  }catch(e){
    flag = false;
  }
  return flag;
}

function symbolicateFile(filePath) {

    console.log(`symbolicating ${filePath}`);

    let fileData = fs.readFileSync(filePath);
    let lines = fileData.toString().split("\n");

    let ipsMetadata = extractIPSMetadata(lines);

    if (ipsMetadata) {
        symbolicateIPSFile(filePath, ipsMetadata, lines);
    }
}

function extractIPSMetadata(fileLines) {
    try {
        let metadata = JSON.parse(fileLines[0]);
        fileLines.shift();
        return metadata;
    } catch (err) {
        console.log(`WARN ${crashFile} does not appear to be IPS format`);
        console.log();
    }
}

function symbolicateIPSFile(crashFile, metaJSON, lines) {

    let version = metaJSON.app_version;
    let crashJSON = JSON.parse(lines.join("\n"));
    let ddgBaseAddress;
    let ddgImageIndex;

    for (const i in crashJSON.usedImages) {
        let image = crashJSON.usedImages[i];
        if (image.name === "DuckDuckGo") {
            ddgBaseAddress = image.base.toString(16);
            ddgImageIndex = i;
            break;
        }
    }

    let dwarf = `binaries/${version}/DuckDuckGo.app.dSYM/Contents/Resources/DWARF/DuckDuckGo`;
    if (!fileExistsSync(dwarf)) {
        console.log(`WARN missing dwarf binary for ${version}`);
        console.log();
        return;
    }

    let app = `binaries/${version}/DuckDuckGo.app`;
    if (!fileExistsSync(app)) {
        console.log(`WARN missing app binary for ${version}`);
        console.log();
        return;
    }

    let changes;
    if (crashJSON.asiBacktraces) {
        changes = symbolicateAsiBacktraces(crashJSON, dwarf, ddgBaseAddress, ddgImageIndex);
    } else if (crashJSON.threads) {
        changes = symbolicateThreads(crashJSON, dwarf, ddgBaseAddress, ddgImageIndex);
    } else {
        console.log(`WARN no 'asiBacktraces' or 'threads' found in ${crashFile}`);
        console.log();
        return;
    }

    let updatedJSON = JSON.stringify(metaJSON) + "\n" + JSON.stringify(crashJSON, null, '\t');

    let fileInfo = path.parse(crashFile);
    if (fileInfo.ext === ".ips") {
        fs.writeFileSync(crashFile, updatedJSON);
    } else {
        fileInfo.base = undefined;
        fileInfo.ext = ".ips";
        fs.writeFileSync(path.format(fileInfo), updatedJSON);
        fs.unlinkSync(crashFile);
    }

    if (changes > 0) {
        console.log(`SUCCESS updated ${crashFile}`);
    } else {
        console.log(`WARN no changes made to ${crashFile}`);
    }
    console.log();
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

function symbolicateAsiBacktraces(crashJSON, dwarf, ddgBaseAddress) {
    let backtrace = crashJSON.asiBacktraces[0].split("\n");

    let regex = /0x([0-9a-f]*) DuckDuckGo \+ (\d*)/

    let changes = 0;
    let symbolicatedCrash = backtrace.map((e) => { 
        let matches = e.match(regex);

        if (matches) {
            changes += 1;
            let rawLoadAddress = "0x" + matches[1];
            let binaryLoadAddress = parseInt(matches[1], 16);
            let offset = Number(matches[2]);
            let symbolOffset = binaryLoadAddress + offset;
            let symbolAddress = symbolOffset.toString(16)

            let command = `atos -o ${dwarf} -l 0x${ddgBaseAddress} 0x${symbolAddress}`
            console.log(command);
            let symbol = execSync(command);
            return e.replace(rawLoadAddress, `${rawLoadAddress} ${symbol}`).replace("DuckDuckGo + ", "").replace("\n", "");
        }

        return e;
    }).join('\n');

    crashJSON.asiBacktraces[0] = symbolicatedCrash;
}

function symbolicateThreads(crashJSON, dwarf, ddgBaseAddress, ddgImageIndex) {
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

    let command = `atos -o ${dwarf} -l 0x${ddgBaseAddress} ${changes.map((c) => c.symbolAddress).join(" ")}`
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
    symbolicateIPSFile(location);
}
