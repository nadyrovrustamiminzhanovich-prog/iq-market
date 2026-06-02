const fs = require('fs');
const path = require('path');

const logPath = path.join(process.env.USERPROFILE, '.gemini/antigravity/brain/02590f0d-aca7-4bac-a91d-16871e6ee038/.system_generated/tasks/task-845.log');
const flutterAnalyzeLog = fs.readFileSync(logPath, 'utf8');

const lines = flutterAnalyzeLog.split('\n');
const unusedLines = [];

for (const line of lines) {
    if (line.includes('unused_element')) {
        const match = line.match(/taxi_service_screen\.dart:(\d+):/);
        if (match) {
            unusedLines.push(parseInt(match[1]));
        }
    }
}

// remove duplicates and sort descending
const uniqueUnusedLines = [...new Set(unusedLines)].sort((a, b) => b - a);
console.log('Found unused elements at lines:', uniqueUnusedLines);

let fileContent = fs.readFileSync('lib/screens/taxi/taxi_service_screen.dart', 'utf8');
let fileLines = fileContent.split('\n');

function findClosingBrace(lines, startLine) {
    let braceCount = 0;
    let started = false;
    for (let i = startLine - 1; i < lines.length; i++) {
        const line = lines[i];
        for (let j = 0; j < line.length; j++) {
            if (line[j] === '{') {
                braceCount++;
                started = true;
            } else if (line[j] === '}') {
                braceCount--;
            }
        }
        if (started && braceCount === 0) {
            return i;
        }
        // If it's a single line arrow function like `Widget foo() => ...;`
        if (line.includes('=>') && line.endsWith(';')) {
            return i;
        }
        if (!started && line.includes(';')) {
           return i;
        }
    }
    return -1;
}

for (const start of uniqueUnusedLines) {
    // start is 1-indexed
    let end = findClosingBrace(fileLines, start);
    
    // For arrow methods that might span multiple lines, let's just do a naive check for `;` if there are no braces.
    if (end === -1 || (!fileLines[start-1].includes('{') && fileLines[start-1].includes('=>'))) {
        for (let i = start - 1; i < fileLines.length; i++) {
            if (fileLines[i].includes(';')) {
                end = i;
                break;
            }
        }
    }

    if (end !== -1) {
        console.log(`Deleting unused method from line ${start} to ${end + 1}`);
        fileLines.splice(start - 1, end - start + 1); 
    }
}

fs.writeFileSync('lib/screens/taxi/taxi_service_screen.dart', fileLines.join('\n'));
console.log('Cleanup complete!');
