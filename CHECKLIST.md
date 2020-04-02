# Release checklist

A checklist for pre-release, release and post-release procedures. Not necessarily to be followed step-by-step, but please consult this checklist for every release and make sure that if a step is skipped, there was a _really_ good reason for it. Some of the steps might seem obvious, but they should be documented for people who might've fallen out of context for one reason or other. Everything about the release should be crystal clear for everyone in the team.

The right thing to do would be copying this list into our discussions for every release and update it when the steps are done, so that everyone could see the progress and comment on it in one place.

## 1. Organizational procedure

- [ ] Create a release discussion or announce to everyone in any other way: make it clear what features will make it into the release.
- [ ] Agree on the release timeline.
- [ ] Agree on the community announcement/outreach plan (@epowell101 has to validate).
- [ ] Assign release owners.

## 2. Features

A list of planned features—different for every release, of course–should follow. Cross the features out only after they're reviewed and merged into master.

## 3. Pre-release procedure

- [ ] Test every feature manually in CentOS/RHEL 6.
- [ ] Test every feature manually in CentOS/RHEL 7.
- [ ] Test every feature manually in Ubuntu 16.
- [ ] Test every feature manually in Ubuntu 18.
- [ ] Ask someone else to test every feature manually in CentOS/RHEL 6.
- [ ] Ask someone else to test every feature manually in CentOS/RHEL 7.
- [ ] Ask someone else to test every feature manually in Ubuntu 16.
- [ ] Ask someone else to test every feature manually in Ubuntu 18.
- [ ] If something failed, fix and repeat from the beginning.
- [ ] If something failed and can't be fixed, write it down, make it a priority for the next patch release, get a KB article out.
- [ ] Make sure that change logs are up to date.
- [ ] Make sure that documentation at `docs.stackstorm.com` is up to date; if there's a specific migration/upgrade procedure, describe it in the ["Upgrade Notes" section](https://docs.stackstorm.com/upgrade_notes.html).

## 4. Release machinery

Valid for minor releases. For patches see [RELEASE_HOWTO.md](https://github.com/StackStorm/st2cd/blob/master/RELEASE_HOWTO.md).

- [ ] Make sure the build box (st2build002 at the time of writing) is working correctly.
- [ ] Note whether Mistral has a new version branch: you'll need it for st2workroom later.
- [ ] Launch `st2cd.prepare-for-release` workflow: `st2_release_version` has to have a patch (e.g. `1.2.0`), `st2_base_url` should __not__ be `localhost` (e.g. `http://st2build002:9101/v1/`).
- [ ] Change the dev version in [st2web/package.json](https://github.com/StackStorm/st2web/blob/master/package.json#L4): e.g. if `1.2.0` is released then `1.3dev` should be in the file.
- [ ] Change the dev version in [st2client](https://github.com/StackStorm/st2/blob/master/st2client/st2client/__init__.py) and [st2common](https://github.com/StackStorm/st2/blob/master/st2common/st2common/__init__.py): same rules as in the previous step apply.
- [ ] Change the dev version in [st2docs/version.txt](https://github.com/StackStorm/st2docs/blob/master/version.txt#L1): e.g. if `1.3.0` is released then `1.4dev` should be in the file.
- [ ] Add new version in [st2docs/docs/source/conf.py](https://github.com/StackStorm/st2docs/blob/master/docs/source/conf.py#L79) e.g. if `1.3.0` is release then `1.3` should be added to the list.
- [ ] Set the version values in the KV store of the build box:
```
st2 key set st2_stable_version 1.2
st2 key set st2_unstable_version 1.3dev
st2 key set st2_master_build_number 1
```
- [ ] Make sure packaging is completed for st2web, st2flow, Mistral, and st2 itself (x4: Ubuntu 16.04, Ubuntu 18.04, RHEL6, RHEL7).
- [ ] Make sure `pytests` are passing and no sudden upstream issues happened (hi, oslo.utils!).
- [ ] Create a temporary version tag say v1.3.0 if releasing v1.3.0 so that st2workroom_test passes. Also, remove tag before finalize.
- [ ] Run `st2cd.package-publish-release` to push the packages to the download server and finalize the release.
- [ ] Start flow packages manually for released and new dev builds. `st2 run st2cd.flow_pkg branch=master dl_server=dl-origin001.uswest2.stackstorm.net version=1.3.0` and `st2 run st2cd.flow_pkg branch=master dl_server=dl-origin001.uswest2.stackstorm.net version=1.4dev` if released version was `1.3.0`.
- [ ] This may also be a good time to run entreprise ldap packaging. `st2 run st2cd.st2_auth_ldap_pkg_enterprise` - note that the command simply overwrites old build but this is likely a problem for future us :)
- [ ] Make sure your new version is now on [the download server](http://downloads.stackstorm.net/releases/st2/).

## 5. Getting the release out

- [ ] Get some rest, grab a cup of coffee, meditate, listen to delightful music, hug someone. Calm down. The next step is going to be very exciting.
- [ ] Change the version in [st2workroom](https://github.com/StackStorm/st2workroom/blob/ef992a96b721a6c5bf225991749ef52d86ccec1a/hieradata/role/st2.yaml#L8-L11). __This is the point where people start getting your release by default. That's it. It's done.__
- [ ] Announce to the team that the code is out, bathe in fame and glory.
- [ ] Test every feature manually in Ubuntu 16.
- [ ] Test every feature manually in Ubuntu 18.
- [ ] Test every feature manually in CentOS/RHEL 6.
- [ ] Test every feature manually in CentOS/RHEL 7.
- [ ] Ask someone else to test every feature manually in Ubuntu 16.
- [ ] Ask someone else to test every feature manually in Ubuntu 18.
- [ ] Ask someone else to test every feature manually in CentOS/RHEL 6.
- [ ] Ask someone else to test every feature manually in CentOS/RHEL 7.
- [ ] If something failed, fix and repeat from the beginning (I know, I know).
- [ ] If something failed and can't be fixed, write it down, make it a priority for the next patch release, get a KB article out.

## 6. Post-release procedure

- [ ] Announce to the community using `@here` or `@channel` (`@channel` might wake someone up, but some people—wink-wink, DZ–still don't shy away from using it).
- [ ] Get a blog post / multiple blog posts out according to the plan.
- [ ] Send an announcement e-mail, execute the rest of the outreach plan—whatever it is.
- [ ] Watch the community: if more than two people encounter the same issue when installing or upgrading, it's already worth creating a KB article about.
