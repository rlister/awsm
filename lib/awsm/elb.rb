module Awsm

  class Elb < Thor
    include Awsm

    desc 'ls [PATTERN]', 'list vpcs [with any tags matching PATTERN]'
    method_option :long, aliases: '-l', default: false, desc: 'Long listing'
    def ls(name = /./)
      fields = options[:long] ?
        ->(e) { [e.load_balancer_name, e.instances.length, e.availability_zones.join(','), e.dns_name] } :
        ->(e) { [e.load_balancer_name] }

      elb.describe_load_balancers.map(&:load_balancer_descriptions).flatten.select do |elb|
        elb.load_balancer_name.match(name)
      end.map do |elb|
        fields.call(elb)
      end.tap do |list|
        print_table list
      end
    end

    desc 'instances NAME', 'list instances and states for elb NAME'
    def instances(name)
      instances = elb.describe_instance_health(load_balancer_name: name).map(&:instance_states).flatten
      instances_by_id = instances.inject({}) { |hash,instance| hash[instance.instance_id] = instance; hash }

      ec2.describe_instances(instance_ids: instances_by_id.keys).map(&:reservations).flatten.map(&:instances).flatten.map do |instance|
        health = instances_by_id[instance.instance_id]
        [ instance.tags.map(&:value).sort.join(','), instance.public_ip_address, health.state, health.reason_code, health.description ]
      end.tap do |list|
         print_table list
      end
    end

    desc 'dump NAME', 'dump VPC with id or tag NAME as yaml'
    def dump(name)
      lb = elb.describe_load_balancers(load_balancer_names: Array(name)).map(&:load_balancer_descriptions).flatten.first.to_hash
      puts YAML.dump(stringify_keys(lb))
    end

    desc 'create NAME', 'create new load-balancer'
    def create(name)
      whitelist = %i[load_balancer_name listeners availability_zones subnets security_groups scheme tags]
      opt = load_cfg
      opt[:load_balancer_name] = name
      opt[:listeners] = opt.fetch(:listener_descriptions, []).map { |l| l[:listener] }
      opt.delete(:availability_zones) unless opt.fetch(:subnets, []).empty?
      opt = remove_empty_strings(opt)
      opt = only_keys_matching(opt, whitelist)
      elb.create_load_balancer(opt)
    end

    desc 'delete NAME', 'delete load-balancer'
    def delete(name)
      if yes? "really delete ELB #{name}?", :yellow
        elb.delete_load_balancer(load_balancer_name: name)
      end
    end

  end

end