'use strict'

mod = angular.module('pusherConnectionHandlers', [
  'idFlash',
  'angularSpinner'
])

mod.factory('pusherConnectionHandlerFactory', [
  '$rootScope', '$window', 'usSpinnerService', 'idFlashFactory',
  ($rootScope,   $window,   usSpinnerService,   idFlashFactory) ->
    # console.log 'pusherConnectionHandler'

    pusherError = (error) ->
      # console.log 'pusherError', wtf
      $window.Bugsnag.notifyException(error)
      idFlashFactory.now('danger', 'Something went wrong. We are working
to fix it.')

    reConnecting = (wtf) ->
      # console.log 'temporaryConnectionFailure', wtf
      idFlashFactory.now('warning', 'Your browser has lost its connection. Reconnecting...')

    connectionFailure = (wtf) ->
      # console.log 'connectionFailure', wtf
      idFlashFactory.now('warning', 'Your browser could not re-connect.')

    connectingIn = (delay) ->
      # console.log 'connectingIn', delay
      idFlashFactory.now('warning', "Your browser could not re-connect. Connecting in #{delay} seconds.")

    browserNotSupported = (wtf) ->
      # console.log 'browserNotSupported', wtf
      $rootScope.$broadcast('pusher:bad_browser')

    connectionHandler = {
      # Service resolved successfully
      success: (pusher) ->
        connecting = ->
          # console.log 'pusher-connecting'
          idFlashFactory.now('info', 'Establishing real-time connection...')
          pusher.connection.unbind('connecting', connecting)
          pusher.connection.bind('connecting', reConnecting)
          usSpinnerService.spin('global-spinner')

        initialConnectedHandler = (wtf) ->
          # console.log 'initialConnectedHandler', wtf
          usSpinnerService.stop('global-spinner')
          pusher.connection.unbind('connected', initialConnectedHandler)
          pusher.connection.bind('connected', runTimeConnectedHandler)
          $rootScope.$broadcast('pusher:ready')

        runTimeConnectedHandler = (obj) ->
          # console.log 'runTimeConnectedHandler', obj
          usSpinnerService.stop('global-spinner')
          idFlashFactory.now('success', 'Connected!', 4000)

        pusher.connection.bind('connecting_in', connectingIn)
        pusher.connection.bind('connecting', connecting)
        pusher.connection.bind('connected', initialConnectedHandler)
        pusher.connection.bind('failed', browserNotSupported)
        pusher.connection.bind('unavailable', connectionFailure)
      # Service did not resolve successfully. Most likely the pusher lib failed to load.
      loadError: (error) ->
        error ||= new Error("Pusher service failed to resolve.")
        $window.Bugsnag.notifyException(error)
        idFlashFactory.now('danger', 'An error occurred loading the page. Please refresh to try again.')
    }

    connectionHandler
])
