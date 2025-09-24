class ApplicationController < ActionController::Base
  def hello
    render html: "hello world! - from Rails"
  end

  def goodbye
    render html: "goodbye world - from Rails"
  end
end
