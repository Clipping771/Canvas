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
  
  // Replace EventType.xyz with 'xyz' (as strings)
  content = content.replace(/EventType\.([a-zA-Z0-9_]+)/g, "'$1'");
  
  // Replace CanvasEvent with BaseEvent
  content = content.replace(/CanvasEvent/g, 'BaseEvent');
  
  // Replace subscribe with a stream filter
  content = content.replace(/EventBus\(\)\.subscribe\(([^,]+),\s*([^)]+)\)/g, "EventBus().stream.listen((e) { if (e.runtimeType.toString() == $1.toString()) { $2(e); } })");
  
  if (content !== original) {
    if (!content.includes('base_event.dart')) {
       content = content.replace(/(import 'package:vinci_board\/core\/event_bus\.dart';)/, "$1\nimport 'package:vinci_board/core/events/base_event.dart';");
    }
    fs.writeFileSync(file, content, 'utf8');
    changedCount++;
  }
});

console.log('Changed', changedCount, 'files for Events');
