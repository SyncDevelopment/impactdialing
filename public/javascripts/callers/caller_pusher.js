Pusher.log = function(message) {
    if (window.console && window.console.log) window.console.log(message);
};

var channel = null;


$(document).ready(function() {
    hide_all_actions();
    setInterval(function() {
        if ($("#caller_session").val()) {
            //do nothing if the caller session context already exists
        } else {
            get_session();
        }
    }, 5000); //end setInterval

    $('#scheduled_date').datepicker();
})

function hide_all_actions() {
    $("#skip_voter").hide();
    $("#call_voter").hide();
    $("#stop_calling").hide();
    $("#hangup_call").hide();
    $("#submit_and_keep_call").hide();
    $("#submit_and_stop_call").hide();

}


function set_session(session_id) {
    $("#caller_session").val(session_id);
}

function get_session() {
    $.ajax({
        url : "/caller/active_session",
        data : {id : $("#caller").val(), campaign_id : $("#campaign").val() },
        type : "POST",
        success : function(json) {
            if (json.caller_session.id) {
                set_session(json.caller_session.id);
                subscribe(json.caller_session.session_key);
                $("#callin_data").hide();
                $('#start_calling').hide();
                $('#stop_calling').show();
                $("#called_in").show();
                get_voter();
            }
        }
    })
}

function get_voter() {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/preview_voter",
        data : {id : $("#caller").val(), session_id : $("#caller_session").val(), voter_id: $("#current_voter").val() },
        type : "POST",
        success : function(response) {
        }
    })
}


function next_voter() {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/skip_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'caller_next_voter' event to browsers
        }
    })
}

function call_voter() {
    console.log('called voter');
    hide_all_actions();
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/call_voter",
        data : {id : $("#caller").val(), voter_id : $("#current_voter").val(), session_id : $("#caller_session").val() },
        type : "POST",
        success : function(response) {
            // pushes 'calling_voter'' event to browsers
        }
    })
}


function schedule_for_later() {
    hide_all_actions();
    var date = $('#scheduled_date').val();
    var hours = $('select#callback_time_hours option:selected').val();
    var minutes = $('select#callback_time_minutes option:selected').val();
    var date_time = date + " " + hours + ":" + minutes;
    $.post("/call_attempts/" + $('#current_call_attempt').val(),
        {_method: 'PUT', call_attempt : { scheduled_date : $('#scheduled_date').val()}},
        function(response) {
        }
    );
}

function send_voter_response() {
    console.log('submit voter response')
    $('#voter_responses').attr('action', "/call_attempts/" + $("#current_call_attempt").val() + "/voter_response");
    var vid = $('#voter_id').val($("#current_voter").val())
    $('#voter_responses').submit(function() {
        $(this).ajaxSubmit({});
        return false;
    });
    if (!vid) {
        alert("voter context not found.")
    } else {
        $("#voter_responses").trigger("submit");
        $("#voter_responses").unbind("submit");
    }


}

function send_voter_response_and_disconnect() {
    var options = {
	    data: {stop_calling: true },
        success:  function() {
            disconnect_caller();
        }
    };
    var str = $("#voter_responses").serializeArray();
    $('#voter_responses').attr('action', "/call_attempts/" + $("#current_call_attempt").val() + "/voter_response");
    $('#voter_id').val($("#current_voter").val())
    $('#voter_responses').submit(function() {
        $(this).ajaxSubmit(options);
        return false;
    });
    $("#voter_responses").trigger("submit");
    $("#voter_responses").unbind("submit");
}

function disconnect_caller() {
    var session_id = $("#caller_session").val();
    if (session_id) {
        $.ajax({
            url : "/caller/" + $("#caller").val() + "/stop_calling",
            data : {session_id : session_id },
            type : "POST",
            success : function(response) {
                if (FlashDetect.installed && flash_supported())
                    $("#start_calling").show();
                // pushes 'calling_voter'' event to browsers
            }
        })
    }else{
        hide_all_actions();
        $("#start_calling").show();
    }
}

function disconnect_voter() {
    $.ajax({
        url : "/call_attempts/" + $("#current_call_attempt").val() + "/hangup",
        type : "POST",
        success : function(response) {
            // pushes 'calling_voter'' event to browsers
        }
    })
}

function dial_in_caller() {

    $.ajax({
        url : "/caller/" + $("#caller").val() + "/start_calling",
        data : {campaign_id : $("#campaign").val() },
        type : "POST",
        success : function(response) {
            $('#start_calling').hide();
        }
    })


}

function show_response_panel() {
    $("#response_panel").show();
    $("#result_instruction").hide();
}


function hide_response_panel() {
    $("#response_panel").hide();
    $("#result_instruction").show();
}

function set_message(text) {
    $("#statusdiv").html(text);
}

function collapse_scheduler() {
    $('#schedule_callback').show();
    $("#callback_info").hide();
}

function expand_scheduler() {
    $('#schedule_callback').hide();
    $("#callback_info").show();
}

function ready_for_calls(data) {
    if (data.dialer && data.dialer.toLowerCase() == "progressive") {
        $("#stop_calling").show();
        call_voter();
    }
    if (data.dialer && data.dialer.toLowerCase() == "preview") {
        $("#stop_calling").show();
        $("#skip_voter").show();
        $("#call_voter").show();
    }

}

function set_new_campaign_script(data) {
    $('#campaign').val(data.campaign_id);
    $('#script').text(data.script);
}

