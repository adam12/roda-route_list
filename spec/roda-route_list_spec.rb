require 'roda'
require 'json'

if defined?(RSpec)
  require 'rspec/version'
  if RSpec::Version::STRING >= '2.11.0'
    RSpec.configure do |config|
      config.expect_with :rspec do |c|
        c.syntax = :should
      end
    end
  end
end

describe 'roda-route_list plugin' do
  def req(path='/', env={})
    if path.is_a?(Hash)
      env = path
    else
      env['PATH_INFO'] = path
    end

    env = {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/", "SCRIPT_NAME" => ""}.merge(env)
    @app.call(env)
  end
  
  def body(path='/', env={})
    s = ''
    b = req(path, env)[2]
    b.each{|x| s << x}
    b.close if b.respond_to?(:close)
    s
  end

  before do 
    @app = Class.new(Roda)
    @app.plugin :route_list
    @app.load_routes 'spec/routes.json'
    @app.route do |r|
      @app.named_route(r.remaining_path.to_sym)
    end
    @app
  end

  it "should correctly parse the routes from the json file" do
    @app.route_list.should == [
      {:path=>'/foo'},
      {:path=>'/foo/bar', :name=>:bar},
      {:path=>'/foo/baz', :methods=>[:GET]},
      {:path=>'/foo/baz/quux/:quux_id', :name=>:quux, :methods=>[:GET, :POST]},
    ]
  end

  it ".named_route should return path for route" do
    @app.named_route(:bar).should == '/foo/bar'
    @app.named_route(:quux).should == '/foo/baz/quux/:quux_id'
  end

  it ".named_route should return path for route when given a values hash" do
    @app.named_route(:quux, :quux_id=>3).should == '/foo/baz/quux/3'
  end

  it ".named_route should return path for route when given a values array" do
    @app.named_route(:quux, [3]).should == '/foo/baz/quux/3'
  end

  it ".named_route should raise RodaError if there is no matching route" do
    proc{@app.named_route(:foo)}.should raise_error(Roda::RodaError)
  end

  it ".named_route should raise RodaError if there is no matching value when using a values hash" do
    proc{@app.named_route(:quux, {})}.should raise_error(Roda::RodaError)
  end

  it ".named_route should raise RodaError if there is no matching value when using a values array" do
    proc{@app.named_route(:quux, [])}.should raise_error(Roda::RodaError)
  end

  it ".named_route should raise RodaError if there are too many values when using a values array" do
    proc{@app.named_route(:quux, [3, 1])}.should raise_error(Roda::RodaError)
  end

  it "should allow parsing routes from a separate file" do
    @app.load_routes('spec/routes2.json')
    @app.route_list.should == [{:path=>'/foo'}]
  end
end

describe 'roda-route_parser executable' do
  after do
    File.delete "spec/routes-example.json"
  end

  it "should correctly parse the routes" do
    system(ENV['RUBY'], "bin/roda-parse_routes", "-f", "spec/routes-example.json", "spec/routes.example")
    File.file?("spec/routes-example.json").should == true
    JSON.parse(File.read('spec/routes-example.json')).should == JSON.parse(File.read('spec/routes.json'))
  end
end
