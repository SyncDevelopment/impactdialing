'use strict'

userMessages = angular.module('idFlash', [
  'idDeviceDetect'
])

userMessages.factory('idFlashFactory', [
  '$timeout', 'idDeviceDetectFactory',
  ($timeout,   idDeviceDetectFactory) ->
    flash = {
      alerts: []
      nowAndDismiss: (type, message, dismissIn) ->
        console.log('idFLashFactory.nowAndDismiss', type, message)
        if idDeviceDetectFactory.isMobile()
          alert(message)
        else
          obj = {type, message}
          flash.alerts.push(obj)
          autoDismiss = ->
            index = flash.alerts.indexOf(obj)
            flash.dismiss(index)
          $timeout(autoDismiss, dismissIn)
      now: (type, message) ->
        console.log('idFLashFactory.now', type, message)
        if idDeviceDetectFactory.isMobile()
          alert(message)
        else
          flash.alerts.push({type, message})
      dismiss: (index) ->
        flash.alerts.splice(index, 1)
    }

    flash
])

userMessages.controller('idFlashCtrl', [
  '$scope', 'idFlashFactory',
  ($scope,   idFlashFactory) ->
    $scope.flash = idFlashFactory
])

userMessages.directive('idUserMessages', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/common/id_flash/id_flash.tpl.html'
    controller: 'idFlashCtrl'
  }
)
