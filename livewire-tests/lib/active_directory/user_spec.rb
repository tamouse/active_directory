require_relative '../../spec_helper'
require 'active_directory'
require 'active_directory/user'
require 'support/ad_setup'
require 'securerandom'
require 'pry'

def setup_user
  first_name = "Orlando"
  last_name = "Jones"
  email = "000#{first_name}.#{last_name}@abc.info".downcase
  dn = "CN=#{email},#{AD_CONFIG['base']}"
  user = nil
  create_params = {
    givenname: first_name,
    sn: last_name,
    cn: email
  }

  begin
    records = ActiveDirectory::User.find(:all, :cn => email)
    user = records.first if records
  rescue => e
    STDERR.puts "#{e.class} #{e}"
    raise e
  end

  unless user
    begin
      user = ActiveDirectory::User.create(dn, create_params)
    rescue => e
      STDERR.puts "#{e.class} #{e}"
      raise e
    end
  end
  user
end

RSpec.describe "ActiveDirectory::User" do
  it "responds to #new" do
    expect(ActiveDirectory::User).to respond_to(:new)
  end

  it "responds to .change_password" do
    expect(ActiveDirectory::User.new).to respond_to(:change_password)
  end

  describe "#change_password" do
    it "can change a user's password" do
      user = setup_user

      expect(user).not_to be_nil
      expect(user.class).not_to be_a(FalseClass)

      password = "5a95!e89"
      result = user.change_password(password)
      expect(result).not_to eq(false)

      authenticates = user.authenticate(password)
      expect(authenticates).not_to eq(false)
    end
  end
end
