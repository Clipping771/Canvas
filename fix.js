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

const files = walk('lib');
let changedCount = 0;

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let original = content;
  
  // Replace absolute-like package imports if any got messed up
  content = content.replace(/package:notesketch_pro\/presentation\/core\//g, 'package:notesketch_pro/core/');
  content = content.replace(/package:notesketch_pro\/presentation\/engine\//g, 'package:notesketch_pro/engines/');
  content = content.replace(/package:notesketch_pro\/presentation\/services\//g, 'package:notesketch_pro/adapters/');
  content = content.replace(/package:notesketch_pro\/presentation\/models\//g, 'package:notesketch_pro/core/models/');
  
  // Replace relative imports blindly if they contain the wrong directory structure.
  // Because 'presentation/core' doesn't exist, we can just remove 'presentation/' 
  // from paths that point to core, engine, or services.
  content = content.replace(/\/presentation\/core\//g, '/core/');
  content = content.replace(/\/presentation\/engine\//g, '/engines/');
  content = content.replace(/\/presentation\/services\//g, '/adapters/');
  
  // Special case for imports starting with 'presentation/' right after the quote
  content = content.replace(/['"]presentation\/core\//g, '"../../core/');
  content = content.replace(/['"]presentation\/engine\//g, '"../../engines/');
  content = content.replace(/['"]presentation\/services\//g, '"../../adapters/');
  
  // Same for `../presentation/core/` -> `../core/`
  content = content.replace(/\.\.\/presentation\/core\//g, '../core/');
  content = content.replace(/\.\.\/presentation\/engine\//g, '../engines/');
  content = content.replace(/\.\.\/presentation\/services\//g, '../adapters/');
  
  // Same for `../../presentation/core/` -> `../../core/`
  content = content.replace(/\.\.\/\.\.\/presentation\/core\//g, '../../core/');

  // For the specific issues logged:
  // 'lib/presentation/core/theme/da_vinci_theme.dart' -> should be 'lib/core/theme/da_vinci_theme.dart'
  
  if (content !== original) {
    fs.writeFileSync(file, content, 'utf8');
    console.log('Fixed', file);
    changedCount++;
  }
});

console.log('Changed', changedCount, 'files');
