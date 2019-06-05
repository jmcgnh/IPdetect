# IPdetect
fork of Sourceforge IPdetect project by koshmar - https://sourceforge.net/projects/ipdetect/

## What's changed?
I ran into a few difficulties getting the original script to run properly on Raspian. The changes are small, but I created this repo so I can record my changes, have them available for me (or anyone else) to download.

## Going dormant
I grew increasingly disappointed in trying to use this script, mainly because it tries to be clever but is a bit hopeless about DNS propagation delays. Far simpler, for me, was to run the update operation on a periodic basis (4-minute interval) with a single /etc/cron.d entry. I don't know when, or if, I'll be returning to do more work on this repo.
