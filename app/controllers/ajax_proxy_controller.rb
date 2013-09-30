require 'open-uri'
require 'net/http'
require 'uri'
require 'cgi'

class AjaxProxyController < ApplicationController


  def get

    page = open(params[:url])
    content =  page.read
    render :text => content

  end

  def jsonp
    if params[:apikey].nil? || params[:apikey].empty?
      render_json '{ "error": "Must supply apikey" }'
      return
    end

    if params[:path].nil? || params[:path].empty?
      render_json '{ "error": "Must supply path" }'
      return
    end

    url = URI.parse($LEGACY_REST_URL + params[:path])
    url.port = $REST_PORT.to_i
    full_path = (url.query.blank?) ? url.path : "#{url.path}?#{url.query}"
    full_path = full_path.include?("?") ? full_path + "&apikey=#{params[:apikey]}&userapikey=#{params[:userapikey]}" : full_path + "?apikey=#{params[:apikey]}&userapikey=#{params[:userapikey]}"
    http = Net::HTTP.new(url.host, url.port)
    headers = { "Accept" => "application/json" }
    res = http.get(full_path, headers)
    response = res.code.to_i >= 400 ? { :status => res.code.to_i, :body => res.body }.to_json : res.body
    render_json response, {:status => 200}
  end

  def json_class
    raise Error404 if params[:conceptid].nil? || params[:conceptid].empty?
    params[:ontology] ||= params[:ontologyid]

    if params[:ontologyid].to_i > 0
      params_cleanup_new_api()
      stop_words = ["controller", "action", "ontologyid"]
      redirect_to "#{request.path}#{params_string_for_redirect(params, stop_words: stop_words)}", :status => :moved_permanently
      return
    end

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    raise Error404 if @ontology.nil?

    @concept = @ontology.explore.single_class({}, params[:conceptid])
    raise Error404 if @concept.nil?

    render_json @concept.to_json
  end

  def recaptcha
    render :partial => "recaptcha"
  end

  def loading_spinner
    render :partial => "loading_spinner"
  end

  private

  def render_json(json, options={})
    callback, variable = params[:callback], params[:variable]
    response = begin
      if callback && variable
        "var #{variable} = #{json};\n#{callback}(#{variable});"
      elsif variable
        "var #{variable} = #{json};"
      elsif callback
        "#{callback}(#{json});"
      else
        json
      end
    end
    render({:content_type => "application/json", :text => response}.merge(options))
  end

end
