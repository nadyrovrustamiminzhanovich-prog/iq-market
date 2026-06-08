const fs = require('fs');
const path = require('path');

function processDir(dir) {
    const files = fs.readdirSync(dir);
    let countOpacity = 0;
    let countShare = 0;

    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            const res = processDir(fullPath);
            countOpacity += res.countOpacity;
            countShare += res.countShare;
        } else if (fullPath.endsWith('.dart')) {
            let content = fs.readFileSync(fullPath, 'utf8');
            let originalContent = content;

            // Fix withOpacity -> withValues(alpha: ...)
            if (content.includes('.withOpacity(')) {
                // regex to match .withOpacity(0.5) etc
                content = content.replace(/\.withOpacity\(([^)]+)\)/g, '.withValues(alpha: $1)');
            }

            // Fix Share.share -> SharePlus.instance.share() in product_details_screen.dart
            if (content.includes('Share.share')) {
                content = content.replace(/Share\.share\(/g, 'SharePlus.instance.share(');
            }

            if (content !== originalContent) {
                fs.writeFileSync(fullPath, content, 'utf8');
                if (originalContent.includes('.withOpacity(')) countOpacity++;
                if (originalContent.includes('Share.share')) countShare++;
                console.log(`Fixed ${fullPath}`);
            }
        }
    }
    return { countOpacity, countShare };
}

const res = processDir('lib');
console.log(`\nCleanup complete.`);
console.log(`- Files with .withOpacity fixed: ${res.countOpacity}`);
console.log(`- Files with Share.share fixed: ${res.countShare}`);
