require 'rexml/document'
include REXML

module GData #:nodoc:
  class RequestMessage < Document #:nodoc:
     # creates the object and initiates the construction
     def initialize
        super '<?xml version="1.0" encoding="UTF-8"?>'
        self.add_element "atom:entry", {"xmlns:apps" => "http://schemas.google.com/apps/2006",
                                        "xmlns:atom" => "http://www.w3.org/2005/Atom"}
     end

     # adds <atom:id> element in the message body. Url is inserted as a text.
     def add_path(url)
        self.elements["atom:entry"].add_element "atom:id"
        self.elements["atom:entry/atom:id"].text = url
     end
  end
end
