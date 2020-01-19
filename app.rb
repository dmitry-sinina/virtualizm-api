require_relative 'config/environment'

Dir.glob('app/**/*.rb').sort.each { |filename| require_relative filename }

# initialize application
require_relative 'config/initializer'

LibvirtApp.add_server :api_cable, AsyncCable::Server.new(connection_class: ApiCable)

# build application server
LibvirtApp.app = Rack::Builder.new do
  if LibvirtApp.config.serve_static
    urls = %w(/screenshots)
    static_root = LibvirtApp.root.join('public')
    LibvirtApp.logger.info { "Serve static folders [#{urls.join(',')}] from #{static_root}" }
    use Rack::Protection::PathTraversal
    use Rack::Static, urls: urls, root: static_root
  end

  use Rack::XRequestId, logger: LibvirtApp.logger
  use Rack::MethodOverride
  use Rack::Session::Cookie, key: LibvirtApp.config.cookie_name, secret: LibvirtApp.config.cookie_secret
  use Rack::ImprovedLogger, LibvirtApp.logger
  use Rack::Protection::CookieTossing
  use Rack::Protection::IPSpoofing
  use Rack::Protection::SessionHijacking

  use Rack::Router::Middleware, logger: LibvirtApp.logger do
    not_found :default

    get '/api_cable', -> (env) do
      LibvirtApp.find_server(:api_cable).call(env)
    end

    namespace :api do
      post '/sessions', [SessionsController, :create]
      get '/sessions', [SessionsController, :show]
      delete '/sessions', [SessionsController, :destroy]

      get '/hypervisors', [HypervisorsController, :index]
      get '/hypervisors/:id', [HypervisorsController, :show]

      get '/virtual-machines', [VirtualMachinesController, :index]
      get '/virtual-machines/:id', [VirtualMachinesController, :show]
    end
  end

  run ->(env) do
    route_result = env[Rack::Router::RACK_ROUTER_PATH]
    return route_result.call(env) if route_result.is_a?(Proc)

    controller_class, action = *route_result
    controller_class.call(env, action)
  end
end
