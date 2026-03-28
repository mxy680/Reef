"""Two-pass layout engine.

Pass 1 (measure): walk the parse tree bottom-up, compute bounding box of each node.
Pass 2 (place): walk top-down, assign absolute (x, y) positions to each symbol.
"""
from __future__ import annotations

from dataclasses import dataclass

from .parser import (
    FractionNode,
    GroupNode,
    Node,
    ParenNode,
    SqrtNode,
    SubscriptNode,
    SuperscriptNode,
    SymbolNode,
)

# ---------------------------------------------------------------------------
# Bounding box
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class BBox:
    width: float   # total horizontal space
    height: float  # total vertical space (positive = downward)
    ascent: float  # distance above baseline (positive)
    descent: float # distance below baseline (positive)


# ---------------------------------------------------------------------------
# Output type
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class PlacedSymbol:
    symbol: str
    x: float   # center x
    y: float   # baseline y
    size: float


# ---------------------------------------------------------------------------
# Width/height estimates per character type
# ---------------------------------------------------------------------------

_NARROW_CHARS = frozenset("1liI.,:;!'|")
_WIDE_CHARS = frozenset("mwMWmw")
_OPERATOR_CHARS = frozenset("+-=×÷·")


def _char_width_factor(ch: str) -> float:
    if ch in _NARROW_CHARS:
        return 0.35
    if ch in _WIDE_CHARS:
        return 0.85
    return 0.6


def _symbol_bbox(symbol: str, size: float) -> BBox:
    """Estimate bounding box for a single rendered symbol."""
    if len(symbol) == 1:
        w = size * _char_width_factor(symbol)
    else:
        # Multi-char (e.g. "sin", "cos")
        w = sum(size * _char_width_factor(c) for c in symbol)
    return BBox(width=w, height=size, ascent=size * 0.7, descent=size * 0.3)


def _spacing(symbol: str, size: float) -> float:
    """Inter-symbol spacing based on symbol type."""
    if symbol in _OPERATOR_CHARS or symbol in ("=",):
        return size * 0.4
    return size * 0.15


# ---------------------------------------------------------------------------
# Measure pass
# ---------------------------------------------------------------------------

def _measure(node: Node, size: float) -> BBox:
    """Compute bounding box for a node at given font size."""
    if isinstance(node, SymbolNode):
        if node.symbol in (" ", ""):
            return BBox(width=size * 0.2, height=0.0, ascent=0.0, descent=0.0)
        return _symbol_bbox(node.symbol, size)

    if isinstance(node, GroupNode):
        if not node.children:
            return BBox(width=0.0, height=0.0, ascent=0.0, descent=0.0)
        boxes = [_measure(child, size) for child in node.children]
        total_width = sum(b.width for b in boxes)
        # Add inter-symbol spacing
        for i, child in enumerate(node.children):
            if i > 0 and isinstance(child, SymbolNode):
                total_width += _spacing(child.symbol, size)
        max_ascent = max(b.ascent for b in boxes)
        max_descent = max(b.descent for b in boxes)
        return BBox(
            width=total_width,
            height=max_ascent + max_descent,
            ascent=max_ascent,
            descent=max_descent,
        )

    if isinstance(node, FractionNode):
        num_size = size * 0.7
        den_size = size * 0.7
        num_box = _measure(node.numerator, num_size)
        den_box = _measure(node.denominator, den_size)
        bar_gap = size * 0.1
        total_width = max(num_box.width, den_box.width) + size * 0.2
        total_height = num_box.height + bar_gap * 2 + den_box.height
        ascent = num_box.height + bar_gap
        descent = bar_gap + den_box.height
        return BBox(width=total_width, height=total_height, ascent=ascent, descent=descent)

    if isinstance(node, SuperscriptNode):
        base_box = _measure(node.base, size)
        exp_size = size * 0.6
        exp_box = _measure(node.exponent, exp_size)
        # Exponent sits upper-right, shifted up by 0.4 * size
        shift_up = size * 0.4
        total_width = base_box.width + exp_box.width + size * 0.05
        ascent = max(base_box.ascent, exp_box.ascent + shift_up)
        descent = base_box.descent
        return BBox(width=total_width, height=ascent + descent, ascent=ascent, descent=descent)

    if isinstance(node, SubscriptNode):
        base_box = _measure(node.base, size)
        sub_size = size * 0.6
        sub_box = _measure(node.subscript, sub_size)
        shift_down = size * 0.2
        total_width = base_box.width + sub_box.width + size * 0.05
        descent = max(base_box.descent, sub_box.descent + shift_down)
        ascent = base_box.ascent
        return BBox(width=total_width, height=ascent + descent, ascent=ascent, descent=descent)

    if isinstance(node, SqrtNode):
        inner_size = size * 0.9
        inner_box = _measure(node.content, inner_size)
        radical_w = size * 0.4
        bar_gap = size * 0.1
        total_width = radical_w + inner_box.width + size * 0.1
        ascent = inner_box.ascent + bar_gap
        descent = inner_box.descent
        return BBox(width=total_width, height=ascent + descent, ascent=ascent, descent=descent)

    if isinstance(node, ParenNode):
        inner_box = _measure(node.content, size)
        paren_w = size * 0.25
        total_width = paren_w * 2 + inner_box.width + size * 0.1
        ascent = max(inner_box.ascent, size * 0.6)
        descent = max(inner_box.descent, size * 0.3)
        return BBox(width=total_width, height=ascent + descent, ascent=ascent, descent=descent)

    return BBox(width=0.0, height=0.0, ascent=0.0, descent=0.0)


