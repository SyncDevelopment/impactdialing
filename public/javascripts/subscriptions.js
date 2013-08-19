var Subscriptions = function(){
	if($("#subscription_type").val() == "PerMinute"){
  	this.showPerMinuteOptions();
   }else{
   	this.showPerAgentOptions();
   }
   this.submitPaymentEvent();
   this.subscriptionTypeChangeEvent();
   this.number_of_callers_reduced();

}

Subscriptions.prototype.showPerMinuteOptions = function(){
	$("#add_to_balance").show();
  $("#num_of_callers_section").hide();
}

Subscriptions.prototype.showPerAgentOptions = function(){
	$("#add_to_balance").hide();
	$("#num_of_callers_section").show(); 
}

Subscriptions.prototype.stripeResponseHandler = function(status, response){
	var $form = $('#payment-form');
    if (response.error) {
      $('#payment-flash').show();
      $('.payment-errors').text(response.error.message);
      $form.find('button').prop('disabled', false);
      } else {
      $('#payment-flash').hide();
      $('.payment-errors').text("");
      var token = response.id;        
      $form.append($('<input type="hidden" name="subscription[stripeToken]" />').val(token));        
      $form.get(0).submit();
     }
}

Subscriptions.prototype.submitPaymentEvent = function(){
	var self = this;
	$('#submit-payment').click(function(event) {
  	var $form = $("#payment-form");
    $form.find('button').prop('disabled', true);        
    Stripe.createToken($form, self.stripeResponseHandler);       
    return false;
   });
}

Subscriptions.prototype.subscriptionTypeChangeEvent = function(){
	var self = this;
	$("#subscription_type").change(function() {
  	if($(this).val() == "PerMinute"){
    	self.showPerMinuteOptions();        
    }else{
    	self.showPerAgentOptions();
    }
	});
}

Subscriptions.prototype.number_of_callers_reduced = function(){
	$("#number_of_callers").on("change", function(){
		if($(this).val()< 1){
			alert("You need to have atleast 1 caller.")			
			return;
		}
		if($(this).val() < $(this).data("value")){
			alert("On reducing the number of callers your minutes you paid for will still be retained, however you wont be refunded for the payment already made for the caller.")
		}
		
	})
}

