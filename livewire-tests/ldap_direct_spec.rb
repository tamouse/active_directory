require 'yaml'
require 'erb'
require 'net/ldap'
require 'iconv'
require 'pry'

AD_CONFIG = YAML.load(
  ERB.new(
    File.read(File.expand_path("../support/active_directory.yml", __FILE__))
    ).result
  )

$settings = {
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

module PasswordEncryption
  extend self

  # From ./lib/active_directory/field_type/password.rb
  #
  # This works.
  def encode_1(password)
    ("\"#{password}\"".split(//).collect { |c| "#{c}\000" }).join
  end

  # From http://blog.bronislavrobenek.com/post/80163028550/changing-password-in-activedirectory-using-ruby
  #
  # This works, and happens to produce the same result as encode_1.
  def encode_2(password)
    ('"' + password + '"').encode("utf-16le").force_encoding("utf-8")
  end

  # From http://stackoverflow.com/questions/16367690/how-to-reset-ldap-user-password-without-old-password-using-the-netldap-gem-or#comment23513903_16367714
  #
  # This does NOT work, although the authors believe it to.
  def encode_3(password)
    Iconv.conv('UTF-16LE', 'UTF-8', (?" + password + ?"))
  end

  # Like encode_3, but forced back to UTF-8
  def encode_4(password)
    encode_3(password).force_encoding('utf-8')
  end
end

def dn(email)
  "CN=#{email},#{$settings[:base]}"
end

def find_by_email(email)
  users = @ldap.search({base: $settings[:base], filter: Net::LDAP::Filter.eq(:cn, email)})
  if users
    users.first
  else
    false
  end
end

def create_user(email)
  attr = {
    sn: "Tam",
    givenname: "River",
    cn: email,
    objectClass: ['top', 'organizationalPerson', 'person', 'user']
  }
  @ldap.add(dn: dn(email), attributes: attr)
end

def find_or_create_by_email(email)
  user = find_by_email(email)
  unless user
    create_user(email)
    user = find_by_email(email)
  end
  user
end

RSpec.describe "Test AD Change password directly with LDAP" do
  let(:email) {"000river.tam@abc.com"}
  let(:password) {"2j4!KKbfTz"}

  it "try old encoding" do
    @ldap = Net::LDAP.new($settings)

    # NOTE: this is the key to fixing the change_password problem!! <tamara.temple@reachlocal.com>
    # So it turns out, that by seeing how to implement ldap directly,
    # the NEXT LINE gave me the solution to the problem in
    # ActiveDirectory::User.change_password. 
    @ldap.bind
    # Without binding the newly minted ldap adapter in
    # .change_password, all the operations would fail as we were
    # seeing them. Yay for testing driven debugging!
    # 
    
    @user = find_or_create_by_email(email)
    ops = [[:replace, :unicodePwd, [ PasswordEncryption.encode_1(password) ]]]
    results = @ldap.modify(dn: dn(email), operations: ops)
    STDERR.puts "After modify: #{@ldap.get_operation_result.inspect}"
    expect(results).not_to eq(false)
    results = @ldap.authenticate(dn(email), password)
    STDERR.puts "After authenticate: #{@ldap.get_operation_result}"
    expect(results).not_to eq(false)
  end

  it "try second encoding" do
    @ldap = Net::LDAP.new($settings)
    @ldap.bind
    @user = find_or_create_by_email(email)
    ops = [[:replace, :unicodePwd, [ PasswordEncryption.encode_2(password) ]]]
    results = @ldap.modify(dn: dn(email), operations: ops)
    STDERR.puts "After modify: #{@ldap.get_operation_result.inspect}"
    expect(results).not_to eq(false)
    results = @ldap.authenticate(dn(email), password)
    STDERR.puts "After authenticate: #{@ldap.get_operation_result}"
    expect(results).not_to eq(false)
  end

  it "try third encoding" do
    @ldap = Net::LDAP.new($settings)
    @ldap.bind
    @user = find_or_create_by_email(email)
    ops = [[:replace, :unicodePwd, [ PasswordEncryption.encode_3(password) ]]]
    results = @ldap.modify(dn: dn(email), operations: ops)
    STDERR.puts "After modify: #{@ldap.get_operation_result.inspect}"
    expect(results).not_to eq(false)
    results = @ldap.authenticate(dn(email), password)
    STDERR.puts "After authenticate: #{@ldap.get_operation_result}"
    expect(results).not_to eq(false)
  end

  it "try fourth encoding" do
    @ldap = Net::LDAP.new($settings)
    @ldap.bind
    @user = find_or_create_by_email(email)
    ops = [[:replace, :unicodePwd, [ PasswordEncryption.encode_4(password) ]]]
    results = @ldap.modify(dn: dn(email), operations: ops)
    STDERR.puts "After modify: #{@ldap.get_operation_result.inspect}"
    expect(results).not_to eq(false)
    results = @ldap.authenticate(dn(email), password)
    STDERR.puts "After authenticate: #{@ldap.get_operation_result}"
    expect(results).not_to eq(false)
  end

  describe "compare encodings" do
    it "encoding 1 same as enconding 2" do
      expect(PasswordEncryption.encode_1(password)).to eq(PasswordEncryption.encode_2(password))
    end

    it "encoding 1 same as encoding 3" do
      expect(PasswordEncryption.encode_1(password)).to eq(PasswordEncryption.encode_3(password))
    end

    it "encoding 1 same as encoding 4" do
      expect(PasswordEncryption.encode_1(password)).to eq(PasswordEncryption.encode_4(password))
    end
  end
end