# ---------------------------------------------------------------------------
# Place pass
# ---------------------------------------------------------------------------

def _place(
    node: Node,
    cx: float,
    baseline_y: float,
    size: float,
    out: list[PlacedSymbol],
) -> None:
    """Recursively place symbols, appending to `out`."""
    if isinstance(node, SymbolNode):
        if node.symbol not in (" ", ""):
            out.append(PlacedSymbol(symbol=node.symbol, x=cx, y=baseline_y, size=size))
        return

    if isinstance(node, GroupNode):
        box = _measure(node, size)
        # Start x = cx - half of total width (centered)
        x = cx - box.width / 2
        for i, child in enumerate(node.children):
            child_box = _measure(child, size)
            child_cx = x + child_box.width / 2
            _place(child, child_cx, baseline_y, size, out)
            x += child_box.width
            # Add spacing after non-last children
            if i < len(node.children) - 1 and isinstance(child, SymbolNode):
                x += _spacing(child.symbol, size)
        return

    if isinstance(node, FractionNode):
        num_size = size * 0.7
        den_size = size * 0.7
        num_box = _measure(node.numerator, num_size)
        den_box = _measure(node.denominator, den_size)
        bar_gap = size * 0.1
        bar_y = baseline_y  # fraction bar at baseline
        # Numerator: centered above bar
        num_baseline = bar_y - bar_gap - num_box.descent
        _place(node.numerator, cx, num_baseline, num_size, out)
        # Fraction bar marker
        out.append(PlacedSymbol(symbol="_frac_bar", x=cx, y=bar_y, size=size))
        # Denominator: centered below bar
        den_baseline = bar_y + bar_gap + den_box.ascent
        _place(node.denominator, cx, den_baseline, den_size, out)
        return

    if isinstance(node, SuperscriptNode):
        base_box = _measure(node.base, size)
        exp_size = size * 0.6
        exp_box = _measure(node.exponent, exp_size)
        # Place base left of center
        total_w = base_box.width + exp_box.width + size * 0.05
        base_cx = cx - total_w / 2 + base_box.width / 2
        _place(node.base, base_cx, baseline_y, size, out)
        # Exponent: upper-right of base, shifted up
        exp_cx = cx - total_w / 2 + base_box.width + size * 0.05 + exp_box.width / 2
        exp_baseline = baseline_y - size * 0.4
        _place(node.exponent, exp_cx, exp_baseline, exp_size, out)
        return

    if isinstance(node, SubscriptNode):
        base_box = _measure(node.base, size)
        sub_size = size * 0.6
        sub_box = _measure(node.subscript, sub_size)
        total_w = base_box.width + sub_box.width + size * 0.05
        base_cx = cx - total_w / 2 + base_box.width / 2
        _place(node.base, base_cx, baseline_y, size, out)
        sub_cx = cx - total_w / 2 + base_box.width + size * 0.05 + sub_box.width / 2
        sub_baseline = baseline_y + size * 0.2
        _place(node.subscript, sub_cx, sub_baseline, sub_size, out)
        return

    if isinstance(node, SqrtNode):
        inner_size = size * 0.9
        inner_box = _measure(node.content, inner_size)
        radical_w = size * 0.4
        box = _measure(node, size)
        # Radical: left side
        radical_cx = cx - box.width / 2 + radical_w / 2
        out.append(PlacedSymbol(symbol="_sqrt", x=radical_cx, y=baseline_y, size=size))
        # Content: right of radical
        content_cx = cx - box.width / 2 + radical_w + size * 0.05 + inner_box.width / 2
        _place(node.content, content_cx, baseline_y, inner_size, out)
        return

    if isinstance(node, ParenNode):
        inner_box = _measure(node.content, size)
        paren_w = size * 0.25
        box = _measure(node, size)
        # Left paren
        left_cx = cx - box.width / 2 + paren_w / 2
        out.append(PlacedSymbol(symbol=node.left, x=left_cx, y=baseline_y, size=size))
        # Content
        content_cx = cx - box.width / 2 + paren_w + size * 0.05 + inner_box.width / 2
        _place(node.content, content_cx, baseline_y, size, out)
        # Right paren
        right_cx = cx + box.width / 2 - paren_w / 2
        out.append(PlacedSymbol(symbol=node.right, x=right_cx, y=baseline_y, size=size))
        return


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def layout(
    tree: Node,
    origin_x: float,
    origin_y: float,
    font_size: float,
) -> list[PlacedSymbol]:
    """Convert a parse tree to a list of positioned symbols.

    The origin marks the start of the baseline. The tree is laid out
    left-to-right starting from origin_x.
    """
    box = _measure(tree, font_size)
    # Place the tree centered at (origin_x + width/2, origin_y)
    cx = origin_x + box.width / 2
    symbols: list[PlacedSymbol] = []
    _place(tree, cx, origin_y, font_size, symbols)
    return symbols
