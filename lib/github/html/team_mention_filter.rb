module GitHub::HTML
  # HTML filter that replaces @user mentions with links. Mentions within <pre>,
  # <code>, and <a> elements are ignored. Mentions that reference users that do
  # not exist are ignored.
  #
  # Context options:
  #   :base_url - Used to construct links to user profile pages for each
  #               mention.
  #
  # The following keys are written to the context hash:
  #   :mentioned_teams - An array of User objects that were mentioned.
  #
  class TeamMentionFilter < Filter
    # Public: Find team @mentions in text.  See
    # MentionFilter#mention_link_filter.
    #
    #   MentionFilter.mentioned_logins_in(text) do |match, login, is_mentioned|
    #     "<a href=...>#{login}</a>"
    #   end
    #
    # text - String text to search.
    #
    # Yields the String match, the String login name, and a Boolean determining
    # if the match = "@mention[ed]".  The yield's return replaces the match in
    # the original text.
    #
    # Returns a String replaced with the return of the block.
    def self.mentioned_logins_in(text)
      text.gsub MentionPattern do |match|
        org = $1
        team = $2
        yield match, org, team
      end
    end

    MentionPattern = /
      (?:^|\W)                   # beginning of string or non-word char
      @([a-z0-9][a-z0-9-]+)      # @organization
        \/                       # dividing slash
        ([a-z0-9][a-z0-9-]+)     # team
      (?=
        \.[ \t]|                 # dot followed by space
        \.$|                     # dot at end of line
        [^0-9a-zA-Z_.]|          # non-word character except dot
        $                        # end of line
      )
    /ix

    MentionedLoginPattern = /^mention(s|ed|)$/

    def call
      mentioned_teams.clear
      doc.search('text()').each do |node|
        content = node.to_html
        next if !content.include?('@')
        next if has_ancestor?(node, %w(pre code a))
        html = mention_link_filter(content, base_url)
        next if html == content
        node.replace(html)
      end
      mentioned_teams.uniq!
      doc
    end

    # List of Team objects that were mentioned in the document. This is
    # available in the context hash as :mentioned_teams.
    def mentioned_teams
      context[:mentioned_teams] ||= []
    end

    # Replace team @mentions in text with...something
    #
    # text      - String text to replace @mention team names in.
    # base_url  - The base URL used to construct user profile URLs.
    #
    # Returns a string with @mentions replaced with #TODO. All links have a
    # 'team-mention' class name attached for styling.
    def mention_link_filter(text, base_url='/')
      self.class.mentioned_logins_in(text) do |match, org_name, team_name|
        link = if org = Organization.find_by_login(org_name)
          if team = org.teams.find_by_name(team_name)
            mentioned_teams << team
            link_to_mentioned_user(team)
          end
        end

        link ? match.sub(match, link) : match
      end
    end

    def link_to_mentioned_user(team)
      %|<span class='team-mention'>@#{team.organization.login}/#{team.name}</span>|
    end
  end
end