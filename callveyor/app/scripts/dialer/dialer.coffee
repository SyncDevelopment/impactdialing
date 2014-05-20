'use strict'

dialer = angular.module('callveyor.dialer', [
  'ui.router',
  'doowb.angular-pusher',
  'callveyor.dialer.ready',
  'callveyor.dialer.hold',
  'callveyor.dialer.active',
  'callveyor.dialer.wrap',
  'callveyor.dialer.stop',
  'survey',
  'callveyor.contact',
  'callveyor.call_flow'
])

dialer.config([
  '$stateProvider',
  ($stateProvider) ->
    $stateProvider.state('dialer', {
      abstract: true
      templateUrl: '/scripts/dialer/dialer.tpl.html'
      resolve:
        callStation: ($http) -> $http.post('/call_center/api/call_station.json')
      controller: 'DialerCtrl'
    })
])

dialer.constant('validTransitions', {
  'dialer.ready': ['dialer.hold'],
  'dialer.hold': ['dialer.active'],
  'dialer.active': ['dialer.wrap', 'dialer.stop', 'dialer.active.transfer.selected', 'dialer.active.transfer.reselected', 'dialer.active.transfer.conference'],
  'dialer.wrap': ['dialer.hold', 'dialer.stop'],
  'dialer.stop': ['dialer.ready']
})

dialer.controller('DialerCtrl', [
  '$rootScope', '$cacheFactory', 'Pusher', 'idCallFlow', 'callStation',
  ($rootScope,   $cacheFactory,   Pusher,   idCallFlow,   callStation) ->
    callStationCache = $cacheFactory('callStation')
    callStationCache.put('data', callStation.data)
    channel = callStation.data.caller.session_key

    ## Bind app call flow handlers
    $rootScope.$on('survey:save:success', idCallFlow.survey.save.success)

    ## Bind Pusher call flow handlers
    Pusher.subscribe(channel, 'start_calling', idCallFlow.startCalling)
    Pusher.subscribe(channel, 'conference_started', idCallFlow.conferenceStarted)
    Pusher.subscribe(channel, 'caller_connected_dialer', idCallFlow.callerConnectedDialer)
    Pusher.subscribe(channel, 'caller_reassigned', idCallFlow.callerReassigned)
    Pusher.subscribe(channel, 'calling_voter', idCallFlow.callingVoter)
    Pusher.subscribe(channel, 'voter_connected', idCallFlow.voterConnected)
    Pusher.subscribe(channel, 'voter_connected_dialer', idCallFlow.voterConnectedDialer)
    Pusher.subscribe(channel, 'voter_disconnected', idCallFlow.voterDisconnected)
    Pusher.subscribe(channel, 'caller_disconnected', idCallFlow.callerDisconnected)
    Pusher.subscribe(channel, 'transfer_busy', idCallFlow.transferBusy)
    Pusher.subscribe(channel, 'transfer_connected', idCallFlow.transferConnected)
    Pusher.subscribe(channel, 'transfer_conference_ended', idCallFlow.transferConferenceEnded)
    Pusher.subscribe(channel, 'warm_transfer', idCallFlow.warmTransfer)
    Pusher.subscribe(channel, 'cold_transfer', idCallFlow.coldTransfer)
    Pusher.subscribe(channel, 'caller_kicked_off', idCallFlow.callerKickedOff)
])
