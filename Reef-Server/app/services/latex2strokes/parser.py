"""Recursive descent LaTeX parser.

Converts a LaTeX math string into a tree of Node objects.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Union


# ---------------------------------------------------------------------------
# Node types (frozen dataclasses for immutability)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class SymbolNode:
    symbol: str


@dataclass(frozen=True)
class GroupNode:
    children: tuple["Node", ...]


@dataclass(frozen=True)
class FractionNode:
    numerator: "Node"
    denominator: "Node"


@dataclass(frozen=True)
class SuperscriptNode:
    base: "Node"
    exponent: "Node"


@dataclass(frozen=True)
class SubscriptNode:
    base: "Node"
    subscript: "Node"


@dataclass(frozen=True)
class SqrtNode:
    content: "Node"


@dataclass(frozen=True)
class ParenNode:
    content: "Node"
    left: str
    right: str


Node = Union[
    SymbolNode,
    GroupNode,
    FractionNode,
    SuperscriptNode,
    SubscriptNode,
    SqrtNode,
    ParenNode,
]

# ---------------------------------------------------------------------------
# Greek and special command mappings
# ---------------------------------------------------------------------------

GREEK_MAP: dict[str, str] = {
    "alpha": "α",
    "beta": "β",
    "theta": "θ",
    "pi": "π",
    "sigma": "σ",
    "lambda": "λ",
    "mu": "μ",
    "phi": "φ",
    "omega": "ω",
    "delta": "δ",
    "Delta": "Δ",
    "Omega": "Ω",
    "Sigma": "Σ",
    "Pi": "Π",
    "Lambda": "Λ",
    "Phi": "Φ",
    "Theta": "Θ",
    "gamma": "γ",
    "Gamma": "Γ",
    "epsilon": "ε",
    "eta": "η",
    "kappa": "κ",
    "nu": "ν",
    "xi": "ξ",
    "rho": "ρ",
    "tau": "τ",
    "upsilon": "υ",
    "chi": "χ",
    "psi": "ψ",
    "zeta": "ζ",
    "infty": "∞",
    "infinity": "∞",
    "implies": "⟹",
    "cdot": "·",
    "times": "×",
    "div": "÷",
    "pm": "±",
    "leq": "≤",
    "geq": "≥",
    "neq": "≠",
    "approx": "≈",
    "in": "∈",
    "forall": "∀",
    "exists": "∃",
    "partial": "∂",
    "nabla": "∇",
}

# Commands that produce a space (rendered as nothing visual)
SPACE_COMMANDS: frozenset[str] = frozenset({",", ";", " ", "quad", "qquad", "!", ":", ">"})


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

class _Parser:
    """Tokenizing recursive descent parser for LaTeX math."""

    def __init__(self, text: str) -> None:
        self._text = text
        self._pos = 0

    # ------------------------------------------------------------------
    # Low-level helpers
    # ------------------------------------------------------------------

    def _peek(self) -> str | None:
        if self._pos < len(self._text):
            return self._text[self._pos]
        return None

    def _advance(self) -> str:
        ch = self._text[self._pos]
        self._pos += 1
        return ch

    def _skip_whitespace(self) -> None:
        while self._pos < len(self._text) and self._text[self._pos] in " \t\n\r":
            self._pos += 1

    def _at_end(self) -> bool:
        return self._pos >= len(self._text)

    # ------------------------------------------------------------------
    # Token readers
    # ------------------------------------------------------------------

    def _read_command(self) -> str:
        r"""Read a \command name (letters only, or single non-letter char)."""
        if self._at_end():
            return ""
        ch = self._peek()
        if ch is None:
            return ""
        if ch.isalpha():
            start = self._pos
            while not self._at_end() and self._text[self._pos].isalpha():
                self._pos += 1
            return self._text[start:self._pos]
        else:
            return self._advance()

    def _read_group(self) -> Node:
        """Read a braced group {…}."""
        self._skip_whitespace()
        if self._peek() == "{":
            self._advance()  # consume {
            children = self._parse_sequence(stop="}")
            if self._peek() == "}":
                self._advance()
            return GroupNode(children=tuple(children)) if len(children) != 1 else children[0]
        else:
            # Single character group
            node = self._parse_atom()
            return node if node is not None else SymbolNode(symbol="")

    # ------------------------------------------------------------------
    # Main entry point
    # ------------------------------------------------------------------

    def parse(self) -> Node:
        self._skip_whitespace()
        children = self._parse_sequence(stop=None)
        if len(children) == 1:
            return children[0]
        return GroupNode(children=tuple(children))

    def _parse_sequence(self, stop: str | None) -> list[Node]:
        """Parse a sequence of nodes until `stop` char or end."""
        nodes: list[Node] = []
        while not self._at_end():
            self._skip_whitespace()
            if self._at_end():
                break
            ch = self._peek()
            if ch == stop:
                break
            if ch in ("}", ) and stop != "}":
                break
            node = self._parse_atom()
            if node is None:
                break
            # Handle superscript/subscript postfix operators
            node = self._parse_postfix(node)
            nodes.append(node)
        return nodes

    def _parse_postfix(self, base: Node) -> Node:
        """Attach ^ and _ postfix operators to base."""
        while True:
            self._skip_whitespace()
            ch = self._peek()
            if ch == "^":
                self._advance()
                exp = self._read_group()
                base = SuperscriptNode(base=base, exponent=exp)
            elif ch == "_":
                self._advance()
                sub = self._read_group()
                base = SubscriptNode(base=base, subscript=sub)
            elif ch == "'":
                self._advance()
                prime_node = SymbolNode(symbol="′")
                base = SuperscriptNode(base=base, exponent=prime_node)
            else:
                break
        return base

    def _parse_atom(self) -> Node | None:
        """Parse a single atomic node."""
        self._skip_whitespace()
        if self._at_end():
            return None

        ch = self._advance()

        # LaTeX command
        if ch == "\\":
            return self._parse_command()

        # Opening brace — inline group
        if ch == "{":
            children = self._parse_sequence(stop="}")
            if self._peek() == "}":
                self._advance()
            if len(children) == 1:
                return children[0]
            return GroupNode(children=tuple(children))

        # Closing brace — return None to let caller handle
        if ch == "}":
            self._pos -= 1  # put it back
            return None

        # Left paren/bracket
        if ch in ("(", "["):
            right = ")" if ch == "(" else "]"
            content_nodes = self._parse_sequence(stop=right)
            if self._peek() == right:
                self._advance()
            content: Node = GroupNode(children=tuple(content_nodes)) if len(content_nodes) != 1 else content_nodes[0]
            return ParenNode(content=content, left=ch, right=right)

        # Right paren/bracket — return None to let callers handle
        if ch in (")", "]"):
            self._pos -= 1
            return None

        # Regular printable characters
        if ch.isalnum() or ch in "+-=.,;:!?|/<>@#%&*":
            return SymbolNode(symbol=ch)

        # Default: treat as symbol
        if ch.isprintable():
            return SymbolNode(symbol=ch)

        return None

    def _parse_command(self) -> Node:
        r"""Parse a \command after the backslash has been consumed."""
        cmd = self._read_command()

        # Space commands → no visual output (skip silently)
        if cmd in SPACE_COMMANDS:
            return SymbolNode(symbol=" ")

        # Fraction
        if cmd == "frac":
            num = self._read_group()
            den = self._read_group()
            return FractionNode(numerator=num, denominator=den)

        # Square root
        if cmd in ("sqrt", "surd"):
            # Optional argument [n] ignored
            self._skip_whitespace()
            if self._peek() == "[":
                self._advance()
                self._parse_sequence(stop="]")
                if self._peek() == "]":
                    self._advance()
            content = self._read_group()
            return SqrtNode(content=content)

        # \left( and \right)
        if cmd == "left":
            self._skip_whitespace()
            if self._at_end():
                return SymbolNode(symbol="(")
            delim = self._advance()
            right_delim = ")" if delim == "(" else ("]" if delim == "[" else delim)
            # parse until \right
            content_nodes = self._parse_until_right()
            content = GroupNode(children=tuple(content_nodes)) if len(content_nodes) != 1 else (content_nodes[0] if content_nodes else SymbolNode(symbol=""))
            return ParenNode(content=content, left=delim, right=right_delim)

        if cmd == "right":
            # Consume the closing delimiter
            self._skip_whitespace()
            if not self._at_end():
                self._advance()
            return SymbolNode(symbol="")  # handled by \left

        # \text{...}
        if cmd in ("text", "mathrm", "mathbf", "mathit", "mathsf", "mathtt", "operatorname"):
            content = self._read_group()
            return content

        # Greek and special symbols
        if cmd in GREEK_MAP:
            return SymbolNode(symbol=GREEK_MAP[cmd])

        # Primes
        if cmd == "prime":
            return SymbolNode(symbol="′")

        # Known math operators as symbols
        if cmd in ("sin", "cos", "tan", "log", "ln", "exp", "lim", "max", "min",
                   "sec", "csc", "cot", "arcsin", "arccos", "arctan"):
            # Render as letter sequence
            nodes = [SymbolNode(symbol=c) for c in cmd]
            return GroupNode(children=tuple(nodes)) if len(nodes) > 1 else nodes[0]

        # cdots, ldots → ellipsis
        if cmd in ("cdots", "ldots", "dots"):
            return SymbolNode(symbol="…")

        # Arrows
        if cmd in ("to", "rightarrow"):
            return SymbolNode(symbol="→")
        if cmd in ("leftarrow",):
            return SymbolNode(symbol="←")

        # Unknown command: render as literal text
        return GroupNode(children=tuple(SymbolNode(symbol=c) for c in cmd)) if cmd else SymbolNode(symbol="")

    def _parse_until_right(self) -> list[Node]:
        """Parse nodes until we hit \right."""
        nodes: list[Node] = []
        while not self._at_end():
            self._skip_whitespace()
            if self._at_end():
                break
            # Peek ahead for \right
            if self._text[self._pos] == "\\" and self._text[self._pos + 1:self._pos + 6] == "right":
                break
            node = self._parse_atom()
            if node is None:
                break
            node = self._parse_postfix(node)
            nodes.append(node)
        return nodes


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def parse_latex(latex: str) -> Node:
    """Parse a LaTeX math string and return the root Node."""
    return _Parser(latex.strip()).parse()
