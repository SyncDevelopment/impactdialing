'use strict'

hold = angular.module('callveyor.dialer.hold', [
  'ui.router'
])

hold.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.hold', {
      views:
        callFlowButtons:
          templateUrl: "/callveyor/dialer/hold/callFlowButtons.tpl.html"
          controller: 'HoldCtrl.buttons'
        callStatus:
          templateUrl: '/callveyor/dialer/hold/callStatus.tpl.html'
          controller: 'HoldCtrl.status'
    })
])

hold.controller('HoldCtrl.buttons', [
  '$scope', '$state', '$timeout', '$cacheFactory', 'callStation', 'idHttpDialerFactory', 'idFlashFactory', 'usSpinnerService',
  ($scope,   $state,   $timeout,   $cacheFactory,   callStation,   idHttpDialerFactory,   idFlashFactory,   usSpinnerService) ->
    hold = {}
    hold.campaign = callStation.data.campaign
    hold.stopCalling = ->
      console.log 'stopCalling clicked'
      $state.go('dialer.stop')

    hold.dial = ->
      # update status > 'Dialing...'
      params            = {}
      contactCache      = $cacheFactory.get('contact')
      contact           = (contactCache.get('data') || {}).fields
      caller            = callStation.data.caller || {}
      params.session_id = caller.session_id
      params.voter_id   = contact.id

      idHttpDialerFactory.dial(caller.id, params)

      $scope.transitionInProgress = true
      hold.callStatusText         = 'Dialing...'

    hold.skip = ->
      # update status > 'Skipping...'
      # POST /skip
      # then -> update contact
      # error -> update status > 'Error + explain, maybe try again'
    $scope.hold ||= hold
])

hold.controller('HoldCtrl.status', [
  '$scope', 'callStation'
  ($scope,   callStation) ->
    hold = {}
    hold.callStatusText = switch callStation.data.campaign.type
                            when 'Power', 'Predictive'
                              'Dialing...'
                            when 'Preview'
                              'Waiting to dial...'
                            else
                              console.log 'Report this problem.'

    $scope.hold = hold
])
