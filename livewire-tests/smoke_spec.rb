require_relative 'spec_helper'
require 'active_directory'

RSpec.describe "smoke test" do
  it "loads active_directory" do
    expect{ActiveDirectory}.not_to raise_error
  end
end
