GrafanaSync.merge_config({
  # Environment name has no special meaning and can be anything you like. You
  # specify it on command-line later on.
  staging: {
    url: "http://robots.staging.usrobotics.com",
    # Grafana dashboards folder to apply commands to.
    folder: "General"
  },

  evil_minded_robots: {
    url: "http://robots.staging.usrobotics.com",
    folder: "Evil-Minded Robots",
    # Exclude dashboards from push by title.
    exclude: ["Kittens Saved", "Grandmas Helped"],
    # Optional datasource mapping. Each datasource name will be replaced on push
    # according to this Hash, other values will be left intact.
    # Note: replacing from/to "default" datasource is not supported.
    datasource_replace: {"robots" => "evil-robots",
                         "robobrains" => "wicked-robobrains"}
  },

  production: {
    url: "http://robots.usrobotics.com",
    folder: "Production"
  }
})
