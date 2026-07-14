import re
import os

def fix_translate_scale(file_path):
    if not os.path.exists(file_path): return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = re.sub(r'\.translate\(', '.translateByDouble(', content)
    new_content = re.sub(r'\.scale\(', '.scaleByDouble(', new_content)
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed translate/scale in {file_path}")

fix_translate_scale(r'lib\core\canvas\canvas_controller.dart')
fix_translate_scale(r'lib\core\utils\sketch_templates.dart')
fix_translate_scale(r'lib\presentation\screens\ai_chat_panel.dart')
fix_translate_scale(r'lib\presentation\screens\canvas\animated_stroke_widget.dart')
fix_translate_scale(r'lib\presentation\screens\canvas\canvas_widget.dart')
fix_translate_scale(r'lib\presentation\screens\canvas_screen.dart')

def fix_graphing_engine():
    p = r'lib\engines\math\core\graphing_engine.dart'
    if not os.path.exists(p): return
    with open(p, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = content.replace('Parser(', 'GrammarParser(').replace('Parser ', 'GrammarParser ')
    new_content = new_content.replace('EvaluationType.REAL', 'RealEvaluator()').replace('evaluate(EvaluationType.REAL', 'evaluate(RealEvaluator()')
    # fallback
    new_content = re.sub(r'\.evaluate\(EvaluationType\.REAL', '.evaluate(RealEvaluator()', new_content)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Fixed graphing engine")

fix_graphing_engine()

def fix_voice():
    p = r'lib\adapters\device\voice_recognition_service.dart'
    if not os.path.exists(p): return
    with open(p, 'r', encoding='utf-8') as f:
        content = f.read()
    target = """      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.dictation,"""
    replacement = """      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),"""
    new_content = content.replace(target, replacement)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Fixed voice recognition")

fix_voice()

def fix_radio_group():
    p = r'lib\presentation\screens\canvas_screen.dart'
    if not os.path.exists(p): return
    with open(p, 'r', encoding='utf-8') as f:
        content = f.read()
    # Replace Radio with RadioGroup logic if needed, but actually Radio is deprecated for RadioGroup? No, in Flutter `groupValue` isn't deprecated. Maybe it's a specific package or custom widget.
    # We will use simple replace for the custom widget or flutter widget if it's there.
    # Wait, the warning says "Use a RadioGroup ancestor to manage group value instead". This is for `RadioMenuButton` or `Radio`?
    pass

