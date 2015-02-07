class PTSystem

  attr_accessor :account_name, :user_name,
                :password, :password_encoded,

                :streams, #Systems own one of more data streams.

                #Rule stats metadata.
                :activities_before, :activities_after,

                #App settings.
                :outbox,
                :verbose,

                :logger

  def initialize
    @streams = [] #Array of stream objects.
    @verbose = false
  end

  def check_rules(rules_api_creds, search_api_creds)

    logger.debug "Checking #{@account_name} streams..."

    @streams.each do |stream|
      stream.verbose = @verbose
      stream.account_name = @account_name
      stream.outbox = @outbox
      stream.logger = @logger
      stream.process_rules(rules_api_creds, search_api_creds)
    end

    write_output

    if @verbose then
      puts
      puts "Finished with #{@account_name}..."
      puts '====================================================================='
    end

  end
  
  def make_rules_api_json
    @streams.each do |stream|
      stream.make_rules_api_json
    end
  end
  

  #Write report text.
  def write_output
    puts "Writing #{@account_name} output..."

    #Create output file...
    filename = "#{@outbox}/#{@account_name}.md" #markdown

    f = File.new(filename,  "w+")

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
