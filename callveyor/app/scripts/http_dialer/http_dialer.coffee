'use strict'

mod = angular.module('callveyor.http_dialer', [
  'idFlash',
  'angularSpinner'
])

mod.factory('idHttpDialerFactory', [
  '$rootScope', '$timeout', '$http', 'idFlashFactory', 'usSpinnerService',
  ($rootScope,   $timeout,   $http,   idFlashFactory,   usSpinnerService) ->
    dialer = {}

    dial = (url, params) ->
      usSpinnerService.spin('global-spinner')
      $http.post(url, params)

    success = (resp, status, headers, config) ->
      console.log 'dialer factory success', resp
      dialer.caller_id = undefined
      dialer.params    = undefined
      dialer.retry     = false
      $rootScope.$broadcast('http_dialer:success', resp)
    error = (resp, status, headers, config) ->
      console.log 'dialer factory error', resp
      if dialer.retry && /(408|500|504)/.test(resp.status)
        $rootScope.$broadcast('http_dialer:retrying', resp)
        dialer[dialer.retry](dialer.caller_id, dialer.params, false)
      else
        $rootScope.$broadcast('http_dialer:error', resp)

    dialer.retry = false

    dialer.dialContact = (caller_id, params, retry) ->
      unless caller_id? and params? and params.session_id? and params.voter_id?
        throw new Error("idHttpDialerFactory.dialContact(#{caller_id}, #{(params || {}).session_id}, #{(params || {}).voter_id}) called with invalid arguments. caller_id, params.session_id and params.voter_id are all required")

      if retry
        dialer.caller_id = caller_id
        dialer.params    = params
        dialer.retry     = 'dialContact'
      else
        dialer.caller_id = undefined
        dialer.params    = undefined
        dialer.retry     = false

      url          = "/call_center/api/#{caller_id}/call_voter"
      dial(url, params).then(success, error)

    dialer.skipContact = (caller_id, params) ->
      dialer.retry = false
      usSpinnerService.spin('global-spinner')

      url = "/call_center/api/#{caller_id}/skip_voter"

      $http.post(url, params) #.then(success, error)

    dialer.dialTransfer = (params, retry) ->
      dialer.retry = false

      url          = "/call_center/api/transfer/dial"
      dial(url, params).then(success, error)

    dialer
])
