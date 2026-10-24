#!/bin/bash
# Build a Lattice pDS design file (.ldf) into a JEDEC fuse map with Lattice pDS 2.61,
# unattended, on Linux or WSL.
#
#   tools/lattice/pds261_build.sh data/lattice/Lattice_original-BE8C.ldf data/lattice/Lattice_original-BE8C.fxp out/U7.jed
#
# pDS 2.61 is a 16-bit Windows 3.1 program. This script runs it in Wine on a virtual
# screen (Xvfb). Steps: File > Import LDF, Design > Verify, Design > Route with the
# Strong router and Extended run time, then Design > Fuse Map. See tools/lattice/README.md.
#
# The placement file (.fxp) goes next to the design under the same name, where pDS
# reads it. Click coordinates use a 1000x740 Wine desktop on a 1024x768 screen;
# the script sets up both.
#
# Needs: wine with a 32-bit prefix (WINEARCH=win32; Wine runs 16-bit programs there),
# Xvfb and xdotool, and pDS 2.61 installed in C:\PDS of that prefix.
# Settings:
#   PDS_PREFIX   the Wine prefix with pDS 2.61 in C:\PDS (default: ~/.wine-pds261)
#   PDS_DISPLAY  the virtual screen number (default: 77)
# Output: the fuse map at the path given, and beside it pDS's Verify report (.rp1) and
# router status (.sta). Exit status 1 when pDS made no fuse map.
set -u
SRC=$1
FXP=${2:--}
OUT=$3
export WINEPREFIX=${PDS_PREFIX:-$HOME/.wine-pds261}
export WINEARCH=win32 WINEDEBUG=-all
export DISPLAY=:${PDS_DISPLAY:-77}
export LATTICE='C:\PDS'
W=$WINEPREFIX/drive_c/WORK
D=BUILD                                  # pDS 2.61 takes 8.3 file names
[ -f "$WINEPREFIX/drive_c/PDS/LATTICE.EXE" ] || { echo "no pDS 2.61 in $WINEPREFIX/drive_c/PDS"; exit 1; }
mkdir -p "$W"
rm -f "$W/$D".*
cp "$SRC" "$W/$D.LDF"
[ "$FXP" != "-" ] && cp "$FXP" "$W/$D.fxp"

# the virtual screen and a fresh pDS
if ! xdpyinfo >/dev/null 2>&1; then
  Xvfb "$DISPLAY" -screen 0 1024x768x16 -nolisten tcp >/dev/null 2>&1 &
  sleep 2
fi
wineserver -k 2>/dev/null; sleep 1
(cd "$W" && nohup wine explorer /desktop=pds,1000x740 'C:\PDS\LATTICE.EXE' >/dev/null 2>&1 &)
sleep 12
popups() { xdotool key Escape; sleep 0.3; xdotool key Escape; sleep 0.3; }
popups

# File > Import LDF
xdotool mousemove 300 13 click 1; sleep 0.3
xdotool mousemove 37 34 click 1; sleep 1
xdotool mousemove 75 165 click 1; sleep 2
if xdotool search --onlyvisible --name "Save LIF" >/dev/null 2>&1; then   # "save the open design?": No
  xdotool mousemove 501 399 click 1; sleep 2
fi
for i in $(seq 1 20); do xdotool search --onlyvisible --name "Import LDF" >/dev/null 2>&1 && break; sleep 0.5; done
xdotool type --delay 20 'C:\WORK\'"$D"'.LDF'; sleep 0.3; xdotool key Return
sleep 10; xdotool key Return; sleep 0.5

# Design > Verify (the compiler, minimizer and fitter); the report is BUILD.rp1
xdotool mousemove 73 34 click 1; sleep 1
xdotool mousemove 85 89 click 1
for i in $(seq 1 120); do sleep 1; [ -f "$W/$D.rp1" ] && break; done
sleep 3
OUTDIR=$(dirname "$OUT")
STEM=$(basename "$OUT" .jed)
mkdir -p "$OUTDIR"
cp "$W/$D.rp1" "$OUTDIR/$STEM.rp1" 2>/dev/null
if ! [ -f "$W/$D.rp1" ] || grep -q "Unsuccessful Design Verification" "$W/$D.rp1"; then
  echo "pDS: Verify failed, see $OUTDIR/$STEM.rp1"; wineserver -k; exit 1
fi
popups

# Design > Route: the Strong router, Extended run time; done when BUILD.sta has its
# closing "Elapsed Time" line
xdotool mousemove 73 34 click 1; sleep 1
xdotool mousemove 91 115 click 1; sleep 3
xdotool mousemove 318 98 click 1; sleep 2
if xdotool search --onlyvisible --name "Run Time Options" >/dev/null 2>&1; then
  xdotool mousemove 301 135 click 1
fi
for i in $(seq 1 1200); do sleep 1; grep -q "Elapsed Time" "$W/$D.sta" 2>/dev/null && break; done
sleep 3
cp "$W/$D.sta" "$OUTDIR/$STEM.sta" 2>/dev/null
xdotool mousemove 471 98 click 1; sleep 1
popups
[ -f "$W/$D.lpr" ] || { echo "pDS: routing failed, see $OUTDIR/$STEM.sta"; wineserver -k; exit 1; }

# Design > Fuse Map > Execute
xdotool mousemove 73 34 click 1; sleep 1
xdotool mousemove 100 141 click 1; sleep 2
xdotool mousemove 68 73 click 1
for i in $(seq 1 120); do sleep 1; [ -f "$W/$D.jed" ] && break; done
sleep 2
wineserver -k
[ -f "$W/$D.jed" ] || { echo "pDS: no fuse map"; exit 1; }
cp "$W/$D.jed" "$OUT"
cp "$W/$D.lpr" "$OUTDIR/$STEM.lpr"
echo "$OUT"
