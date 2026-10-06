<!--
This file is part of Medication Tracker
docs/how-to/update-the-website.md
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: How the documentation website is built from README.md and docs/, which files
         control its look, and how to preview a change before it is published.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Medication Tracker

## How to update the website

[Back to project README](../../README.md)

This page explains the documentation website at
[dev.mongefranco.com/privatium-app-meds](https://dev.mongefranco.com/privatium-app-meds/).
It is for developers. The website is made from the same Markdown files you read on
GitHub, so you update it by changing those files. This page also shows how to change the
website's look and how to preview a change.

### How the site is built

GitHub Pages builds the site with Jekyll, a program that turns Markdown into web pages.
The build follows the same rules GitHub uses to show the files:

- `README.md` becomes the home page, and `docs/README.md` becomes the `docs/` page.
- A link to another `.md` file becomes a link to that file's page, so the relative links
  between pages keep working.
- Pictures and other files are published at the same paths they have in the repository.
- A page needs no front matter, the block of settings that some Markdown files start
  with.

The workflow `.github/workflows/pages.yml` builds the site on every push and pull
request. A pull request only builds it, so a page that breaks the build shows up in
review. A push to `main` builds the site and publishes it.

The site lives under `dev.mongefranco.com` because that is the custom domain of the
owner's GitHub Pages site. GitHub serves each repository's site under its name, so this
repository needs no domain file of its own.

### Files that control the site

| File | What it does |
|---|---|
| `_config.yml` | The site's title, description and address, the Markdown settings, and the files left out of the site. |
| `_layouts/default.html` | The page around each Markdown file: the header and its links, the footer, and the page title. |
| `assets/css/site.css` | The colors, fonts and spacing. They follow the Privatium website, so the two sites match. |
| `assets/js/diagrams.js` | Draws Mermaid diagrams. It loads only on pages that have one. |

Each page's title comes from its first H2 heading, the page subtitle that every
documentation page has. So a new page needs no extra setting.

### Change a page

Edit the Markdown file and open a pull request. When the pull request merges, the site
updates within a few minutes. Keep these rules in mind:

- Link to other pages with relative `.md` links, as the other pages do.
- Never write two opening curly braces in a row, or an opening curly brace followed by a
  percent sign, even in a code block. Jekyll reads them as its own commands, and the page
  breaks or the build fails.
- A Mermaid diagram needs a text description next to it, as on the
  [data model page](../data-model.md). The text is what a screen reader reads.

### Preview a change

The quickest preview is the pull request's own build:

1. Open the pull request's **Checks** tab and choose the **Website** workflow.
2. Download the `github-pages` artifact. It holds a file named `artifact.tar`.
3. Unpack it into a folder named `privatium-app-meds`, inside an empty folder, and serve
   that empty folder:

   ```sh
   mkdir -p site/privatium-app-meds
   tar -xf artifact.tar -C site/privatium-app-meds
   cd site
   python3 -m http.server 8000 --bind 127.0.0.1
   ```

4. Open `http://127.0.0.1:8000/privatium-app-meds/` in your browser.

The extra folder is needed because the site's links start with `/privatium-app-meds/`,
the same as on the real site.

You can also build the site on your own computer. You need Ruby and the `github-pages`
gem, which holds the same Jekyll version and plugins as GitHub. Put a `Gemfile` with the
line `gem "github-pages", group: :jekyll_plugins` in a folder outside the repository, run
`bundle install` there, and then run:

```sh
bundle exec jekyll build --source ~/git/privatium-app-meds --destination site/privatium-app-meds
```

Serve the `site` folder the same way as above.

### Set up GitHub Pages

This is needed once for the repository. In the repository's **Settings**, open
**Pages**. Under **Build and deployment**, set **Source** to **GitHub Actions**. The next
push to `main` publishes the site, or run the **Website** workflow by hand from the
**Actions** tab.

### Conclusion

You can now change a page or the site's look, preview the result, and know when it goes
live.

### Additional resources

- [How to publish a release](publish-a-release.md)
- [Documentation index](../README.md)
- [Data model](../data-model.md), the page with a Mermaid diagram
- [GitHub Pages and Jekyll](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll)
- [Plugins GitHub Pages turns on by default](https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll#plugins)
- [Privatium website](https://dev.mongefranco.com/privatium/), whose look this site follows

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
