# frozen_string_literal: true

require 'tempfile'
require 'securerandom'

class VirtualMachine
  include LibvirtAsync::WithDbg



  attr_reader :domain,
              :hypervisor

  attr_accessor :id,
                :name,
                :cpus,
                :memory,
                :state,
                :xml

  class << self
    def all
      Hypervisor.all.map(&:virtual_machines).flatten
    end

    def find_by(id:)
      all.detect { |domain| domain.id == id }
    end

    # def create(attrs)
    #   factory = DomainFactory.new(memory: attrs[:memory], cpus: attrs[:cpus])
    #   domain  = CLIENT.define_domain_xml(factory.to_xml)
    #   new(domain)
    # end
  end

  def initialize(domain:, hypervisor:)
    @domain = domain
    @hypervisor = hypervisor
    setup_attributes
  end

  def setup_attributes
    self.id = domain.uuid
    self.name = domain.name
    self.state = get_state
    self.cpus = get_cpus
    self.memory = domain.max_memory
    self.xml = domain.xml_desc
  end

  def tags
    nil
  end

  def running?
    state == 'running'
  end

  def get_cpus
    if running?
      domain.max_vcpus
    else
      # domain.vcpus.count
    end
  end

  def get_state
    state, _ = domain.get_state
    state.to_s.downcase
  end

  # @param [Symbol]
  # @raise [ArgumentError]
  # @raise [Libvirt::Error]
  def set_state(state)
    case state
    when :RUNNING
      domain.start
    when :SHUTDOWN
      domain.shutdown(1)
    when :SHUTOFF
      domain.power_off
    when :SUSPEND
      domain.suspend
    when :RESUME
      domain.resume
    when :REBOOT
      domain.reboot
    when :RESET
      domain.reset
    when :PAUSE
      domain.save_memory
    when :RESTORE
      domain.start
      domain.resume
    else
      raise ArgumentError, "invalid state #{state}"
    end
  end

  # Take screenshot asynchronously.
  # @param opaque [Object]
  # @param display [Integer] default 0
  # @yield when stream receive data
  # @yieldparam stream [Libvirt::Stream]
  # @yieldparam events [Integer]
  # @yieldparam opaque [Object]
  # @return [Libvirt::Stream]
  def take_screenshot(opaque, display = 0, &block)
    stream = hypervisor.create_stream
    domain.screenshot(stream, display)
    stream.event_add_callback(
        Libvirt::Stream::EVENT_READABLE,
        opaque,
        &block
    )
    stream
  end

  # @param event_id [Symbol]
  # @param opaque [Object,NilClass]
  # @yieldparam conn [Libvirt::Connection]
  # @yieldparam dom [Libvirt::Domain]
  # @yieldparam *args [Array] specific event arguments
  # @yieldparam opaque [Object,NilClass]
  def register_event_callback(event_id, opaque = nil, &block)
    hypervisor.register_domain_event_callback(
        event_id,
        domain,
        opaque,
        &block
    )
  end

  # def start
  #   domain.create
  # rescue Libvirt::Error => exception
  #   case exception.libvirt_message
  #   when 'Requested operation is not valid: domain is already running'
  #     return domain
  #   end
  # end
  #
  # def shutdown
  #   domain.shutdown if running?
  # end
  #
  # def halt
  #   domain.destroy if running?
  # end
  #
  # def update
  #   raise NotImplementedError
  # end
  #
  # def destroy
  #   shutdown if running?
  #   domain.undefine
  # end
end
