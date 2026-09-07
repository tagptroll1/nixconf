/* Omarchy palette for the vendored midnight Discord theme.
 *
 * omarchy-theme-set-vesktop concatenates vendor/midnight-discord/midnight.css
 * with this file into ~/.config/vesktop/themes/omarchy.css, so these variables
 * land after the ones midnight ships and win. Only the base ramps and the
 * bg/text scales are set: midnight derives accents, statuses and borders from
 * them, so its own semantics stay intact.
 */

body {
    /* Bundled font would be a Google Fonts request on every launch. */
    --font: '';
    --code-font: '';
    /* Its icon is fetched from refact0r.github.io. */
    --custom-dms-icon: off;
}

:root {
    --colors: on;

    /* Text, lightest to most muted. Mixing toward the background is what
       makes a channel name read as quieter than a message. */
    --text-1: {{ bright_foreground }};
    --text-2: {{ foreground }};
    --text-3: {{ mix foreground background 20% }};
    --text-4: {{ mix foreground background 45% }};
    --text-5: {{ mix foreground background 65% }};

    /* Backgrounds, darkest last: --bg-4 is the main surface, and each step up
       lifts a panel or button off it. */
    --bg-1: {{ mix background foreground 18% }};
    --bg-2: {{ mix background foreground 12% }};
    --bg-3: {{ mix background foreground 6% }};
    --bg-4: {{ background }};

    --offline: {{ muted }};

    /* Base ramps, light to dark. midnight points --accent-* at the blue ramp
       and each status colour at a *-2, so setting these retints everything. */
    --red-1: {{ mix red foreground 30% }};
    --red-2: {{ mix red foreground 15% }};
    --red-3: {{ red }};
    --red-4: {{ mix red background 15% }};
    --red-5: {{ mix red background 30% }};

    --green-1: {{ mix green foreground 30% }};
    --green-2: {{ mix green foreground 15% }};
    --green-3: {{ green }};
    --green-4: {{ mix green background 15% }};
    --green-5: {{ mix green background 30% }};

    --blue-1: {{ mix blue foreground 30% }};
    --blue-2: {{ mix blue foreground 15% }};
    --blue-3: {{ blue }};
    --blue-4: {{ mix blue background 15% }};
    --blue-5: {{ mix blue background 30% }};

    --yellow-1: {{ mix yellow foreground 30% }};
    --yellow-2: {{ mix yellow foreground 15% }};
    --yellow-3: {{ yellow }};
    --yellow-4: {{ mix yellow background 15% }};
    --yellow-5: {{ mix yellow background 30% }};

    --purple-1: {{ mix purple foreground 30% }};
    --purple-2: {{ mix purple foreground 15% }};
    --purple-3: {{ purple }};
    --purple-4: {{ mix purple background 15% }};
    --purple-5: {{ mix purple background 30% }};
}
