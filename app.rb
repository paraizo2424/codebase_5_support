
require 'sinatra'
require 'sinatra/reloader'
require 'mysql2'
require 'mysql2-cs-bind'
require 'sinatra/cookies'

enable :sessions

def db
  @db ||= Mysql2::Client.new(
    host: 'localhost',
    username: 'root',
    password: 'root',
    database: 'modoki'
  )
end

def my_info
  @my_info = db.xquery('select * from users where id = ?', session[:login_user_id]).map{ |i| i }.first
end

def login_check
  redirect '/login' unless session[:login_user_id]
end

get '/' do
  login_check
  @title = 'TOP'

  @res = db.xquery('select distinct vs.id, vs.creater_id, vs.name, vs.img_path, vs.msg, vs.created_at, vs.updated_at, f.from_user_id follow_from_user_id, l.from_user_id like_from_user_id from view_sub vs left outer join follows f on vs.creater_id = (select to_user_id from follows where to_user_id = vs.creater_id && from_user_id = ?) left outer join likes l on vs.id = (select to_post_id from likes where to_post_id = vs.id && from_user_id = ?) where (f.from_user_id is null || f.from_user_id = ?) && (l.from_user_id is null || l.from_user_id = ?) order by vs.id asc;', session[:login_user_id], session[:login_user_id], session[:login_user_id], session[:login_user_id])

  erb :top, layout: :layout
end

post '/save' do

  temp_filename = ((0..9).to_a + ("a".."z").to_a + ("A".."Z").to_a).sample(30).join
  temp_filename += ('.' + params[:up_img][:type].split('/').last)

  FileUtils.mv(params[:up_img][:tempfile], "./public/up_images/#{temp_filename}")

  up_msg = params[:up_msg]
  up_msg ||= ''

  db.xquery('insert into posts(creater_id, img_path, msg) values(?, ?, ?);', session[:login_user_id], temp_filename, up_msg)

  cookies[:msg] = '成功： 投稿が正常に保存されました'

  redirect '/'
end

get '/login' do
  @title = 'LOGIN'
  erb :login, layout: :layout
end

post '/login' do
  res = db.xquery('select * from users where name = ? && pass = ?', params[:l_name], params[:l_pass]).first
  if res
    cookies[:msg] = '成功： ログインしました'
    session[:login_user_id] = res['id']
    cookies[:l_name] = nil
  else

    session[:login_user_id] = nil
    cookies[:l_name] = params['l_name']

    unless db.xquery('select id from users where name = ?', params[:l_name]).first
      cookies[:msg] = '失敗： そのNameのユーザーは存在しません'
    else
      cookies[:msg] = '失敗： パスワードが間違っています'
    end

  end
  redirect '/'
end

get '/signup' do
  @title = 'SIGNUP'
  erb :signup
end

post '/signup' do

  cookies[:s_name] = params['s_name']

  unless params[:s_pass] == params[:s_pass_re]
    cookies[:msg] = '失敗： パスワードが一致しません'
    redirect '/signup'
  end

  res = db.xquery('select name from users where name = ?;', params[:s_name]).first

  s_profile = params[:s_profile]
  s_profile ||= ''

  p s_profile

  unless res
    db.xquery('insert into users values(null, ?, ?, ?, ?)', params[:s_name], params[:s_pass], s_profile, 'default_user_icon.jpg')

    res2 = db.xquery('select * from users where name = ? && pass = ?', params[:s_name], params[:s_pass]).first

    cookies[:msg] = '成功： ログインしました'
    session[:login_user_id] = res2['id']
    cookies[:s_name] = nil

    redirect '/'
  else
    cookies[:msg] = '失敗： そのnameは使用されています'
    redirect '/signup'
  end
end

get '/logout' do
  session[:login_user_id] = nil
  redirect '/'
end

get '/follow/:to_user_id' do
  login_check

  # 一応、フォローされていないか確認する
  temp = db.xquery('select to_user_id from follows where from_user_id = ? && to_user_id = ?', session[:login_user_id], params[:to_user_id]).first
  redirect '/' if temp

  db.xquery('insert into follows values(null, ?, ?)', session[:login_user_id], params[:to_user_id])

  cookies[:msg] = '成功： フォローに成功しました'

  redirect '/'
end

get '/unfollow/:to_user_id' do
  login_check

  # 一応、フォローされているか確認する
  temp = db.xquery('select to_user_id from follows where from_user_id = ? && to_user_id = ?', session[:login_user_id], params[:to_user_id]).first
  redirect '/' unless temp

  db.xquery('delete from follows where from_user_id = ? && to_user_id = ?;', session[:login_user_id], params[:to_user_id])

  cookies[:msg] = '成功： フォロー解除に成功しました'

  redirect '/'
end

get '/follow_list' do
  login_check
  @title = 'FOLLOE_LIST'
  @res= db.xquery('select f.to_user_id, u.name from follows f left outer join users u on f.to_user_id = u.id where from_user_id = ? order by f.to_user_id asc;', session[:login_user_id])
  erb :follow_list
end

get '/follower_list' do
  login_check
  @title = 'FOLLOEER_LIST'
  @res= db.xquery('select f.from_user_id, u.name from follows f left outer join users u on f.from_user_id = u.id where to_user_id = ? order by f.from_user_id asc;', session[:login_user_id])
  erb :follower_list
end

get '/like/:to_post_id' do
  login_check

  # 一応、いいねされていないか確認する
  temp = db.xquery('select to_post_id from likes where from_user_id = ? && to_post_id = ?', session[:login_user_id], params[:to_post_id]).first
  redirect '/' if temp

  db.xquery('insert into likes values(null, ?, ?)', session[:login_user_id], params[:to_post_id])

  cookies[:msg] = '成功： いいねに成功しました'

  redirect '/'
end

get '/unlike/:to_post_id' do
  login_check

  # 一応、いいねされているか確認する
  temp = db.xquery('select to_post_id from likes where from_user_id = ? && to_post_id = ?', session[:login_user_id], params[:to_post_id]).first
  redirect '/' unless temp

  db.xquery('delete from likes where from_user_id = ? && to_post_id = ?;', session[:login_user_id], params[:to_post_id])

  cookies[:msg] = '成功： いいね解除に成功しました'

  redirect '/'
end

get '/like_list' do
  login_check
  @title = 'LIKE_LIST'
  @res= db.xquery('select to_post_id from likes where from_user_id = ? order by to_post_id asc;', session[:login_user_id])
  erb :like_list
end

get '/edit_profile' do
  login_check
  @title = 'PROFILE_EDIT'
  erb :edit_profile
end

post '/edit_profile' do
  new_profile = params[:new_profile]
  new_profile ||= ''

  new_icon_img_filename = ''
  if params[:new_icon_img]
    new_icon_img_filename = ((0..9).to_a + ("a".."z").to_a + ("A".."Z").to_a).sample(30).join
    new_icon_img_filename += ('.' + params[:new_icon_img][:type].split('/').last)

    FileUtils.mv(params[:new_icon_img][:tempfile], "./public/user_icon_images/#{new_icon_img_filename}")
  else
    new_icon_img_filename = 'default_user_icon.jpg'
  end

  db.xquery('update users set profile = ?, icon_img_path = ? where id = ?;', new_profile, new_icon_img_filename, session[:login_user_id])
  redirect '/edit_profile'
end
