# GitHub Action to automatically publish to the Factorio mod portal

Builds and publishes tagged releases of a Factorio mod to the Factorio mod portal.

## Usage
Currently, this action expects a flat repo structure with exactly one complete mod in the git repo (with a valid info.json in the repo's root).

It also expects tag names to match the Factorio mod version numbering scheme - three numbers separated by periods, eg. `1.15.0`.

Non-tag pushes will be ignored, but when a tag is pushed that is valid and matches the version number in info.json, the mod will be zipped up and published to the mod portal using the required secrets `FACTORIO_MOD_API_KEY` authenticate.

An example workflow to publish tagged releases:

    on: push
    name: Publish
    jobs:
      publish:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@master
        - name: Publish Mod
          uses: shanemadden/factorio-mod-portal-publish@stable
          env:
            FACTORIO_MOD_API_KEY: ${{ secrets.FACTORIO_MOD_API_KEY }}


The `FACTORIO_MOD_API_KEY` secret should be a valid API key generated with `ModPortal: Upload Mods` usage at https://factorio.com/profile

A valid .gitattributes file is required to filter .git*/* directories. This file must be checked in and tagged to filter during a git-archive operation.

    .gitattributes export-ignore
    .gitignore export-ignore
    .github export-ignore


Be aware that the zip will be published and immediately available for download for users - make sure you're ready to publish the changes and have tested the commit before pushing the tag!
