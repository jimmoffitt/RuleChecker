#TODO: [] Figure out stats class.
#      [] handle rules that have multiple issues.

require_relative './common/pt_rules'  #--> Collections of stream rules.
require_relative './common/pt_rule_stats'  #--> Various stream rule stats.
require_relative './common/pt_restful' #--> Understands Rules and Search APIs.
require_relative './common/pt_logging' 

require 'json'

class PTStream

  attr_accessor :account_name, :product, :publisher, :label,

                :http, :urlRules, :urlSearch,  #need a HTTP object to make requests of

                #Select Stream rule metadata.
                :pt_rules, #PT Rules object, which owns an PTRule array.
                :pt_rules_corrected,
                :pt_rules_non_search, #Flagging suspect rules that can not be used with Search API.
                
                :pt_rule_stats, #Helper class.
                :rule_stats,
  
                #App settings.
                :outbox,
                :verbose,
                :request_sleep,
                :save_ok_rules,
                :include_rule_count_timeseries,

                :logger

  def initialize
    @product = 'track' #Only product supported, only one needed.
    @publisher = 'twitter'
    @count_interval = 'day'

    @verbose = false
    @request_sleep = 0

    @pt_rules = [] #Array of rule objects.
    @pt_rules_corrected = []
    @pt_rules_non_search = []
    @pt_rule_helper = PTRules.new
        
    @save_ok_rules = false
    @include_rule_count_timeseries = false

    @rule_length_max = 0
    @rule_length_avg = 0.0

    @pt_rule_stats = PTRuleStats.new
    @rule_stats = {}
    
    @http = PtRESTful.new
  end

  def call_rules_api rules_api_creds

    logger.debug "Retrieving rules for account: #{@account_name}..."

    @http.publisher = @publisher
    @http.url = @http.getRulesURL(@account_name, @label)
    @http.user_name = rules_api_creds['user_name']
    @http.password_encoded = rules_api_creds['password_encoded']

    headers = {}
    if rules_api_creds['user_name'] == 'system' then
      headers['X-ON-BEHALF-OF-ACCOUNT'] = @account_name
    end
    headers['Content-Type'] = 'application/json'
    headers['accept'] = 'application/json'

    response = @http.GET(nil,headers)
    #TODO: handle response.code > 299

    return response.body

  end

  def load_rules rules_api_creds

    puts "Loading rules..." if @verbose

    response = call_rules_api rules_api_creds
    rules_json = JSON.parse(response)['rules']
    @pt_rules = @pt_rule_helper.load_rules rules_json

  end

  def identify_bad_rules rules
    
    puts "Scanning for bad rules..." if @verbose
    
    bad_rules = []

    rules.each do |rule|
      #Scan for AND rules.
      if @pt_rule_helper.unquoted_clause? rule.value, 'AND' or @pt_rule_helper.unquoted_clause? rule.value, 'and' then
        bad_rule = PT_RULE_Corrected.new
        bad_rule.value = rule.value
        bad_rule.tag = rule.tag
        bad_rule.type << 'AND'
        
        bad_rules << bad_rule
      end


      #Scan for unquoted or rules.
      if @pt_rule_helper.unquoted_clause? rule.value, 'or' then
        bad_rule = PT_RULE_Corrected.new
        bad_rule.value = rule.value
        bad_rule.tag = rule.tag
        bad_rule.type << 'unquoted or'

        bad_rules << bad_rule     
      end

      #have another rule pattern to scan for?
      #Write a test for it, and add that type/
      #
      # unquoted punctuation?
      # AND and OR without '(' and ')'
    end
    
    puts "#{bad_rules.length} bad rules..." if @verbose
    
    return bad_rules      
    
  end

  def correct_bad_rules rules

    puts "Correcting bad rules..." if @verbose

    rules.each do |rule|
      if rule.type.include? 'AND' then
        rule.value_corrected = @pt_rule_helper.fix_AND_rule rule.value
      end

      if rule.type.include? 'unquoted or' then
        rule.value_corrected = @pt_rule_helper.fix_or_rule rule.value
      end
      
      #Other types to fix?
      
    end
      
    return rules

  end
  
  def check_corrections rules_corrected, search_api_creds
    
    return if rules_corrected.length == 0

    logger.debug "Analyzing #{rules_corrected.length} 'corrected' rules."
    logger.debug "Getting 30-day counts (before and after)..."

    puts "Starting Search API requests... Getting 30-day counts for original and 'corrected' rules..." if @verbose

    #Analyze Corrected rules.
    rules_corrected.each do |rule|

      if @pt_rule_helper.worksWithSearch? rule.value then
        counts_response = get_search_counts(search_api_creds, rule.value)
      else
        msg = "Skipping rule, has Operators unsupported by Search API: #{rule.value}."
        @pt_rules_non_search << rule
        logger.info msg
        next #skip
      end

      #Called Search API counts endpoint, but not successful.
      if counts_response['results'].nil? or counts_response.include? 'error' or counts_response.include? 'Could not accept' then
        msg = "Error with rule: #{rule.value}."
        logger.error msg
        puts msg
        msg = counts_response['error']['message'] if not counts_response['error']['message'].nil?
        logger.error msg
        next #skip
      end
      
      rule.count_30_day = get_count_total(counts_response)
      rule.count_timeseries = get_count_timeseries(counts_response) if @include_rule_count_timeseries

      #Call Search API counts for rule as originally written.
      counts_response = get_search_counts(search_api_creds, rule.value_corrected)

      #Called Search API counts endpoint, but not successful.
      if counts_response['results'].nil? or counts_response.include? 'error' or counts_response.include? 'Could not accept' then
        msg = "Error with corrected rule: #{rule.value}."
        logger.error msg
        puts msg
        msg = counts_response['error']['message'] if not counts_response['error']['message'].nil?
        logger.error msg
        next #skip
      end

      rule.count_30_day_corrected = get_count_total(counts_response)
      rule.count_timeseries_corrected = get_count_timeseries(counts_response) if @include_rule_count_timeseries

    end
    
    rules_corrected

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
      logger.error 'ERROR calculating total count.'
    end
  end

  def get_count_timeseries(count_response)

    begin
      timeseries = []

      results = count_response["results"]
      results.each do |result|
        timeseries << result["count"]
      end

      timeseries
    rescue
      logger.error 'ERROR set count time-series.'
    end
  end

  def get_search_counts(search_api_creds, rule)

    puts "Getting Search API 30-day counts for rule: #{rule}" if @verbose

    @http.user_name = search_api_creds['user_name']
    @http.password_encoded = search_api_creds['password_encoded']
    @http.publisher = @publisher
    @http.url = @http.getSearchCountURL(search_api_creds['account_name'],search_api_creds['search_label'])

    #Build count request.
    search_request = {:publisher => @publisher, :query => rule, :bucket => @count_interval}
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

  #Write Stream report text.
  def write_output(f=nil)

    return if f.nil?

    puts "Writing Stream output..." if @verbose

    f.puts '### Stream summary ###'
    f.puts "Endpoint: #{@publisher}/#{@product}/#{@label}.json"
    f.puts
    f.puts "+ Number of rules: #{separate_comma(@rule_stats['rule_count'])}"
    f.puts "+ Rule average characters: #{separate_comma(@rule_stats['rule_length_avg'])}"
    f.puts "+ Rule maximum characters: #{separate_comma(@rule_stats['rule_length_max'])}"
    f.puts "+ Rule value with maximum characters: #{@rule_stats['rule_value_max']}"
    f.puts "+ Number of AND rules: #{separate_comma(@rule_stats['rules_AND'])}"
    f.puts "+ Number of 'or' rules: #{separate_comma(@rule_stats['rules_or'])}"
    f.puts

    if !@pt_rules_corrected.nil? then 
      f.puts "+ 30-day counts before: #{separate_comma(@rule_stats['rule_count_totals'].to_i)}" if (@pt_rules_corrected.length) > 0
      f.puts "+ 30-day counts after: #{separate_comma(@rule_stats['rule_count_corrected_totals'].to_i)}" if (@pt_rules_corrected.length) > 0
      f.puts "+ Rule with highest delta (#{separate_comma(@rule_stats['rule_max_delta'])} <= #{separate_comma(@rule_stats['rule_max_delta_30_day_corrected'])} - #{separate_comma(@rule_stats['rule_max_delta_30_day'])}): #{@rule_stats['rule_max_delta_value']}" if (@pt_rules_corrected.length) > 0
      f.puts "+ Rule with highest factor (#{separate_comma(@rule_stats['rule_max_factor'])} <= #{separate_comma(@rule_stats['rule_max_factor_30_day_corrected'])} / #{separate_comma(@rule_stats['rule_max_factor_30_day'])}): #{@rule_stats['rule_max_factor_value']}" if (@pt_rules_corrected.length) > 0
      f.puts
  
      f.puts "#### Corrected rule analysis:"
      
      spaces = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
  
      @pt_rules_corrected.each do |rule|
        f.puts
        f.puts rule.value + '  <br>'
        f.puts rule.value_corrected + '  <br>'
        f.puts "--> 30-day counts --> Before: #{separate_comma(rule.count_30_day)} | After: #{separate_comma(rule.count_30_day_corrected)} <br>"
        f.puts "#{spaces}Delta: #{separate_comma(rule.count_30_day_corrected - rule.count_30_day)} | Factor: #{'%.1f' % (rule.count_30_day_corrected/(rule.count_30_day * 1.0))}" if rule.count_30_day > 0
        f.puts
       end
    end


    if !@pt_rules_non_search.nil? and @pt_rules_non_search.length > 0 then
      f.puts
      f.puts
      f.puts "Here are #{@pt_rules_non_search.length} rules that could not be tested with the Search API:"
      f.puts
      @pt_rules_non_search.each do |rule|
        f.puts "Original rule: #{rule.value}"
        f.puts "Suggested rule: #{rule.value_corrected}"
        f.puts
      end
    end
    
      
    if @verbose then
      puts '=============================================================================================================='
      puts
      puts '## Stream summary ##'
      puts "Account/System name:#{@account_name}:"
      puts "Number of rules: #{separate_comma(@rule_stats['rule_count'])}"
      puts "Rule average characters: #{separate_comma(@rule_stats['rule_length_avg'])}"
      puts "Rule maximum characters: #{separate_comma(@rule_stats['rule_length_max'])}"
      puts "Rule maximum value: #{@rule_stats['rule_value_max']}"
      puts "Number of AND rules: #{separate_comma(@rule_stats['rules_AND'])}"
      puts "Number of 'or' rules: #{separate_comma(@rule_stats['rules_or'])}"
      puts

      puts " #{@account_name} rule metadata --------------------------------------------------"
      puts "Longest rule has #{@rule_stats['rule_length_max']} characters."
      puts "Average rule has #{@rule_stats['rule_length_avg']} characters"

      if !@pt_rules_corrected.nil? and @pt_rules_non_search.length > 0 then
        puts "30-day counts before: #{separate_comma(@rule_stats['rule_count_totals'].to_i)}" if (@pt_rules_corrected.length) > 0
        puts "30-day counts after: #{separate_comma(@rule_stats['rule_count_corrected_totals'].to_i)}" if (@pt_rules_corrected.length) > 0
        puts "Rule with highest delta (#{@rule_stats['rule_max_delta']} <= #{@rule_stats['rule_max_delta_30_day_corrected']} - #{@rule_stats['rule_max_delta_30_day']}): #{@rule_stats['rule_max_delta_value']}" if (@pt_rules_corrected.length) > 0
        puts "Rule with highest factor (#{@rule_stats['rule_max_factor']} <= #{@rule_stats['rule_max_factor_30_day_corrected']} / #{@rule_stats['rule_max_factor_30_day']}): #{@rule_stats['rule_max_factor_value']}" if (@pt_rules_corrected.length) > 0
        puts
        puts "=============================================================================================================="
        puts
      end
    end

    if !@pt_rules_non_search.nil? and @pt_rules_non_search.length > 0 then
      puts
      puts
      puts "Here are #{@pt_rules_non_search.length} rules that could not be tested with the Search API:"
      puts
      @pt_rules_non_search.each do |rule|
        puts "Original rule: #{rule.value}"
        puts "Suggested rule: #{rule.value_corrected}"
        puts
      end
    end
  end
  
  def make_rules_api_json

    output_folder = './output/JSON_updates/'


    if !@pt_rules_corrected.nil? and @pt_rules_corrected.length > 0 then 
    
      add_rules = {}
      rules_to_add = []
      @pt_rules_corrected.each do |rule|
        rule_to_add = {}
        rule_to_add['value'] = rule.value_corrected
        rule_to_add['tag'] = rule.tag
        
        rules_to_add << rule_to_add
      end
      
      add_rules['rules'] = rules_to_add #Construct 'rules' JSON array.
      
      filename = "#{@account_name}_#{@label}_ADD.json"
  
      f = File.new(output_folder + filename,  "w+")
      f.puts add_rules.to_json
      f.close
     
      
      delete_rules = {}
      rules_to_delete = []
      @pt_rules_corrected.each do |rule|
        rule_to_delete = {}
        rule_to_delete['value'] = rule.value
        #rule_to_delete['tag'] = rule['tag'] #Not needed for deletes.
  
        rules_to_delete << rule_to_delete
      end
  
      delete_rules['rules'] = rules_to_delete #Construct 'rules' JSON array.
  
      filename = "#{@account_name}_#{@label}_DELETE.json"
  
      f = File.new(output_folder + filename,  "w+")
      f.puts delete_rules.to_json
      f.close
    end
      
    #Now handle rules that could not be confirmed with Search API.

    return if @pt_rules_non_search.nil? or @pt_rules_non_search.length > 0

    add_rules = {}
    rules_to_add = []
    @pt_rules_non_search.each do |rule|
      rule_to_add = {}
      rule_to_add['value'] = rule.value_corrected
      rule_to_add['tag'] = rule.tag

      rules_to_add << rule_to_add
    end

    add_rules['rules'] = rules_to_add #Construct 'rules' JSON array.

    filename = "#{@account_name}_#{@label}_ADD_UNCHECKED.json"

    f = File.new(output_folder + filename,  "w+")
    f.puts add_rules.to_json
    f.close

    delete_rules = {}
    rules_to_delete = []
    @pt_rules_non_search.each do |rule|
      rule_to_delete = {}
      rule_to_delete['value'] = rule.value
      #rule_to_delete['tag'] = rule['tag'] #Not needed for deletes.

      rules_to_delete << rule_to_delete
    end

    delete_rules['rules'] = rules_to_delete #Construct 'rules' JSON array.

    filename = "#{@account_name}_#{@label}_DELETE_UNCHECKED.json"

    f = File.new(output_folder + filename,  "w+")
    f.puts delete_rules.to_json
    f.close
  end
  

  #Formats 233456 --> 233,456
  def separate_comma(number)
    number.to_s.chars.to_a.reverse.each_slice(3).map(&:join).join(",").reverse
  end

  #Check the stream, do the rules analysis, etc.
  def process_rules(rules_api_creds, search_api_creds)
  
    logger.debug  "Checking stream for #{@account_name}..."
    
    load_rules rules_api_creds #Load all rules, the good, the bad, and the ugly.
    
    @rule_stats = @pt_rule_stats.get_rule_stats @pt_rules
   
    #Scan rules for those need to be corrected! ------------
    @pt_rules_corrected = []
    @pt_rules_corrected = identify_bad_rules @pt_rules
    
    @pt_rules = nil if !@save_ok_rules
    
    @pt_rules_corrected = correct_bad_rules @pt_rules_corrected
  
    @pt_rules_corrected = check_corrections @pt_rules_corrected, search_api_creds
  
    @rule_stats = @pt_rule_stats.get_corrected_stats @pt_rules_corrected if !@pt_rules_corrected.nil?
  
  end

