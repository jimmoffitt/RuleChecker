require_relative './pt_rules'
require_relative './pt_restful'

require 'json'
require 'logging'
require 'base64'


class NegationRule < PTRule
  
  
  
end

class PTNegationator

  attr_accessor :account_name, :product, :publisher, :label,
                :http, :urlSearch,  #need a HTTP object to make requests of
                :search_api_creds,
                :rule_set,
                :base_rule,
                :negations,
                :count_interval,
                :request_sleep

  def initialize
    @negations = []
    @search_api_creds = {}

    @product = 'track' #Only product supported, only one needed.
    @publisher = 'twitter'
    @count_interval = 'day'
    
    @http = PtRESTful.new
    @rule_set = PTRules.new
  end
  
  def load_negation_candidates
    negations = "\"@love_absolut\" OR \"@_absolut_truth\" OR \"@absolut_blank\" OR \"@absolutamber\" OR \"@d_absolut_truth\" OR \"@elyx__\" OR \"@socallme_elyx\" OR \"elyxyak\" OR \"erotikgirls\" OR \"formel 1\" OR\"formula 1\" OR \"dj smirnoff\" OR \"dj absolut\" OR \"dj_smirnoff\" OR \"dj_smirnoff_ice\" OR \"karin smirnoff\" OR \"karina smirnoff\" OR \"katrina smirnoff\" OR \"kyza smirnoff\" OR \"oleg smirnoff\" OR \"pere smirnoff\" OR \"quick get some smirnoff ice\" OR \"red bull media\" OR \"serg smirnoff\" OR \"serg_smirnoff\" OR \"smirnoff centre\" OR \"smirnoff hotel\" OR \"smirnoff dj\" OR \"smirnoff music centre\" OR\"smirnoff turntable\" OR \"smirnoff type\" OR \"smirnoff wrote\" OR \"viagra\" OR \"victoria smirnoff\" OR \"yaakov smirnoff\" OR \"yakov smirnoff\" OR \"zmey smirnoff\" OR \"absolut nicht\" OR \"absolut nichts\"OR \"absolut repair\" OR \"absolut_blank\" OR \"absolut_truth\" OR \"absolut_watkins\" OR \"absolute_pepper\" OR \"dancing with the\" OR \"dancing with the stars\" OR \"natalia smirnoff\" OR \"chilling in the sea\" OR \"d_absolut_truth\" OR \"erotik girls\" OR \"garota_smirnoff\" OR \"nick smirnoff\" OR \"dimitri smirnoff\" OR \"diully kethellyn\" OR \"karina-smirnoff\" OR \"l'oreal\" OR \"alexander smirnoff\" OR\"minichill\" OR \"anna smirnoff\" OR \"doctor smirnoff\" OR \"penis\" OR \"socallme_elyx\" OR \"nvidea\" OR \"von smirnoff\" OR \"absolut inte\" OR \"absolut värsta\" OR \"#rasism\" OR \"doodle\" OR \"le petit\"OR \"yak\" OR \"little things i like\" OR \"mouvmatin\" OR \"arena naţională\" OR \"iphone 6\" OR \"windos\" OR \"mozilla\" OR \"http://forum.softpedia.com/\" OR \"scf\" OR sex OR \"sex video\" OR toys OR \"absolut garden\""
    @negations = negations.split("OR")
  end
  
  def load_base_rule
    @base_rule = "absolut OR #absolut OR #absolutamber OR #absolutapeach OR #absolutberriacai OR #absolutchicago OR #absolutciron OR #absolutelyx OR #absolutgreyhound OR #absolutinspire OR #absolutkarnival"
    #Other terms: #absolutnextframe OR #absolutoriginal OR #absolutoriginality OR #absolutoz OR #absolutraspberriOR #absoluttexas OR #absoluttune OR #absoluttune OR ( #absoluttune AND incona ) OR #absolutverticalgarden OR #allequalunderthesun OR #bottle to the extreme ~0 OR #elyx OR #jardimverticalOR #nextframe OR #transformtoday OR #verticalgarden OR ( #verticalgarden AND #absolut ) OR #wearekarnival OR absolut tune ~0 OR absoluttune OR 'absolut tune' ~0 OR 'absoluttune' OR ( 'absoluttune' AND icona ) OR ( absolut tune ~0 AND icona ) OR 'nextframe' OR nextframe OR ( 11 amazing augmented reality ads ~0 AND absolut ) OR 4 million absolutely unique ~0 OR 4 million uniquely ~0 OR 5 days la roma ~0 OR 5dayslaroma OR ( 72 transformations ~0 AND absolut AND bottle ) OR @absoluttune OR ( @absoluttune AND icona ) OR ( @blahblahblanda ANDabsolutvodka_us ) OR ( absolut AND elyx ) OR ( absolut AND glimmer ) OR ( absolut AND jay-z ) OR ( absolut AND rirkrit tiravanija ~0 ) OR absolut atelier ~0 OR ( lemon andersen ~0 AND absolut ) OR( rirkrit tiravanija ~0 AND lydmar ) OR ( rirkrit tiravanija ~0 AND moderna museet ~0 ) OR ( rirkrit tiravanija ~0 AND absolut art ~0 ) OR ( spike jonze ~0 AND geheime liebesgeschichte ~0 ) OR ( spike lee ~0 AND absolut ) OR the absolut company ~0 OR abslut apeach ~0 OR ( absoilut AND aaron koblin ~0 ) OR absolut 'mexico' ~0 OR ( absolut AND transform today ~0 ) OR absolut 100 ~0 OR absolut 100 ~0 OR ( absolut 100 ~0 AND -ich AND -es absolut ~0 AND -du absolut ~0 ) OR ( absolut AND 365 days ~0 ) OR ( absolut AND 4 milhão ~0 ) OR ( absolut AND 4 milione ~0 ) OR ( absolut AND 4 miljoen ~0 ) OR ( absolut AND 4 miljoner ~0 ) OR ( absolut AND 4 million ~0 ) OR ( absolut AND 4 millón ~0 ) OR ( absolut AND 5 days la roma ~0 ) OR absolut 72 bian ~0 OR ( absolut AND 72 transformations ~0 ) OR ( absolut AND 72bian ) OR ( absolut AND 72变 ) OR ( absolut AND ellen von unwerth ~0 ) OR ( absolut AND kate beckinsale ~0 ) OR ( absolut AND keren cytter ~0 ) OR absolut masquerade ~0 OR absolut mango ~0 OR ( absolut AND tiravanija ) OR ( absolut AND zooey deschanel ~0 ) OR absolut advertising ~0 OR ( absolut AND a unique limited edition ~0 ) OR ( absolut ANDa380 ) OR ( absolut AND aaron koblin ~0 ) OR ( absolut AND acai ) OR ( absolut AND ads ) OR ( absolut AND advertising ) OR ( absolut AND agbeviade anthony ~0 ) OR ( absolut AND airbus ) OR ( absolut AND ali larter ~0 ) OR ( absolut AND anri sala ~0 ) OR ( absolut AND apeach ) OR absolut amber ~0 OR ( absolut AND anri sala ~0 ) OR absolut apeach ~0 OR absolut art bureau ~0 OR ( absolut AND art celebration ~0 ) OR ( absolut AND art collection ~0 ) OR ( absolut AND art exhibition ~0 ) OR ( absolut AND artful bottles ~0 ) OR ( absolut AND atelier ) OR ( absolut AND augemented reality app ~0 ) OR ( absolut AND augemented reality ~0 ) OR absolut australia ~0 OR absolut azul ~0 OR absolut berri ~0 OR absolut berri acai ~0 OR absolut bian ~0 OR absolut blank ~0 ORabsolut bling ~0 OR absolut blue ~0 OR absolut brand ~0 OR absolut brings 2d to life with artist rafael ~0 OR absolut brooklyn ~0 OR absolut carnaval ~0 OR absolut carnival ~0 OR absolut celestial bars ~0 OR absolut chalk ~0 OR absolut cherrykran ~0 OR absolut chicago ~0 OR absolut citron ~0 OR absolut citron glimmer ~0 OR absolut cocktail ~0 OR absolut collection ~0 OR
  end

  def build_rules 

    #Create and add the base rule, whose 30-count provides the base-line.
    rule = PTRule.new
    rule.value = @base_rule
    rules = []
    rules << rule
    
    @negations.each do |negation|
      rule = PT_Rule_Negation.new
      rule.value = "-#{negation.strip} (#{@base_rule})"
      rule.negation = negation.strip
      rules << rule
    end
    
    @rule_set = rules
    
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
  
  def check
    
    load_base_rule
    load_negation_candidates
    build_rules
    
    #Establish static 30-day start and end times: base rule results can otherwise change during the negation checks.
    #High volume base rules are likely to change during the multiple negation rule checks... 
    end_time = Time.now.utc 
    start_time = end_time - (30 * 24 * 60 * 60) # 30 days.


    #loop through negations, adding one negation at a time to base rule, than get 30-day counts
    @rule_set.each do |rule|
      
      puts rule.value
      counts_response = get_search_counts(@search_api_creds, rule.value, start_time, end_time)
      rule.count_30_day = get_count_total(counts_response)
      puts rule.count_30_day
      
    end

    #Sanity-check, same results for base rules.
    counts_response = get_search_counts(@search_api_creds, @rule_set[0].value, start_time, end_time)
    puts get_count_total(counts_response)

    #Sort results and write output
    
    baseline = @rule_set[0].count_30_day

    results = []
    results_sorted = []
    
    @rule_set.each do |rule|
      if rule.is_a? PT_Rule_Negation then
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
  end

  
end



#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

  #TODO: look for any '*config.yaml' file in app directory.
  config_file = './config/config_private_internal.yaml'

  oApp = PTNegationator.new()

  #oApp.get_logger(config_file)

  oApp.get_app_config(config_file) #This triggers loading of streams.

  oApp.check

end
