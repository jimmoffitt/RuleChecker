class PTSystem

  attr_accessor :account_name, :user_name,
                :password, :password_encoded,

                :streams, #Systems own one of more data streams.

                #Rule stats metadata.
                :activities_before, :activities_after,

                :pt_rule_stats, #Helper class.
                :rule_stats,

                #App settings.
                :outbox,
                :verbose,

                :logger

  def initialize
    @streams = [] #Array of stream objects.
    @verbose = false

    @pt_rule_stats = PTRuleStats.new
    @rule_stats = {}
  end

  def check_rules(rules_api_creds, search_api_creds)

    logger.debug "Checking #{@account_name} streams..."
    
    stats = {}
    stats[:rules] = 0  
    stats[:rules_AND] = 0
    stats[:rules_or] = 0
    stats[:tweets_original] = 0
    stats[:tweets_corrected] = 0

    @streams.each do |stream|
      stream.verbose = @verbose
      stream.account_name = @account_name
      stream.outbox = @outbox
      stream.logger = @logger
      stream.process_rules(rules_api_creds, search_api_creds)
      stream.write_rules_api_json

      stats[:rules] = stats[:rules].to_i + stream.rule_stats['rule_count'].to_i
      stats[:rules_AND] = stats[:rules_AND].to_i + stream.rule_stats['rules_AND'].to_i
      stats[:rules_or] = stats[:rules_or].to_i + stream.rule_stats['rules_or'].to_i
      stats[:tweets_original] = stats[:tweets_original].to_i + stream.rule_stats['rule_count_totals'].to_i
      stats[:tweets_corrected] = stats[:tweets_corrected].to_i + stream.rule_stats['rule_count_corrected_totals'].to_i
       
      if !stream.pt_rules_corrected.nil? and stream.pt_rules_corrected.length > 0 then
        stream.rank_results #At Stream level.
      end
    end
    
    rank_results stats

    write_output

    if @verbose then
      puts
      puts "Finished with #{@account_name} System..."
      puts '====================================================================='
    end

  end
  
  def write_rules_api_json
    @streams.each do |stream|
      stream.write_rules_api_json
    end
  end

  def rank_results stats

    rank_results = "#{@outbox}/results.dat"
    results = {}

    #Confirm we found a results ranking file, otherwise create empty JSON file.
    if File.exist?(rank_results) then
      f = File.open(rank_results, "r")
      results = f.read
      f.close
      results = JSON.parse(results) #Parse JSON into Hash.
    else
      results = {}
      results['systems'] = {}
    end

    #Create the hash entry for this stream
    system_data = {}
    system_data[:name] = "#{@account_name}"
    system_data[:tweets_original] = stats[:tweets_original]
    system_data[:tweets_corrected] = stats[:tweets_corrected]
    system_data[:delta] = stats[:tweets_corrected].to_i - stats[:tweets_original].to_i
    system_data[:rules] = stats[:rules]
    system_data[:rules_bad] = stats[:rules_AND].to_i + stats[:rules_or].to_i
    
    system_data[:time] = Time.now

    #Add it to results, replacing old one if it exists.
    begin
      key = "#{@account_name}"
      results['systems'][key] = {}
      results['systems'][key] = system_data
    rescue
      puts 'error'
    end

    #results = results.sort_by { |k, v| v['delta'] }

    #Write file.
    f = File.new(rank_results, "w+") #Rewrites file...
    f.puts results.to_json
    f.close

  end
  
  
  

  #Write System report text.
  def write_output
    puts "Writing #{@account_name} output..."
    
    #Make System directory.
    output_folder = "#{@outbox}/#{@account_name}/"
    unless File.directory?(output_folder)
      FileUtils.mkdir_p(output_folder)
    end
    
    #Make filename foroutput file...
    filename = "#{@account_name}.md" #markdown

    f = File.new(output_folder + filename,  "w+")

    f.puts "## #{@account_name} System Summary ##"

    f.puts "Number of Power Track real-time streams: #{@streams.length}"
    f.puts

    @streams.each do |stream|
      stream.write_output f
    end

    f.puts("Finished with #{@account_name} system.")

    f.close

  end
end
