require File.expand_path '../spec_helper.rb', __FILE__

RSpec.describe Polizei do
  it "root should redirect to login" do
    get '/'
    follow_redirect!
    expect(last_request.url).to be_eql('http://example.org/login')
    expect(last_response).to be_ok
  end
end