function set_response_panel(data) {
    $.ajax({
        url : "/caller/" + $("#caller").val() + "/new_campaign_response_panel",
        data : {},
        type : "POST",
        success : function(response) {
            $('#response_panel').replaceWith(response);
        }
    })
}

function subscribe(session_key) {
    channel = pusher.subscribe(session_key);
    console.log(channel)


    channel.bind('caller_connected', function(data) {
        console.log('caller_connected' + data)
        hide_all_actions();
        $('#browserTestContainer').hide();
        $("#start_calling").hide();
        $("#callin_data").hide();
        hide_response_panel();
        $("#stop_calling").show();
        if (!$.isEmptyObject(data.fields)) {
            set_message("Status: Ready for calls.");
            set_voter(data);
            ready_for_calls(data)
        } else {
            $("#stop_calling").show();
            set_message("Status: There are no more numbers to call in this campaign.");
        }
    });

    channel.bind('conference_started', function(data) {
        ready_for_calls(data)
    });


    channel.bind('caller_connected_dialer', function(data) {
        hide_all_actions();
        $("#stop_calling").show();
        set_message("Status: Dialing.");
    });

    channel.bind('answered_by_machine', function(data) {
        if (data.dialer && data.dialer == 'preview') {
            set_message("Status: Ready for calls.");
        }
    });

    channel.bind('voter_push', function(data) {
        set_message("Status: Ready for calls.");
        set_voter(data);
        $("#start_calling").hide();
    });

    channel.bind('call_could_not_connect', function(data) {
        set_message("Status: Ready for calls.");
        set_voter(data);
        $("#start_calling").hide();
        if ($.isEmptyObject(data.fields)) {
            $("#stop_calling").show();

        }
        else {
            ready_for_calls(data);
        }
    });


    channel.bind('voter_disconnected', function(data) {
        hide_all_actions();
        show_response_panel();
        set_message("Status: Waiting for call results.");
        $("#submit_and_keep_call").show();
        $("#submit_and_stop_call").show();
    });

    channel.bind('voter_connected', function(data) {
        set_call_attempt(data.attempt_id);
        hide_all_actions();
        if (data.dialer && data.dialer != 'preview') {
            set_voter(data.voter);
            set_message("Status: Connected.")
        }
        show_response_panel();
        cleanup_previous_call_results();
        $("#hangup_call").show();
    });

    channel.bind('calling_voter', function(data) {
        set_message('Status: Call in progress.');
        hide_all_actions();
    });

    channel.bind('caller_disconnected', function(data) {
        clear_caller();
        clear_voter();
        hide_response_panel();
        set_message('Status: Not connected.');
        $("#callin_data").show();
        hide_all_actions();
        if (FlashDetect.installed && flash_supported())
            $("#start_calling").show();
    });

    channel.bind('waiting_for_result', function(data) {
        show_response_panel();
        set_message('Status: Waiting for call results.');
        hide_all_actions();
        $("#submit_and_keep_call").show();
        $("#submit_and_stop_call").show();
    });

    channel.bind('no_voter_on_call', function(data) {
        $('status').text("Status: Waiting for caller to be connected.")
    });

    channel.bind('predictive_successful_voter_response', function(data) {
        clear_voter();
        hide_response_panel();
        set_message("Status: Dialing.");
    });

    channel.bind('caller_re_assigned_to_campaign', function(data) {

        set_new_campaign_script(data);
        set_response_panel(data);
        clear_voter();
        if (data.dialer && (data.dialer.toLowerCase() == "preview" || data.dialer.toLowerCase() == "progressive")) {
            if (!$.isEmptyObject(data.fields)) {
                set_message("Status: Ready for calls.");
                set_voter(data);
            } else {
                $("#stop_calling").show();
                set_message("Status: There are no more numbers to call in this campaign.");
            }

        }
        else {
            $("#stop_calling").show();
        }
        alert("You have been re-assigned to " + data.campaign_name + ".");

    });

    function set_call_attempt(id) {
        $("#current_call_attempt").val(id);
    }

    function set_voter(data) {
        if (!$.isEmptyObject(data.fields)) {
            $("#voter_info_message").hide();
            $("#current_voter").val(data.fields.id);
            bind_voter(data);
            hide_response_panel();
            hide_all_actions();

        } else {
            clear_voter();
            hide_all_actions();
            hide_response_panel();
            set_message("Status: There are no more numbers to call in this campaign.");
            $("#stop_calling").show();
        }
    }

    function clear_caller() {
        $("#caller_session").val(null);
    }

    function clear_voter() {
        $("#voter_info_message").show();
        $("#current_voter").val(null);
        $('#voter_info').empty();
        hide_all_actions();

    }


    function bind_voter(data) {
        if (data.custom_fields) {
            var customList = []
            $.each(data.custom_fields, function(item) {
                customList.push({name:item, value:data.custom_fields[item]});
            });
            $.extend(data, {custom_field_list: customList})
        }

        var voter = ich.voter(data); //using ICanHaz a moustache. js like thingamagic
        $('#voter_info').empty();
        $('#voter_info').append(voter);
        alert(data.CustomID);
    }

    function cleanup_previous_call_results() {
        $("#response_panel select option:selected").attr('selected', false);
        $('.note_text').val('');
        $('#scheduled_date').val('')
        collapse_scheduler();
    }

}