class CFPluginPRConfig
  attr_reader :access_token, :author_contact, :author_homepage, :author_name,
    :author, :company, :created_at, :description, :homepage, :name,
    :release_repo

  def initialize
    # TODO: Is this acceptable or should all contributors be included?
    @author_name = 'CF Loggregator'
    @author_contact = 'cf-loggregator@pivotal.io'
    @author_homepage = 'https://github.com/orgs/cloudfoundry/teams/cf-loggregator'

    @access_token = ENV.fetch("GITHUB_ACCESS_TOKEN")
    @company = 'Pivotal'
    @created_at = ENV.fetch("CREATED_AT") # ISO8601 timestamp
    @description = ENV.fetch("DESCRIPTION")
    @homepage = "https://github.com/#{release_repo}"
    @name = ENV.fetch("NAME")
    @release_repo = ENV.fetch("RELEASE_REPO")
  end
end
