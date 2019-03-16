# -*- coding: utf-8 -*-

Plugin.create(:twitter_home_tracker) do

  filter_filter_stream_follow do |targets|
    birds = Enumerator.new { |y|
      Plugin.filtering(:worlds, y)
    }.select { |world|
      world.class.slug == :twitter
    }

    [targets + birds.map { |bird| Plugin[:followingcontrol].relation.followings[bird.user_obj] || [] }.inject(:+) ]
  end

  # フォロイー情報が変動したらFilterStreamの再接続を要求する。
  # :filter_stream_reconnect_request は短時間に連続で呼んでも問題ないので、こちらでは何も考えずに呼ぶ。

  on_followings_modified do |service, followings|
    Plugin.call(:filter_stream_reconnect_request)
  end

  on_followings_created do |service, created|
    Plugin.call(:filter_stream_reconnect_request)
  end

  on_followings_destroy do |service, destroyed|
    Plugin.call(:filter_stream_reconnect_request)
  end

  # Twitter Worldのメッセージ着信のうち、FilterStreamのfollowパラメータによって
  # 得られた可能性のあるものをHome Timelineに転送する。

  on_appear do |msgs|
    twitter_msgs = msgs.select { |m| m.class.slug == :twitter_tweet }
    next if twitter_msgs.empty?

    # streaming PluginのFilterStream接続処理におけるWorld特定と同じコードで
    # :update イベントの引数に設定するWorldを決定する。
    # もし、streaming Pluginで複数アカウントの取り回しに対応するようであれば、
    # 不正確な受信Worldを伝達することになってしまうので、考えなおしたほうが良いかも。
    twitter = Enumerator.new { |y|
      Plugin.filtering(:worlds, y)
    }.find { |world|
      world.class.slug == :twitter
    }
    
    followings = Plugin[:followingcontrol].relation.followings[twitter.user_obj] || []

    Plugin.call(:update, twitter, twitter_msgs.select { |m| forwardable_message?(twitter, followings, m) })
  end

  def forwardable_message?(service, followings, msg)
    # TODO: 本文がメンションから始まるツイートの場合「自己宛リプ」「メンションされている」「フォロイーにメンションしている」
    #       に絞って転送する必要がある。そうしないとHomeに無関係のツイートが流入する。
    followings.include?(msg.user)
  end

end
