from pathlib import Path
path = Path(r"c:\Advertisment-game\lib\game_screen.dart")
text = path.read_text(encoding="utf-8")
text = text.replace('behavior: HitTestBehavior.translucent', 'behavior: HitTestBehavior.opaque')
path.write_text(text, encoding="utf-8")
