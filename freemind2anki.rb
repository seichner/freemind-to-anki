#!/usr/bin/ruby
#
# Converts an XHTML export from Freemind Mindmaps to Anki (Spaced Repition Learning) CSV file
#    * Takes all nodes with a red-pencil-icon and turns them into Questions in Anki. 
#    * The Answer ("back side") in Anki will be the HTML list of the subnodes.
#    * Parent nodes will be included as "titles" (eg. "Highest Node > Parent Node" with 2 parent nodes)
#    * bonus: adds some tags for management in Anki
#    * IMPORTANT: import with "separated with ,"! (defaults to space in Anki)
#
# Probably works best with mindmaps that are structured sort of like this:
# (root node) -> 1+ Title Node -> Anki's Front Side -> Subnodes as Anki's back side
# eg (2 title nodes): ("Coaching Mindmap") -> "Coaching Questions" -> "Scaling Questions" > "2-dimensional scaling" -> (...explanations)
# results in...
# Front side: 
#      Coaching Questions > Scaling Questions
#      2-dimensional scaling
#
# Back side: (...explanations)
#

require 'nokogiri'
require 'csv'

input_filename = ARGV[0] || "index.html"
csv_filename = ARGV[1] || input_filename.gsub(/\.html?$/, '.csv' ) # best guess (replace suffix)
csv_filename = "#{input_filename}.csv" unless csv_filename # last guess ;-) (add suffix)

doc = File.open(input_filename) { |f| Nokogiri::XML(f) }

raise "Freemind XHTML file '#{input_filename}' doesn't exist!" unless File.exist?(input_filename)

root_name = doc.css('[class="nodecontent"]').first.content
timestamp = Time.now.strftime("%Y-%m-%d_%H-%M")

pencils = doc.css('[alt="pencil"]')

cards = pencils.map do |pencil|

  question = pencil.parent.css('[class="nodecontent"]').first
  ancestor_lis = question.ancestors.select{|node| node.node_name=="li"}

  question_parents = ancestor_lis[1..-2].map do |li|
    name_node = li.css('[class="nodecontent"]').first
    name_node.content
  end.map(&:strip).reverse

  answer = question.parent.css('/ul').first

  # return our intermediate struct representation
  {
    question: question.content,
    parents: question_parents,
    html: answer.to_html,
    #text: answer.content,
  }
end


File.rename(csv_filename, "#{csv_filename}.old") if File.exists?(csv_filename)

CSV.open(csv_filename, "wb") do |csv|
  cards.each do |card|
    question = "#{card[:parents].join(' > ')}<br><br>\n\n<strong>#{card[:question]}</strong>"
    first_level_name = card[:parents].first
    tags = [root_name, "import-#{timestamp}"]
    tags << first_level_name if first_level_name
    tags_string = tags.map {|tag| tag.gsub(/[\t ]+/, "-")}.join(" ")

    csv << [ 
      question, 
      card[:html],
      tags_string
    ]
  end
end
