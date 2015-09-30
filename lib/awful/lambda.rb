module Awful

  class Lambda < Cli

    no_commands do
      def lambda
        @lambda ||= Aws::Lambda::Client.new
      end
    end

    desc 'ls NAME', 'list lambda functions matching NAME pattern'
    method_option :long, aliases: '-l', default: false, desc: 'Long listing'
    method_option :arns, aliases: '-a', default: false, desc: 'List ARNs for functions'
    def ls(name = /./)
      lambda.list_functions.functions.select do |function|
        function.function_name.match(name)
      end.tap do |functions|
        if options[:long]
          print_table functions.map { |f| [f.function_name, f.description, f.last_modified] }.sort
        elsif options[:arns]
          puts functions.map(&:function_arn).sort
        else
          puts functions.map(&:function_name).sort
        end
      end
    end

  end

end