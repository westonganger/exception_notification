class PostsController < ApplicationController
  def show
    render :show
  end

  def create
    @sections = Object.new
    # Have this line raise an exception
    Object.nw
  end
end
