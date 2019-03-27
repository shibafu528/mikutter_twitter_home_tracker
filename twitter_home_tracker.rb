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
    
    followings = (Plugin[:followingcontrol].relation.followings[twitter.user_obj] || []).compact

    Plugin.call(:update, twitter, twitter_msgs.select { |m| forwardable_message?(twitter, followings, m) })
  end

  def forwardable_message?(service, followings, msg)
    # リプライは自分かフォロイーに向いているものに限定して転送する
    # (昔ながらのin_reply_toを持たない手打ちのリプライも対象)
    # in_reply_toが付与されているが自己宛で@から始まっていないスレッドツイートや、メンションの場合は全て転送する
    mentions = msg.receive_user_screen_names
    if !mentions.empty? && msg.body.start_with?("@")
      followings.include?(msg.user) && mentions.any? { |idname|
        service.idname == idname || followings.any? { |u| u.idname == idname }
      }
    else
      followings.include?(msg.user)
    end
  end

end
