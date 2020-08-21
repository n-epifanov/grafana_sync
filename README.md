# Grafana Sync

Syncs dashboards between Grafana instances. Lifts the burden of migrating
changes between environment instances by hand. Unleashes the power of Linux
command-line tools on Grafana config files.

Tested against Grafana 6.

## Installation and Usage

Suggested workflow is:
- for each separately deployed project create a repo based off of a `sample_repo`
and head to it
    ```
    cp sample_repo ../mars_shuttle
    cd ../mars_shuttle
    ```
- install GrafanaSync locally (with e.g. [asdf](https://github.com/asdf-vm/asdf))
    ```
    asdf install
    gem install bundler -v 2.1.4
    bundle
    ```
    or globally
    ```
    gem install grafana_sync
    ```
- adjust `config.rb` to suit your needs. For each environment there has to be
specified Grafana URL and Grafana folder. One environment (say "staging") is
tweaked manually through Grafana web-interface, optionally stored in a VCS and
then deployed to other environments (say "production").
- tweak manually staging Grafana through web-interface to fit your needs
- fetch staging Grafana configs
    ```
    grafync staging pull
    ```
- optionally review changes and commit
- see what are the changes to be applied to production
    ```
    grafync production diff
    ```
    same with paging
    ```
    grafync production diff | less -R
    ```
- apply Grafana configs to production
    ```
    grafync production push
    ```
