<!--
This file is part of Prescription Tracker
README.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-09-26
Summary: Provides an overview of the project, in Markdown format.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.

-->

# Prescription Tracker

## Description
Prescription Tracker is a personal prescription tracker for families with chronic conditions, hosted on your own PC with [Privatium](https://github.com/gabrielmongefranco/privatium).

It is a Privatium app: a folder of Lua, SQL and HTML templates that a Privatium node runs on hardware you control. Your records live as plain text in a folder on your disk, with no account, no cloud, and no database server. Backing up is copying a folder.

This is the app that Privatium was built for. The first version stores a household name and greets with it; the prescription, refill and prior-authorization screens follow. The [documentation](./docs) records each table as it lands.

Tested with Privatium v0.3.

**A note on your data.** Privatium stores every record as plain text by design. Anyone who can read the files on your computer can read what this app stores, so protect the computer and its backups the way you protect any file with health information in it. [Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md) explains what the design does and does not protect.


## Quick Start Guide
1. Install Privatium. Download the release for your platform from the [Privatium README](https://github.com/gabrielmongefranco/privatium#quick-start-guide) and run it once so it creates its data directory. Every start prints that directory on a line beginning `privatium: data in`.
2. Clone this repository and link the app folder into the `apps/` folder of that data directory, using the slug `meds` as the link's name:

   ```sh
   git clone https://github.com/gabrielmongefranco/privatium-app-meds.git ~/git/privatium-app-meds
   ln -s ~/git/privatium-app-meds/apps/meds ~/.local/share/privatium/apps/meds
   ```

   On Windows without permission to create symbolic links, copy the folder instead.
3. Run it:

   ```sh
   privatium dev --app meds
   ```

   The command prints the app's URL. Save a file, refresh the browser, and the change is there.

Before you commit a change, lint from the repository root with `privatium lint apps/meds`.

Installing an app from a stranger deserves the same thought as running a script someone emailed you: a Privatium app's Lua runs on your node against your data. Read the code, or have someone you trust read it, before you install an app you did not write.


## Documentation
+ **Complete documentation:** See the [`/docs`](./docs) folder in this repository for the data model, setup notes and technical details.
+ [`apps/meds/README.md`](apps/meds/README.md) describes the app folder itself.
+ [`SKILLS.md`](SKILLS.md) lists the guides an AI assistant reads before changing this repository, including the Privatium guides pinned to the version above.


## Additional Resources
+ [Privatium](https://github.com/gabrielmongefranco/privatium): the framework this app runs on.
+ [Your app in its own repository](https://github.com/gabrielmongefranco/privatium/blob/main/docs/app-repository.md): the guide this repository follows.



## About the Author

Prescription Tracker is built by [Gabriel Mongefranco](https://gabriel.mongefranco.com), a database and
software architect who has spent two decades building data platforms in healthcare and
research — enterprise data warehouses, BI systems, knowledge bases, and the first architecture for mobile and
wearable research data at a large research university.

Learn more at: [Gabriel Mongefranco's website](https://gabriel.mongefranco.com).


## Contact

Questions, bug reports, enhancement ideas and requests are welcome as GitHub issues. Feel
free to send pull requests as well!



## Credits
### Authors:
+ [Gabriel Mongefranco](https://gabriel.mongefranco.com) [(@gabrielmongefranco)](https://github.com/gabrielmongefranco)


#### This work is based in part on the following projects, libraries and/or studies:
+ Privatium: the local-first framework that stores, syncs and serves this app. This repository is an app folder that a Privatium node runs, and the `skills/privatium-*` folders are the assistant guides that Privatium exports. License: GPL-3.0-or-later. https://github.com/gabrielmongefranco/privatium



## License
### Copyright Notice
Copyright © 2026 Gabriel Mongefranco


### Software and Library License Notice
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.


### Documentation License Notice
Permission is granted to copy, distribute and/or modify this document 
under the terms of the GNU Free Documentation License, Version 1.3 
or any later version published by the Free Software Foundation; 
with no Invariant Sections, no Front-Cover Texts, and no Back-Cover Texts. 
You should have received a copy of the license included in the section entitled "GNU 
Free Documentation License". If not, see <https://www.gnu.org/licenses/fdl-1.3-standalone.html>



## Citation
If you find this repository, code or paper useful for your research, please cite it.

#### Citation Example:
>_Mongefranco, Gabriel (2026). Prescription Tracker. Software. https://github.com/gabrielmongefranco/privatium-app-meds_


----

Copyright © 2026 Gabriel Mongefranco
