module ApplicationHelper

  def nav_link(link_text, link_path, options=nil)
    class_name = current_page?(link_path) ? 'active' : nil
    class_name = 'active' if current_page?(root_path) and link_path == '/home'
    content_tag(:li, :class => class_name) do
      link_to link_text, link_path, options
    end
  end

end
