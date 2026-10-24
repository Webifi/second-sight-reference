"""Evaluate a pDS LDF source directly, without any fuse map: the reference that chipsim.py
is checked against (simcheck.py). Reads what the test designs use:
  * SYM GLB blocks: SIGTYPE name (or [A0..A3]) REG / OUT / OE ..., EQUATIONS with ! & # $$
    ( ) VCC GND, X.CLK (a clock signal), X.PTCLK (a product-term clock), X.RE / X.PTRE
    (reset term), X.PIN / X.Q / X.FB (the signal's own value);
  * SYM IOC blocks: XPIN type name [LOCK pin], and one of IB11(Z,XI), OB11(XO,A),
    OT11(XO,A,OE), BI11(Z,XB,A,OE); a dedicated input or clock cell (I0..I3, Y0..Y2)
    takes its package pin from the cell name.

Semantics (Lattice: LATSYSM.LIB macros, 1996 Data Book, ispLSI 1016 data sheet):
  * a REG signal loads its equation on the rising edge of its clock; X.RE resets it, and
    so does the Y1/RESET pin when it is low with OPTION Y1_AS_RESET ON (pDS's default for
    the 1016: it adds the option when the source does not set it); a reset register is 0;
  * combinational signals follow their equations;
  * OB11 drives the pin with A; OT11 and BI11 drive it while OE is 1; IB11 and BI11 read it.

Operators: ! binds tightest, then &, then #. A $$ (XOR) mixed with & or # without
parentheses is refused rather than guessed. Evaluation is like chipsim: every signal
takes one step to follow its inputs, registers sample when their clock rises, settle()
steps until nothing changes."""
import re
import sys
from pathlib import Path

DEDICATED = {"I0": 14, "I1": 24, "I2": 36, "I3": 2, "Y0": 11, "Y1": 35, "Y2": 33}


class LdfError(Exception):
    pass


def tokens(text):
    return re.findall(r"\$\$|[A-Za-z_][A-Za-z0-9_.]*|[!&#()]", text)


class Parser:
    def __init__(self, toks):
        self.t = toks
        self.i = 0

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else None

    def take(self):
        self.i += 1
        return self.t[self.i - 1]

    def expr(self):
        """a # b # ... or a $$ b $$ ...; the two are not mixed, and an operand of $$ is a
        single factor (anything longer must be in parentheses)."""
        left = self.term()
        ops = []
        while self.peek() in ("#", "$$"):
            op = self.take()
            ops.append(op)
            right = self.term()
            if op == "$$" and (left[0] == "&" or right[0] == "&"):
                raise LdfError("$$ and & mixed without parentheses")
            left = (op, left, right)
        if "$$" in ops and "#" in ops:
            raise LdfError("$$ and # mixed without parentheses")
        return left

    def term(self):
        left = self.factor()
        while self.peek() == "&":
            self.take()
            left = ("&", left, self.factor())
        return left

    def factor(self):
        tok = self.take()
        if tok == "!":
            return ("!", self.factor())
        if tok == "(":
            e = self.expr()
            if self.take() != ")":
                raise LdfError("missing )")
            return ("()", e)
        if tok is None or tok in ("&", "#", "$$", ")"):
            raise LdfError(f"unexpected {tok}")
        return ("sym", tok)


def expand(name):
    m = re.fullmatch(r"\[([A-Za-z_]+?)(\d+)\.\.([A-Za-z_]+?)(\d+)\]", name)
    if not m:
        return [name]
    a, b = int(m.group(2)), int(m.group(4))
    step = 1 if b >= a else -1
    return [f"{m.group(1)}{k}" for k in range(a, b + step, step)]


