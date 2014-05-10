describe 'survey module', ->

  describe 'idSurvey directive', ->

    $rootScope = ''
    $compiler = ''
    $httpBackend = ''
    surveyTemplate = ''
    scope = ''
    element = ''

    # Load module under test
    beforeEach module 'survey'

    # Load template module
    # beforeEach module '/scripts/survey/survey.tpl.html'

    beforeEach(inject((_$rootScope_, _$compile_, _$httpBackend_) ->
      $rootScope = _$rootScope_
      $compile = _$compile_
      $httpBackend = _$httpBackend_
      $httpBackend.whenGET('/call_center/api/survey_fields.json').respond({})
      @tpl = '<div data-id-survey></div>'
      scope = _$rootScope_
      element = $compile(@tpl)(scope)
      scope.$digest()
    ))

    it('shows 2 buttons when survey.hideButtons = false', ->
      console.log 'element = ', element
      expect(element.find('button').length).toEqual(2)
      expect(element.html()).toContain('Save &amp; stop calling')
      expect(element.html()).toContain('Save &amp; continue')
    )

    it('hides buttons when survey.hideButtons = true', ->
      scope.hideButtons = true
      scope.$digest()
      expect(element.find('button').length).toEqual(2)
    )
