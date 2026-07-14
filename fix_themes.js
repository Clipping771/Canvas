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

const files = walk(path.resolve('lib'));
let changedCount = 0;

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let original = content;
  
  content = content.replace(/DaVinciTheme\.background/g, 'AppColors.background');
  content = content.replace(/DaVinciTheme\.primary/g, 'AppColors.primary');
  content = content.replace(/DaVinciTheme\.textPrimary/g, 'AppColors.textPrimary');
  content = content.replace(/DaVinciTheme\.textSecondary/g, 'AppColors.textSecondary');
  
  if (content !== original) {
    fs.writeFileSync(file, content, 'utf8');
    changedCount++;
  }
});

console.log('Changed', changedCount, 'files for Themes');
