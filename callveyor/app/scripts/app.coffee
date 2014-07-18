'use strict'

idTransition = angular.module('idTransition', [
  'idCacheFactories',
  'angularSpinner'
])
idTransition.factory('idTransitionPrevented', [
  '$rootScope', '$state', 'ErrorCache', 'FlashCache', 'usSpinnerService',
  ($rootScope,   $state,   ErrorCache,   FlashCache,   usSpinnerService) ->
    isFailedResolve = (err) ->
      err.config? and err.config.url? and /(GET|POST)/.test(err.config.method)

    fn = (errObj) ->
      console.log 'report this problem', errObj
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')

      if isFailedResolve(errObj)
        # record the time & error
        key = (new Date()).getTime()
        val = {error: errObj, context: 'Remote $state dependency failed to resolve.'}
        ErrorCache.put(key, val)

        FlashCache.put('error', errObj.data.message)
        $state.go('abort')

    fn
])

callveyor = angular.module('callveyor', [
  'config',
  'ui.bootstrap',
  'ui.router',
  'doowb.angular-pusher',
  'pusherConnectionHandlers',
  'idTwilio',
  'idFlash',
  'idTransition',
  'idCacheFactories',
  'angularSpinner',
  'callveyor.dialer'
])

callveyor.config([
  '$stateProvider', 'serviceTokens', 'idTwilioServiceProvider', 'PusherServiceProvider',
  ($stateProvider,   serviceTokens,   idTwilioServiceProvider,   PusherServiceProvider) ->
    idTwilioServiceProvider.setScriptUrl('//static.twilio.com/libs/twiliojs/1.2/twilio.js')
    PusherServiceProvider.setPusherUrl('//d3dy5gmtp8yhk7.cloudfront.net/2.1/pusher.min.js')
    PusherServiceProvider.setToken(serviceTokens.pusher)


    $stateProvider.state('abort', {
      template: ''
      controller: 'AppCtrl.abort'
    })
])

callveyor.controller('AppCtrl.abort', [
  '$http', 'TwilioCache', 'FlashCache', 'PusherService', 'idFlashFactory',
  ($http,   TwilioCache,   FlashCache,   PusherService,   idFlashFactory) ->
    # console.log 'AppCtrl.abort', FlashCache.get('error'), FlashCache.info()
    flash = FlashCache.get('error')
    idFlashFactory.now('danger', flash)
    FlashCache.remove('error')
    # console.log 'AppCtrl.abort', flash

    twilioConnection = TwilioCache.get('connection')

    if twilioConnection?
      twilioConnection.disconnect()

    PusherService.then((p) ->
      console.log 'PusherService abort', p
    )
])

callveyor.controller('MetaCtrl', [
  '$scope',
  ($scope) ->
    # todo: de-register the $watch on $scope.meta.currentYear
    $scope.currentYear = (new Date()).getFullYear()
])

callveyor.directive('idLogout', ->
  {
    restrict: 'A'
    template: '<button class="btn btn-primary navbar-btn"'+
                      'data-ng-click="logout()">'+
                'Logout'+
              '</button>'
    controller: [
      '$scope', '$http', 'ErrorCache', 'idFlashFactory',
      ($scope,   $http,   ErrorCache,   idFlashFactory) ->
        $scope.logout = ->
          promise = $http.post("/app/logout")
          suc = ->
            window.location.reload(true)
          err = (e) ->
            ErrorCache.put("logout.failed", e)
            idFlashFactory.now('danger', "Logout failed.")

          promise.then(suc,err)
    ]
  }
)

callveyor.controller('AppCtrl', [
  '$rootScope', '$scope', '$state', '$timeout', 'usSpinnerService', 'PusherService', 'pusherConnectionHandlerFactory', 'idFlashFactory', 'idTransitionPrevented', 'TransitionCache', 'ContactCache', 'CallStationCache',
  ($rootScope,   $scope,   $state,   $timeout,   usSpinnerService,   PusherService,   pusherConnectionHandlerFactory,   idFlashFactory,   idTransitionPrevented,   TransitionCache,   ContactCache,   CallStationCache) ->
    $rootScope.transitionInProgress = false
    getContact = ->
      contact = ContactCache.get('data')
      phone   = ''
      id      = ''
      if contact? and contact.fields?
        id    = contact.fields.id
        phone = contact.fields.phone
      {id, phone}
    getMeta = ->
      caller = CallStationCache.get('caller')
      campaign = CallStationCache.get('campaign')
      {caller, campaign}
    # handle generic state change conditions
    transitionStart = (event, toState, toParams, fromState, fromParams) ->
      contact = getContact()
      TransitionCache.put('$stateChangeStart', {toState: toState.name, fromState: fromState.name, contact})
      usSpinnerService.spin('global-spinner')
      $rootScope.transitionInProgress = true
    transitionComplete = (event, toState, toParams, fromState, fromParams) ->
      contact = getContact()
      meta  = getMeta()
      TransitionCache.put('$stateChangeSuccess', {toState: toState.name, fromState: fromState.name, contact, meta})
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')
    transitionError = (event, unfoundState, fromState, fromParams) ->
      # todo: submit error to error collection tool
      console.error 'Error transitioning $state', event, unfoundState, fromState, fromParams
      contact = getContact()
      meta  = getMeta()
      TransitionCache.put('$stateChangeError', {unfoundState: unfoundState.name, fromState: fromState.name, contact, meta})
      # hmm: $stateChangeError seems to not be thrown when preventDefault is called
      # if e.message == 'transition prevented'
      #   # something called .preventDefault, probably the transitionGateway
      #   console.log 'todo: report transition prevented error to collection tool'
      $rootScope.transitionInProgress = false
      usSpinnerService.stop('global-spinner')

    $rootScope.$on('$stateChangeStart', transitionStart)
    $rootScope.$on('$stateChangeSuccess', transitionComplete)
    $rootScope.$on('$stateChangeError', transitionError)

    # handle pusher app-specific events
    markPusherReady = ->
      now = ->
        p = $state.go('dialer.ready')
        p.catch(idTransitionPrevented)
      $timeout(now, 300)
    abortAllAndNotifyUser = ->
      # todo: implement
      console.log 'Unsupported browser...'
      TransitionCache.put('pusher:bad_browser', '.')

    $rootScope.$on('pusher:ready', markPusherReady)
    $rootScope.$on('pusher:bad_browser', abortAllAndNotifyUser)

    PusherService.then(pusherConnectionHandlerFactory.success,
                       pusherConnectionHandlerFactory.loadError)
])
