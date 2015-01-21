'use strict'

surveyForm = angular.module('survey', [
  'ui.router',
  'angularSpinner',
  'idFlash',
  'idCacheFactories',
  'Janitor'
])

# surveyForm.config([])

surveyForm.factory('SurveyFormFieldsFactory', [
  '$http', '$filter', '$sce',
  ($http,   $filter,   $sce) ->
    fields = {
      data: {}
      prepareSurveyForm: (payload) ->
        normalizeObj = (object, type) ->
          obj = {
            id: object.id
            order: object.script_order
            type: ''
            content: ''
          }
          switch type
            when 'notes'
              obj.type = 'note'
              obj.content = object.note
            when 'script_texts'
              obj.type = 'scriptText'
              obj.content = $sce.trustAsHtml(object.markdown_content)
            when 'questions'
              obj.type = 'question'
              obj.content = object.text
              obj.possibleResponses = object.possible_responses
          obj

        normalizedSurvey = []
        normalizeSurvey  = (arr, type) ->
          switch type
            when 'notes', 'script_texts', 'questions'
              angular.forEach(arr, (obj) ->
                normalizedSurvey.push(normalizeObj(obj, type))
              )

        angular.forEach(payload.data, (obj, type) ->
          normalizeSurvey(obj, type)
        )
        console.log 'normal survey', normalizedSurvey
        fields.data = $filter('orderBy')(normalizedSurvey, 'order')

      fetch: ->
        $http.get('/call_center/api/survey_fields.json')
    }
])

