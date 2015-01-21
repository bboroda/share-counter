require 'nokogiri'
require 'open-uri'
require 'json'
require 'rest-client'

class ShareCounter

  # network lookups

  def self.reddit url
    html = make_request "http://www.reddit.com/api/info.json", url: url
    j = JSON.parse(html)

    unless j['data']['children'].empty?
      return j['data']['children'][0]['data']['score']
    else
      return 0
    end
  end

  def self.twitter url
    html = make_request "http://urls.api.twitter.com/1/urls/count.json",  url: url
    return JSON.parse(html)['count']
  end

  def self.facebook url
    html = make_request "https://api.facebook.com/method/fql.query", format: "json", query: "select like_count from link_stat where url=\"#{url}\""
    return JSON.parse(html)[0]['like_count']
  end

  def self.linkedin url
    html = make_request "http://www.linkedin.com/countserv/count/share", url: url, callback: "IN.Tags.Share.handleCount"
    return JSON.parse(html)['count']
  end

  def self.googleplus url
    html = make_request "https://plusone.google.com/_/+1/fastbutton", url: url
    return Nokogiri::HTML.parse(html).xpath('//*[@id="aggregateCount"]').text.to_i
  end

  def self.delicious url
    html = make_request "http://feeds.delicious.com/v2/json/urlinfo/data", url: url
    json = JSON.parse(html)
    if json.empty?
      return -1
    else
      return json[0]['total_posts']
    end
  end

  def self.stumbleupon url
    html = make_request "http://www.stumbleupon.com/services/1.01/badge.getinfo", url: url
    return JSON.parse(html)['result']['views']
  end

  def self.pinterest url
    html = make_request "http://widgets.pinterest.com/v1/urls/count.json", url: url, source: 6
    html.gsub! 'receiveCount(', ''
    html.gsub! ')', ''
    return JSON.parse(html)['count']
  end


  # helpers - get all or selected networks

  def self.supported_networks
    %w(reddit twitter facebook linkedin googleplus delicious stumbleupon pinterest)
  end

  def self.all url
    supported_networks.inject({}) { |r, c| r[c.to_sym] = ShareCounter.send(c, url); r }
  end

  def self.selected url, selections
    selections.map{|name| name.downcase}.select{|name| supported_networks.include? name.to_s}.inject({}) {
       |r, c| r[c.to_sym] = ShareCounter.send(c, url); r }
  end
  private

  #
  #
  # Performs an HTTP request to the given API URL with the specified params
  # and within 2 seconds, and max 3 attempts
  #
  # If a :callback param is also specified, then it is assumed that the API
  # returns a JSON text wrapped in a call to a method by that callback name,
  # therefore in this case it manipulates the response to extract only
  # the JSON data required.
  #
  def self.make_request *args
    result   = nil
    attempts = 1
    url      = args.shift
    params   = args.inject({}) { |r, c| r.merge! c }

    begin
      response    = RestClient.get url,  { :params => params, :timeout => 5 }

      # if a callback is specified, the expected response is in the format "callback_name(JSON data)";
      # with the response ending with ";" and, in some cases, "\n"
      #Strip off the preceeding /**/
      result = params.keys.include?(:callback) \
        ? response.gsub(/\A\/\*\*\/\s+/, "").gsub(/^(.*);+\n*$/, "\\1").gsub(/^#{params[:callback]}\((.*)\)$/, "\\1") \
        : response

    rescue Exception => e
      puts "Failed #{attempts} attempt(s) - #{e}"
      attempts += 1
      if attempts <= 3
        retry
      else
        raise Exception
      end
    end

    result
  end


end

