# COSMIC (libcosmic) theme, rendered per Omarchy theme and split into one file
# per key by omarchy-theme-set-cosmic. Sections are `### <cosmic-config key>`.
#
# Every surface is the theme background mixed toward its foreground, so the
# elevation ramp comes out right in light and dark themes alike; the alpha byte
# on each color and the mix percentages follow the defaults libcosmic ships
# (cosmic-fallback-themes). Keys left out here -- spacing, corner_radii, gaps,
# alpha_map, frosted*, shade, hints -- are layout, not palette, and cosmic-config
# falls back to its own default per missing key.

### background
(
    base: "{{ background }}FF",
    component: (
        base: "{{ mix background foreground 8% }}FF",
        hover: "{{ mix background foreground 16% }}FF",
        pressed: "{{ mix background foreground 24% }}FF",
        selected: "{{ mix background foreground 16% }}FF",
        selected_text: "{{ accent }}FF",
        focus: "{{ accent }}FF",
        divider: "{{ foreground }}33",
        on: "{{ foreground }}FF",
        disabled: "{{ mix background foreground 8% }}80",
        on_disabled: "{{ foreground }}A6",
        border: "{{ mix background foreground 75% }}FF",
        disabled_border: "{{ mix background foreground 75% }}80",
    ),
    divider: "{{ mix background foreground 13% }}FF",
    on: "{{ foreground }}FF",
    small_widget: "{{ mix background foreground 5% }}40",
)

### primary
(
    base: "{{ mix background foreground 5% }}FF",
    component: (
        base: "{{ mix background foreground 13% }}FF",
        hover: "{{ mix background foreground 21% }}FF",
        pressed: "{{ mix background foreground 29% }}FF",
        selected: "{{ mix background foreground 21% }}FF",
        selected_text: "{{ accent }}FF",
        focus: "{{ accent }}FF",
        divider: "{{ foreground }}33",
        on: "{{ foreground }}FF",
        disabled: "{{ mix background foreground 13% }}80",
        on_disabled: "{{ foreground }}A6",
        border: "{{ mix background foreground 75% }}FF",
        disabled_border: "{{ mix background foreground 75% }}80",
    ),
    divider: "{{ mix background foreground 18% }}FF",
    on: "{{ foreground }}FF",
    small_widget: "{{ mix background foreground 10% }}40",
)

### secondary
(
    base: "{{ mix background foreground 10% }}FF",
    component: (
        base: "{{ mix background foreground 18% }}FF",
        hover: "{{ mix background foreground 26% }}FF",
        pressed: "{{ mix background foreground 34% }}FF",
        selected: "{{ mix background foreground 26% }}FF",
        selected_text: "{{ accent }}FF",
        focus: "{{ accent }}FF",
        divider: "{{ foreground }}33",
        on: "{{ foreground }}FF",
        disabled: "{{ mix background foreground 18% }}80",
        on_disabled: "{{ foreground }}A6",
        border: "{{ mix background foreground 75% }}FF",
        disabled_border: "{{ mix background foreground 75% }}80",
    ),
    divider: "{{ mix background foreground 23% }}FF",
    on: "{{ foreground }}FF",
    small_widget: "{{ mix background foreground 15% }}40",
)

### transparent_background
(
    base: "{{ background }}99",
    component: (
        base: "{{ mix background foreground 8% }}99",
        hover: "{{ mix background foreground 16% }}99",
        pressed: "{{ mix background foreground 24% }}99",
        selected: "{{ mix background foreground 16% }}99",
        selected_text: "{{ accent }}FF",
        focus: "{{ accent }}FF",
        divider: "{{ foreground }}33",
        on: "{{ foreground }}99",
        disabled: "{{ mix background foreground 8% }}4C",
        on_disabled: "{{ foreground }}A6",
        border: "{{ mix background foreground 75% }}FF",
        disabled_border: "{{ mix background foreground 75% }}80",
    ),
    divider: "{{ mix background foreground 13% }}AD",
    on: "{{ foreground }}99",
    small_widget: "{{ mix background foreground 5% }}40",
)

