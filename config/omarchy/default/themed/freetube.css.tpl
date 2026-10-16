/* Omarchy palette for FreeTube.
 *
 * omarchy-theme-set-freetube copies this to ~/.config/FreeTube/omarchy.css,
 * which the patched FreeTube (patches/freetube-omarchy-theme.patch) inserts
 * into every window. FreeTube's base, main and secondary colour pickers each
 * set these variables through a class on <body>; !important wins over all of
 * them, so the palette holds whichever the settings page has selected.
 */

body {
    --primary-text-color: {{ foreground }} !important;
    --secondary-text-color: {{ mix foreground background 15% }} !important;
    --tertiary-text-color: {{ mix foreground background 40% }} !important;
    --title-color: {{ bright_foreground }} !important;
    --favorite-icon-color: {{ green }} !important;

    --bg-color: {{ background }} !important;
    --card-bg-color: {{ dark_background }} !important;
    --secondary-card-bg-color: {{ background }} !important;
    --search-bar-color: {{ lighter_background }} !important;
    --side-nav-color: {{ dark_background }} !important;
    --side-nav-hover-color: {{ lighter_background }} !important;
    --side-nav-active-color: {{ selection }} !important;
    --scrollbar-color: {{ lighter_background }} !important;
    --scrollbar-color-hover: {{ selection }} !important;

    /* Main colour: top bar buttons, toggles, primary actions. */
    --primary-color: {{ accent }} !important;
    --primary-color-hover: {{ mix accent foreground 15% }} !important;
    --primary-color-active: {{ mix accent background 20% }} !important;
    --text-with-main-color: {{ background }} !important;

    /* Secondary colour: links, sliders, the player's progress bar. FreeTube
       builds the translucent steps from a space-separated triple the template
       cannot emit, so they are set directly. The comma form of *_rgb still
       suits the plain rgb() it is used in elsewhere. */
    --accent-color-rgb: {{ accent_rgb }} !important;
    --accent-color: {{ accent }} !important;
    --accent-color-hover: {{ mix accent foreground 15% }} !important;
    --accent-color-active: {{ mix accent background 20% }} !important;
    --accent-color-light: {{ mix accent foreground 40% }} !important;
    --accent-color-visited: {{ mix accent background 35% }} !important;
    --accent-color-opacity1: rgb(from {{ accent }} r g b / 4%) !important;
    --accent-color-opacity2: rgb(from {{ accent }} r g b / 12%) !important;
    --accent-color-opacity3: rgb(from {{ accent }} r g b / 16%) !important;
    --accent-color-opacity4: rgb(from {{ accent }} r g b / 24%) !important;
    --text-with-accent-color: {{ background }} !important;
}
