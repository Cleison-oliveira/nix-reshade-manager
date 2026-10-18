# ReShade keycode converter
# Format: <VirtualKeyCode>,<Ctrl>,<Shift>,<Alt> (e.g. "117,0,1,0" for Shift+F6)
let
  toUpper = str:
    let
      chars = [
        { from = "a"; to = "A"; } { from = "b"; to = "B"; } { from = "c"; to = "C"; }
        { from = "d"; to = "D"; } { from = "e"; to = "E"; } { from = "f"; to = "F"; }
        { from = "g"; to = "G"; } { from = "h"; to = "H"; } { from = "i"; to = "I"; }
        { from = "j"; to = "J"; } { from = "k"; to = "K"; } { from = "l"; to = "L"; }
        { from = "m"; to = "M"; } { from = "n"; to = "N"; } { from = "o"; to = "O"; }
        { from = "p"; to = "P"; } { from = "q"; to = "Q"; } { from = "r"; to = "R"; }
        { from = "s"; to = "S"; } { from = "t"; to = "T"; } { from = "u"; to = "U"; }
        { from = "v"; to = "V"; } { from = "w"; to = "W"; } { from = "x"; to = "X"; }
        { from = "y"; to = "Y"; } { from = "z"; to = "Z"; }
      ];
      replaceChar = acc: c: builtins.replaceStrings [c.from] [c.to] acc;
    in
      builtins.foldl' replaceChar str chars;

  keyMap = {
    # Disabled / None
    "NONE" = 0;
    "OFF" = 0;
    "DISABLED" = 0;
    "0" = 0;

    # Function keys (F1 - F24)
    "F1" = 112; "F2" = 113; "F3" = 114; "F4" = 115;
    "F5" = 116; "F6" = 117; "F7" = 118; "F8" = 119;
    "F9" = 120; "F10" = 121; "F11" = 122; "F12" = 123;
    "F13" = 124; "F14" = 125; "F15" = 126; "F16" = 127;
    "F17" = 128; "F18" = 129; "F19" = 130; "F20" = 131;
    "F21" = 132; "F22" = 133; "F23" = 134; "F24" = 135;

    # Letters (A - Z)
    "A" = 65; "B" = 66; "C" = 67; "D" = 68; "E" = 69;
    "F" = 70; "G" = 71; "H" = 72; "I" = 73; "J" = 74;
    "K" = 75; "L" = 76; "M" = 77; "N" = 78; "O" = 79;
    "P" = 80; "Q" = 81; "R" = 82; "S" = 83; "T" = 84;
    "U" = 85; "V" = 86; "W" = 87; "X" = 88; "Y" = 89;
    "Z" = 90;

    # Numbers (0 - 9)
    "1" = 49; "2" = 50; "3" = 51; "4" = 52;
    "5" = 53; "6" = 54; "7" = 55; "8" = 56; "9" = 57;

    # Numpad (NUMPAD0 - NUMPAD9)
    "NUM0" = 96; "NUMPAD0" = 96;
    "NUM1" = 97; "NUMPAD1" = 97;
    "NUM2" = 98; "NUMPAD2" = 98;
    "NUM3" = 99; "NUMPAD3" = 99;
    "NUM4" = 100; "NUMPAD4" = 100;
    "NUM5" = 101; "NUMPAD5" = 101;
    "NUM6" = 102; "NUMPAD6" = 102;
    "NUM7" = 103; "NUMPAD7" = 103;
    "NUM8" = 104; "NUMPAD8" = 104;
    "NUM9" = 105; "NUMPAD9" = 105;
    "MULTIPLY" = 106; "NUMPADMULTIPLY" = 106;
    "ADD" = 107; "NUMPADADD" = 107;
    "SUBTRACT" = 109; "NUMPADSUBTRACT" = 109;
    "DECIMAL" = 110; "NUMPADDECIMAL" = 110;
    "DIVIDE" = 111; "NUMPADDIVIDE" = 111;

    # Navigation / Editing
    "HOME" = 36;
    "END" = 35;
    "INSERT" = 45;
    "DELETE" = 46; "DEL" = 46;
    "PAGEUP" = 33; "PGUP" = 33;
    "PAGEDOWN" = 34; "PGDN" = 34;
    "SCROLLLOCK" = 145;
    "PAUSE" = 19;
    "PRINTSCREEN" = 44; "PRINT" = 44; "PRTSC" = 44;

    # Arrows
    "LEFT" = 37;
    "UP" = 38;
    "RIGHT" = 39;
    "DOWN" = 40;

    # Common keys
    "SPACE" = 32;
    "TAB" = 9;
    "ESCAPE" = 27; "ESC" = 27;
    "RETURN" = 13; "ENTER" = 13;
    "BACKSPACE" = 8; "BACK" = 8;
    "CAPSLOCK" = 20; "CAPS" = 20;
    "NUMLOCK" = 144;
    "GRAVE" = 192; # ` / ~
    "TILDE" = 192;
    "MINUS" = 189;
    "EQUALS" = 187; "EQUAL" = 187;
    "BRACKETLEFT" = 219;
    "BRACKETRIGHT" = 221;
    "BACKSLASH" = 220;
    "SEMICOLON" = 186;
    "APOSTROPHE" = 222; "QUOTE" = 222;
    "COMMA" = 188;
    "PERIOD" = 190; "DOT" = 190;
    "SLASH" = 191;
  };

  # Converts a human-friendly string (e.g. "Shift+F6", "Ctrl+Alt+Home", "Home", "None") or raw "117,0,1,0"
  toReShadeHotkey = input: let
    trimmed = builtins.replaceStrings [" "] [""] input;
    upperInput = toUpper trimmed;
  in
    if upperInput == "" || upperInput == "NONE" || upperInput == "OFF" || upperInput == "DISABLED" || upperInput == "0"
    then "0,0,0,0"
    else let
      isRaw = builtins.match "[0-9]+,[0-1],[0-1],[0-1]" trimmed != null;
    in
      if isRaw
      then trimmed
      else let
        # Split by '+' or '-'
        parts = builtins.filter (x: builtins.isString x && x != "") (builtins.split "[+-]" trimmed);
        upperParts = map (p: toUpper p) parts;

        hasCtrl = builtins.elem "CTRL" upperParts || builtins.elem "CONTROL" upperParts;
        hasShift = builtins.elem "SHIFT" upperParts;
        hasAlt = builtins.elem "ALT" upperParts;

        baseParts = builtins.filter (p: p != "CTRL" && p != "CONTROL" && p != "SHIFT" && p != "ALT") upperParts;
        baseKey = if baseParts != [] then builtins.head baseParts else "NONE";

        code =
          if keyMap ? ${baseKey}
          then keyMap.${baseKey}
          else if baseKey == "NONE" then 0
          else 36; # Fallback to Home

        ctrlVal = if hasCtrl && code != 0 then "1" else "0";
        shiftVal = if hasShift && code != 0 then "1" else "0";
        altVal = if hasAlt && code != 0 then "1" else "0";
      in
        "${toString code},${ctrlVal},${shiftVal},${altVal}";
in {
  inherit toReShadeHotkey;
}