### transparent_primary
(
    base: "{{ mix background foreground 5% }}99",
    component: (
        base: "{{ mix background foreground 13% }}99",
        hover: "{{ mix background foreground 21% }}99",
        pressed: "{{ mix background foreground 29% }}99",
        selected: "{{ mix background foreground 21% }}99",
        selected_text: "{{ accent }}FF",
        focus: "{{ accent }}FF",
        divider: "{{ foreground }}33",
        on: "{{ foreground }}99",
        disabled: "{{ mix background foreground 13% }}4C",
        on_disabled: "{{ foreground }}A6",
        border: "{{ mix background foreground 75% }}FF",
        disabled_border: "{{ mix background foreground 75% }}80",
    ),
    divider: "{{ mix background foreground 18% }}AD",
    on: "{{ foreground }}99",
    small_widget: "{{ mix background foreground 10% }}40",
)

### transparent_secondary
(
    base: "{{ mix background foreground 10% }}99",
    component: (
        base: "{{ mix background foreground 18% }}99",
        hover: "{{ mix background foreground 26% }}99",
        pressed: "{{ mix background foreground 34% }}99",
        selected: "{{ mix background foreground 26% }}99",
        selected_text: "{{ accent }}FF",
        focus: "{{ accent }}FF",
        divider: "{{ foreground }}33",
        on: "{{ foreground }}99",
        disabled: "{{ mix background foreground 18% }}4C",
        on_disabled: "{{ foreground }}A6",
        border: "{{ mix background foreground 75% }}FF",
        disabled_border: "{{ mix background foreground 75% }}80",
    ),
    divider: "{{ mix background foreground 23% }}AD",
    on: "{{ foreground }}99",
    small_widget: "{{ mix background foreground 15% }}40",
)

### accent
(
    base: "{{ accent }}FF",
    hover: "{{ mix accent background 12% }}FF",
    pressed: "{{ mix accent background 30% }}FF",
    selected: "{{ mix accent background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ accent }}FF",
    on_disabled: "{{ mix background accent 50% }}FF",
    border: "{{ accent }}FF",
    disabled_border: "{{ accent }}80",
)

### accent_button
(
    base: "{{ accent }}FF",
    hover: "{{ mix accent background 12% }}FF",
    pressed: "{{ mix accent background 30% }}FF",
    selected: "{{ mix accent background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ accent }}FF",
    on_disabled: "{{ mix background accent 50% }}FF",
    border: "{{ accent }}FF",
    disabled_border: "{{ accent }}80",
)

### destructive
(
    base: "{{ red }}FF",
    hover: "{{ mix red background 12% }}FF",
    pressed: "{{ mix red background 30% }}FF",
    selected: "{{ mix red background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ red }}FF",
    on_disabled: "{{ mix background red 50% }}FF",
    border: "{{ red }}FF",
    disabled_border: "{{ red }}80",
)

### destructive_button
(
    base: "{{ red }}FF",
    hover: "{{ mix red background 12% }}FF",
    pressed: "{{ mix red background 30% }}FF",
    selected: "{{ mix red background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ red }}FF",
    on_disabled: "{{ mix background red 50% }}FF",
    border: "{{ red }}FF",
    disabled_border: "{{ red }}80",
)

### success
(
    base: "{{ green }}FF",
    hover: "{{ mix green background 12% }}FF",
    pressed: "{{ mix green background 30% }}FF",
    selected: "{{ mix green background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ green }}FF",
    on_disabled: "{{ mix background green 50% }}FF",
    border: "{{ green }}FF",
    disabled_border: "{{ green }}80",
)

### success_button
(
    base: "{{ green }}FF",
    hover: "{{ mix green background 12% }}FF",
    pressed: "{{ mix green background 30% }}FF",
    selected: "{{ mix green background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ green }}FF",
    on_disabled: "{{ mix background green 50% }}FF",
    border: "{{ green }}FF",
    disabled_border: "{{ green }}80",
)

### warning
(
    base: "{{ yellow }}FF",
    hover: "{{ mix yellow background 12% }}FF",
    pressed: "{{ mix yellow background 30% }}FF",
    selected: "{{ mix yellow background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ yellow }}FF",
    on_disabled: "{{ mix background yellow 50% }}FF",
    border: "{{ yellow }}FF",
    disabled_border: "{{ yellow }}80",
)

