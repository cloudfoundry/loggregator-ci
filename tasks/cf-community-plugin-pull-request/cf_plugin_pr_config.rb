class CFPluginPRConfig
  attr_reader :access_token, :author_contact, :author_homepage, :author_name,
    :author, :company, :created_at, :description, :homepage, :name,
    :release_repo

  DESCRIPTIONS = {
    "drains": "A plugin to simplify interactions with user provided syslog drains."
  }

  RELEASE_REPOS = {
    "drains": "cloudfoundry/cf-drain-cli",
  }

  CREATED_ATS = {
    "drains": "2018-04-20T00:00:00Z",
  }

  def initialize
    # TODO: Is this acceptable or should all contributors be included?
    @author_name = 'CF Loggregator Team'

    @access_token = ENV.fetch("GITHUB_ACCESS_TOKEN")
    @company = 'Pivotal'
    @name = ENV.fetch("NAME")
    @created_at = CREATED_ATS.fetch(name.to_sym) # ISO8601 timestamp
    @description = DESCRIPTIONS.fetch(name.to_sym)
    @release_repo = RELEASE_REPOS.fetch(name.to_sym)
    @homepage = "https://github.com/#{release_repo}"
  end
end
