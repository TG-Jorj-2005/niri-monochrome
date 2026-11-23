#!/usr/bin/env python3
"""Niri 26.04 is the oracle for supported fixture syntax and duplicate/include semantics."""
import shutil
import subprocess
import tempfile
from pathlib import Path

if not shutil.which('niri'):
    print('SKIP native shortcut fixtures: niri unavailable')
    raise SystemExit(0)
with tempfile.TemporaryDirectory(prefix='nm-shortcut-native-') as temp:
    root=Path(temp)
    (root/'base.kdl').write_text('binds { Mod+T { spawn "first"; }; }\n')
    (root/'later.kdl').write_text('binds { Mod+T { spawn "second"; }; }\n')
    cases=[
        ('native modifier aliases', 'binds { Control+Win+T { spawn "x"; }; Mod5+guillemotleft { focus-column-left; }; }',True),
        ('comments disabled nodes multiline and quoted braces', '/* comment */ binds { /- Mod+Q { quit; }; Mod+T {\n spawn "sh" "-c" "echo } literal";\n}; }',True),
        ('same-block duplicates rejected', 'binds { Mod+T { spawn "a"; }; Mod+T { spawn "b"; }; }',False),
        ('duplicate binds node rejected', 'binds {}\nbinds {}',False),
        ('positional includes and main override allowed', 'include "base.kdl"\ninclude "later.kdl"\nbinds { Mod+T { spawn "inline"; }; }',True),
        ('hidden title is valid without unbinding action', 'binds { Mod+T hotkey-overlay-title=null { spawn "x"; }; }',True),
    ]
    for name,content,valid in cases:
        config=root/'config.kdl';config.write_text(content)
        p=subprocess.run(['niri','validate','-c',str(config)],capture_output=True,text=True,timeout=5)
        assert (p.returncode==0)==valid,(name,p.stderr)
        print('PASS '+name)
    print(f'RESULT {len(cases)}/{len(cases)} passed')
