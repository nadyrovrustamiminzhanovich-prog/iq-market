const fs = require('fs');

const uniqueUnusedLines = [
  5288, 5203, 4801, 4756, 4702,
  3885, 3870, 3856, 3825, 3770,
  3561, 2707, 2394, 2187, 1679,
  1627, 1622,  733
];
console.log('Unused starts:', uniqueUnusedLines);

let content = fs.readFileSync('lib/screens/taxi/taxi_service_screen.dart', 'utf8');

function findMethodEnd(text, startLineIdx) {
    const lines = text.split('\n');
    let i = 0;
    for (let currentLineIdx = 0; currentLineIdx < lines.length; currentLineIdx++) {
        if (currentLineIdx === startLineIdx - 1) {
            break;
        }
        i += lines[currentLineIdx].length + 1; // +1 for \n
    }

    let braceCount = 0;
    let started = false;
    let inSingleQuote = false;
    let inDoubleQuote = false;
    let inMultiLineComment = false;
    let inSingleLineComment = false;

    for (; i < text.length; i++) {
        const char = text[i];
        const nextChar = text[i+1];
        const prevChar = text[i-1];

        if (inSingleLineComment) {
            if (char === '\n') inSingleLineComment = false;
            continue;
        }

        if (inMultiLineComment) {
            if (char === '*' && nextChar === '/') {
                inMultiLineComment = false;
                i++;
            }
            continue;
        }

        // We will ignore escaping complexity by checking prevChar !== '\\'
        const isEscaped = (prevChar === '\\');

        if (inSingleQuote) {
            if (char === "'" && !isEscaped) inSingleQuote = false;
            continue;
        }

        if (inDoubleQuote) {
            if (char === '"' && !isEscaped) inDoubleQuote = false;
            continue;
        }

        if (char === '/' && nextChar === '/') {
            inSingleLineComment = true;
            i++;
            continue;
        }

        if (char === '/' && nextChar === '*') {
            inMultiLineComment = true;
            i++;
            continue;
        }

        if (char === "'" && !isEscaped) {
            // handle triple quotes rough approximation: just skip next two if they are also '
            if (text[i+1] === "'" && text[i+2] === "'") {
                // it's a triple quote, let's treat it same but wait for ending triple quote
                // actually treating it as single quote is fine, because the next ' will turn it off, and the 3rd will turn it back on.
            }
            inSingleQuote = true;
            continue;
        }

        if (char === '"' && !isEscaped) {
            inDoubleQuote = true;
            continue;
        }

        if (char === '{') {
            started = true;
            braceCount++;
        } else if (char === '}') {
            braceCount--;
            if (started && braceCount === 0) {
                // Found the end!
                // Let's return the line number of this index
                const substring = text.substring(0, i + 1);
                return substring.split('\n').length;
            }
        }
        
        // Single line arrow functions like `Widget foo() => Container();`
        // We only check for ; if we haven't seen a brace yet
        if (!started && char === ';') {
            const substring = text.substring(0, i + 1);
            return substring.split('\n').length;
        }
    }
    return -1;
}

let fileLines = content.split('\n');
let linesDeleted = 0;

for (const start of uniqueUnusedLines) {
    const end = findMethodEnd(content, start);
    if (end !== -1) {
        console.log(`Deleting unused method from line ${start} to ${end}`);
        // fileLines is mutating! No, wait, if we process descending, line numbers don't shift!
        fileLines.splice(start - 1, end - start + 1);
        linesDeleted += (end - start + 1);
        
        // Update content for the next iterations so string indices remain aligned
        content = fileLines.join('\n');
    } else {
        console.log(`Could not find end for method starting at ${start}`);
    }
}

fs.writeFileSync('lib/screens/taxi/taxi_service_screen.dart', fileLines.join('\n'));
console.log('Cleanup complete! Lines deleted:', linesDeleted);
