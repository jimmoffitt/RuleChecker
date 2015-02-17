require_relative './common/pt_rules'
require_relative './common/pt_http'
require_relative './common/pt_search_helper'

require 'json'
require 'yaml'
require 'logging'
require 'base64'

#Uses Search API to assess negation effectiveness.

class PTNegationator

  attr_accessor :account_name, :product, :publisher, :label,
                :http, :urlSearch,  #need a HTTP object to make requests of
                :search_api_creds,
                :count_interval,
                :request_sleep,

                :rule_set, # <-- PtRules.new
                :base_rule,
                
                :negations,
                :saved_results,
                :min_threshold,
                :max_number,
                
                :project_name
  
  def initialize

    # @project_name -- no default.
    @saved_results = './SavedCounts/'
    @min_threshold = 30
    @max_number = 50
    
    @negations = []

    @search_api_creds = {}
    @request_sleep = 5 #seconds

    @product = 'track' #Only product supported, only one needed.
    @publisher = 'twitter'
    @count_interval = 'day'
    
    @http = PtHTTP.new
    @pt_rules = PTRules.new
  end

  def build_rules 

    #Create and add the base rule, whose 30-count provides the base-line.
    rule = PTRule.new
    rule.value = @base_rule
    rules = []
    rules << rule
    
    @negations.each do |negation|
      rule = PT_Negation_Test_Rule.new
      rule.value = "-#{negation.strip} (#{@base_rule})"
      rule.negation = negation.strip
      rules << rule
    end
    
    @pt_rules = rules
    
  end
  
  #Load in the configuration file details, setting many object attributes.
  def get_app_config(config_file)

    #logger.debug 'Loading configuration file.'

    #look locally, if not there then look in ./config folder/
    if !File.exist?(config_file) then
      config_file = "./config/#{config_file}"
    end

    config = {}
    config = YAML.load_file(config_file)

    #Config details.

    #Account details for Search API...
    #... and Rules API when used in 'customer' mode.
    account_name = config['account']['account_name']
    user_name = config['account']['user_name']

    #Users can pass in plain text, if they must.
    password_encoded = config["account"]["password_encoded"]
    if password_encoded.nil? then #User is passing in plain-text password...
      password = config["account"]["password"]
      password_encoded = Base64.encode64(@password)
    end

    search_label = config['account']['search_label']

    @search_api_creds['account_name'] = account_name
    @search_api_creds['user_name'] = user_name
    @search_api_creds['password_encoded'] = password_encoded
    @search_api_creds['search_label'] = search_label

    #App settings.
    begin
      @outbox = checkDirectory(config["app"]["outbox"])
    rescue
      @outbox = "./output"
    end
    @request_sleep = config['app']['request_sleep']

    #Negationator settings!
    @project_name = config['negations']['project_name']
    @saved_results = config['negations']['saved_results']
    @min_threshold = config['negations']['min_threshold']
    @max_number = config['negations']['max_number']
    
  end

  def get_date_string(time)
    return time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)
  end

  def get_search_counts(search_api_creds, rule, start_time, end_time)

    @http.user_name = search_api_creds['user_name']
    @http.password_encoded = search_api_creds['password_encoded']
    @http.publisher = @publisher
    @http.url = @http.getSearchCountURL(search_api_creds['account_name'],search_api_creds['search_label'])

    #Build count request.
    search_request = {:publisher => @publisher, :query => rule, :bucket => @count_interval, :fromDate => get_date_string(start_time), :toDate => get_date_string(end_time)}
    data = JSON.generate(search_request)

    response = @http.POST(data)
    sleep @request_sleep

    if response.body.include? 'Rate limit exceeded' then
      sleep 5
      if @verbose then
        p "Rate limited, sleeping for 5 seconds before retrying..."
      end
      response = @http.POST(data) #retry
    end

    #p response.code

    begin
      response = JSON.parse(response.body)
    rescue
      logger.error "JSON parse error with: #{response.body}"
      response = '{"error"}'
    end

    return response
  end

  def get_count_total(count_response)

    begin

      count_total = 0

      results = count_response["results"]
      results.each do |result|
        #p  result["count"]
        count_total = count_total + result["count"]
      end

      @count_total = count_total

    rescue
      #logger.error 'ERROR calculating total count.'
    end
  end
  
  def get_top_negations

  end
  
  def check_negations(return_rule_set=nil)
    
    return_rules = false
    
    if !return_rule_set.nil? then
      return_rules = true
    end
    
    
    #TODO:
    #Check for saved counts... Do not want to slam Search API when we don't need to
    #if /SavedCounts/oApp.project_name.json exists load it!

    results_file = "#{@saved_results}/#{@project_name}.yaml"

    #If file exists, then load it
    if File.exist? results_file then 
      serialized_object = File.open(results_file, "rb")
      @pt_rules = YAML::load(serialized_object)
    
    else #Go get counts, and populate @pt_rules objects.
      
      build_rules

      #Establish static 30-day start and end times: base rule results can otherwise change during the negation checks.
      #High volume base rules are likely to change during the multiple negation rule checks...
      end_time = Time.now.utc
      start_time = end_time - (30 * 24 * 60 * 60) # 30 days.

      #loop through negations, adding one negation at a time to base rule, than get 30-day counts
      @pt_rules.each do |rule|
        
        puts rule.value
        counts_response = get_search_counts(@search_api_creds, rule.value, start_time, end_time)
        rule.count_30_day = get_count_total(counts_response)
        puts rule.count_30_day
        
      end
  
      #Saved current results
      serialized_objects = YAML::dump(@pt_rules)
      File.open(results_file, 'w') {|f| f.write(serialized_objects) }
    end
      
    #Sort results and write output
    
    baseline = @pt_rules[0].count_30_day

    results = []
    results_sorted = []
    
    @pt_rules.each do |rule|
      if rule.is_a? PT_Negation_Test_Rule then
        difference = rule.count_30_day - baseline
        rule.effect = difference
        puts "Change in counts: #{difference}"
        results << rule
      end
    end

    results_sorted = results.sort_by {|result| result.effect}

    puts "Ranking of negations, in decreasing effectiveness:"
    results_sorted.each do |result|
      puts "#{result.negation}: #{result.effect} " unless result.effect > 0 #TODO: bug alert!
    end
    
    negations_before = @pt_rules.length
    
    #Eliminate negations under the effectiveness threshold.
    negations = []
    @pt_rules.each do |rule|
      if rule.is_a? PT_Negation_Test_Rule then 
        if rule.effect <= (-1 * @min_threshold) then
          negations << rule
        end
      end
    end

    @pt_rules = negations
    negations_after = @pt_rules.length
    puts "Eliminated #{negations_before - negations_after} rules due to minimum threshold of #{@min_threshold}"

    negations_before = @pt_rules.length
    negations = []

    #Eliminate negations over the max number to keep.
    if @pt_rules.length > @max_number
      (@pt_rules.length - @max_number).times do |item|
        @pt_rules.pop
      end
    end

    @pt_rules = negations
    negations_after = @pt_rules.length
    puts "Eliminated #{negations_before - negations_after} rules due to maximum number, #{@max_number}, to keep"

    if return_rules == true then
      return @pt_rules
    end
  end
end



#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

  #TODO: look for any '*config.yaml' file in app directory.
  config_file = './config/config_private_internal.yaml'

  oApp = PTNegationator.new()

  #oApp.get_logger(config_file)

  oApp.get_app_config(config_file) #This triggers loading of streams.


  oApp.project_name = "dev" #Negation have 'projects' because negation analysis may require large amounts of Search API calls.
  #Before making calls, it checks to see if a saved 'project' set of negation results exists.

  #oApp.negations is an array of independent 'negation' clauses.
  negations = "ice OR icy OR \"heavy rain\" OR scared OR roads OR  \"don't like\" OR \"flip-flops\" OR \"heat lamps\" OR \"sand trap\" OR \"mud season\" OR \"can't stand\" OR \"heat wave\" OR \"fast melt\""
  oApp.negations = negations.split("OR")

  oApp.base_rule = "(snow OR powder OR mountain OR \"snow storm\" OR snowing OR snowfall OR \"ski resort\" OR breckenridge OR vail OR keystone OR aspen) profile_region:colorado"

  oApp.check_negations

end
