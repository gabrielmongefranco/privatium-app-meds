<!--
This file is part of Medication Tracker
docs/how-to/publish-a-release.md
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: How to publish a new version of the app, and how the release workflow builds and
         attaches the meds.zip file that families install.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Medication Tracker

## How to publish a release

[Back to project README](../../README.md)

This page shows how to publish a new version of the app. It is for developers. You set
the version, merge it, and publish a GitHub release. A workflow then checks the code and
attaches `meds.zip`, the file families download and unzip into Privatium's `apps` folder.

### What a release holds

Each release has two files that the workflow adds:

| File | What it is |
|---|---|
| `meds.zip` | The `apps/meds` folder and nothing else. Its one top folder is `meds/`, so it unzips straight into Privatium's `apps` folder. It holds only files tracked by git, so no test data or local files get in. |
| `meds.zip.sha256` | The SHA-256 checksum of `meds.zip`, so anyone can check that the download is complete and unchanged. |

GitHub also adds the source code archives, as it does for every release.

The README links to
`https://github.com/gabrielmongefranco/privatium-app-meds/releases/latest/download/meds.zip`.
That address always gives the `meds.zip` of the newest release, so the README never
needs a new link.

### Steps

1. Set the new version in `apps/meds/app.toml`, for example `version = "0.9.0"`. This is
   the only place the version is written.
2. Merge that change into `main`, and wait for the **Lint** check to pass.
3. On GitHub, open **Releases** and choose **Draft a new release**.
4. Create a tag on `main` named after the version, such as `v0.9.0`. A short tag such as
   `v0.9` also works, because missing parts count as zero.
5. Write the release notes. Name the Privatium version the app was tested with, which
   the project README also names.
6. Choose **Publish release**.
7. Open the **Actions** tab and watch the **Release app zip** workflow. When it finishes,
   `meds.zip` and `meds.zip.sha256` appear under the release's assets.

### What the workflow checks

`.github/workflows/release.yml` runs only when a release is published, or when you start
it by hand. Regular pushes and pull requests never build the zip. It does these things in
order, and stops at the first failure:

1. It runs the same lint and tests as the **Lint** workflow, on the tagged code.
2. It compares the tag with the version in `app.toml`. The tag `v0.9.0` matches version
   `0.9.0`, and so do `v0.9` and `0.9.0`.
3. It builds `meds.zip` with `git archive` and writes its checksum.
4. It attaches both files to the release. If they are already there, it replaces them.

### When the workflow fails

- **The tag does not match the version.** The log says which tag and version it found.
  Set the right version in `app.toml` and merge it. Then delete the release and its tag,
  and publish the release again on the new commit.
- **The lint or a test fails.** Fix the problem, merge the fix, and publish the release
  again on the new commit, the same way.
- **Something else failed, such as a network error.** Open **Actions**, choose **Release
  app zip**, then **Run workflow**. Type the release's tag, such as `v0.9.0`, and run it.
  The workflow builds the zip from that tag and attaches it.

### Check a download

On Linux or macOS, put both files in one folder and run:

```sh
sha256sum -c meds.zip.sha256
```

On macOS without `sha256sum`, use `shasum -a 256 -c meds.zip.sha256`. Both print
`meds.zip: OK` when the file is unchanged.

### Conclusion

You can now publish a version of the app that families install by unzipping one file.
The user guide tells families how to move to the new version.

### Additional resources

- [User guide: update to a new version](../usage.md#update-to-a-new-version)
- [How to run the tests](run-the-tests.md)
- [How to update the website](update-the-website.md)
- [Privatium's guide to sharing an app](https://github.com/gabrielmongefranco/privatium/blob/main/docs/app-repository.md#9-share-the-app)
- [GitHub's guide to managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
