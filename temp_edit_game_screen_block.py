from pathlib import Path
path = Path(r"c:\Advertisment-game\lib\game_screen.dart")
text = path.read_text(encoding="utf-8")
target = "                if (game.screenSize != size) {\r\n                  game.setScreenSize(size);\r\n                }\r\n\r\n                final halfWidth = size.width * 0.5;\r\n"
if target not in text:
    raise SystemExit('target block not found')
replacement = "                if (game.screenSize != size) {\r\n                  game.setScreenSize(size);\r\n                }\r\n                if (kDebugMode) {\r\n                  debugPrint(\r\n                    'state=\${game.gameState} size=\${size.width.toStringAsFixed(1)}x\${size.height.toStringAsFixed(1)}',\r\n                  );\r\n                }\r\n\r\n                final halfWidth = size.width * 0.5;\r\n"
text = text.replace(target, replacement, 1)
path.write_text(text, encoding="utf-8")