end

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

  o = PTStream.new

  #Detecting unquoted clauses --------------

  #unquoted ANDs rules.
  r = '"this and that" AND these '
  puts o.pt_rules.unquoted_clause? r, 'and'
  puts o.pt_rules.unquoted_clause? r, 'AND'
  
  r = 'up and down and "this and that"'
  puts o.pt_rules.unquoted_clause? r, 'and'
  puts o.pt_rules.unquoted_clause? r, 'AND'

  r = '"up and down" AND "this and that"'
  puts o.pt_rules.unquoted_clause? r, 'and'
  puts o.pt_rules.unquoted_clause? r, 'AND'
  
  r = 'these and "up and down" AND "this and that"'
  puts o.pt_rules.unquoted_clause? r, 'and'
  puts o.pt_rules.unquoted_clause? r, 'AND'
  
  r = '"this and that"'
  puts o.pt_rules.unquoted_clause? r, 'and'
  puts o.pt_rules.unquoted_clause? r, 'AND'
  
  r = 'these AND "this and that" AND "up and down" and "back and forth" AND "first and last"'
  puts o.pt_rules.unquoted_clause? r, 'and'
  puts o.pt_rules.unquoted_clause? r, 'AND'
  
  #unquoted, lowercase 'or' rules.
  
  r = '"this or that" OR these '
  puts o.pt_rules.unquoted_clause? r, 'or'

  r = 'up or down or "this or that"'
  puts o.pt_rules.unquoted_clause? r, 'or'

  r = '"up or down" OR "this or that"'
  puts o.pt_rules.unquoted_clause? r, 'or'

  r = 'these or "up or down" OR "this or that"'
  puts o.pt_rules.unquoted_clause? r, 'or'

  r = '"this or that"'
  puts o.pt_rules.unquoted_clause? r, 'or'

  r = 'these OR "this or that" OR "up or down" or "back or forth" OR "first or last"'
  puts o.pt_rules.unquoted_clause? r, 'or'

  #Fix or rule tests ---------------------
  r = 'this or that'
  puts o.pt_rules.fix_or_rule r

  r = 'this or that "this or that"'
  puts o.pt_rules.fix_or_rule r

  #Fix AND rule tests ---------------------
  r = 'this AND that and "this and that" and "up AND down"'
  puts o.pt_rules.fix_AND_rule r

  r = 'that "this and that" and "up AND down"'
  puts o.pt_rules.fix_AND_rule r

  r = '"this and that" "up AND down"'
  puts o.pt_rules.fix_AND_rule r
  
  puts 'done'

end


=begin


    @pt_rules.rules.each do |rule|

      #Scan for AND rules.
      if @pt_rules.unquoted_clause? rule.value, 'AND' or @pt_rules.unquoted_clause? rule.value, 'and' then
        r = PT_RULE_Corrected.new
        r.value = rule.value
        r.type = 'AND'
        
        #'Fix' AND rule here. Just remove unquoted ANDs.
        r.value_corrected = @pt_rules.fix_AND_rule r.value
         
        @pt_rules_corrected << r
        true #Mark for deletion.
      end
      
      #Scan for unquoted or rules.
      if @pt_rules.unquoted_clause? rule.value, 'or' then
        r = PT_RULE_Corrected.new
        r.value = rule.value
        r.type = 'unquoted or'
        
        #'Fix' rule here. Convert unquoted 'or' to 'OR'
        r.value_corrected = @pt_rules.fix_or_rule r.value

        @pt_rules_corrected << r
        true #Mark for deletion. 
      end

      
      
    end

=end

