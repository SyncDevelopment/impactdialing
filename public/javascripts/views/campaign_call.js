ImpactDialing.Views.CampaignCall = Backbone.View.extend({

  initialize: function(){
    this.lead_info = new ImpactDialing.Models.LeadInfo();
    this.caller_script = new ImpactDialing.Models.CallerScript();
    this.script_view  = new ImpactDialing.Views.CallerScript({model: this.caller_script,
      lead_info: this.lead_info, campaign_call: this.model});
    this.start_calling_view = new ImpactDialing.Views.StartCalling({model: this.model});

    this.schedule_callback_view = new ImpactDialing.Views.ScheduleCallback();
    this.caller_actions = new ImpactDialing.Views.CallerActions({model: this.model, lead_info: this.lead_info,
      schedule_callback: this.schedule_callback_view});
    this.caller_session = new ImpactDialing.Models.CallerSession();
    this.lead_info_view = new ImpactDialing.Views.LeadInfo({model: this.lead_info})

    this.fetchCallerInfo();
    $("#schedule_callback").html(this.schedule_callback_view.render().el);
  },


  render: function(){
    var self = this;
    this.caller_script.fetch({success: function(){
      self.renderScript();
    }});

  },

  renderScript: function(){
    $("#voter_responses").empty();
    $("#voter_responses").html(this.script_view.render().el);
    this.schedule_callback_view.render();
    $("#transfer-calls").hide();
    $('#transfer_button').html("Transfer");
    $("#schedule_callback").hide();
  },

  fetchCallerInfo: function(){
    var self = this;
    $.ajax({
      type: 'POST',
      url: "/callers/campaign_calls/token",
      dataType: "json",
      beforeSend: function(request)
        {
          var token = $("meta[name='csrf-token']").attr("content");
          request.setRequestHeader("X-CSRF-Token", token);
        },
      success: function(data){
        self.model.set(data);
        self.pusher = new Pusher(self.model.get("pusher_key"))
        self.channel = self.pusher.subscribe(self.model.get("session_key"));
        self.bindPusherEvents();
        $("#caller-actions").html(self.start_calling_view.render().el);
        var ios_url = "inapp://capture?campaign_id=" + self.model.get("campaign_id") +"&phone_number="+ self.model.get("phone_number") +
         "&caller_id=" + self.model.get("caller_id") + "&session_key=" + self.model.get("session_key") + "&token=" + self.model.get("twilio_token");
        $("#start-calling-mobile").attr("href", ios_url);
        $("#callin").show();
        if (!FlashDetect.installed || !flash_supported() || !browser_supported()){
          $("#start-calling").hide();
        }
        if(isNativeApp()){
         $("#start-calling-mobile").show();
         $(".webapp-callin-info").hide();
        }
        $("#callin-number").html(self.model.get("phone_number"));
        $("#callin-pin").html(self.model.get("pin"));
        self.stopCallingOnPageReload()
        self.setupTwilio();
        },
      error: function(jqXHR, textStatus, errorThrown){
        self.callerShouldNotDial(jqXHR["responseText"]);
      },
      });
  },

  stopCallingOnPageReload: function(){
    var self = this;
      $(window).bind("beforeunload", function() {
        if(self.model.has("session_id")){
          $.ajax({
            url : "/caller/" + self.model.get("caller_id") + "/stop_calling",
            data : {session_id : self.model.get("session_id") },
            type : "POST",
            async : false,
            success : function(response) {
              $("#start_calling").show();
            }
          });
        }
    });

  },

  callerShouldNotDial:  function(error){
    $("#caller-alert p strong").html(error);
    $("#caller-alert").addClass("callout alert clearfix")
  },

   setupTwilio:  function(){
    var self = this;
    Twilio.Device.setup(this.model.get("twilio_token"), {'debug':true});

    Twilio.Device.connect(function (conn) {
        $("#start_calling").hide();
    });
    Twilio.Device.ready(function (device) {
      client_ready=true;
    });
    Twilio.Device.error(function (error) {
      alert(error.message);
    });
  },

  bindPusherEvents: function(){
    var self = this;
    this.channel.bind('start_calling', function(data) {
      self.model.set("session_id", data.caller_session_id);
      $("#caller-actions").html(self.caller_actions.render().el);
      $("#caller-actions a").hide();
      $("#callin_data").hide();
      self.caller_actions.startCalling();
    });

    this.channel.bind('caller_connected_dialer', function(data) {
        self.model.unset("call_id")
        self.lead_info.clear();
        self.lead_info.set(data);
        self.renderScript();
        $("#voter_info_message").show();
        $("#voter_info").hide();
        self.caller_actions.callerConnectedDialer();
    });

    this.channel.bind('conference_started', function(data) {
      self.model.unset("call_id")
      self.lead_info.clear();
      self.lead_info.set(data);
      self.renderScript();
      $("#voter_info_message").hide();
      $("#voter_info").html(self.lead_info_view.render().el);
      self.caller_actions.conferenceStarted();
    });

    this.channel.bind('caller_reassigned', function(data) {
      self.caller_script.fetch({success: function(){
        self.renderScript();
        self.lead_info.clear();
        self.lead_info.set(data);
        $("#voter_info_message").hide();
        $("#voter_info").html(self.lead_info_view.render().el);
        self.caller_actions.conferenceStarted();
        alert("You have been re-assigned to " + data.campaign_name + ".");
      }});
    });



    this.channel.bind('calling_voter', function(data) {
      self.caller_actions.callingVoter();
    });

    this.channel.bind('voter_connected', function(data) {
      self.model.set("call_id", data.call_id);
      self.caller_actions.voterConnected();
    });

    this.channel.bind('voter_connected_dialer', function(data) {
      self.model.set("call_id", data.call_id);
      self.lead_info.clear();
      self.lead_info.set(data.voter)
      $("#voter_info_message").hide();
      $("#voter_info").show();
      $("#voter_info").html(self.lead_info_view.render().el);
      self.caller_actions.voterConnectedDialer();
    });

    this.channel.bind('voter_disconnected', function(data) {
      self.caller_actions.voterDisconected();
    });

    this.channel.bind('caller_disconnected', function(data) {
        var campaign_call = new ImpactDialing.Models.CampaignCall();
        campaign_call.set({pusher_key: data.pusher_key});
        var campaign_call_view = new ImpactDialing.Views.CampaignCall({model: campaign_call});
        campaign_call_view.render();
        self.lead_info.clear();
        $("#voter_info").html(self.lead_info_view.render().el);
        $("#voter_info_message").show();
    });

    this.channel.bind('transfer_busy', function(data) {
        self.caller_actions.showHangupButton();
    });

    this.channel.bind('transfer_connected', function(data) {
      self.model.set("transfer_type", data.type);
      self.model.set("transfer_call_id", self.model.get("call_id"));
    });

    this.channel.bind('transfer_conference_ended', function(data) {
      var transfer_type = self.model.get("transfer_type");
      if(transfer_type == "warm"){
        self.caller_actions.transferConferenceEnded();
      }
      self.model.unset("transfer_type");
      var transfer_section = self.script_view.transfer_section;
      transfer_section.render();
    });

    this.channel.bind('warm_transfer',function(data){
      self.caller_actions.kickSelfOutOfConferenceShow();
    });

    this.channel.bind('caller_kicked_off',function(data){
      self.caller_actions.callerKickedOff()
    });

  },



});