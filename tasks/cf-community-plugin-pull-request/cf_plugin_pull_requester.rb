
require 'octokit'
require 'openssl'
require 'typhoeus'
require_relative './cf_plugin_pr_config'

class CFPluginPullRequester
  def initialize(cfg)
    @config = cfg
  end

  def manifest
    rel = newest_release

    {
      authors: [
        {
          name: config.author_name,
        }
      ],
      binaries: manifest_binaries(rel.assets),
      company: config.company,
      created: config.created_at,
      description: config.description,
      homepage: config.homepage,
      name: config.name,
      updated: rel.published_at.iso8601,
      version: rel.tag_name.tr('v', ''),
    }
  end

  private

  attr_reader :config

  def newest_release
    if @newest_release
      return @newest_release
    end

    @newest_release = client.releases(config.release_repo).map do |r|
      Release.new(r)
    end.first
  end

  def manifest_binaries(assets)
    assets.map do |a|
      {
        checksum: a.checksum,
        platform: a.platform,
        url: a.download_url
      }
    end
  end

  def client
    if @client
      return @client
    end

    @client = Octokit::Client.new(access_token: config.access_token)
  end
end

class Release
  attr_reader :published_at, :tag_name, :name, :assets

  def initialize(rel)
    @published_at = rel[:published_at]
    @tag_name = rel[:tag_name]
    @name = rel[:name]
    @assets = rel[:assets].map { |a| Asset.new(a) }.select(&:is_plugin?)
  end
end

class Asset
  PLATFORMS = {
    "darwin" => "osx",
    "windows" => "win64",
    "linux" => "linux64",
  }.freeze

  attr_reader :name, :download_url

  def initialize(asset)
    @name = asset[:name]
    @download_url = asset[:browser_download_url]
  end

  def platform
    PLATFORMS[name.split("-").last]
  end

  def is_plugin?
    name.end_with?(*PLATFORMS.keys)
  end

  def checksum
    if @checksum
      return @checksum
    end

    resp = Typhoeus.get(download_url, followlocation: true)
    Digest::SHA1.hexdigest(resp.body)
  end
end
