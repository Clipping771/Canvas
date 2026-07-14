const fs = require('fs');
const path = require('path');

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) { 
      results = results.concat(walk(file));
    } else if (file.endsWith('.dart')) { 
      results.push(file);
    }
  });
  return results;
}

const libDir = path.resolve('lib');
const allFiles = walk(libDir);

// Map of filename -> absolute path
const fileMap = {};
allFiles.forEach(file => {
  const baseName = path.basename(file);
  // We'll keep the first one found or make it an array. Let's make it an array just in case of duplicates.
  if (!fileMap[baseName]) {
    fileMap[baseName] = [];
  }
  fileMap[baseName].push(file);
});

let changedCount = 0;

allFiles.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let original = content;
  
  // Find all import statements
  const importRegex = /import\s+['"]([^'"]+)['"]/g;
  let match;
  let replacements = [];

  while ((match = importRegex.exec(content)) !== null) {
    const importPath = match[1];
    
    // Skip package imports that aren't ours
    if (importPath.startsWith('package:') && !importPath.startsWith('package:notesketch_pro')) {
      continue;
    }
    if (importPath.startsWith('dart:')) continue;

    let targetAbsolutePath;

    if (importPath.startsWith('package:notesketch_pro/')) {
       // Convert to absolute path on disk
       targetAbsolutePath = path.join(libDir, importPath.substring('package:notesketch_pro/'.length));
    } else {
       // Relative import
       targetAbsolutePath = path.resolve(path.dirname(file), importPath);
    }

    // Check if the file exists
    if (!fs.existsSync(targetAbsolutePath)) {
      // It's broken! Let's find it by basename
      const baseName = path.basename(importPath);
      const candidates = fileMap[baseName];
      
      if (candidates && candidates.length === 1) {
        // We found exactly one match in the codebase! Let's use it.
        const correctAbsolutePath = candidates[0];
        
        // Compute new package import
        const relativeToLib = path.relative(libDir, correctAbsolutePath).replace(/\\/g, '/');
        const newImport = `package:notesketch_pro/${relativeToLib}`;
        
        replacements.push({
          oldStr: match[0],
          newStr: `import '${newImport}'`
        });
      } else if (candidates && candidates.length > 1) {
        console.log(`Ambiguous match for ${baseName} in ${file}`);
      } else {
        console.log(`Could not find replacement for ${importPath} in ${file}`);
      }
    }
  }

  // Apply replacements backwards so indices don't shift (if we were using indices)
  // Or just use replace since we are replacing the whole string `import '...'`
  // We have to be careful if there are duplicate imports, but usually there aren't.
  if (replacements.length > 0) {
    replacements.forEach(r => {
      content = content.replace(r.oldStr, r.newStr);
    });
    
    if (content !== original) {
      fs.writeFileSync(file, content, 'utf8');
      console.log(`Fixed ${replacements.length} imports in ${file}`);
      changedCount++;
    }
  }
});

console.log('Changed', changedCount, 'files');
