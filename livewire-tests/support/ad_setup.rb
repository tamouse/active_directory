require 'active_directory'
require 'active_directory/base'
require 'yaml'

AD_CONFIG = YAML.load(
  ERB.new(
    File.read(File.expand_path("../active_directory.yml", __FILE__))
    ).result
  )

settings = {
    :host => AD_CONFIG["host"],
    :base => AD_CONFIG["base"],
    :port => AD_CONFIG["port"],
    :encryption => :simple_tls,
    :auth => {
        :method => :simple,
        :username => AD_CONFIG["username"],
        :password => AD_CONFIG["password"]
    }
}

ActiveDirectory::Base.setup settings

