require 'nokogiri'
require 'open-uri'
require 'sinatra'
require 'json'

SERVER_URL = 'http://54.194.156.79:8153/go/cctray.xml'
USER = "admin"
PASS = "PASSWORD"

get '/' do
  @doc = Nokogiri::XML(open(SERVER_URL, :http_basic_authentication=>[USER, PASS]))
  erb :index
end

def readFromUrl(url)
  begin
    open(url).read
  rescue 
    "{}"
  end
end

helpers do

  def labelFor(project)
    @label =  project.split[4] +" ["+ project.split[2]+"]"
    @status = Status.new(@doc.xpath("//Project[@name='#{project}']").first)
    erb '<%= if @status.success? then "" else "!" end %> <%= @label %> <%= if @status.success? then "" else "!" end %>'
  end

  def status_of(project)
    # puts "getting status for #{project}."    
    @status = Status.new(@doc.xpath(".//Project[regex(., '^#{project}$')]", Class.new {
      def regex node_set, regex
        node_set.find_all { |node| node['name'] =~ /#{regex}/ }
      end
    }.new), @end_to_end_times)
    erb 'status <%= if @status.success? then "success" else "failure" end %><%= " building" if @status.building? %>'
  end
  
end

class Status
  def initialize(nodes, end_to_end_times)
    # puts "nodes: #{nodes}"    
    @nodes = nodes
    @end_to_end_times = end_to_end_times
  end
  
  def success?
    @nodes.all? { |node| node['lastBuildStatus'] == "Success" }
  end
  
  def building?
    @nodes.any? { |node| node['activity'] == "Building" }
  end
  
  def buildLabel
    strip_runs @nodes.first['lastBuildLabel']
  end
  
  private  
  def get_commit_message_from_url (url)
    web_html = Nokogiri::HTML(open(url, :http_basic_authentication=>[USER, PASS]))
    script = web_html.xpath("//script")[6].content
    commitJson = JSON.parse(script.slice(22,script.length).rstrip.chop.chop)["modifications"][0]
    return commitJson["comment"]+" by "+commitJson["user"]
  end
  
end
