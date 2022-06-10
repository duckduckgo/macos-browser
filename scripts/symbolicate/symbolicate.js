/**
 * See README.md for instructions.
 */

let fs = require('fs');
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

function symbolicateFile(crashFile) {

    console.log(`symbolicating ${crashFile}`);

    let ips = fs.readFileSync(crashFile);
    let lines = ips.toString().split("\n");

    let metaJSON
    try {
        metaJSON = JSON.parse(lines.shift());
    } catch (err) {
        console.log(`WARN ${crashFile} does not appear to be IPS format`);
        console.log();
        return;
    }

    let version = metaJSON["app_version"];
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

    fs.writeFileSync(crashFile, updatedJSON);

    if (changes > 0) {
        console.log(`SUCCESS updated ${crashFile}`);
    } else {
        console.log(`WARN no changes made to ${crashFile}`);
    }
    console.log();
}

function symbolicateFolder(folderName) {
    const files = fs.readdirSync(folderName);

    files.forEach(file => {
        if (file.endsWith(".ips")) {
            let ipsFile = `${folderName}${file}`;
            try {
                symbolicateFile(ipsFile);
            } catch (err) {
                console.log(`FAILED to symbolicate ${ipsFile}`);
                console.log(err);
                console.log();
            }
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

    let changes = 0;

    for (let thread of threads) {
        for (let i in thread.frames) {
            let frame = thread.frames[i];
            if (frame.imageIndex == ddgImageIndex) {
                let offset = frame.imageOffset;
                let symbolOffset = parseInt(ddgBaseAddress, 16) + offset;
                let symbolAddress = symbolOffset.toString(16);

                let command = `atos -o ${dwarf} -l 0x${ddgBaseAddress} 0x${symbolAddress}`
                console.log(command);
                let symbol = execSync(command);
                frame.symbol = symbol.toString().trim();
                changes += 1;
            }
        }
    }

    return changes;
}

let location = process.argv[2];
if (fs.lstatSync(location).isDirectory()) {
    symbolicateFolder(location.endsWith("/") ? location : `${location}/`);
} else {
    symbolicateFile(location);
}