class Design:
    def __init__(self, text, pkg_ioc):
        text = re.sub(r"//[^\n]*", "", text)
        self.y1_reset = True
        m = re.search(r"OPTION\s+Y1_AS_RESET\s+(ON|OFF)", text)
        if m:
            self.y1_reset = m.group(1) == "ON"
        self.reg = set()
        self.eq = {}          # signal -> expression (D for registers)
        self.clk = {}         # register -> ("pin" signal | "pt" expression)
        self.rst = {}         # register -> expression
        self.pins_in = {}     # signal -> package pin
        self.pins_out = {}    # package pin -> (signal, OE signal or None)
        self.ioreg = {}       # signal -> ("ff" | "latch", package pin, clock signal)
        for blk in re.finditer(r"SYM\s+(GLB|IOC)\s+(\w+)[^;]*;(.*?)\bEND\s*;", text, re.S):
            kind, loc, body = blk.groups()
            if kind == "GLB":
                self._glb(body)
            else:
                self._ioc(loc, body, pkg_ioc)

    def _glb(self, body):
        for st in re.finditer(r"SIGTYPE\s+([^;]+);", body):
            words = st.group(1).split()
            names = []
            for w in re.findall(r"\[[^\]]+\]|\S+", st.group(1)):
                if w.upper() in ("REG", "OUT", "OE", "STRONGMIN", "NOMIN", "FASTMIN", "CRIT", "ASYNC"):
                    continue
                names += expand(w)
            if "REG" in [w.upper() for w in words]:
                self.reg |= set(names)
        m = re.search(r"EQUATIONS(.*)", body, re.S)
        if not m:
            return
        regs_before = set(self.reg)
        declared = set()
        for st in re.finditer(r"SIGTYPE\s+([^;]+);", body):
            declared |= {n for w in re.findall(r"\[[^\]]+\]|\S+", st.group(1)) for n in expand(w)}
        for line in m.group(1).split(";"):
            line = line.strip()
            if not line or "=" not in line:
                continue
            lhs, rhs = line.split("=", 1)
            lhs = lhs.strip()
            p = Parser(tokens(rhs))
            e = p.expr()
            if p.peek() is not None:
                raise LdfError(f"trailing {p.peek()} in {line}")
            base, _, ext = lhs.partition(".")
            ext = ext.upper()
            if ext == "":
                self.eq[base] = e
            elif ext == "D":
                self.eq[base] = e
                self.reg.add(base)
            elif ext == "CLK":
                self.clk[base] = ("pin", e)
            elif ext == "PTCLK":
                self.clk[base] = ("pt", e)
            elif ext in ("RE", "PTRE"):
                self.rst[base] = e
            elif ext == "OE":
                self.eq[base] = e     # NAME.OE: an output enable, kept as an ordinary signal
            else:
                raise LdfError(f"extension .{ext} on {lhs}")
        # A GLB has one clock and one reset for all its registers, so a design may write
        # them once per block, on one of its registers; the others share them.
        regs = (self.reg & declared) | (self.reg - regs_before)
        for table in (self.clk, self.rst):
            given = {table[r] for r in regs if r in table}
            if len(given) > 1 and table is self.clk:
                raise LdfError(f"registers {sorted(regs)}: more than one clock in one block")
            if len(given) == 1:
                one = next(iter(given))
                for r in regs:
                    table.setdefault(r, one)

    def _ioc(self, loc, body, pkg_ioc):
        xp = re.search(r"XPIN\s+\w+\s+(\w+)(?:\s+LOCK\s+(\d+))?", body)
        if not xp:
            raise LdfError(f"IOC {loc} without XPIN")
        xname, lock = xp.group(1), xp.group(2)
        if lock:
            pin = int(lock)
        elif loc in DEDICATED:
            pin = DEDICATED[loc]
        else:
            pin = pkg_ioc[int(loc[2:])]
        mac = re.search(r"(\w+)\s*\(([^)]*)\)", body[xp.end():])
        name, args = mac.group(1).upper(), [a.strip() for a in mac.group(2).split(",")]
        if name == "IB11":
            self.pins_in[args[0]] = pin
        elif name == "OB11":
            self.pins_out[pin] = (args[1], None)
        elif name == "OB21":
            self.pins_out[pin] = ("!" + args[1], None)        # the inverting output buffer
        elif name == "OT11":
            self.pins_out[pin] = (args[1], args[2])
        elif name == "OT21":
            self.pins_out[pin] = ("!" + args[1], args[2])     # inverting, with an enable
        elif name == "BI11":
            self.pins_in[args[0]] = pin
            self.pins_out[pin] = (args[2], args[3])
        elif name in ("ID11", "IL11", "ID21", "IL21"):
            # registered / latched input: Q0 loads the pin on CLK's rising edge (ID11) or
            # follows it while G is 1 (IL11); the 21 forms invert the clock / enable
            ck = ("!" if name.endswith("21") else "") + args[2]
            self.ioreg[args[0]] = ("ff" if name[1] == "D" else "latch", pin, ck)
        elif name in ("BIID11", "BIIL11", "BIID51", "BIIL51"):
            # bidirectional pin with a registered / latched input: (Q0, XB0, A0, CLK, OE)
            ck = ("!" if name.endswith("51") else "") + args[3]
            self.ioreg[args[0]] = ("ff" if name[3] == "D" else "latch", pin, ck)
            self.pins_out[pin] = (args[2], args[4])
        else:
            raise LdfError(f"I/O macro {name}")


