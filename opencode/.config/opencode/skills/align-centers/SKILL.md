---
name: align-centers
description: Use when centering or aligning icons, glyphs, controls, rails, bars, toolbars, or repeated UI elements. Ensures visible content shares a true optical centerline regardless of glyph width, side bearings, padding, or asset dimensions.
---

# Align Centers

Treat alignment as a visual requirement, not merely a layout-coordinate requirement.

## Core Preference

- Make the visible center of every repeated icon or control align on one shared centerline.
- Do not assume that centering a widget, text cell, font advance box, SVG view box, or image canvas centers its visible content.
- Preserve the existing layout, order, spacing, sizing, colors, and interactions unless changing them is necessary for alignment.
- Prefer a general alignment rule over manually tuning every icon.

## Workflow

1. Identify the intended horizontal or vertical centerline from the containing rail, bar, row, column, or control group.
2. Verify that every parent container and fixed-size icon slot is geometrically centered on that line.
3. Inspect child content for asymmetric padding, margins, transforms, font side bearings, SVG view boxes, and transparent image pixels.
4. Center the visible bounds of the content, not only its allocated box.
5. Check every dynamic state and icon variant, including hover, active, disabled, connected, muted, charging, and percentage-bearing controls.
6. Keep other orientations unchanged unless the request applies to them too.

## Implementation Guidance

### Font Glyphs

- Put icons in equal-size slots aligned to the shared centerline.
- Use tight rendered glyph bounds when the UI framework exposes them.
- Compensate for unequal side bearings dynamically instead of maintaining per-icon magic offsets.
- For Qt Quick, use `TextMetrics.tightBoundingRect` and `advanceWidth`. If text is centered by its advance width, calculate the optical correction as:

```qml
textMetrics.advanceWidth / 2
    - textMetrics.tightBoundingRect.x
    - textMetrics.tightBoundingRect.width / 2
```

- Apply the correction only to icon glyphs when ordinary text should retain typographic centering.

### Images And SVGs

- Center images in equal-size containers.
- Check for transparent padding or an asymmetric SVG `viewBox`; geometric canvas centering may still look wrong.
- Prefer normalized assets or consistent view boxes over arbitrary per-instance translations.
- Keep intentional asymmetry within the artwork; center its visible bounds unless product design specifies otherwise.

### Repeated Controls

- Use one shared centering mechanism for all controls in a rail or toolbar.
- Ensure narrower, wider, and dynamically changing icons remain centered without special cases.
- Remove inherited or historical offsets that conflict with the shared centering rule.

## Verification

- Confirm all containers resolve to the same center coordinate.
- Confirm visible glyph or image bounds are centered within those containers.
- Exercise dynamic icon variants and controls with secondary labels.
- Validate or reload the UI configuration and check logs for layout or syntax errors.
- Do not claim visual alignment based solely on matching `anchors.centerIn` or `AlignHCenter` declarations.
