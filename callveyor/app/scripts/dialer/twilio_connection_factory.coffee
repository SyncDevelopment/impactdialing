mod = angular.module('idTwilioConnectionHandlers', [
  'ui.router',
  'idFlash',
  'idTransition',
  'idTwilio'
])

mod.factory('idTwilioConnectionFactory', [
  '$rootScope', '$state', '$cacheFactory', 'idFlashFactory', 'idTwilioService', 'idTransitionPrevented'
  ($rootScope,   $state,   $cacheFactory,   idFlashFactory,   idTwilioService,   idTransitionPrevented) ->
    console.log 'idTwilioConnectionFactory'
    _twilioCache = $cacheFactory.get('Twilio') || $cacheFactory('Twilio')
    twilioParams = {}

    factory = {
      connect: (params) ->
        twilioParams = params
        idTwilioService.then(factory.resolved, factory.resolveError)

      connected: (connection) ->
        console.log 'connected', connection
        _twilioCache.put('connection', connection)
        p = $state.go('dialer.hold')
        p.catch(idTransitionPrevented)

      # ready: (device) ->
      #   console.log 'twilio connection ready', device

      disconnected: (connection) ->
        console.log 'twilio disconnected', connection

      error: (error) ->
        console.log 'report this problem', error
        idFlashFactory.now('error', 'Browser phone could not connect to the call center. Please dial-in to continue.', 5000)
        p = $state.go('dialer.ready')
        p.catch(idTransitionPrevented)

      resolved: (twilio) ->
        console.log 'idTwilioService resolved', twilio
        twilio.Device.connect(factory.connected)
        # twilio.Device.ready(handlers.ready)
        twilio.Device.disconnect(factory.disconnected)
        twilio.Device.error(factory.error)
        twilio.Device.connect(twilioParams)

      resolveError: (err) ->
        console.log 'idTwilioService error', err
        idFlashFactory.now('error', 'Browser phone setup failed. Please dial-in to continue.', 5000)
    }

    factory
])