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
    # Function keys
    "F1" = 112;
    "F2" = 113;
    "F3" = 114;
    "F4" = 115;
    "F5" = 116;
    "F6" = 117;
    "F7" = 118;
    "F8" = 119;
    "F9" = 120;
    "F10" = 121;
    "F11" = 122;
    "F12" = 123;

    # Navigation / Editing
    "HOME" = 36;
    "END" = 35;
    "INSERT" = 45;
    "DELETE" = 46;
    "PAGEUP" = 33;
    "PAGEDOWN" = 34;
    "SCROLLLOCK" = 145;
    "PAUSE" = 19;
    "PRINTSCREEN" = 44;

    # Common keys
    "SPACE" = 32;
    "TAB" = 9;
    "ESCAPE" = 27;
    "GRAVE" = 192; # ` / ~
  };

  # Converts a human-friendly string (e.g. "Shift+F6", "Ctrl+Alt+Home", "Home") or raw "117,0,1,0"
  toReShadeHotkey = input: let
    # If the user already provided a raw code like "117,0,1,0", return as is
    isRaw = builtins.match "[0-9]+,[0-1],[0-1],[0-1]" input != null;
  in
    if isRaw
    then input
    else let
      # Split by '+' or '-'
      parts = builtins.filter (x: builtins.isString x && x != "") (builtins.split "[+-]" input);
      upperParts = map (p: toUpper p) parts;

      hasCtrl = builtins.elem "CTRL" upperParts || builtins.elem "CONTROL" upperParts;
      hasShift = builtins.elem "SHIFT" upperParts;
      hasAlt = builtins.elem "ALT" upperParts;

      baseParts = builtins.filter (p: p != "CTRL" && p != "CONTROL" && p != "SHIFT" && p != "ALT") upperParts;
      baseKey = if baseParts != [] then builtins.head baseParts else "HOME";

      code =
        if keyMap ? ${baseKey}
        then keyMap.${baseKey}
        else 36; # Fallback to Home

      ctrlVal = if hasCtrl then "1" else "0";
      shiftVal = if hasShift then "1" else "0";
      altVal = if hasAlt then "1" else "0";
    in
      "${toString code},${ctrlVal},${shiftVal},${altVal}";
in {
  inherit toReShadeHotkey;
}