class Sim:
    def __init__(self, design):
        self.d = design
        self.v = {s: 0 for s in list(design.eq) + list(design.reg) + list(design.ioreg)}
        self.ext = {}
        self.clk_was = {}
        self.counting = True
        self.pin_delay = False      # True: I/O pins reach the logic one step late
        self.pbuf = {}

    def drive(self, pin, value):
        """Drive package pin `pin` from outside (0/1), or release it (None): a released
        pin nothing drives reads 1 (the 1016's active pull-up, as in chipsim.py)."""
        if value is None:
            self.ext.pop(pin, None)
        else:
            self.ext[pin] = value

    def value(self, e, v):
        op = e[0]
        if op == "sym":
            name = e[1]
            base, _, ext = name.partition(".")
            if base.upper() == "VCC":
                return 1
            if base.upper() == "GND":
                return 0
            if base in self.d.pins_in:
                p = self.d.pins_in[base]
                if p in self.d.pins_out:      # a bidirectional pin reads its pad
                    sig, oe = self.d.pins_out[p]
                    if oe is None or self.value(("sym", oe), v):
                        return self.value(("sym", sig), v)
                if self.pin_delay and p not in DEDICATED.values():
                    return self.pbuf.get(p, 1)
                return self.ext.get(p, 1)
            if base in v:
                return v[base]
            raise LdfError(f"unknown signal {name}")
        if op == "!":
            return 1 - self.value(e[1], v)
        if op == "()":
            return self.value(e[1], v)
        a, b = self.value(e[1], v), self.value(e[2], v)
        return {"&": a & b, "#": a | b, "$$": a ^ b}[op]

    def pad(self, p, v):
        """The level on package pin p: the design's own drive when enabled, else outside."""
        if p in self.d.pins_out:
            sig, oe = self.d.pins_out[p]
            on = oe is None or (1 - self.value(("sym", oe[1:]), v) if oe.startswith("!")
                                else self.value(("sym", oe), v))
            if on:
                return (1 - self.value(("sym", sig[1:]), v) if sig.startswith("!")
                        else self.value(("sym", sig), v))
        return self.ext.get(p, 1)

    def signal(self, name):
        """A macro argument: a signal, or !signal (the macro sees its complement)."""
        if name.startswith("!"):
            return 1 - self.signal(name[1:].strip())
        return self.value(("sym", name), self.v)

    def pin(self, p):
        if p in self.d.pins_out:
            sig, oe = self.d.pins_out[p]
            if oe is None or self.signal(oe):
                return self.signal(sig)
        return self.ext.get(p, 1)

    def power_up(self):
        """Every register 0, the logic settled to the pins with no clock edge counted
        (Lattice documents no power-up state for the 1016; this is the convention both
        ldfsim.py and chipsim.py use)."""
        self.counting = False
        self.settle()
        self.counting = True

    def step(self):
        v = dict(self.v)
        new = {}
        greset = self.d.y1_reset and self.ext.get(35, 1) == 0
        for s, e in self.d.eq.items():
            if s in self.d.reg:
                if s not in self.d.clk:
                    raise LdfError(f"register {s} without a clock")
                kind, ce = self.d.clk[s]
                c = self.value(ce, v)
                rising = c == 1 and self.clk_was.get(s, c) == 0 and self.counting
                self.clk_was[s] = c
                r = greset or (s in self.d.rst and self.value(self.d.rst[s], v))
                if r:
                    new[s] = 0
                elif rising:
                    new[s] = self.value(e, v)
                else:
                    new[s] = v[s]
            else:
                new[s] = self.value(e, v)
        for s, (kind, pin, ck) in self.d.ioreg.items():
            c = 1 - self.value(("sym", ck[1:]), v) if ck.startswith("!") else self.value(("sym", ck), v)
            d = self.pad(pin, v)
            if greset:
                new[s] = 0
            elif kind == "ff":
                rising = c == 1 and self.clk_was.get(s, c) == 0 and self.counting
                new[s] = d if rising else v[s]
            else:
                new[s] = d if c == 1 else v[s]
            self.clk_was[s] = c
        changed = any(self.v[s] != x for s, x in new.items())
        self.v.update(new)
        if self.pin_delay:
            # an I/O pin reaches the logic through its I/O cell: one step later, as in chipsim
            changed |= self.pbuf != self.ext
            self.pbuf = dict(self.ext)
        return changed

    def settle(self, limit=500):
        for _ in range(limit):
            if not self.step():
                return
        raise LdfError("did not settle")
