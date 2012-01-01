class Answer < ActiveRecord::Base
  belongs_to :voter
  belongs_to :question
  belongs_to :possible_response

  scope :for, lambda{|question| where("question_id = #{question.id}")}
  scope :within, lambda { |from, to| where(:created_at => from..(to + 1.day))}
  scope :belong_to, lambda { |campaign_voters| where(:voter_id => campaign_voters)}
end
