module StuffToDoHelper
  # BAD BAD :(
  # Copied from redmine_tags helper
  include ActsAsTaggableOn::TagsHelper
  include FiltersHelper
  # END Copied from redmine_tags helper

  def progress_bar_sum(collection, field, opts)
    issues = remove_non_issues(collection)

    total = issues.inject(0) {|sum, n| sum + n.read_attribute(field) }
    divisor = issues.length
    return if divisor.nil? || divisor == 0

    progress_bar(total / divisor, opts)
  end

  def total_estimates(issues)
    remove_non_issues(issues).collect(&:estimated_hours).compact.sum
  end

  def filter_options(filters, selected = nil)
    html = options_for_select([[l(:stuff_to_do_label_filter_by), '']]) # Blank

    filters.each do |filter_group, options|
      next unless [:users, :priorities, :statuses, :projects].include?(filter_group)
      if filter_group == :projects
        # Projects only needs a single item
        html << content_tag(:option,
                            filter_group.to_s.capitalize,
                            :value => 'projects',
                            :style => 'font-weight: bold')
      else
        html << content_tag(:optgroup,
                            options_for_select(options.collect { |item| [item.to_s, filter_group.to_s + '-' + item.id.to_s]}, selected),
                            :label => filter_group.to_s.capitalize )
      end
    end

    return html
  end

  # Returns the stuff for a collection of StuffToDo items, removing anything
  # that have been deleted.
  def stuff_for(stuff_to_do_items)
    return stuff_to_do_items.collect(&:stuff).compact
  end

  # Returns the issues for a collection of StuffToDo items, removing anything
  # that have been deleted or isn't an Issue
  def issues_for(stuff_to_do_items)
    return remove_non_issues(stuff_to_do_items.collect(&:stuff).compact)
  end

  def remove_non_issues(stuff_to_do_items)
    stuff_to_do_items.reject {|item| item.class != Issue }
  end

  def total_hours_for_user_on_day(issue, user, date)
    total = issue.time_entries.inject(0.0) {|sum, time_entry|
      if time_entry.user_id == user.id && time_entry.spent_on == date
        sum += time_entry.hours
      end
      sum
    }

    total != 0.0 ? total : nil
  end

  def total_hours_for_issue_for_user(issue, user)
    total = issue.time_entries.inject(0.0) {|sum, time_entry|
      if time_entry.user_id == user.id
        sum += time_entry.hours
      end
      sum
    }
    total
  end

  def total_hours_for_date(issues, user, date)
    issues.collect {|issue| total_hours_for_user_on_day(issue, user, date)}.compact.sum
  end

  def total_hours_for_user(issues, user)
    issues.collect {|issue| total_hours_for_issue_for_user(issue, user)}.compact.sum
  end

  # Redmine 0.8.x compatibility
  def l_hours(hours)
    hours = hours.to_f
    l((hours < 2.0 ? :label_f_hour : :label_f_hour_plural), ("%.2f" % hours.to_f))
  end unless Object.method_defined?('l_hours')


  ##########################################
  # BAD BAD BAD :(
  # Copied from redmine_tags helper.
  ##########################################

  # Returns tag link
  # === Parameters
  # * <i>tag</i> = Instance of Tag
  # * <i>options</i> = (optional) Options (override system settings)
  #   * show_count  - Boolean. Whenever show tag counts
  #   * open_only   - Boolean. Whenever link to the filter with "open" issues
  #                   only limit.
  def render_tag_link(tag, options = {})
    filters = [[:tags, '=', tag.name]]
    filters << [:status_id, 'o'] if options[:open_only]
    if options[:use_search]
      content =  link_to(tag, {:controller => "search", :action => "index", :id => @project, :q => tag.name, :wiki_pages => true, :issues => true})
    else
      content = link_to_filter tag.name, filters, :project_id => @project
    end
    if options[:show_count]
      content << content_tag('span', "(#{tag.count})", :class => 'tag-count')
    end

    style = RedmineTags.settings[:issues_use_colors].to_i > 0 ? {:class => "tag-label-color", :style => "background-color: #{tag_color(tag)}"} : {:class => "tag-label"}
    content_tag('span', content, style)
  end

  def tag_color(tag)
    tag_name = tag.respond_to?(:name) ? tag.name : tag
    "##{Digest::MD5.hexdigest(tag_name)[0..5]}"
  end

  # Renders list of tags
  # Clouds are rendered as block <tt>div</tt> with internal <tt>span</t> per tag.
  # Lists are rendered as unordered lists <tt>ul</tt>. Lists are ordered by
  # <tt>tag.count</tt> descending.
  # === Parameters
  # * <i>tags</i> = Array of Tag instances
  # * <i>options</i> = (optional) Options (override system settings)
  #   * show_count  - Boolean. Whenever show tag counts
  #   * open_only   - Boolean. Whenever link to the filter with "open" issues
  #                   only limit.
  #   * style       - list, cloud
  def render_tags_list(tags, options = {})
    unless tags.nil? or tags.empty?
      content, style = '', options.delete(:style)

      # prevent ActsAsTaggableOn::TagsHelper from calling `all`
      # otherwise we will need sort tags after `tag_cloud`
      tags = tags.all if tags.respond_to?(:all)

      case sorting = "#{RedmineTags.settings[:issues_sort_by]}:#{RedmineTags.settings[:issues_sort_order]}"
      when "name:asc";    tags.sort! { |a,b| a.name <=> b.name }
      when "name:desc";   tags.sort! { |a,b| b.name <=> a.name }
      when "count:asc";   tags.sort! { |a,b| a.count <=> b.count }
      when "count:desc";  tags.sort! { |a,b| b.count <=> a.count }
        # Unknown sorting option. Fallback to default one
      else
        logger.warn "[redmine_tags] Unknown sorting option: <#{sorting}>"
        tags.sort! { |a,b| a.name <=> b.name }
      end

      if :list == style
        list_el, item_el = 'ul', 'li'
      elsif  :simple_cloud == style
        list_el, item_el = 'div', 'span'
      elsif :cloud == style
        list_el, item_el = 'div', 'span'
        tags = cloudify(tags)
      else
        raise "Unknown list style"
      end

      content = content.html_safe
      tag_cloud tags, (1..8).to_a do |tag, weight|
        content << " ".html_safe + content_tag(item_el, render_tag_link(tag, options), :class => "tag-nube-#{weight}", :style => (:simple_cloud == style ? "font-size: 1em;" : "")) + " ".html_safe
      end

      content_tag(list_el, content, :class => 'tags', :style => (:simple_cloud == style ? "text-align: left;" : ""))
    end
  end

  private

  # make snowball. first tags comes in th middle.
  def cloudify(tags)
    temp, tags, trigger = tags, [], true
    temp.each do |tag|
      tags.send((trigger ? 'push' : 'unshift'), tag)
      trigger = !trigger
    end
    tags
  end

end