##
# SurveyFormCtrl manages
# - loading of survey form data, including the list of transfers
#   associated w/ the campaign
# - saving survey responses
#
# Notifications:
# - survey:load:success - $broadcast when form data is fetched and loaded.
# - survey:save:success, {andContinue} - $broadcast when survey save returns success response
# - survey:save:done, {andContinue} - $broadcast when survey save returns failure response
#
# Listeners:
# - $stateChangeSuccess - triggers hide/show buttons according to toState.name
# - survey:save:click - triggers survey response submission
# - survey:reload - triggers re-fetch/load of survey form data & transfer list
#
surveyForm.controller('SurveyFormCtrl', [
  '$rootScope', '$scope', '$filter', '$state', '$http', '$window', '$timeout', 'TransferCache', 'CallCache', 'TwilioCache', 'usSpinnerService', 'SurveyFormFieldsFactory', 'idFlashFactory', 'SurveyCache', 'ErrorCache', 'idJanitor', 'ContactCache',
  ($rootScope,   $scope,   $filter,   $state,   $http,   $window,   $timeout,   TransferCache,   CallCache,   TwilioCache,   usSpinnerService,   SurveyFormFieldsFactory,   idFlashFactory,   SurveyCache,   ErrorCache,   idJanitor,   ContactCache) ->
    # Public 
    survey = {
      hideButtons: true
      responses: {
        notes: {}
        question: {}
      }
    }

    # SurveyCache.put('responses', survey.responses)

    selectDefaults = ->
      console.log 'selectDefaults'
      # :ngupsetting:
      # set default value to avoid displaying blank options
      angular.forEach(survey.form, (item) ->
        console.log 'item', item
        if item.type == 'question' and !survey.responses.question[item.id]?
          console.log "setting #{item.id} = #{item.possibleResponses[0].id}"
          survey.responses.question["#{item.id}"] = item.possibleResponses[0]
      )
      $timeout(-> $scope.$digest())
      # :endngupsetting:

    reset = ->
      console.log 'reset survey'
      survey.responses = {
        voter_id: null
        notes: {}
        question: {}
      }
      CallCache.remove('id')
      CallCache.remove('voter_id')

      selectDefaults()

    # :tmp: to maintain back compat (where transfers are sent alongside call script data)
    # todo: move transfer data out of survey related modules to dialer
    cacheTransferList = (payload) ->
      list          = payload.data.transfers
      # coldOnly      = (transfer) -> transfer.transfer_type == 'cold'
      # list          = $filter('filter')(list, coldOnly)
      TransferCache.put('list', list)
    # :endtmp:

    fetchErr = (e) ->
      err = new Error("Survey fields failed to load")
      $window._errs.meta = {
        'Status': e.status,
        'StatusText': e.statusText,
        'Data': e.data
      }
      $window._errs.push(err)
      idFlashFactory.now('danger', 'Survey failed to load. Please refresh the page to try again.')
    prepForm = (payload) ->
      SurveyFormFieldsFactory.prepareSurveyForm(payload)
      survey.form = SurveyFormFieldsFactory.data
      selectDefaults()
      # :tmp:
      cacheTransferList(payload)
      # :endtmp:
      $rootScope.$broadcast('survey:load:success')

    loadForm = ->
      SurveyFormFieldsFactory.fetch().then(prepForm, fetchErr)

    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      switch toState.name
        when 'dialer.wrap'
          survey.hideButtons = false
        else
          survey.hideButtons = true

    $rootScope.$on('$stateChangeSuccess', handleStateChange)

    normalizeQuestion = ->
      normalized = {}
      for question_id, response of survey.responses.question
        normalized[question_id] = response.id

      normalized

    updateVoterId = (voter) -> CallCache.put('voter_id', voter.id)

    callAndVoter = ->
      call_id  = CallCache.get('id')
      voter_id = CallCache.get('voter_id')

      unless call_id? and voter_id?
        ErrorCache.put('survey.save.failed', "Call or Voter had no ID: Call[#{call_id}] Voter[#{voter_id}].")
        idFlashFactory.now('danger', 'You found a bug! Please report problem and we will have you up and running ASAP.')
        return false
      else
        return {call_id, voter_id}

    requestInProgress = false
    survey.save = ($event, andContinue) ->
      if requestInProgress
        console.log 'survey.requestInProgress, returning'
        return

      usSpinnerService.spin('global-spinner')

      ids = callAndVoter()
      return unless ids.call_id? and ids.voter_id?

      action = 'submit_result'
      unless andContinue
        action += '_and_stop'
        TwilioCache.put('disconnect_pending', 1)

      successRan = false
      success = (resp) ->
        # console.log 'survey.success', resp
        reset()
        $rootScope.$broadcast('survey:save:success', {andContinue})
        successRan = true
      error = (resp) ->
        # console.log 'survey.error', resp
        msg = ''
        switch resp.status
          when 400 # bad request, try again and contact support
            msg += 'Bad request. Try again and report problem if error continues.'
          when 408, 504 # server/gatewa timeout, try again and contact support
            msg += 'Browser took too long sending data. Verify internet connection and try again. Report problem if the error continues.'
          when 500 # server error, try again and contact support
            msg += 'Server error. We have been notified and will update account holders soon. Report problem then Stop calling.'
          when 503 # server unavailable/in maintenance, wait a minute, try again and contact support
            msg += 'Minor maintenance in-progress. Try again in a minute or so. Report problem if the error continues.'
          else
            msg += 'Please try again and Report problem if the error continues.'
        idFlashFactory.now('danger', msg)
        $rootScope.transitionInProgress = false
      always = (resp) ->
        # console.log 'survey.always, successRan', successRan
        requestInProgress = false

        if andContinue and successRan
          usSpinnerService.spin('global-spinner')
        else
          usSpinnerService.stop('global-spinner')
          $rootScope.transitionInProgress = false

        $rootScope.$broadcast('survey:save:done', {andContinue})

      requestInProgress               = true
      $rootScope.transitionInProgress = true
      
      # make a request, get a promise
      $http.post("/call_center/api/#{ids.call_id}/#{action}", {
        voter_id: ids.voter_id,
        notes: survey.responses.notes,
        question: normalizeQuestion()
      })
      .then(success, error).finally(always)

    survey.autoSubmitConfig = ->
      ids = callAndVoter()
      return unless ids.call_id? and ids.voter_id?
      {
        url: "/call_center/api/#{ids.call_id}/submit_result_and_stop"
        data: {
          voter_id: ids.voter_id
          notes: survey.responses.notes
          question: normalizeQuestion()
        }
      }

    unless SurveyCache.get('eventsBound')
      $rootScope.$on('survey:save:click', survey.save)
      $rootScope.$on('survey:reload', loadForm)
      $rootScope.$on('household:member:selected', updateVoterId)
      idJanitor.cleanUpUnload(true, survey.autoSubmitConfig)
      SurveyCache.put('eventsBound', true)

    loadForm()

    $scope.survey ||= survey
])

surveyForm.directive('idSurvey', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/survey/survey.tpl.html'
    controller: 'SurveyFormCtrl'
  }
)
