module CallPayment
  
  module ClassMethods    
  end
  
  module InstanceMethods
    
    def debit
      account = campaign.account
      return  if call_not_connected? || !payment_id.nil? || account.manual_subscription?
      payment = Payment.where("amount_remaining > 0 and account_id = ?", account).last
      if payment.nil?      
        payment = account.check_autorecharge(account.current_balance)
      end
      
      unless payment.nil?              
        payment.debit_call_charge(amount_to_debit, account)
        self.update_attributes(payment_id: payment.try(:id))
        account.check_autorecharge(account.current_balance)
      end
    end
    
    def amount_to_debit
      call_time.to_f * determine_call_cost
    end
    
    def determine_call_cost
      return 0.02 if campaign.account.per_caller_subscription?      
      campaign.cost_per_minute
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end