### warning_button
(
    base: "{{ yellow }}FF",
    hover: "{{ mix yellow background 12% }}FF",
    pressed: "{{ mix yellow background 30% }}FF",
    selected: "{{ mix yellow background 12% }}FF",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ background }}FF",
    on: "{{ background }}FF",
    disabled: "{{ yellow }}FF",
    on_disabled: "{{ mix background yellow 50% }}FF",
    border: "{{ yellow }}FF",
    disabled_border: "{{ yellow }}80",
)

### button
(
    base: "{{ mix background foreground 62% }}40",
    hover: "{{ mix background foreground 39% }}66",
    pressed: "{{ mix background foreground 25% }}9F",
    selected: "{{ mix background foreground 39% }}66",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ foreground }}33",
    on: "{{ foreground }}FF",
    disabled: "{{ mix background foreground 62% }}20",
    on_disabled: "{{ foreground }}A6",
    border: "{{ mix background foreground 75% }}FF",
    disabled_border: "{{ mix background foreground 75% }}80",
)

### icon_button
(
    base: "{{ background }}00",
    hover: "{{ mix background foreground 39% }}33",
    pressed: "{{ mix background foreground 20% }}80",
    selected: "{{ mix background foreground 39% }}33",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ foreground }}33",
    on: "{{ foreground }}FF",
    disabled: "{{ background }}00",
    on_disabled: "{{ foreground }}A6",
    border: "{{ mix background foreground 75% }}FF",
    disabled_border: "{{ mix background foreground 75% }}80",
)

### text_button
(
    base: "{{ background }}00",
    hover: "{{ mix background foreground 39% }}33",
    pressed: "{{ mix background foreground 20% }}80",
    selected: "{{ mix background foreground 39% }}33",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ accent }}33",
    on: "{{ accent }}FF",
    disabled: "{{ background }}00",
    on_disabled: "{{ accent }}A6",
    border: "{{ mix background foreground 75% }}FF",
    disabled_border: "{{ mix background foreground 75% }}80",
)

### link_button
(
    base: "{{ background }}00",
    hover: "{{ mix background foreground 39% }}33",
    pressed: "{{ mix background foreground 20% }}80",
    selected: "{{ mix background foreground 39% }}33",
    selected_text: "{{ accent }}FF",
    focus: "{{ accent }}FF",
    divider: "{{ accent }}33",
    on: "{{ accent }}FF",
    disabled: "{{ background }}00",
    on_disabled: "{{ accent }}A6",
    border: "{{ mix background foreground 75% }}FF",
    disabled_border: "{{ mix background foreground 75% }}80",
)

### accent_text
Some("{{ accent }}FF")

### palette
(
    name: "omarchy",
    bright_red: "{{ bright_red }}FF",
    bright_green: "{{ bright_green }}FF",
    bright_orange: "{{ orange }}FF",
    gray_1: "{{ background }}FF",
    gray_2: "{{ mix background foreground 5% }}FF",
    neutral_0: "{{ darker_background }}FF",
    neutral_1: "{{ dark_background }}FF",
    neutral_2: "{{ background }}FF",
    neutral_3: "{{ mix background foreground 10% }}FF",
    neutral_4: "{{ mix background foreground 20% }}FF",
    neutral_5: "{{ mix background foreground 30% }}FF",
    neutral_6: "{{ mix background foreground 40% }}FF",
    neutral_7: "{{ mix background foreground 55% }}FF",
    neutral_8: "{{ mix background foreground 70% }}FF",
    neutral_9: "{{ mix background foreground 85% }}FF",
    neutral_10: "{{ bright_foreground }}FF",
    accent_blue: "{{ blue }}FF",
    accent_indigo: "{{ bright_blue }}FF",
    accent_purple: "{{ magenta }}FF",
    accent_pink: "{{ bright_magenta }}FF",
    accent_red: "{{ red }}FF",
    accent_orange: "{{ orange }}FF",
    accent_yellow: "{{ yellow }}FF",
    accent_green: "{{ green }}FF",
    accent_warm_grey: "{{ muted }}FF",
    ext_warm_grey: "{{ dark_foreground }}FF",
    ext_orange: "{{ orange }}FF",
    ext_yellow: "{{ bright_yellow }}FF",
    ext_blue: "{{ cyan }}FF",
    ext_purple: "{{ bright_magenta }}FF",
    ext_pink: "{{ magenta }}FF",
    ext_indigo: "{{ bright_cyan }}FF",
)
